from datetime import datetime, timedelta, timezone
from pathlib import Path

import httpx
import pytest

from app.perf.collector import (
    CollectionBlocked,
    Collector,
    CollectorPolicy,
    is_challenge,
)
from app.perf.collector_store import CollectionTask, CollectorStore


NOW = datetime(2026, 7, 12, 8, 0, tzinfo=timezone.utc)
HTML = """
<table>
<tr><th>Resolution</th><th>Average</th><th>Minimum</th><th>Maximum</th><th>Bottleneck</th></tr>
<tr><td>1920x1080</td><td>77</td><td>66</td><td>89</td><td>GPU 5%</td></tr>
<tr><td>2560x1440</td><td>58</td><td>49</td><td>66</td><td>GPU 8%</td></tr>
<tr><td>3840x2160</td><td>38</td><td>32</td><td>44</td><td>balanced 0%</td></tr>
</table>
"""


def seed(store: CollectorStore, *names: str, host: str = "pc-builds.com") -> None:
    store.seed_tasks(
        [
            CollectionTask(
                cpu_id=f"cpu-{name}",
                gpu_id=f"gpu-{name}",
                game_id=f"game-{name}",
                source_url=f"https://{host}/{name}",
            )
            for name in names
        ]
    )


def collector(
    store: CollectorStore,
    handler,
    *,
    policy: CollectorPolicy = CollectorPolicy(delay_seconds=0, jitter_seconds=0),
    sleep=lambda _: None,
    random_uniform=lambda _start, _end: 0,
    now=lambda: NOW,
) -> Collector:
    return Collector(
        store,
        httpx.Client(transport=httpx.MockTransport(handler)),
        policy,
        sleep=sleep,
        random_uniform=random_uniform,
        now=now,
    )


@pytest.mark.parametrize(
    "kwargs",
    [
        {"delay_seconds": -1},
        {"jitter_seconds": -1},
        {"max_attempts": 0},
        {"timeout_seconds": 0},
        {"delay_seconds": float("nan")},
        {"jitter_seconds": float("inf")},
        {"max_attempts": 1.5},
        {"timeout_seconds": float("inf")},
    ],
)
def test_policy_rejects_invalid_values(kwargs: dict) -> None:
    with pytest.raises(ValueError):
        CollectorPolicy(**kwargs)


@pytest.mark.parametrize(
    "marker", ["challenge-platform", "cf-chl", "captcha", "Just a moment"]
)
def test_challenge_detection_is_case_insensitive_and_limited_to_first_20k(
    marker: str,
) -> None:
    assert is_challenge(httpx.Response(200, text=marker.upper()))
    assert is_challenge(httpx.Response(200, text="中" * 19_980 + marker))
    assert not is_challenge(httpx.Response(200, text="x" * 20_000 + marker))


def test_success_records_rows_hash_and_sends_only_safe_get_headers(tmp_path: Path) -> None:
    store = CollectorStore(tmp_path / "collector.sqlite")
    seed(store, "one")

    def handler(request: httpx.Request) -> httpx.Response:
        assert request.method == "GET"
        assert "AI PC Builder FPS Collector" in request.headers["user-agent"]
        assert "cookie" not in request.headers
        assert "authorization" not in request.headers
        return httpx.Response(200, text=HTML)

    summary = collector(store, handler).run()

    assert summary.processed == summary.succeeded == 1
    assert store.task_counts() == {"succeeded": 1}
    assert [row.average_fps for row in store.results_for_task(1)] == [77, 58, 38]
    assert len(store.successful_records()[0]["response_hash"]) == 64


def test_set_cookie_from_one_response_is_not_sent_to_the_next_task(
    tmp_path: Path,
) -> None:
    store = CollectorStore(tmp_path / "collector.sqlite")
    seed(store, "one", "two")
    requests = []

    def handler(request: httpx.Request) -> httpx.Response:
        requests.append(request)
        assert "cookie" not in request.headers
        if len(requests) == 1:
            return httpx.Response(
                200,
                text=HTML,
                headers={"Set-Cookie": "session=secret; Path=/"},
            )
        return httpx.Response(404)

    summary = collector(store, handler).run()

    assert summary.processed == 2
    assert len(requests) == 2


@pytest.mark.parametrize("credential", ["header", "auth"])
def test_preloaded_client_credentials_are_not_sent(
    tmp_path: Path, credential: str
) -> None:
    store = CollectorStore(tmp_path / "collector.sqlite")
    seed(store, "one")
    requests = []
    kwargs = {"auth": ("user", "password")} if credential == "auth" else {}

    def handler(request: httpx.Request) -> httpx.Response:
        requests.append(request)
        return httpx.Response(400)

    client = httpx.Client(
        transport=httpx.MockTransport(handler),
        headers={"Authorization": "Bearer secret"} if credential == "header" else None,
        cookies={"session": "secret"},
        **kwargs,
    )

    summary = Collector(
        store,
        client,
        CollectorPolicy(delay_seconds=0, jitter_seconds=0),
        sleep=lambda _: None,
        now=lambda: NOW,
    ).run()

    assert summary.failed == 1
    assert len(requests) == 1
    assert "cookie" not in requests[0].headers
    assert "authorization" not in requests[0].headers


def test_redirect_is_not_followed_and_is_recorded_failed(tmp_path: Path) -> None:
    store = CollectorStore(tmp_path / "collector.sqlite")
    seed(store, "redirect")
    hosts = []

    def handler(request: httpx.Request) -> httpx.Response:
        hosts.append(request.url.host)
        return httpx.Response(302, headers={"Location": "https://evil.example/secret"})

    client = httpx.Client(
        transport=httpx.MockTransport(handler),
        follow_redirects=True,
    )
    summary = Collector(
        store,
        client,
        CollectorPolicy(delay_seconds=0, jitter_seconds=0),
        sleep=lambda _: None,
        now=lambda: NOW,
    ).run()

    assert summary.failed == 1
    assert hosts == ["pc-builds.com"]
    assert store.task_counts() == {"failed": 1}


def test_404_records_missing(tmp_path: Path) -> None:
    store = CollectorStore(tmp_path / "collector.sqlite")
    seed(store, "gone")

    summary = collector(store, lambda _: httpx.Response(404)).run()

    assert summary.missing == 1
    assert store.task_counts() == {"missing": 1}


@pytest.mark.parametrize("kind", ["transport", "server"])
def test_transport_and_5xx_retry_then_become_failed(tmp_path: Path, kind: str) -> None:
    store = CollectorStore(tmp_path / "collector.sqlite")
    seed(store, "flaky")
    current = [NOW]

    def handler(request: httpx.Request) -> httpx.Response:
        if kind == "transport":
            raise httpx.ConnectError("offline", request=request)
        return httpx.Response(503)

    runner = collector(store, handler, now=lambda: current[0])
    assert runner.run().retryable == 1
    current[0] += timedelta(seconds=2)
    assert runner.run().retryable == 1
    current[0] += timedelta(seconds=4)
    assert runner.run().failed == 1
    assert store.task_counts() == {"failed": 1}


def test_retry_uses_simple_exponential_backoff(tmp_path: Path) -> None:
    store = CollectorStore(tmp_path / "collector.sqlite")
    seed(store, "flaky")
    runner = collector(store, lambda _: httpx.Response(500))

    assert runner.run().retryable == 1
    assert store.claim_next(NOW + timedelta(seconds=1)) is None
    assert store.claim_next(NOW + timedelta(seconds=2)) is not None


@pytest.mark.parametrize(
    ("status", "headers", "reason"),
    [(403, {}, "403"), (429, {"Retry-After": "120"}, "retry_after=120")],
)
def test_blocking_status_pauses_without_sleeping(
    tmp_path: Path, status: int, headers: dict, reason: str
) -> None:
    store = CollectorStore(tmp_path / "collector.sqlite")
    seed(store, "blocked")
    sleeps = []

    with pytest.raises(CollectionBlocked, match=reason):
        collector(
            store,
            lambda _: httpx.Response(status, headers=headers),
            sleep=sleeps.append,
        ).run()

    assert store.task_counts() == {"blocked": 1}
    assert reason in store.pause_reason()
    assert sleeps == []


def test_200_challenge_blocks_and_pauses(tmp_path: Path) -> None:
    store = CollectorStore(tmp_path / "collector.sqlite")
    seed(store, "challenge")

    with pytest.raises(CollectionBlocked, match="challenge"):
        collector(store, lambda _: httpx.Response(200, text="Just a moment")).run()

    assert store.task_counts() == {"blocked": 1}


def test_three_consecutive_parse_failures_pause_collection(tmp_path: Path) -> None:
    store = CollectorStore(tmp_path / "collector.sqlite")
    seed(store, "one", "two", "three", "four")

    with pytest.raises(CollectionBlocked, match="parse_error_threshold"):
        collector(store, lambda _: httpx.Response(200, text="not a table")).run()

    assert store.task_counts() == {"parse_failed": 3, "pending": 1}
    assert store.pause_reason() == "parse_error_threshold"


def test_success_resets_consecutive_parse_failure_count(tmp_path: Path) -> None:
    store = CollectorStore(tmp_path / "collector.sqlite")
    seed(store, "bad-1", "good", "bad-2", "bad-3")

    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(200, text=HTML if request.url.path == "/good" else "bad")

    summary = collector(store, handler).run()

    assert summary.parse_failed == 3
    assert summary.succeeded == 1
    assert store.pause_reason() is None


def test_sleep_uses_delay_and_jitter_only_between_processed_tasks(tmp_path: Path) -> None:
    store = CollectorStore(tmp_path / "collector.sqlite")
    seed(store, "one", "two")
    sleeps = []
    uniform_calls = []

    def uniform(start: float, end: float) -> float:
        uniform_calls.append((start, end))
        return 0.25

    summary = collector(
        store,
        lambda _: httpx.Response(404),
        policy=CollectorPolicy(delay_seconds=2, jitter_seconds=0.4),
        sleep=sleeps.append,
        random_uniform=uniform,
    ).run()

    assert summary.processed == 2
    assert uniform_calls == [(0, 0.4)]
    assert sleeps == [2.25]


def test_max_tasks_limits_claimed_tasks(tmp_path: Path) -> None:
    store = CollectorStore(tmp_path / "collector.sqlite")
    seed(store, "one", "two")

    summary = collector(store, lambda _: httpx.Response(404)).run(max_tasks=1)

    assert summary.processed == 1
    assert store.task_counts() == {"missing": 1, "pending": 1}


@pytest.mark.parametrize(
    "url",
    [
        "http://pc-builds.com/result",
        "https://pc-builds.com.evil.test/result",
        "https://evil.test/?next=pc-builds.com",
        "https://pc-builds.com:bad/result",
        "https://[pc-builds.com/result",
    ],
)
def test_untrusted_source_url_fails_without_request(tmp_path: Path, url: str) -> None:
    store = CollectorStore(tmp_path / "collector.sqlite")
    store.seed_tasks([CollectionTask("cpu", "gpu", "game", url)])
    requests = []

    summary = collector(store, requests.append).run()

    assert summary.failed == 1
    assert requests == []
    assert store.task_counts() == {"failed": 1}
