from dataclasses import dataclass
from typing import Optional, Sequence


@dataclass(frozen=True)
class LimitPoint:
    performance_score: int
    average_fps: int


@dataclass(frozen=True)
class AverageFPSPrediction:
    average_fps: int
    cpu_limit: int
    gpu_limit: int
    limiting_component: str


def predict_average_fps(
    cpu_score: int,
    gpu_score: int,
    cpu_points: Sequence[LimitPoint],
    gpu_points: Sequence[LimitPoint],
    correction_factor: float,
    fps_cap: Optional[int],
) -> AverageFPSPrediction:
    cpu_limit = round(_interpolate(cpu_points, cpu_score))
    gpu_limit = round(_interpolate(gpu_points, gpu_score))
    limiting_component = "cpu" if cpu_limit <= gpu_limit else "gpu"
    estimated = max(1, round(min(cpu_limit, gpu_limit) * correction_factor))
    if fps_cap is not None:
        estimated = min(estimated, fps_cap)
    return AverageFPSPrediction(
        average_fps=estimated,
        cpu_limit=cpu_limit,
        gpu_limit=gpu_limit,
        limiting_component=limiting_component,
    )


def _interpolate(points: Sequence[LimitPoint], target_score: int) -> float:
    ordered = sorted(points, key=lambda point: point.performance_score)
    if len({point.performance_score for point in ordered}) != len(ordered):
        raise ValueError("performance scores must be distinct")
    if len(ordered) < 2:
        raise ValueError("each axis requires at least two distinct points")
    if any(
        right.average_fps < left.average_fps
        for left, right in zip(ordered, ordered[1:])
    ):
        raise ValueError("average FPS must be monotonic")

    if target_score <= ordered[0].performance_score:
        lower, upper = ordered[0], ordered[1]
    elif target_score >= ordered[-1].performance_score:
        lower, upper = ordered[-2], ordered[-1]
    else:
        lower, upper = next(
            (left, right)
            for left, right in zip(ordered, ordered[1:])
            if left.performance_score <= target_score <= right.performance_score
        )

    distance = upper.performance_score - lower.performance_score
    ratio = (target_score - lower.performance_score) / distance
    interpolated = lower.average_fps + ratio * (
        upper.average_fps - lower.average_fps
    )
    return max(1.0, interpolated)
