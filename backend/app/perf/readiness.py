import json
import tempfile
from dataclasses import asdict, dataclass
from pathlib import Path
from statistics import mean
from typing import Dict, List, Tuple

from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.catalog.models import HardwareComponent
from app.perf.anchor_repository import (
    get_active_calibration,
    get_hardware_performance_profiles,
    list_axis_anchors,
    list_validation_anchors,
)
from app.perf.models import GamePerformanceAnchor, HardwarePerformanceProfile
from app.perf.profiles import (
    APPROVED_GAME_PROFILES,
    GPUCapabilities,
    RenderMode,
    render_mode_for,
)
from app.perf.time_spy import effective_performance_score, has_time_spy_scores


RESOLUTIONS = ("1080p", "2k", "4k")


@dataclass(frozen=True)
class ModelReadiness:
    ready: bool
    cpu_fit_score_count: int
    gpu_fit_score_count: int
    validation_count: int
    validation_share: float
    common_validation_count: int
    active_model_version: str
    validation_mape: float
    common_validation_mape: float
    reasons: List[str]


@dataclass(frozen=True)
class EstimatorReadiness:
    ready: bool
    hardware_profile_count: int
    required_hardware_profile_count: int
    anchor_count: int
    active_model_count: int
    required_model_count: int
    missing_hardware_profiles: List[str]
    missing_models: List[str]
    models: Dict[str, ModelReadiness]


def required_model_keys(session: Session) -> List[Tuple[str, str, str]]:
    gpu_ids = list(
        session.scalars(
            select(HardwareComponent.id).where(
                HardwareComponent.category == "gpu",
                HardwareComponent.status == "active",
            )
        )
    )
    profiles = get_hardware_performance_profiles(session, gpu_ids)
    gpu_capabilities = [
        GPUCapabilities(
            profile.supports_dlss,
            profile.supports_fsr,
            profile.supports_standard_frame_generation,
        )
        for profile in profiles.values()
    ]

    keys = []
    for game_id, game in APPROVED_GAME_PROFILES.items():
        modes = {
            render_mode_for(game, capabilities).value
            for capabilities in gpu_capabilities
        }
        if not modes:
            modes = {RenderMode.NATIVE.value}
        for resolution in RESOLUTIONS:
            for mode in sorted(modes):
                keys.append((game_id, resolution, mode))
    return keys


def build_estimator_readiness(session: Session) -> EstimatorReadiness:
    catalog_rows = list(
        session.execute(
            select(HardwareComponent.id, HardwareComponent.category).where(
                HardwareComponent.category.in_(("cpu", "gpu")),
                HardwareComponent.status == "active",
            )
        )
    )
    required_hardware_ids = {component_id for component_id, _ in catalog_rows}
    profiles = get_hardware_performance_profiles(
        session,
        sorted(required_hardware_ids),
    )
    missing_hardware_profiles = sorted(required_hardware_ids - profiles.keys())

    models = {}
    missing_models = []
    for game_id, resolution, render_mode in required_model_keys(session):
        key = f"{game_id}/{resolution}/{render_mode}"
        model = _build_model_readiness(
            session,
            game_id,
            resolution,
            render_mode,
            profiles,
        )
        models[key] = model
        if not model.ready:
            missing_models.append(key)

    anchor_count = session.scalar(
        select(func.count()).select_from(GamePerformanceAnchor)
    ) or 0
    return EstimatorReadiness(
        ready=not missing_hardware_profiles and not missing_models,
        hardware_profile_count=len(profiles),
        required_hardware_profile_count=len(required_hardware_ids),
        anchor_count=anchor_count,
        active_model_count=sum(model.ready for model in models.values()),
        required_model_count=len(models),
        missing_hardware_profiles=missing_hardware_profiles,
        missing_models=missing_models,
        models=models,
    )


def write_estimator_readiness(
    readiness: EstimatorReadiness,
    path: Path,
) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary_path = None
    try:
        with tempfile.NamedTemporaryFile(
            mode="w",
            encoding="utf-8",
            dir=path.parent,
            prefix=f".{path.name}.",
            suffix=".tmp",
            delete=False,
        ) as temporary_file:
            temporary_path = Path(temporary_file.name)
            json.dump(asdict(readiness), temporary_file, ensure_ascii=False, indent=2)
            temporary_file.write("\n")
        temporary_path.replace(path)
    finally:
        if temporary_path:
            temporary_path.unlink(missing_ok=True)


def _build_model_readiness(
    session: Session,
    game_id: str,
    resolution: str,
    render_mode: str,
    profiles: Dict[str, HardwarePerformanceProfile],
) -> ModelReadiness:
    calibration = get_active_calibration(
        session,
        game_id,
        resolution,
        render_mode,
    )
    if calibration is None:
        return ModelReadiness(
            ready=False,
            cpu_fit_score_count=0,
            gpu_fit_score_count=0,
            validation_count=0,
            validation_share=0.0,
            common_validation_count=0,
            active_model_version="",
            validation_mape=0.0,
            common_validation_mape=0.0,
            reasons=["active_calibration_missing"],
        )

    cpu_anchors = list_axis_anchors(
        session,
        game_id,
        resolution,
        render_mode,
        "cpu",
        calibration.model_version,
    )
    gpu_anchors = list_axis_anchors(
        session,
        game_id,
        resolution,
        render_mode,
        "gpu",
        calibration.model_version,
    )
    validation_anchors = list_validation_anchors(
        session,
        game_id,
        resolution,
        render_mode,
        calibration.model_version,
    )
    cpu_scores = {
        profiles[row.cpu_id].performance_score
        for row in cpu_anchors
        if row.cpu_id in profiles
    }
    gpu_axis_ids = {
        row.gpu_id
        for row in gpu_anchors
        if row.gpu_id in profiles
    }
    use_time_spy = has_time_spy_scores(gpu_axis_ids)
    gpu_scores = {
        effective_performance_score(
            profiles[row.gpu_id],
            use_time_spy=use_time_spy,
        )
        for row in gpu_anchors
        if row.gpu_id in profiles
    }
    common_validation_count = sum(
        row.cpu_id in profiles
        and row.gpu_id in profiles
        and profiles[row.cpu_id].is_common
        and profiles[row.gpu_id].is_common
        for row in validation_anchors
    )
    total_rows = len(cpu_anchors) + len(gpu_anchors) + len(validation_anchors)
    validation_share = (
        len(validation_anchors) / total_rows if total_rows else 0.0
    )
    reasons = []
    if len(cpu_scores) < 2:
        reasons.append("cpu_fit_scores")
    elif not _axis_is_monotonic(cpu_anchors, profiles, "cpu"):
        reasons.append("cpu_fit_monotonicity")
    if len(gpu_scores) < 2:
        reasons.append("gpu_fit_scores")
    elif not _axis_is_monotonic(
        gpu_anchors,
        profiles,
        "gpu",
        use_time_spy,
    ):
        reasons.append("gpu_fit_monotonicity")
    if validation_share < 0.2:
        reasons.append("validation_holdout")
    if common_validation_count < 1:
        reasons.append("common_validation")
    if calibration.validation_count != len(validation_anchors):
        reasons.append("validation_count_mismatch")
    if calibration.common_validation_count != common_validation_count:
        reasons.append("common_validation_count_mismatch")
    if calibration.common_validation_mape > 8.0:
        reasons.append("common_validation_mape")
    return ModelReadiness(
        ready=not reasons,
        cpu_fit_score_count=len(cpu_scores),
        gpu_fit_score_count=len(gpu_scores),
        validation_count=len(validation_anchors),
        validation_share=validation_share,
        common_validation_count=common_validation_count,
        active_model_version=calibration.model_version,
        validation_mape=calibration.validation_mape,
        common_validation_mape=calibration.common_validation_mape,
        reasons=reasons,
    )


def _axis_is_monotonic(
    anchors: List[GamePerformanceAnchor],
    profiles: Dict[str, HardwarePerformanceProfile],
    axis: str,
    use_time_spy: bool = False,
) -> bool:
    fps_by_score: Dict[int, List[int]] = {}
    for row in anchors:
        component_id = row.cpu_id if axis == "cpu" else row.gpu_id
        if component_id not in profiles:
            return False
        profile = profiles[component_id]
        score = (
            profile.performance_score
            if axis == "cpu"
            else effective_performance_score(
                profile,
                use_time_spy=use_time_spy,
            )
        )
        fps_by_score.setdefault(score, []).append(row.average_fps)
    ordered_fps = [
        mean(values)
        for _, values in sorted(fps_by_score.items())
    ]
    return all(
        right >= left
        for left, right in zip(ordered_fps, ordered_fps[1:])
    )
