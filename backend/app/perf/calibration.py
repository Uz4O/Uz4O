from dataclasses import dataclass
from datetime import datetime, timezone
from statistics import mean, median
from typing import Dict, List, Optional, Sequence

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.perf.anchor_repository import (
    get_hardware_performance_profiles,
    list_axis_anchors,
    list_validation_anchors,
    replace_active_calibration,
)
from app.perf.estimator import LimitPoint, predict_average_fps
from app.perf.models import (
    GamePerformanceAnchor,
    GamePerformanceCalibration,
    HardwarePerformanceProfile,
)
from app.perf.profiles import APPROVED_GAME_PROFILES
from app.perf.readiness import required_model_keys


@dataclass(frozen=True)
class ValidationSample:
    cpu_score: int
    gpu_score: int
    actual_average_fps: int
    is_common: bool


@dataclass(frozen=True)
class CalibrationResult:
    correction_factor: float
    validation_mape: float
    validation_count: int
    common_validation_mape: float
    common_validation_count: int


@dataclass(frozen=True)
class CalibrationRunSummary:
    evaluated_count: int
    activated_count: int
    skipped_models: List[str]


def calibrate_game_model(
    cpu_points: Sequence[LimitPoint],
    gpu_points: Sequence[LimitPoint],
    validation_samples: Sequence[ValidationSample],
    fps_cap: Optional[int],
) -> CalibrationResult:
    if len({point.performance_score for point in cpu_points}) < 2:
        raise ValueError("CPU axis requires two distinct fit scores")
    if len({point.performance_score for point in gpu_points}) < 2:
        raise ValueError("GPU axis requires two distinct fit scores")
    if not validation_samples:
        raise ValueError("independent validation samples are required")
    if any(sample.actual_average_fps <= 0 for sample in validation_samples):
        raise ValueError("validation FPS must be positive")

    baselines = [
        predict_average_fps(
            sample.cpu_score,
            sample.gpu_score,
            cpu_points,
            gpu_points,
            1.0,
            fps_cap,
        ).average_fps
        for sample in validation_samples
    ]
    correction_factor = median(
        sample.actual_average_fps / predicted
        for sample, predicted in zip(validation_samples, baselines)
    )
    if not 0.5 <= correction_factor <= 1.5:
        raise ValueError("correction factor is outside the publishable range")

    errors = []
    common_errors = []
    for sample in validation_samples:
        predicted = predict_average_fps(
            sample.cpu_score,
            sample.gpu_score,
            cpu_points,
            gpu_points,
            correction_factor,
            fps_cap,
        ).average_fps
        error = abs(sample.actual_average_fps - predicted) / sample.actual_average_fps
        errors.append(error)
        if sample.is_common:
            common_errors.append(error)
    if not common_errors:
        raise ValueError("common-hardware validation samples are required")
    return CalibrationResult(
        correction_factor=correction_factor,
        validation_mape=mean(errors) * 100,
        validation_count=len(errors),
        common_validation_mape=mean(common_errors) * 100,
        common_validation_count=len(common_errors),
    )


def calibrate_available_models(
    session: Session,
    model_version: str,
) -> CalibrationRunSummary:
    evaluated_count = 0
    activated_count = 0
    skipped_models = []
    for game_id, resolution, render_mode in required_model_keys(session):
        key = f"{game_id}/{resolution}/{render_mode}"
        cpu_anchors = list_axis_anchors(
            session,
            game_id,
            resolution,
            render_mode,
            "cpu",
            model_version,
        )
        gpu_anchors = list_axis_anchors(
            session,
            game_id,
            resolution,
            render_mode,
            "gpu",
            model_version,
        )
        validation_anchors = list_validation_anchors(
            session,
            game_id,
            resolution,
            render_mode,
            model_version,
        )
        total_count = len(cpu_anchors) + len(gpu_anchors) + len(validation_anchors)
        if not total_count or len(validation_anchors) / total_count < 0.2:
            skipped_models.append(key)
            continue

        component_ids = {
            component_id
            for row in cpu_anchors + gpu_anchors + validation_anchors
            for component_id in (row.cpu_id, row.gpu_id)
        }
        profiles = get_hardware_performance_profiles(
            session,
            sorted(component_ids),
        )
        if profiles.keys() != component_ids:
            skipped_models.append(key)
            continue

        cpu_points = _limit_points(cpu_anchors, profiles, "cpu")
        gpu_points = _limit_points(gpu_anchors, profiles, "gpu")
        validation_samples = [
            ValidationSample(
                cpu_score=profiles[row.cpu_id].performance_score,
                gpu_score=profiles[row.gpu_id].performance_score,
                actual_average_fps=row.average_fps,
                is_common=(
                    profiles[row.cpu_id].is_common
                    and profiles[row.gpu_id].is_common
                ),
            )
            for row in validation_anchors
        ]
        try:
            result = calibrate_game_model(
                cpu_points,
                gpu_points,
                validation_samples,
                APPROVED_GAME_PROFILES[game_id].fps_cap,
            )
        except ValueError:
            skipped_models.append(key)
            continue

        evaluated_count += 1
        calibration = GamePerformanceCalibration(
            game_id=game_id,
            resolution=resolution,
            render_mode=render_mode,
            model_version=model_version,
            correction_factor=result.correction_factor,
            validation_mape=result.validation_mape,
            validation_count=result.validation_count,
            common_validation_mape=result.common_validation_mape,
            common_validation_count=result.common_validation_count,
            is_active=False,
            calibrated_at=datetime.now(timezone.utc),
        )
        if result.common_validation_mape <= 8.0:
            replace_active_calibration(session, calibration)
            activated_count += 1
        else:
            _store_inactive_calibration(session, calibration)
            skipped_models.append(key)
    session.commit()
    return CalibrationRunSummary(
        evaluated_count=evaluated_count,
        activated_count=activated_count,
        skipped_models=skipped_models,
    )


def _limit_points(
    anchors: Sequence[GamePerformanceAnchor],
    profiles: Dict[str, HardwarePerformanceProfile],
    axis: str,
) -> List[LimitPoint]:
    fps_by_score: Dict[int, List[int]] = {}
    for row in anchors:
        component_id = row.cpu_id if axis == "cpu" else row.gpu_id
        score = profiles[component_id].performance_score
        fps_by_score.setdefault(score, []).append(row.average_fps)
    return [
        LimitPoint(score, round(mean(fps_values)))
        for score, fps_values in sorted(fps_by_score.items())
    ]


def _store_inactive_calibration(
    session: Session,
    calibration: GamePerformanceCalibration,
) -> None:
    existing = session.scalar(
        select(GamePerformanceCalibration).where(
            GamePerformanceCalibration.game_id == calibration.game_id,
            GamePerformanceCalibration.resolution == calibration.resolution,
            GamePerformanceCalibration.render_mode == calibration.render_mode,
            GamePerformanceCalibration.model_version == calibration.model_version,
        )
    )
    if existing is None:
        session.add(calibration)
    elif not existing.is_active:
        for name in (
            "correction_factor",
            "validation_mape",
            "validation_count",
            "common_validation_mape",
            "common_validation_count",
            "calibrated_at",
        ):
            setattr(existing, name, getattr(calibration, name))
    session.flush()
