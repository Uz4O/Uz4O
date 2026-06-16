from statistics import mean
from typing import Dict, List, Literal, Optional

from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from app.catalog.models import HardwareComponent
from app.catalog.repository import get_components_by_ids


PerfStatus = Literal["ready", "needs_more_data"]
Confidence = Literal["low", "medium", "high"]
Resolution = Literal["1080p", "2k", "4k"]

RESOLUTION_FACTORS: Dict[str, float] = {
    "1080p": 1.25,
    "2k": 1.0,
    "4k": 0.58,
}

GAME_WEIGHTS: Dict[str, float] = {
    "CS2": 1.28,
    "无畏契约": 1.35,
    "PUBG": 0.92,
    "赛博朋克2077": 0.58,
    "黑神话悟空": 0.55,
    "原神": 1.08,
    "永劫无间": 0.82,
}


class PerfHardwareInput(BaseModel):
    cpu: str = Field(min_length=1, max_length=160)
    gpu: str = Field(min_length=1, max_length=160)


class PerfEstimateRequest(BaseModel):
    hardware: PerfHardwareInput
    resolution: Resolution
    games: List[str] = Field(min_length=1, max_length=12)


class GamePerfEstimate(BaseModel):
    game: str
    average_fps: int
    low_fps: int
    confidence: Confidence


class PerfEstimateResponse(BaseModel):
    status: PerfStatus
    average_fps: Optional[int]
    low_fps: Optional[int]
    bottleneck: Optional[str]
    confidence: Confidence
    advice: str
    missing_data: List[str]
    game_results: List[GamePerfEstimate]


def estimate_performance(session: Session, request: PerfEstimateRequest) -> PerfEstimateResponse:
    components = {
        component.id: component
        for component in get_components_by_ids(session, [request.hardware.cpu, request.hardware.gpu])
    }
    cpu = components.get(request.hardware.cpu)
    gpu = components.get(request.hardware.gpu)
    missing_data = _missing_data(cpu, gpu)
    if missing_data:
        return PerfEstimateResponse(
            status="needs_more_data",
            average_fps=None,
            low_fps=None,
            bottleneck=None,
            confidence="low",
            advice="当前硬件缺少性能指标，暂时不能给出可信 FPS 估算。",
            missing_data=missing_data,
            game_results=[],
        )

    assert cpu is not None
    assert gpu is not None
    cpu_perf = _int_spec(cpu, "perf_index")
    gpu_perf = _int_spec(gpu, "perf_index")
    bottleneck = _bottleneck(cpu_perf, gpu_perf, request.resolution)
    game_results = [
        _estimate_game(game, cpu_perf, gpu_perf, request.resolution)
        for game in request.games
    ]
    average_fps = round(mean(result.average_fps for result in game_results))
    low_fps = round(mean(result.low_fps for result in game_results))
    confidence: Confidence = "medium"
    return PerfEstimateResponse(
        status="ready",
        average_fps=average_fps,
        low_fps=low_fps,
        bottleneck=bottleneck,
        confidence=confidence,
        advice=_advice(bottleneck, request.resolution),
        missing_data=[],
        game_results=game_results,
    )


def _estimate_game(
    game: str,
    cpu_perf: int,
    gpu_perf: int,
    resolution: str,
) -> GamePerfEstimate:
    game_weight = GAME_WEIGHTS.get(game, 0.85)
    resolution_factor = RESOLUTION_FACTORS[resolution]
    cpu_limited = cpu_perf * 2.1
    gpu_limited = gpu_perf * 2.35 * resolution_factor
    average_fps = round(min(cpu_limited, gpu_limited) * game_weight)
    low_fps = max(round(average_fps * 0.78), 1)
    return GamePerfEstimate(
        game=game,
        average_fps=max(average_fps, 1),
        low_fps=low_fps,
        confidence="medium" if game in GAME_WEIGHTS else "low",
    )


def _missing_data(
    cpu: Optional[HardwareComponent],
    gpu: Optional[HardwareComponent],
) -> List[str]:
    missing = []
    if cpu is None:
        missing.append("cpu")
    elif _int_spec(cpu, "perf_index") <= 0:
        missing.append("cpu.perf_index")
    if gpu is None:
        missing.append("gpu")
    elif _int_spec(gpu, "perf_index") <= 0:
        missing.append("gpu.perf_index")
    if any(item.endswith(".perf_index") for item in missing):
        missing.insert(0, "perf_index")
    return missing


def _bottleneck(cpu_perf: int, gpu_perf: int, resolution: str) -> str:
    gpu_pressure = {"1080p": 0.85, "2k": 1.0, "4k": 1.35}[resolution]
    adjusted_gpu = gpu_perf / gpu_pressure
    if adjusted_gpu < cpu_perf * 0.95:
        return "gpu"
    if cpu_perf < adjusted_gpu * 0.85:
        return "cpu"
    return "balanced"


def _advice(bottleneck: str, resolution: str) -> str:
    if bottleneck == "gpu":
        return f"{resolution} 下主要瓶颈在显卡，优先升级显卡会更直接提升帧率。"
    if bottleneck == "cpu":
        return "当前更容易受 CPU 影响，尤其是高刷电竞游戏，优先升级 CPU/平台更稳。"
    return "CPU 和显卡比较均衡，建议结合预算和游戏类型决定下一步升级。"


def _int_spec(component: HardwareComponent, key: str) -> int:
    value = component.specs.get(key)
    return value if isinstance(value, int) else 0
