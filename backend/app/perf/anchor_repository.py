from datetime import datetime, timezone
from typing import Dict, List, Optional, Sequence

from sqlalchemy import select, update
from sqlalchemy.orm import Session

from app.perf.models import (
    GamePerformanceAnchor,
    GamePerformanceCalibration,
    HardwarePerformanceProfile,
)


def upsert_hardware_performance_profiles(
    session: Session,
    profiles: Sequence[HardwarePerformanceProfile],
) -> int:
    written_count = 0
    for profile in profiles:
        reviewed_at = _as_utc(profile.reviewed_at)
        existing = session.get(HardwarePerformanceProfile, profile.component_id)
        if existing is None:
            profile.reviewed_at = reviewed_at
            session.add(profile)
        else:
            if reviewed_at < _as_utc(existing.reviewed_at):
                continue
            for name in (
                "category",
                "performance_score",
                "is_common",
                "supports_dlss",
                "supports_fsr",
                "supports_standard_frame_generation",
                "source_kind",
                "source_reference",
                "import_batch",
            ):
                setattr(existing, name, getattr(profile, name))
            existing.reviewed_at = reviewed_at
        written_count += 1
    session.flush()
    return written_count


def get_hardware_performance_profiles(
    session: Session,
    component_ids: Sequence[str],
) -> Dict[str, HardwarePerformanceProfile]:
    if not component_ids:
        return {}
    rows = session.scalars(
        select(HardwarePerformanceProfile).where(
            HardwarePerformanceProfile.component_id.in_(component_ids)
        )
    )
    return {row.component_id: row for row in rows}


def upsert_game_performance_anchors(
    session: Session,
    anchors: Sequence[GamePerformanceAnchor],
) -> int:
    written_count = 0
    for anchor in anchors:
        tested_at = _as_utc(anchor.tested_at)
        existing = session.scalar(
            select(GamePerformanceAnchor).where(
                GamePerformanceAnchor.game_id == anchor.game_id,
                GamePerformanceAnchor.axis == anchor.axis,
                GamePerformanceAnchor.cpu_id == anchor.cpu_id,
                GamePerformanceAnchor.gpu_id == anchor.gpu_id,
                GamePerformanceAnchor.resolution == anchor.resolution,
                GamePerformanceAnchor.render_mode == anchor.render_mode,
                GamePerformanceAnchor.sample_role == anchor.sample_role,
                GamePerformanceAnchor.game_version == anchor.game_version,
                GamePerformanceAnchor.driver_version == anchor.driver_version,
            )
        )
        if existing is None:
            anchor.tested_at = tested_at
            session.add(anchor)
        else:
            if tested_at < _as_utc(existing.tested_at):
                continue
            existing.average_fps = anchor.average_fps
            existing.source_kind = anchor.source_kind
            existing.source_reference = anchor.source_reference
            existing.tested_at = tested_at
            existing.import_batch = anchor.import_batch
        written_count += 1
    session.flush()
    return written_count


def list_axis_anchors(
    session: Session,
    game_id: str,
    resolution: str,
    render_mode: str,
    axis: str,
) -> List[GamePerformanceAnchor]:
    statement = select(GamePerformanceAnchor).where(
        GamePerformanceAnchor.game_id == game_id,
        GamePerformanceAnchor.resolution == resolution,
        GamePerformanceAnchor.render_mode == render_mode,
        GamePerformanceAnchor.axis == axis,
        GamePerformanceAnchor.sample_role == "fit",
    )
    return list(session.scalars(statement))


def list_validation_anchors(
    session: Session,
    game_id: str,
    resolution: str,
    render_mode: str,
) -> List[GamePerformanceAnchor]:
    statement = select(GamePerformanceAnchor).where(
        GamePerformanceAnchor.game_id == game_id,
        GamePerformanceAnchor.resolution == resolution,
        GamePerformanceAnchor.render_mode == render_mode,
        GamePerformanceAnchor.sample_role == "validation",
    )
    return list(session.scalars(statement))


def get_active_calibration(
    session: Session,
    game_id: str,
    resolution: str,
    render_mode: str,
) -> Optional[GamePerformanceCalibration]:
    return session.scalar(
        select(GamePerformanceCalibration)
        .where(
            GamePerformanceCalibration.game_id == game_id,
            GamePerformanceCalibration.resolution == resolution,
            GamePerformanceCalibration.render_mode == render_mode,
            GamePerformanceCalibration.is_active.is_(True),
        )
        .order_by(GamePerformanceCalibration.calibrated_at.desc())
        .limit(1)
    )


def replace_active_calibration(
    session: Session,
    calibration: GamePerformanceCalibration,
) -> None:
    session.execute(
        update(GamePerformanceCalibration)
        .where(
            GamePerformanceCalibration.game_id == calibration.game_id,
            GamePerformanceCalibration.resolution == calibration.resolution,
            GamePerformanceCalibration.render_mode == calibration.render_mode,
        )
        .values(is_active=False)
    )
    existing = session.scalar(
        select(GamePerformanceCalibration).where(
            GamePerformanceCalibration.game_id == calibration.game_id,
            GamePerformanceCalibration.resolution == calibration.resolution,
            GamePerformanceCalibration.render_mode == calibration.render_mode,
            GamePerformanceCalibration.model_version == calibration.model_version,
        )
    )
    if existing is None:
        calibration.is_active = True
        calibration.calibrated_at = _as_utc(calibration.calibrated_at)
        session.add(calibration)
    else:
        for name in (
            "correction_factor",
            "validation_mape",
            "validation_count",
            "common_validation_mape",
            "common_validation_count",
        ):
            setattr(existing, name, getattr(calibration, name))
        existing.calibrated_at = _as_utc(calibration.calibrated_at)
        existing.is_active = True
    session.flush()


def _as_utc(value: datetime) -> datetime:
    if value.tzinfo is None:
        return value.replace(tzinfo=timezone.utc)
    return value.astimezone(timezone.utc)
