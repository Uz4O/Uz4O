from datetime import datetime, timezone
from typing import TYPE_CHECKING, List, Sequence

from sqlalchemy import select, tuple_
from sqlalchemy.orm import Session

from app.perf.models import GamePerformanceEstimate

if TYPE_CHECKING:
    from app.perf.importer import PerformanceEstimateInput


UPSERT_CHUNK_SIZE = 150


def get_performance_estimates(
    session: Session,
    cpu_id: str,
    gpu_id: str,
    game_ids: Sequence[str],
    resolution: str,
    quality: str,
) -> List[GamePerformanceEstimate]:
    if not game_ids:
        return []
    statement = select(GamePerformanceEstimate).where(
        GamePerformanceEstimate.cpu_id == cpu_id,
        GamePerformanceEstimate.gpu_id == gpu_id,
        GamePerformanceEstimate.game_id.in_(game_ids),
        GamePerformanceEstimate.resolution == resolution,
        GamePerformanceEstimate.quality == quality,
    )
    return list(session.scalars(statement))


def upsert_performance_estimates(
    session: Session,
    estimates: Sequence["PerformanceEstimateInput"],
) -> int:
    written_count = 0
    for offset in range(0, len(estimates), UPSERT_CHUNK_SIZE):
        chunk = estimates[offset : offset + UPSERT_CHUNK_SIZE]
        keys = [
            (
                item.cpu_id,
                item.gpu_id,
                item.game_id,
                item.resolution,
                item.quality,
            )
            for item in chunk
        ]
        rows = session.scalars(
            select(GamePerformanceEstimate).where(
                tuple_(
                    GamePerformanceEstimate.cpu_id,
                    GamePerformanceEstimate.gpu_id,
                    GamePerformanceEstimate.game_id,
                    GamePerformanceEstimate.resolution,
                    GamePerformanceEstimate.quality,
                ).in_(keys)
            )
        )
        existing = {
            (
                row.cpu_id,
                row.gpu_id,
                row.game_id,
                row.resolution,
                row.quality,
            ): row
            for row in rows
        }
        for estimate, key in zip(chunk, keys):
            row = existing.get(key)
            values = vars(estimate)
            if row is None:
                row = GamePerformanceEstimate(**values)
                session.add(row)
                existing[key] = row
            else:
                if _as_utc(estimate.source_fetched_at) < _as_utc(
                    row.source_fetched_at
                ):
                    continue
                for name, value in values.items():
                    setattr(row, name, value)
            written_count += 1
        session.flush()
    session.commit()
    return written_count


def _as_utc(value: datetime) -> datetime:
    if value.tzinfo is None:
        return value.replace(tzinfo=timezone.utc)
    return value.astimezone(timezone.utc)
