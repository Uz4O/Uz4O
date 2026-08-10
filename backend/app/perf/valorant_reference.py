from statistics import mean
from typing import Dict, List, Optional, Tuple


# User-provided Valorant CPU benchmark charts. Values are average FPS at high
# quality under the chart's fixed DX11 custom 1v1 scene. They are CPU ceilings;
# the estimator still applies the selected GPU's lower limit when necessary.
CPU_AVERAGE_FPS: Dict[str, Dict[str, int]] = {
    "1080p": {
        "r7-9800x3d": 712,
        "r7-9700x": 663,
        "r7-7800x3d": 625,
        "r9-9950x": 624,
        "r9-9900x": 607,
        "r5-9600x": 599,
        "r9-7900x": 596,
        "r5-7600x": 578,
        "r7-7700x": 577,
        "r9-7950x": 576,
        "r5-7500f": 550,
        "r9-7900x3d": 543,
        "r9-7950x3d": 539,
        "r7-5800x3d": 504,
        "i9-14900k": 462,
        "i9-14900ks": 461,
        "i7-14700k": 460,
        "u9-285k": 421,
        "i5-14600k": 417,
        "u7-265k": 387,
        "u5-245k": 362,
        "i5-12600kf": 328,
        "i5-12400f": 290,
    },
    "2k": {
        "r7-9800x3d": 708,
        "r7-9700x": 643,
        "r7-7800x3d": 625,
        "r5-9600x": 609,
        "r9-9950x": 604,
        "r7-7700x": 603,
        "r9-9900x": 603,
        "r9-7900x": 600,
        "r9-7950x": 579,
        "r5-7600x": 579,
        "r9-7950x3d": 561,
        "r9-7900x3d": 547,
        "r5-7500f": 532,
        "r7-5800x3d": 517,
        "i9-14900k": 482,
        "i9-14900ks": 474,
        "i7-14700k": 468,
        "u9-285k": 437,
        "i5-14600k": 431,
        "u7-265k": 395,
        "u5-245k": 356,
        "i5-12600kf": 320,
        "i5-12400f": 286,
    },
}

CPU_REFERENCE_ALIASES = {
    "i9-14900kf": "i9-14900k",
    "i7-14700kf": "i7-14700k",
    "i5-14600kf": "i5-14600k",
    "i5-12600k": "i5-12600kf",
    "i5-12400": "i5-12400f",
}


def valorant_cpu_average_fps(cpu_id: str, resolution: str) -> Optional[int]:
    reference_id = CPU_REFERENCE_ALIASES.get(cpu_id, cpu_id)
    return CPU_AVERAGE_FPS.get(resolution, {}).get(reference_id)


def valorant_cpu_performance_ranking() -> List[Tuple[str, float]]:
    reference_id = "r7-9800x3d"
    common_ids = set.intersection(
        *(set(rows) for rows in CPU_AVERAGE_FPS.values())
    )
    ranking = []
    for cpu_id in common_ids:
        relative_scores = [
            CPU_AVERAGE_FPS[resolution][cpu_id]
            / CPU_AVERAGE_FPS[resolution][reference_id]
            for resolution in CPU_AVERAGE_FPS
        ]
        ranking.append((cpu_id, round(mean(relative_scores) * 100, 1)))
    return sorted(ranking, key=lambda row: (-row[1], row[0]))


def valorant_cpu_performance_percent(cpu_id: str) -> Optional[float]:
    reference_id = CPU_REFERENCE_ALIASES.get(cpu_id, cpu_id)
    return dict(valorant_cpu_performance_ranking()).get(reference_id)
