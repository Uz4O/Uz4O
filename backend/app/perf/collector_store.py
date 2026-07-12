import sqlite3
import json
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Dict, List, Optional, Sequence

from app.perf.collector_parser import ParsedPerformanceRow


@dataclass(frozen=True)
class CollectionTask:
    cpu_id: str
    gpu_id: str
    game_id: str
    source_url: str


@dataclass(frozen=True)
class StoredTask:
    id: int
    cpu_id: str
    gpu_id: str
    game_id: str
    source_url: str
    attempts: int


def _utc_iso(value: Optional[datetime] = None) -> str:
    value = value or datetime.now(timezone.utc)
    if value.tzinfo is None:
        value = value.replace(tzinfo=timezone.utc)
    return value.astimezone(timezone.utc).isoformat()


def _utc_datetime(value: datetime) -> datetime:
    if value.tzinfo is None:
        value = value.replace(tzinfo=timezone.utc)
    return value.astimezone(timezone.utc)


class CollectorStore:
    def __init__(self, path: Path):
        path = Path(path)
        path.parent.mkdir(parents=True, exist_ok=True)
        self._connection = sqlite3.connect(path)
        self._connection.row_factory = sqlite3.Row
        self._connection.execute("PRAGMA foreign_keys = ON")
        self._connection.executescript(
            """
            CREATE TABLE IF NOT EXISTS task (
                id INTEGER PRIMARY KEY,
                cpu_id TEXT NOT NULL,
                gpu_id TEXT NOT NULL,
                game_id TEXT NOT NULL,
                source_url TEXT NOT NULL UNIQUE,
                status TEXT NOT NULL DEFAULT 'pending',
                attempts INTEGER NOT NULL DEFAULT 0,
                next_attempt_at TEXT,
                error TEXT,
                response_hash TEXT,
                updated_at TEXT NOT NULL
            );
            CREATE TABLE IF NOT EXISTS result (
                task_id INTEGER NOT NULL,
                resolution TEXT NOT NULL CHECK (resolution IN ('1080p', '2k', '4k')),
                average_fps INTEGER NOT NULL,
                minimum_fps INTEGER NOT NULL,
                maximum_fps INTEGER NOT NULL,
                bottleneck_type TEXT CHECK (
                    bottleneck_type IN ('cpu', 'gpu', 'balanced')
                    OR bottleneck_type IS NULL
                ),
                bottleneck_percent INTEGER CHECK (
                    bottleneck_percent BETWEEN 0 AND 100
                    OR bottleneck_percent IS NULL
                ),
                CHECK (
                    0 < minimum_fps
                    AND minimum_fps <= average_fps
                    AND average_fps <= maximum_fps
                    AND maximum_fps <= 2000
                ),
                PRIMARY KEY (task_id, resolution),
                FOREIGN KEY (task_id) REFERENCES task(id) ON DELETE CASCADE
            );
            CREATE TABLE IF NOT EXISTS collector_state (
                key TEXT PRIMARY KEY,
                value TEXT NOT NULL
            );
            """
        )

    def __enter__(self) -> "CollectorStore":
        return self

    def __exit__(self, exc_type: object, exc_value: object, traceback: object) -> None:
        self.close()

    def close(self) -> None:
        self._connection.close()

    def seed_tasks(self, tasks: Sequence[CollectionTask]) -> int:
        before = self._connection.total_changes
        updated_at = _utc_iso()
        with self._connection:
            self._connection.executemany(
                """
                INSERT OR IGNORE INTO task
                    (cpu_id, gpu_id, game_id, source_url, updated_at)
                VALUES (?, ?, ?, ?, ?)
                """,
                [
                    (item.cpu_id, item.gpu_id, item.game_id, item.source_url, updated_at)
                    for item in tasks
                ],
            )
        return self._connection.total_changes - before

    def claim_next(self, now: Optional[datetime] = None) -> Optional[StoredTask]:
        current_time = _utc_iso(now)
        self._connection.execute("BEGIN IMMEDIATE")
        try:
            paused = self._connection.execute(
                "SELECT 1 FROM collector_state WHERE key = 'pause_reason'"
            ).fetchone()
            if paused:
                self._connection.commit()
                return None
            self._connection.execute(
                """
                UPDATE task
                SET status = 'retryable', next_attempt_at = NULL,
                    error = 'interrupted', updated_at = ?
                WHERE status = 'fetching'
                """,
                (current_time,),
            )
            row = self._connection.execute(
                """
                SELECT id FROM task
                WHERE status IN ('pending', 'retryable')
                  AND (next_attempt_at IS NULL OR next_attempt_at <= ?)
                ORDER BY id
                LIMIT 1
                """,
                (current_time,),
            ).fetchone()
            if row is None:
                self._connection.commit()
                return None
            self._connection.execute(
                """
                UPDATE task
                SET status = 'fetching', attempts = attempts + 1,
                    next_attempt_at = NULL, error = NULL, updated_at = ?
                WHERE id = ?
                """,
                (current_time, row["id"]),
            )
            claimed = self._connection.execute(
                """
                SELECT id, cpu_id, gpu_id, game_id, source_url, attempts
                FROM task WHERE id = ?
                """,
                (row["id"],),
            ).fetchone()
            self._connection.commit()
        except Exception:
            self._connection.rollback()
            raise
        return StoredTask(**dict(claimed))

    def has_claimable(self, now: Optional[datetime] = None) -> bool:
        current_time = _utc_iso(now)
        paused = self._connection.execute(
            "SELECT 1 FROM collector_state WHERE key = 'pause_reason'"
        ).fetchone()
        if paused:
            return False
        return (
            self._connection.execute(
                """
                SELECT 1 FROM task
                WHERE status IN ('pending', 'retryable')
                  AND (next_attempt_at IS NULL OR next_attempt_at <= ?)
                LIMIT 1
                """,
                (current_time,),
            ).fetchone()
            is not None
        )

    def record_success(
        self,
        task_id: int,
        rows: Sequence[ParsedPerformanceRow],
        response_hash: str,
    ) -> None:
        resolutions = [row.resolution for row in rows]
        if len(resolutions) != 3 or set(resolutions) != {"1080p", "2k", "4k"}:
            raise ValueError("result resolutions must be exactly 1080p, 2k, and 4k")
        if any(
            not 0
            < row.minimum_fps
            <= row.average_fps
            <= row.maximum_fps
            <= 2000
            for row in rows
        ):
            raise ValueError("invalid FPS values")
        with self._connection:
            self._connection.execute("DELETE FROM result WHERE task_id = ?", (task_id,))
            self._connection.executemany(
                """
                INSERT INTO result
                    (task_id, resolution, average_fps, minimum_fps, maximum_fps,
                     bottleneck_type, bottleneck_percent)
                VALUES (?, ?, ?, ?, ?, ?, ?)
                """,
                [
                    (
                        task_id,
                        row.resolution,
                        row.average_fps,
                        row.minimum_fps,
                        row.maximum_fps,
                        row.bottleneck_type,
                        row.bottleneck_percent,
                    )
                    for row in rows
                ],
            )
            self._connection.execute(
                """
                UPDATE task
                SET status = 'succeeded', response_hash = ?, error = NULL,
                    next_attempt_at = NULL, updated_at = ?
                WHERE id = ?
                """,
                (response_hash, _utc_iso(), task_id),
            )

    def record_retryable(
        self, task_id: int, error: str, next_attempt_at: datetime
    ) -> None:
        self._record_failure(task_id, "retryable", error, _utc_iso(next_attempt_at))

    def record_missing(self, task_id: int, error: str) -> None:
        self._record_failure(task_id, "missing", error, None)

    def record_parse_failed(self, task_id: int, error: str) -> None:
        self._record_failure(task_id, "parse_failed", error, None)

    def record_parse_failure_and_maybe_pause(
        self, task_id: int, error: str, threshold: int
    ) -> bool:
        if threshold <= 0:
            raise ValueError("threshold must be positive")
        self._connection.execute("BEGIN IMMEDIATE")
        try:
            updated = self._connection.execute(
                """
                UPDATE task
                SET status = 'parse_failed', error = ?, next_attempt_at = NULL,
                    updated_at = ?
                WHERE id = ?
                """,
                (error, _utc_iso(), task_id),
            )
            if updated.rowcount != 1:
                raise KeyError(task_id)
            row = self._connection.execute(
                "SELECT value FROM collector_state WHERE key = 'consecutive_parse_failures'"
            ).fetchone()
            count = (int(row["value"]) if row else 0) + 1
            self._connection.execute(
                """
                INSERT INTO collector_state (key, value)
                VALUES ('consecutive_parse_failures', ?)
                ON CONFLICT(key) DO UPDATE SET value = excluded.value
                """,
                (str(count),),
            )
            paused = count >= threshold
            if paused:
                self._connection.execute(
                    """
                    INSERT INTO collector_state (key, value)
                    VALUES ('pause_reason', 'parse_error_threshold')
                    ON CONFLICT(key) DO UPDATE SET value = excluded.value
                    """
                )
            self._connection.commit()
            return paused
        except Exception:
            self._connection.rollback()
            raise

    def reset_parse_failures(self) -> None:
        with self._connection:
            self._connection.execute(
                "DELETE FROM collector_state WHERE key = 'consecutive_parse_failures'"
            )

    def record_failed(self, task_id: int, error: str) -> None:
        self._record_failure(task_id, "failed", error, None)

    def block_and_pause(self, task_id: int, reason: str) -> None:
        with self._connection:
            updated = self._connection.execute(
                """
                UPDATE task
                SET status = 'blocked', error = ?, next_attempt_at = NULL,
                    updated_at = ?
                WHERE id = ?
                """,
                (reason, _utc_iso(), task_id),
            )
            if updated.rowcount != 1:
                raise KeyError(task_id)
            self._connection.execute(
                """
                INSERT INTO collector_state (key, value) VALUES ('pause_reason', ?)
                ON CONFLICT(key) DO UPDATE SET value = excluded.value
                """,
                (reason,),
            )

    def _record_failure(
        self, task_id: int, status: str, error: str, next_attempt_at: Optional[str]
    ) -> None:
        with self._connection:
            updated = self._connection.execute(
                """
                UPDATE task
                SET status = ?, error = ?, next_attempt_at = ?, updated_at = ?
                WHERE id = ?
                """,
                (status, error, next_attempt_at, _utc_iso(), task_id),
            )
            if updated.rowcount != 1:
                raise KeyError(task_id)

    def pause_all(self, reason: str) -> None:
        with self._connection:
            self._connection.execute(
                """
                INSERT INTO collector_state (key, value) VALUES ('pause_reason', ?)
                ON CONFLICT(key) DO UPDATE SET value = excluded.value
                """,
                (reason,),
            )

    def resume_all(self) -> None:
        with self._connection:
            self._connection.execute(
                "DELETE FROM collector_state WHERE key = 'pause_reason'"
            )

    def pause_reason(self) -> Optional[str]:
        row = self._connection.execute(
            "SELECT value FROM collector_state WHERE key = 'pause_reason'"
        ).fetchone()
        return row["value"] if row else None

    def acquire_run_lock(
        self, owner: str, now: datetime, ttl_seconds: float
    ) -> bool:
        if ttl_seconds <= 0:
            raise ValueError("lock TTL must be positive")
        current = _utc_datetime(now)
        self._connection.execute("BEGIN IMMEDIATE")
        try:
            row = self._connection.execute(
                "SELECT value FROM collector_state WHERE key = 'run_lock'"
            ).fetchone()
            if row:
                lock = json.loads(row["value"])
                expires_at = datetime.fromisoformat(lock["expires_at"])
                if lock["owner"] != owner and expires_at > current:
                    self._connection.commit()
                    return False
            value = json.dumps(
                {
                    "owner": owner,
                    "expires_at": (current + timedelta(seconds=ttl_seconds)).isoformat(),
                }
            )
            self._connection.execute(
                """
                INSERT INTO collector_state (key, value) VALUES ('run_lock', ?)
                ON CONFLICT(key) DO UPDATE SET value = excluded.value
                """,
                (value,),
            )
            self._connection.commit()
            return True
        except Exception:
            self._connection.rollback()
            raise

    def renew_run_lock(self, owner: str, now: datetime, ttl_seconds: float) -> bool:
        if ttl_seconds <= 0:
            raise ValueError("lock TTL must be positive")
        current = _utc_datetime(now)
        self._connection.execute("BEGIN IMMEDIATE")
        try:
            row = self._connection.execute(
                "SELECT value FROM collector_state WHERE key = 'run_lock'"
            ).fetchone()
            lock = json.loads(row["value"]) if row else None
            if (
                not lock
                or lock["owner"] != owner
                or datetime.fromisoformat(lock["expires_at"]) <= current
            ):
                self._connection.commit()
                return False
            value = json.dumps(
                {
                    "owner": owner,
                    "expires_at": (current + timedelta(seconds=ttl_seconds)).isoformat(),
                }
            )
            self._connection.execute(
                "UPDATE collector_state SET value = ? WHERE key = 'run_lock'",
                (value,),
            )
            self._connection.commit()
            return True
        except Exception:
            self._connection.rollback()
            raise

    def release_run_lock(self, owner: str) -> None:
        self._connection.execute("BEGIN IMMEDIATE")
        try:
            row = self._connection.execute(
                "SELECT value FROM collector_state WHERE key = 'run_lock'"
            ).fetchone()
            if row and json.loads(row["value"])["owner"] == owner:
                self._connection.execute(
                    "DELETE FROM collector_state WHERE key = 'run_lock'"
                )
            self._connection.commit()
        except Exception:
            self._connection.rollback()
            raise

    def task_counts(self) -> Dict[str, int]:
        return {
            row["status"]: row["count"]
            for row in self._connection.execute(
                "SELECT status, COUNT(*) AS count FROM task GROUP BY status"
            )
        }

    def results_for_task(self, task_id: int) -> List[ParsedPerformanceRow]:
        rows = self._connection.execute(
            """
            SELECT resolution, average_fps, minimum_fps, maximum_fps,
                   bottleneck_type, bottleneck_percent
            FROM result
            WHERE task_id = ?
            ORDER BY CASE resolution WHEN '1080p' THEN 1 WHEN '2k' THEN 2 ELSE 3 END
            """,
            (task_id,),
        )
        return [
            ParsedPerformanceRow(
                row["resolution"],
                row["average_fps"],
                row["minimum_fps"],
                row["maximum_fps"],
                row["bottleneck_type"],
                row["bottleneck_percent"],
            )
            for row in rows
        ]

    def successful_records(self) -> List[dict]:
        records: List[dict] = []
        rows = self._connection.execute(
            """
            SELECT task.id, task.cpu_id, task.gpu_id, task.game_id,
                   task.source_url, task.response_hash,
                   result.resolution, result.average_fps, result.minimum_fps,
                   result.maximum_fps, result.bottleneck_type,
                   result.bottleneck_percent
            FROM task JOIN result ON result.task_id = task.id
            WHERE task.status = 'succeeded'
            ORDER BY task.source_url,
                CASE result.resolution WHEN '1080p' THEN 1 WHEN '2k' THEN 2 ELSE 3 END
            """
        )
        for row in rows:
            if not records or records[-1]["source_url"] != row["source_url"]:
                records.append(
                    {
                        "cpu_id": row["cpu_id"],
                        "gpu_id": row["gpu_id"],
                        "game_id": row["game_id"],
                        "source_url": row["source_url"],
                        "response_hash": row["response_hash"],
                        "results": [],
                    }
                )
            records[-1]["results"].append(
                {
                    "resolution": row["resolution"],
                    "average_fps": row["average_fps"],
                    "minimum_fps": row["minimum_fps"],
                    "maximum_fps": row["maximum_fps"],
                    "bottleneck_type": row["bottleneck_type"],
                    "bottleneck_percent": row["bottleneck_percent"],
                }
            )
        return records
