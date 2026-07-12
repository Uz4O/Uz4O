import inspect
import sqlite3
from datetime import datetime, timedelta, timezone
from pathlib import Path

import pytest

from app.perf.collector_parser import ParsedPerformanceRow
from app.perf.collector_store import CollectionTask, CollectorStore


NOW = datetime(2026, 7, 12, 8, 0, tzinfo=timezone.utc)


def task(name: str) -> CollectionTask:
    return CollectionTask(
        cpu_id=f"cpu-{name}",
        gpu_id=f"gpu-{name}",
        game_id=f"game-{name}",
        source_url=f"https://example.test/{name}",
    )


def rows(offset: int = 0):
    return [
        ParsedPerformanceRow("1080p", 80 + offset, 70, 90 + offset, "cpu", 10),
        ParsedPerformanceRow("2k", 60 + offset, 50, 70 + offset, "gpu", 8),
        ParsedPerformanceRow("4k", 40 + offset, 30, 50 + offset, "balanced", 0),
    ]


def test_seed_ignores_duplicate_urls_in_input_and_across_calls(tmp_path: Path) -> None:
    store = CollectorStore(tmp_path / "nested" / "collector.sqlite3")

    assert store.seed_tasks([task("one"), task("one"), task("two")]) == 2
    assert store.seed_tasks([task("one"), task("two")]) == 0
    assert store.task_counts() == {"pending": 2}


def test_result_schema_uses_parser_field_names_and_fps_checks(tmp_path: Path) -> None:
    path = tmp_path / "collector.sqlite3"
    store = CollectorStore(path)
    store.seed_tasks([task("one")])
    claimed = store.claim_next(NOW)
    assert claimed is not None

    with sqlite3.connect(path) as connection:
        columns = [row[1] for row in connection.execute("PRAGMA table_info(result)")]
        assert columns == [
            "task_id",
            "resolution",
            "average_fps",
            "minimum_fps",
            "maximum_fps",
            "bottleneck_type",
            "bottleneck_percent",
        ]
        with pytest.raises(sqlite3.IntegrityError):
            connection.execute(
                """
                INSERT INTO result
                    (task_id, resolution, average_fps, minimum_fps, maximum_fps)
                VALUES (?, '1080p', 80, -1, 90)
                """,
                (claimed.id,),
            )


def test_claims_oldest_task_and_increments_attempts(tmp_path: Path) -> None:
    store = CollectorStore(tmp_path / "collector.sqlite3")
    store.seed_tasks([task("oldest"), task("newer")])

    claimed = store.claim_next(NOW)

    assert claimed is not None
    assert (claimed.source_url, claimed.attempts) == (
        "https://example.test/oldest",
        1,
    )
    assert store.task_counts() == {"fetching": 1, "pending": 1}


def test_claim_implementation_does_not_require_sqlite_returning() -> None:
    assert "RETURNING" not in inspect.getsource(CollectorStore.claim_next).upper()


def test_reopening_recovers_interrupted_fetching_task(tmp_path: Path) -> None:
    path = tmp_path / "collector.sqlite3"
    first_store = CollectorStore(path)
    first_store.seed_tasks([task("one")])
    first_claim = first_store.claim_next(NOW)
    assert first_claim is not None

    recovered = CollectorStore(path).claim_next(NOW + timedelta(minutes=1))

    assert recovered is not None
    assert (recovered.id, recovered.attempts) == (first_claim.id, 2)


def test_future_retry_is_skipped_until_due(tmp_path: Path) -> None:
    store = CollectorStore(tmp_path / "collector.sqlite3")
    store.seed_tasks([task("one")])
    claimed = store.claim_next(NOW)
    assert claimed is not None
    store.record_retryable(claimed.id, "rate limited", NOW + timedelta(hours=1))

    assert store.claim_next(NOW + timedelta(minutes=59)) is None
    due = store.claim_next(NOW + timedelta(hours=1))
    assert due is not None
    assert due.attempts == 2


def test_pause_persists_across_reopen_and_resume_does_not_rewrite_tasks(
    tmp_path: Path,
) -> None:
    path = tmp_path / "collector.sqlite3"
    store = CollectorStore(path)
    store.seed_tasks([task("one")])
    store.pause_all("manual review")

    reopened = CollectorStore(path)
    assert reopened.pause_reason() == "manual review"
    assert reopened.claim_next(NOW) is None
    assert reopened.task_counts() == {"pending": 1}

    reopened.resume_all()
    assert reopened.pause_reason() is None
    assert reopened.task_counts() == {"pending": 1}
    assert reopened.claim_next(NOW) is not None


def test_paused_claim_does_not_recover_fetching_task(tmp_path: Path) -> None:
    store = CollectorStore(tmp_path / "collector.sqlite3")
    store.seed_tasks([task("one")])
    assert store.claim_next(NOW) is not None
    store.pause_all("forbidden")

    assert store.claim_next(NOW + timedelta(minutes=1)) is None
    assert store.task_counts() == {"fetching": 1}


def test_block_and_pause_persists_and_blocked_task_never_reclaims(
    tmp_path: Path,
) -> None:
    path = tmp_path / "collector.sqlite3"
    store = CollectorStore(path)
    store.seed_tasks([task("one")])
    claimed = store.claim_next(NOW)
    assert claimed is not None

    store.block_and_pause(claimed.id, "403 forbidden")

    assert store.task_counts() == {"blocked": 1}
    assert store.pause_reason() == "403 forbidden"
    with CollectorStore(path) as reopened:
        assert reopened.claim_next(NOW + timedelta(minutes=1)) is None
        reopened.resume_all()
        assert reopened.pause_reason() is None
        assert reopened.claim_next(NOW + timedelta(minutes=2)) is None
        assert reopened.task_counts() == {"blocked": 1}
    with sqlite3.connect(path) as connection:
        state = connection.execute(
            "SELECT status, error, next_attempt_at FROM task WHERE id = ?",
            (claimed.id,),
        ).fetchone()
    assert state == ("blocked", "403 forbidden", None)


def test_success_saves_hash_and_replaces_results_without_duplicates(
    tmp_path: Path,
) -> None:
    path = tmp_path / "collector.sqlite3"
    store = CollectorStore(path)
    store.seed_tasks([task("one")])
    claimed = store.claim_next(NOW)
    assert claimed is not None

    store.record_success(claimed.id, rows(), "hash-one")
    store.record_success(claimed.id, rows(5), "hash-two")

    saved = store.results_for_task(claimed.id)
    assert [row.resolution for row in saved] == ["1080p", "2k", "4k"]
    assert [row.average_fps for row in saved] == [85, 65, 45]
    with sqlite3.connect(path) as connection:
        status, response_hash = connection.execute(
            "SELECT status, response_hash FROM task WHERE id = ?", (claimed.id,)
        ).fetchone()
    assert (status, response_hash) == ("succeeded", "hash-two")


@pytest.mark.parametrize(
    "invalid_rows",
    [
        rows()[:2],
        [rows()[0], rows()[0], rows()[2]],
        [
            rows()[0],
            rows()[1],
            ParsedPerformanceRow("8k", 20, 10, 30, "gpu", 5),
        ],
    ],
    ids=["incomplete", "duplicate", "unknown"],
)
def test_invalid_result_set_preserves_previous_results_status_and_hash(
    tmp_path: Path, invalid_rows: list
) -> None:
    path = tmp_path / "collector.sqlite3"
    store = CollectorStore(path)
    store.seed_tasks([task("one")])
    claimed = store.claim_next(NOW)
    assert claimed is not None
    store.record_success(claimed.id, rows(), "old-hash")

    with pytest.raises(ValueError, match="resolution"):
        store.record_success(claimed.id, invalid_rows, "new-hash")

    assert store.results_for_task(claimed.id) == rows()
    with sqlite3.connect(path) as connection:
        status, response_hash = connection.execute(
            "SELECT status, response_hash FROM task WHERE id = ?", (claimed.id,)
        ).fetchone()
    assert (status, response_hash) == ("succeeded", "old-hash")


@pytest.mark.parametrize(
    "invalid_row",
    [
        ParsedPerformanceRow("1080p", 80, -1, 90, "cpu", 10),
        ParsedPerformanceRow("1080p", 80, 81, 90, "cpu", 10),
        ParsedPerformanceRow("1080p", 91, 70, 90, "cpu", 10),
        ParsedPerformanceRow("1080p", 80, 70, 2001, "cpu", 10),
    ],
    ids=["negative", "minimum-above-average", "average-above-maximum", "over-2000"],
)
def test_invalid_fps_values_preserve_previous_results_status_and_hash(
    tmp_path: Path, invalid_row: ParsedPerformanceRow
) -> None:
    path = tmp_path / "collector.sqlite3"
    store = CollectorStore(path)
    store.seed_tasks([task("one")])
    claimed = store.claim_next(NOW)
    assert claimed is not None
    store.record_success(claimed.id, rows(), "old-hash")

    with pytest.raises(ValueError, match="FPS"):
        store.record_success(claimed.id, [invalid_row, *rows()[1:]], "new-hash")

    assert store.results_for_task(claimed.id) == rows()
    with sqlite3.connect(path) as connection:
        status, response_hash = connection.execute(
            "SELECT status, response_hash FROM task WHERE id = ?", (claimed.id,)
        ).fetchone()
    assert (status, response_hash) == ("succeeded", "old-hash")


def test_database_insert_failure_rolls_back_deleted_results_status_and_hash(
    tmp_path: Path,
) -> None:
    path = tmp_path / "collector.sqlite3"
    store = CollectorStore(path)
    store.seed_tasks([task("one")])
    claimed = store.claim_next(NOW)
    assert claimed is not None
    store.record_success(claimed.id, rows(), "old-hash")
    with sqlite3.connect(path) as connection:
        connection.execute(
            """
            CREATE TRIGGER force_result_insert_failure
            BEFORE INSERT ON result
            BEGIN
                SELECT RAISE(FAIL, 'forced');
            END
            """
        )

    with pytest.raises(sqlite3.DatabaseError, match="forced"):
        store.record_success(claimed.id, rows(5), "new-hash")

    assert store.results_for_task(claimed.id) == rows()
    with sqlite3.connect(path) as connection:
        status, response_hash = connection.execute(
            "SELECT status, response_hash FROM task WHERE id = ?", (claimed.id,)
        ).fetchone()
    assert (status, response_hash) == ("succeeded", "old-hash")


def test_terminal_and_retryable_states_store_expected_error_fields(
    tmp_path: Path,
) -> None:
    path = tmp_path / "collector.sqlite3"
    store = CollectorStore(path)
    store.seed_tasks([task("retry"), task("missing"), task("parse"), task("failed")])
    claimed = store.claim_next(NOW)
    assert claimed is not None
    retry_at = NOW + timedelta(minutes=5)
    store.record_retryable(claimed.id, "temporary", retry_at)
    claimed = store.claim_next(NOW)
    assert claimed is not None
    store.record_missing(claimed.id, "not found")
    claimed = store.claim_next(NOW)
    assert claimed is not None
    store.record_parse_failed(claimed.id, "bad table")
    claimed = store.claim_next(NOW)
    assert claimed is not None
    store.record_failed(claimed.id, "exhausted")

    with sqlite3.connect(path) as connection:
        states = connection.execute(
            "SELECT status, error, next_attempt_at FROM task ORDER BY id"
        ).fetchall()
    assert states == [
        ("retryable", "temporary", retry_at.isoformat()),
        ("missing", "not found", None),
        ("parse_failed", "bad table", None),
        ("failed", "exhausted", None),
    ]


@pytest.mark.parametrize(
    "operation",
    ["retryable", "missing", "parse_failed", "failed", "block_and_pause"],
)
def test_status_updates_reject_unknown_task_ids(
    tmp_path: Path, operation: str
) -> None:
    store = CollectorStore(tmp_path / "collector.sqlite3")

    with pytest.raises(KeyError, match="999"):
        if operation == "retryable":
            store.record_retryable(999, "error", NOW)
        elif operation == "missing":
            store.record_missing(999, "error")
        elif operation == "parse_failed":
            store.record_parse_failed(999, "error")
        elif operation == "failed":
            store.record_failed(999, "error")
        else:
            store.block_and_pause(999, "error")
    assert store.pause_reason() is None


def test_close_and_context_manager_release_connection(tmp_path: Path) -> None:
    path = tmp_path / "collector.sqlite3"
    store = CollectorStore(path)
    store.close()
    with pytest.raises(sqlite3.ProgrammingError):
        store.task_counts()

    with CollectorStore(path) as managed:
        managed.seed_tasks([task("one")])
    with pytest.raises(sqlite3.ProgrammingError):
        managed.task_counts()


def test_task_counts_include_each_present_status(tmp_path: Path) -> None:
    store = CollectorStore(tmp_path / "collector.sqlite3")
    store.seed_tasks([task("success"), task("missing"), task("pending")])
    claimed = store.claim_next(NOW)
    assert claimed is not None
    store.record_success(claimed.id, rows(), "hash")
    claimed = store.claim_next(NOW)
    assert claimed is not None
    store.record_missing(claimed.id, "gone")

    assert store.task_counts() == {"missing": 1, "pending": 1, "succeeded": 1}


def test_parse_failure_counter_pauses_atomically_at_threshold(tmp_path: Path) -> None:
    path = tmp_path / "collector.sqlite3"
    store = CollectorStore(path)
    store.seed_tasks([task("one"), task("two"), task("three")])

    for expected_paused in (False, False, True):
        claimed = store.claim_next(NOW)
        assert claimed is not None
        assert (
            store.record_parse_failure_and_maybe_pause(
                claimed.id, "bad table", threshold=3
            )
            is expected_paused
        )

    with CollectorStore(path) as reopened:
        assert reopened.task_counts() == {"parse_failed": 3}
        assert reopened.pause_reason() == "parse_error_threshold"
        assert reopened.claim_next(NOW) is None


def test_reset_parse_failures_starts_counter_over(tmp_path: Path) -> None:
    store = CollectorStore(tmp_path / "collector.sqlite3")
    store.seed_tasks([task("one"), task("two"), task("three"), task("four")])
    claimed = store.claim_next(NOW)
    assert claimed is not None
    assert not store.record_parse_failure_and_maybe_pause(claimed.id, "bad", 3)
    claimed = store.claim_next(NOW)
    assert claimed is not None
    assert not store.record_parse_failure_and_maybe_pause(claimed.id, "bad", 3)

    store.reset_parse_failures()

    claimed = store.claim_next(NOW)
    assert claimed is not None
    assert not store.record_parse_failure_and_maybe_pause(claimed.id, "bad", 3)
    assert store.pause_reason() is None


def test_has_claimable_observes_due_time_and_pause_without_claiming(
    tmp_path: Path,
) -> None:
    store = CollectorStore(tmp_path / "collector.sqlite3")
    store.seed_tasks([task("one")])
    assert store.has_claimable(NOW)
    assert store.task_counts() == {"pending": 1}
    store.pause_all("manual")
    assert not store.has_claimable(NOW)
    store.resume_all()
    claimed = store.claim_next(NOW)
    assert claimed is not None
    store.record_retryable(claimed.id, "later", NOW + timedelta(seconds=10))
    assert not store.has_claimable(NOW + timedelta(seconds=9))
    assert store.has_claimable(NOW + timedelta(seconds=10))


def test_run_lock_excludes_other_owner_and_releases(tmp_path: Path) -> None:
    path = tmp_path / "collector.sqlite3"
    first = CollectorStore(path)
    second = CollectorStore(path)

    assert first.acquire_run_lock("first", NOW, ttl_seconds=60)
    assert not second.acquire_run_lock("second", NOW, ttl_seconds=60)
    assert first.renew_run_lock("first", NOW + timedelta(seconds=1), 60)
    assert not second.renew_run_lock("second", NOW + timedelta(seconds=1), 60)
    first.release_run_lock("first")
    assert second.acquire_run_lock("second", NOW, ttl_seconds=60)


def test_expired_run_lock_can_be_taken_over(tmp_path: Path) -> None:
    path = tmp_path / "collector.sqlite3"
    first = CollectorStore(path)
    second = CollectorStore(path)

    assert first.acquire_run_lock("first", NOW, ttl_seconds=5)
    assert not first.renew_run_lock("first", NOW + timedelta(seconds=5), 60)
    assert second.acquire_run_lock("second", NOW + timedelta(seconds=5), 60)
    first.release_run_lock("first")
    assert second.renew_run_lock("second", NOW + timedelta(seconds=6), 60)


def test_successful_records_returns_only_succeeded_tasks_in_stable_order(
    tmp_path: Path,
) -> None:
    store = CollectorStore(tmp_path / "collector.sqlite3")
    store.seed_tasks([task("two"), task("one"), task("pending")])
    claimed = store.claim_next(NOW)
    assert claimed is not None
    store.record_success(claimed.id, rows(2), "hash-two")
    claimed = store.claim_next(NOW)
    assert claimed is not None
    store.record_success(claimed.id, rows(1), "hash-one")

    records = store.successful_records()

    assert [record["source_url"] for record in records] == [
        "https://example.test/one",
        "https://example.test/two",
    ]
    assert records[0] == {
        "cpu_id": "cpu-one",
        "gpu_id": "gpu-one",
        "game_id": "game-one",
        "source_url": "https://example.test/one",
        "response_hash": "hash-one",
        "results": [
            {
                "resolution": "1080p",
                "average_fps": 81,
                "minimum_fps": 70,
                "maximum_fps": 91,
                "bottleneck_type": "cpu",
                "bottleneck_percent": 10,
            },
            {
                "resolution": "2k",
                "average_fps": 61,
                "minimum_fps": 50,
                "maximum_fps": 71,
                "bottleneck_type": "gpu",
                "bottleneck_percent": 8,
            },
            {
                "resolution": "4k",
                "average_fps": 41,
                "minimum_fps": 30,
                "maximum_fps": 51,
                "bottleneck_type": "balanced",
                "bottleneck_percent": 0,
            },
        ],
    }


def test_results_enforce_foreign_key_and_cascade_on_task_delete(tmp_path: Path) -> None:
    path = tmp_path / "collector.sqlite3"
    store = CollectorStore(path)
    store.seed_tasks([task("one")])
    claimed = store.claim_next(NOW)
    assert claimed is not None
    store.record_success(claimed.id, rows(), "hash")

    with pytest.raises(sqlite3.IntegrityError):
        store.record_success(9999, rows(), "invalid")

    with sqlite3.connect(path) as connection:
        connection.execute("PRAGMA foreign_keys = ON")
        connection.execute("DELETE FROM task WHERE id = ?", (claimed.id,))
    assert store.results_for_task(claimed.id) == []
