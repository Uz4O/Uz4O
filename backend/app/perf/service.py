from statistics import mean
from typing import Dict, List, Literal, Optional, Sequence

from fastapi import HTTPException
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from app.catalog.models import HardwareComponent
from app.catalog.repository import get_components_by_ids
from app.perf.anchor_repository import (
    get_active_calibration,
    get_hardware_performance_profiles,
    list_axis_anchors,
)
from app.perf.cs2_reference import cs2_cpu_average_fps
from app.perf.delta_force_reference import delta_force_average_fps
from app.perf.estimator import LimitPoint, predict_average_fps
from app.perf.generated_estimator import (
    generated_average_fps,
    generated_fps_limits,
    hardware_performance_score,
)
from app.perf.models import GamePerformanceAnchor, HardwarePerformanceProfile
from app.perf.profiles import (
    APPROVED_GAME_PROFILES,
    GPUCapabilities,
    render_mode_for,
)
from app.perf.pubg_reference import pubg_cpu_average_fps
from app.perf.repository import get_performance_estimates
from app.perf.time_spy import (
    effective_performance_score,
    generated_gpu_performance_score,
    gpu_time_spy_score,
    has_time_spy_scores,
)
from app.perf.valorant_reference import valorant_cpu_average_fps


PerfStatus = Literal["ready", "partial", "needs_more_data"]
Resolution = Literal["1080p", "2k", "4k"]
ALL_GAME_IDS = list(APPROVED_GAME_PROFILES)
CALIBRATED_GAME_IDS = {"valorant", "cs2", "pubg", "delta-force"}
CPU_GAME_UNLIMITED_1080P_TIME_SPY = 28_000


class PerfHardwareInput(BaseModel):
    cpu: str = Field(min_length=1, max_length=160)
    gpu: str = Field(min_length=1, max_length=160)


class PerfEstimateRequest(BaseModel):
    hardware: PerfHardwareInput
    resolution: Resolution
    games: List[str] = Field(min_length=1, max_length=15)


class GamePerfEstimate(BaseModel):
    game: str
    average_fps: int


class PerfEstimateResponse(BaseModel):
    status: PerfStatus
    average_fps: Optional[int]
    gpu_time_spy_score: Optional[int] = None
    advice: str
    missing_data: List[str]
    missing_games: List[str]
    game_results: List[GamePerfEstimate]


def estimate_generated_game_fps(
    game_id: str,
    resolution: Resolution,
    cpu: HardwareComponent,
    gpu: HardwareComponent,
) -> Optional[int]:
    """Return the maintained generated estimate for one catalog CPU/GPU pair."""
    if game_id not in APPROVED_GAME_PROFILES:
        return None
    cpu_score = hardware_performance_score(cpu.id, cpu.category, cpu.name, cpu.specs)
    gpu_fallback = hardware_performance_score(gpu.id, gpu.category, gpu.name, gpu.specs)
    gpu_score = generated_gpu_performance_score(gpu.id, gpu_fallback)
    if cpu_score is None or gpu_score is None:
        return None
    return _estimate_generated_game(
        game_id,
        resolution,
        cpu.id,
        gpu.id,
        cpu_score,
        gpu_score,
    ).average_fps


def estimate_performance(
    session: Session,
    request: PerfEstimateRequest,
) -> PerfEstimateResponse:
    requested_games = _requested_games(request.games)
    time_spy_score = gpu_time_spy_score(request.hardware.gpu)
    component_ids = [request.hardware.cpu, request.hardware.gpu]
    components = {
        component.id: component
        for component in get_components_by_ids(session, component_ids)
    }
    cpu = components.get(request.hardware.cpu)
    gpu = components.get(request.hardware.gpu)
    _validate_hardware(cpu, gpu)

    exact_game_ids = [
        game_id
        for game_id in requested_games
        if game_id not in CALIBRATED_GAME_IDS
    ]
    exact_rows = get_performance_estimates(
        session,
        request.hardware.cpu,
        request.hardware.gpu,
        exact_game_ids,
        request.resolution,
        "medium",
    )
    exact_by_game = {row.game_id: row for row in exact_rows}
    unresolved_games = [
        game_id for game_id in requested_games if game_id not in exact_by_game
    ]
    profiles = (
        get_hardware_performance_profiles(session, component_ids)
        if unresolved_games
        else {}
    )
    cpu_profile = profiles.get(request.hardware.cpu)
    gpu_profile = profiles.get(request.hardware.gpu)
    if cpu_profile is not None and cpu_profile.category != "cpu":
        raise HTTPException(status_code=422, detail="硬件性能档案类型不匹配")
    if gpu_profile is not None and gpu_profile.category != "gpu":
        raise HTTPException(status_code=422, detail="硬件性能档案类型不匹配")
    cpu_generated_score = hardware_performance_score(
        cpu.id,
        cpu.category,
        cpu.name,
        cpu.specs,
    )
    gpu_generated_score = generated_gpu_performance_score(
        gpu.id,
        hardware_performance_score(
            gpu.id,
            gpu.category,
            gpu.name,
            gpu.specs,
        ),
    )

    game_results = []
    missing_games = []
    generated_used = False
    for game_id in requested_games:
        exact = exact_by_game.get(game_id)
        if exact is not None:
            game_results.append(
                GamePerfEstimate(game=game_id, average_fps=exact.average_fps)
            )
            continue
        result = None
        if cpu_profile is not None and gpu_profile is not None:
            result = _estimate_game(
                session,
                game_id,
                request.resolution,
                cpu_profile,
                gpu_profile,
            )
        if (
            result is None
            and cpu_generated_score is not None
            and gpu_generated_score is not None
        ):
            result = _estimate_generated_game(
                game_id,
                request.resolution,
                request.hardware.cpu,
                request.hardware.gpu,
                cpu_generated_score,
                gpu_generated_score,
            )
            generated_used = True
        if result is None:
            missing_games.append(game_id)
        else:
            game_results.append(result)
    missing_data = []
    if missing_games and cpu_generated_score is None and cpu_profile is None:
        missing_data.append("cpu_profile")
    if missing_games and gpu_generated_score is None and gpu_profile is None:
        missing_data.append("gpu_profile")
    if not game_results:
        return _no_data_response(missing_games, missing_data, time_spy_score)
    return PerfEstimateResponse(
        status="partial" if missing_games or missing_data else "ready",
        average_fps=round(mean(row.average_fps for row in game_results)),
        gpu_time_spy_score=time_spy_score,
        advice=(
            "高画质；超分与帧生成设置以对应游戏的校准样本为准。"
            if CALIBRATED_GAME_IDS.intersection(requested_games)
            else (
                "平均帧为 AI 估算值，实际会受画质、版本和散热影响。"
                if generated_used
                else (
                    "第三方网站中等画质估算，实际帧数会因游戏设置和版本变化。"
                    if exact_rows
                    else "高画质，支持时开启质量档超分和标准帧生成。"
                )
            )
        ),
        missing_data=missing_data,
        missing_games=missing_games,
        game_results=game_results,
    )


def _estimate_generated_game(
    game_id: str,
    resolution: str,
    cpu_id: str,
    gpu_id: str,
    cpu_score: int,
    gpu_score: int,
) -> GamePerfEstimate:
    if game_id == "delta-force":
        reference_fps = delta_force_average_fps(cpu_id, gpu_id, resolution)
        if reference_fps is not None:
            return GamePerfEstimate(game=game_id, average_fps=reference_fps)

    cpu_reference = _cpu_game_reference(game_id, cpu_id, resolution)
    if cpu_reference is not None:
        _, gpu_ceiling = generated_fps_limits(
            game_id,
            resolution,
            cpu_score,
            gpu_score,
        )
        return GamePerfEstimate(
            game=game_id,
            average_fps=_apply_gpu_limit_to_cpu_reference(
                cpu_reference,
                gpu_ceiling,
                gpu_id,
                resolution,
            ),
        )
    return GamePerfEstimate(
        game=game_id,
        average_fps=generated_average_fps(
            game_id,
            resolution,
            cpu_score,
            gpu_score,
        ),
    )


def _cpu_game_reference(
    game_id: str,
    cpu_id: str,
    resolution: str,
) -> Optional[int]:
    if game_id == "valorant":
        return valorant_cpu_average_fps(cpu_id, resolution)
    if game_id == "cs2":
        return cs2_cpu_average_fps(cpu_id, resolution)
    if game_id == "pubg":
        return pubg_cpu_average_fps(cpu_id)
    return None


def _requested_games(games: Sequence[str]) -> List[str]:
    invalid_games = [
        game_id
        for game_id in games
        if game_id != "all-games" and game_id not in APPROVED_GAME_PROFILES
    ]
    if invalid_games:
        raise HTTPException(
            status_code=422,
            detail="不支持的游戏: " + ", ".join(invalid_games),
        )
    if "all-games" in games:
        return ALL_GAME_IDS
    return list(dict.fromkeys(games))


def _validate_hardware(
    cpu: Optional[HardwareComponent],
    gpu: Optional[HardwareComponent],
) -> None:
    if cpu is None or cpu.category != "cpu":
        raise HTTPException(status_code=422, detail="CPU 型号不受支持")
    if gpu is None or gpu.category != "gpu":
        raise HTTPException(status_code=422, detail="显卡型号不受支持")


def _estimate_game(
    session: Session,
    game_id: str,
    resolution: str,
    cpu_profile: HardwarePerformanceProfile,
    gpu_profile: HardwarePerformanceProfile,
) -> Optional[GamePerfEstimate]:
    if game_id == "delta-force":
        reference_fps = delta_force_average_fps(
            cpu_profile.component_id,
            gpu_profile.component_id,
            resolution,
        )
        if reference_fps is not None:
            return GamePerfEstimate(game=game_id, average_fps=reference_fps)

    game = APPROVED_GAME_PROFILES[game_id]
    render_mode = render_mode_for(
        game,
        GPUCapabilities(
            gpu_profile.supports_dlss,
            gpu_profile.supports_fsr,
            gpu_profile.supports_standard_frame_generation,
        ),
    ).value
    calibration = get_active_calibration(
        session,
        game_id,
        resolution,
        render_mode,
    )
    if calibration is None:
        return None

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
    anchor_ids = {
        component_id
        for row in cpu_anchors + gpu_anchors
        for component_id in (row.cpu_id, row.gpu_id)
    }
    anchor_profiles = get_hardware_performance_profiles(
        session,
        sorted(anchor_ids),
    )
    if anchor_profiles.keys() != anchor_ids:
        return None
    gpu_axis_ids = {gpu_profile.component_id} | {
        row.gpu_id for row in gpu_anchors
    }
    use_time_spy = has_time_spy_scores(gpu_axis_ids)
    try:
        prediction = predict_average_fps(
            cpu_profile.performance_score,
            effective_performance_score(
                gpu_profile,
                use_time_spy=use_time_spy,
            ),
            _limit_points(cpu_anchors, anchor_profiles, "cpu", False),
            _limit_points(
                gpu_anchors,
                anchor_profiles,
                "gpu",
                use_time_spy,
            ),
            calibration.correction_factor,
            game.fps_cap,
        )
    except ValueError:
        return None
    average_fps = prediction.average_fps
    if game_id == "valorant":
        cpu_reference = valorant_cpu_average_fps(
            cpu_profile.component_id,
            resolution,
        )
        if cpu_reference is not None:
            gpu_ceiling = round(
                prediction.gpu_limit * calibration.correction_factor
            )
            average_fps = _apply_gpu_limit_to_cpu_reference(
                cpu_reference,
                gpu_ceiling,
                gpu_profile.component_id,
                resolution,
            )
    elif game_id == "cs2":
        cpu_reference = cs2_cpu_average_fps(
            cpu_profile.component_id,
            resolution,
        )
        if cpu_reference is not None:
            gpu_ceiling = round(
                prediction.gpu_limit * calibration.correction_factor
            )
            average_fps = _apply_gpu_limit_to_cpu_reference(
                cpu_reference,
                gpu_ceiling,
                gpu_profile.component_id,
                resolution,
            )
    elif game_id == "pubg":
        cpu_reference = pubg_cpu_average_fps(cpu_profile.component_id)
        if cpu_reference is not None:
            gpu_ceiling = round(
                prediction.gpu_limit * calibration.correction_factor
            )
            average_fps = _apply_gpu_limit_to_cpu_reference(
                cpu_reference,
                gpu_ceiling,
                gpu_profile.component_id,
                resolution,
            )
    return GamePerfEstimate(game=game_id, average_fps=average_fps)


def _apply_gpu_limit_to_cpu_reference(
    cpu_reference: int,
    gpu_ceiling: int,
    gpu_id: str,
    resolution: str,
) -> int:
    time_spy_score = gpu_time_spy_score(gpu_id)
    if (
        resolution == "1080p"
        and time_spy_score is not None
        and time_spy_score >= CPU_GAME_UNLIMITED_1080P_TIME_SPY
    ):
        return max(1, cpu_reference)
    return max(1, min(cpu_reference, gpu_ceiling))


def _limit_points(
    anchors: Sequence[GamePerformanceAnchor],
    profiles: Dict[str, HardwarePerformanceProfile],
    axis: str,
    use_time_spy: bool,
) -> List[LimitPoint]:
    fps_by_score: Dict[int, List[int]] = {}
    for row in anchors:
        component_id = row.cpu_id if axis == "cpu" else row.gpu_id
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
    return [
        LimitPoint(score, round(mean(fps_values)))
        for score, fps_values in sorted(fps_by_score.items())
    ]


def _no_data_response(
    missing_games: List[str],
    missing_data: List[str],
    gpu_time_spy_score: Optional[int],
) -> PerfEstimateResponse:
    return PerfEstimateResponse(
        status="needs_more_data",
        average_fps=None,
        gpu_time_spy_score=gpu_time_spy_score,
        advice="当前硬件和游戏组合暂时没有可靠的 FPS 数据。",
        missing_data=missing_data,
        missing_games=missing_games,
        game_results=[],
    )
