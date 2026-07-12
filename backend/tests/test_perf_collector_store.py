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
    store.seed_tasks([task("retry"), task("missing"), task("parse")])
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

    with sqlite3.connect(path) as connection:
        states = connection.execute(
            "SELECT status, error, next_attempt_at FROM task ORDER BY id"
        ).fetchall()
    assert states == [
        ("retryable", "temporary", retry_at.isoformat()),
        ("missing", "not found", None),
        ("parse_failed", "bad table", None),
    ]


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
