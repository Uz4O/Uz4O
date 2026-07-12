import hashlib
import math
import random
import time
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from typing import Callable, Optional
from urllib.parse import urlsplit

import httpx

from app.perf.collector_parser import ParseError, parse_medium_results
from app.perf.collector_store import CollectorStore, StoredTask


USER_AGENT = "AI PC Builder FPS Collector/1.0 (low-rate public result fetcher)"
ALLOWED_HOSTS = {"pc-builds.com", "www.pc-builds.com"}


@dataclass(frozen=True)
class CollectorPolicy:
    delay_seconds: float = 2.0
    jitter_seconds: float = 0.4
    max_attempts: int = 3
    timeout_seconds: float = 20.0

    def __post_init__(self) -> None:
        if (
            not math.isfinite(self.delay_seconds)
            or not math.isfinite(self.jitter_seconds)
            or self.delay_seconds < 0
            or self.jitter_seconds < 0
        ):
            raise ValueError("delay and jitter must be non-negative")
        if (
            not isinstance(self.max_attempts, int)
            or self.max_attempts <= 0
            or not math.isfinite(self.timeout_seconds)
            or self.timeout_seconds <= 0
        ):
            raise ValueError("max attempts and timeout must be positive")


@dataclass(frozen=True)
class RunSummary:
    processed: int = 0
    succeeded: int = 0
    missing: int = 0
    retryable: int = 0
    failed: int = 0
    parse_failed: int = 0
    blocked: int = 0


class CollectionBlocked(RuntimeError):
    pass


def is_challenge(response: httpx.Response) -> bool:
    text = response.content[:80_000].decode(
        response.encoding or "utf-8", errors="ignore"
    )[:20_000]
    return any(
        marker in text.casefold()
        for marker in ("challenge-platform", "cf-chl", "captcha", "just a moment")
    )


class Collector:
    def __init__(
        self,
        store: CollectorStore,
        client: httpx.Client,
        policy: CollectorPolicy = CollectorPolicy(),
        sleep: Callable[[float], None] = time.sleep,
        random_uniform: Callable[[float, float], float] = random.uniform,
        now: Callable[[], datetime] = lambda: datetime.now(timezone.utc),
    ) -> None:
        self.store = store
        self.client = client
        self.policy = policy
        self.sleep = sleep
        self.random_uniform = random_uniform
        self.now = now

    def run(self, max_tasks: Optional[int] = None) -> RunSummary:
        counts = {
            "processed": 0,
            "succeeded": 0,
            "missing": 0,
            "retryable": 0,
            "failed": 0,
            "parse_failed": 0,
            "blocked": 0,
        }
        consecutive_parse_errors = 0
        task = None if max_tasks == 0 else self.store.claim_next(self.now())
        while task is not None:
            counts["processed"] += 1
            result = self._process(task)
            counts[result] += 1
            if result == "parse_failed":
                consecutive_parse_errors += 1
                if consecutive_parse_errors == 3:
                    reason = "parse_error_threshold"
                    self.store.pause_all(reason)
                    raise CollectionBlocked(reason)
            else:
                consecutive_parse_errors = 0

            if max_tasks is not None and counts["processed"] >= max_tasks:
                break
            task = self.store.claim_next(self.now())
            if task is not None:
                self.sleep(
                    self.policy.delay_seconds
                    + self.random_uniform(0, self.policy.jitter_seconds)
                )
        return RunSummary(**counts)

    def _process(self, task: StoredTask) -> str:
        try:
            parsed_url = urlsplit(task.source_url)
            valid_url = (
                parsed_url.scheme == "https"
                and parsed_url.hostname in ALLOWED_HOSTS
                and parsed_url.username is None
                and parsed_url.password is None
                and parsed_url.port in (None, 443)
            )
        except ValueError:
            valid_url = False
        if not valid_url:
            self.store.record_failed(task.id, "invalid source URL")
            return "failed"

        self.client.cookies.clear()
        self.client.headers.pop("Cookie", None)
        self.client.headers.pop("Authorization", None)
        try:
            response = self.client.get(
                task.source_url,
                headers={"User-Agent": USER_AGENT},
                timeout=self.policy.timeout_seconds,
                auth=None,
                follow_redirects=False,
            )
        except httpx.TransportError as error:
            return self._record_network_failure(task, f"transport error: {error}")

        if is_challenge(response):
            self._block(task, "challenge page detected")
        if response.status_code in (403, 429):
            reason = f"HTTP {response.status_code}"
            retry_after = response.headers.get("Retry-After", "").strip()
            if response.status_code == 429 and retry_after.isdigit():
                reason += f" retry_after={retry_after}"
            self._block(task, reason)
        if response.status_code == 404:
            self.store.record_missing(task.id, "HTTP 404")
            return "missing"
        if 300 <= response.status_code < 400:
            self.store.record_failed(task.id, "redirect_not_allowed")
            return "failed"
        if 500 <= response.status_code < 600:
            return self._record_network_failure(task, f"HTTP {response.status_code}")
        if response.status_code != 200:
            self.store.record_failed(task.id, f"HTTP {response.status_code}")
            return "failed"

        try:
            rows = parse_medium_results(response.text)
        except ParseError as error:
            self.store.record_parse_failed(task.id, str(error))
            return "parse_failed"
        self.store.record_success(
            task.id,
            rows,
            hashlib.sha256(response.content).hexdigest(),
        )
        return "succeeded"

    def _record_network_failure(self, task: StoredTask, error: str) -> str:
        if task.attempts >= self.policy.max_attempts:
            self.store.record_failed(task.id, error)
            return "failed"
        self.store.record_retryable(
            task.id,
            error,
            self.now() + timedelta(seconds=2**task.attempts),
        )
        return "retryable"

    def _block(self, task: StoredTask, reason: str) -> None:
        self.store.block_and_pause(task.id, reason)
        raise CollectionBlocked(reason)
