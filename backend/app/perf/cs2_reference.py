from typing import Dict, Optional

from app.perf.valorant_reference import valorant_cpu_performance_percent


# User's measured CS2 result: R7 9700X, 1920x1080, about 432 average FPS.
# Other 1080P CPU ceilings follow the maintained relative CPU ranking. The
# selected GPU ceiling is still applied by the estimator, so a slower GPU can
# lower the final result.
REFERENCE_CPU_ID = "r7-9700x"
REFERENCE_1080P_FPS = 432

CPU_REFERENCE_ALIASES = {
    "i9-14900kf": "i9-14900k",
    "i7-14700kf": "i7-14700k",
    "i5-14600kf": "i5-14600k",
    "i5-13600kf": "i5-13600k",
}

# CPUs present in the earlier CS2 chart but absent from the shared ranking are
# positioned relative to the chart's i9-14900K result.
CS2_CHART_AVERAGE_FPS: Dict[str, int] = {
    "i9-14900k": 545,
    "i9-13900ks": 540,
    "i7-13700k": 501,
    "i5-13600k": 452,
}


def cs2_cpu_average_fps(cpu_id: str, resolution: str) -> Optional[int]:
    if resolution != "1080p":
        return None

    reference_id = CPU_REFERENCE_ALIASES.get(cpu_id, cpu_id)
    performance_percent = valorant_cpu_performance_percent(reference_id)
    if performance_percent is None:
        performance_percent = _chart_performance_percent(reference_id)

    reference_percent = valorant_cpu_performance_percent(REFERENCE_CPU_ID)
    if performance_percent is None or reference_percent is None:
        return None
    return round(REFERENCE_1080P_FPS * performance_percent / reference_percent)


def _chart_performance_percent(cpu_id: str) -> Optional[float]:
    average_fps = CS2_CHART_AVERAGE_FPS.get(cpu_id)
    anchor_fps = CS2_CHART_AVERAGE_FPS["i9-14900k"]
    anchor_percent = valorant_cpu_performance_percent("i9-14900k")
    if average_fps is None or anchor_percent is None:
        return None
    return anchor_percent * average_fps / anchor_fps
