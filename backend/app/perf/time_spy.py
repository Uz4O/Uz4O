from typing import Dict, Iterable, Optional

from app.perf.models import HardwarePerformanceProfile


# User-provided 3DMark Time Spy chart, dated 2025-07-07. Exact chart matches
# are used directly. RTX 5090 and RTX 5090 D share the confirmed 47539-point
# gaming baseline and therefore both normalize to 100%.
GPU_TIME_SPY_SCORES: Dict[str, int] = {
    "arc-b580-12gb": 14688,
    "arc-b570-10gb": 12610,
    "arc-a770-16gb": 13243,
    "arc-a580-8gb": 10309,
    "rtx-5090": 47539,
    "rtx-5090-d": 47539,
    "rtx-5090-d-v2": 47000,
    "rtx-5080": 33018,
    "rtx-5070-ti": 27702,
    "rtx-5070": 22603,
    "rtx-5060-ti": 15827,
    "rtx-5060": 13742,
    "rtx-5050": 10237,
    "rtx-4090-d": 34257,
    "rtx-4080-super": 28448,
    "rtx-4080": 28194,
    "rtx-4070-ti-super": 24349,
    "rtx-4070-ti": 22762,
    "rtx-4070-super": 21070,
    "rtx-4070": 17867,
    "rtx-4060-ti": 13514,
    "rtx-4060": 10626,
    "rtx-3090-ti": 21827,
    "rtx-3090": 19904,
    "rtx-3080-ti": 19628,
    "rtx-3080": 17662,
    "rtx-3070-ti": 14868,
    "rtx-3070": 13640,
    "rtx-3060-ti": 11710,
    "rtx-3060": 8741,
    "rtx-3050": 6198,
    "rtx-2080-ti": 14670,
    "rtx-2070-super": 10171,
    "rtx-2060-super": 8748,
    "rtx-2060": 7502,
    "gtx-1660-ti": 6262,
    "gtx-1660-super": 5986,
    "gtx-1650": 3592,
    "gtx-1080-ti": 9955,
    "gtx-1080": 7545,
    "gtx-1070-ti": 6806,
    "gtx-1070": 6052,
    "gtx-1060-6gb": 4181,
    "gtx-1060-5gb": 3891,
    "gtx-1060-3gb": 3830,
    "gtx-1050-ti": 2337,
    "gtx-1050": 1735,
    "rx-9070-xt": 30073,
    "rx-9070-gre": 21829,
    "rx-9060-xt-8gb": 16280,
    "rx-9060-xt-16gb": 16565,
    "rx-7900-xtx": 30633,
    "rx-7900-xt": 26965,
    "rx-7900-gre": 22505,
    "rx-7800-xt": 20027,
    "rx-7700-xt": 17042,
    "rx-7650-gre": 10872,
    "rx-7600": 10982,
    "rx-6950-xt": 21562,
    "rx-6900-xt": 20782,
    "rx-6800-xt": 19302,
    "rx-6800": 16166,
    "rx-6750-xt": 13536,
    "rx-6700-xt": 12798,
    "rx-6700": 11196,
    "rx-6650-xt": 9951,
    "rx-6600-xt": 9669,
    "rx-6600": 8021,
    "rx-6500-xt": 4935,
    "rx-5700-xt": 9427,
    "rx-5700": 8220,
    "rx-5600-xt": 7556,
    "rx-5500-xt": 4858,
}

REFERENCE_TIME_SPY_SCORE = 10_626
REFERENCE_GENERATED_GPU_SCORE = 40
GPU_COMPARISON_REFERENCE_SCORE = 47_539
GPU_TIME_SPY_PERCENT_OVERRIDES = {
    "rtx-5090": 100.0,
    "rtx-5090-d": 100.0,
}


def gpu_time_spy_score(component_id: str) -> Optional[int]:
    return GPU_TIME_SPY_SCORES.get(component_id)


def gpu_time_spy_percent(component_id: str) -> Optional[float]:
    override = GPU_TIME_SPY_PERCENT_OVERRIDES.get(component_id)
    if override is not None:
        return override
    exact_percent = gpu_time_spy_comparison_percent(component_id)
    if exact_percent is None:
        return None
    return round(exact_percent, 1)


def gpu_time_spy_comparison_percent(component_id: str) -> Optional[float]:
    override = GPU_TIME_SPY_PERCENT_OVERRIDES.get(component_id)
    if override is not None:
        return override
    score = gpu_time_spy_score(component_id)
    if score is None:
        return None
    return score / GPU_COMPARISON_REFERENCE_SCORE * 100


def generated_gpu_performance_score(
    component_id: str,
    fallback_score: Optional[int],
) -> Optional[int]:
    score = gpu_time_spy_score(component_id)
    if score is None:
        return fallback_score
    return max(
        1,
        round(
            REFERENCE_GENERATED_GPU_SCORE
            * score
            / REFERENCE_TIME_SPY_SCORE
        ),
    )


def has_time_spy_scores(component_ids: Iterable[str]) -> bool:
    ids = set(component_ids)
    return bool(ids) and ids.issubset(GPU_TIME_SPY_SCORES)


def effective_performance_score(
    profile: HardwarePerformanceProfile,
    *,
    use_time_spy: bool,
) -> int:
    if profile.category == "gpu" and use_time_spy:
        return gpu_time_spy_score(profile.component_id) or profile.performance_score
    return profile.performance_score
