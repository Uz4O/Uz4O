from typing import TYPE_CHECKING, List, Sequence

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.perf.models import GamePerformanceEstimate

if TYPE_CHECKING:
    from app.perf.importer import PerformanceEstimateInput


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
    for estimate in estimates:
        row = session.scalar(
            select(GamePerformanceEstimate).where(
                GamePerformanceEstimate.cpu_id == estimate.cpu_id,
                GamePerformanceEstimate.gpu_id == estimate.gpu_id,
                GamePerformanceEstimate.game_id == estimate.game_id,
                GamePerformanceEstimate.resolution == estimate.resolution,
                GamePerformanceEstimate.quality == estimate.quality,
            )
        )
        values = vars(estimate)
        if row is None:
            session.add(GamePerformanceEstimate(**values))
        else:
            for key, value in values.items():
                setattr(row, key, value)
    session.commit()
    return len(estimates)
