from typing import Dict, Optional

from app.perf.valorant_reference import valorant_cpu_performance_percent


# User-provided PUBG replay benchmark: 1080p, three-ultra settings. The 4K
# rows cluster around the same result and are treated as GPU-bottleneck
# validation, not as CPU ceilings.
EXACT_CPU_AVERAGE_FPS: Dict[str, int] = {
    "i9-14900k": 470,
    "r7-9800x3d": 597,
    "r7-9700x": 502,
    "r7-7800x3d": 538,
    "r7-5800x3d": 439,
}

CPU_REFERENCE_ALIASES = {
    "i9-14900kf": "i9-14900k",
}

VENDOR_ANCHORS = {
    "amd": ("r7-9800x3d", 597),
    "intel": ("i9-14900k", 470),
}


def pubg_cpu_average_fps(cpu_id: str) -> Optional[int]:
    reference_id = CPU_REFERENCE_ALIASES.get(cpu_id, cpu_id)
    exact = EXACT_CPU_AVERAGE_FPS.get(reference_id)
    if exact is not None:
        return exact

    performance_percent = valorant_cpu_performance_percent(reference_id)
    vendor = _vendor(reference_id)
    if performance_percent is None or vendor is None:
        return None
    anchor_id, anchor_fps = VENDOR_ANCHORS[vendor]
    anchor_percent = valorant_cpu_performance_percent(anchor_id)
    if anchor_percent is None:
        return None
    return round(anchor_fps * performance_percent / anchor_percent)


def _vendor(cpu_id: str) -> Optional[str]:
    if cpu_id.startswith("r"):
        return "amd"
    if cpu_id.startswith(("i", "u")):
        return "intel"
    return None
