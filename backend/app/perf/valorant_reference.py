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

# CPU ladder snapshot sourced from truebottleneck.com/zh/cpu-tier-list/.
# Scores are the site's normalized gaming-performance values (100 = the
# current list leader), kept separately from the measured Valorant references
# used by the FPS estimator and comparison endpoint.
CPU_TIER_LIST: List[Tuple[str, str, str, float]] = [
    ("r7-9850x3d", "AMD Ryzen 7 9850X3D", "AMD", 100.0),
    ("r9-9900x3d", "AMD Ryzen 9 9900X3D", "AMD", 99.0),
    ("r7-9800x3d", "AMD Ryzen 7 9800X3D", "AMD", 97.0),
    ("r9-9950x3d", "AMD Ryzen 9 9950X3D", "AMD", 90.0),
    ("r9-7900x3d", "AMD Ryzen 9 7900X3D", "AMD", 83.0),
    ("u9-285k", "Intel Core Ultra 9 285K", "Intel", 83.0),
    ("r7-7800x3d", "AMD Ryzen 7 7800X3D", "AMD", 79.0),
    ("u7-265k", "Intel Core Ultra 7 265K", "Intel", 75.0),
    ("r9-7950x3d", "AMD Ryzen 9 7950X3D", "AMD", 75.0),
    ("u9-285", "Intel Core Ultra 9 285", "Intel", 75.0),
    ("u7-265kf", "Intel Core Ultra 7 265KF", "Intel", 74.0),
    ("u5-245k", "Intel Core Ultra 5 245K", "Intel", 73.0),
    ("u5-245kf", "Intel Core Ultra 5 245KF", "Intel", 72.0),
    ("r5-5600x3d", "AMD Ryzen 5 5600X3D", "AMD", 71.0),
    ("i9-14900ks", "Intel Core i9-14900KS", "Intel", 68.0),
    ("r5-5500x3d", "AMD Ryzen 5 5500X3D", "AMD", 66.0),
    ("r9-9900x", "AMD Ryzen 9 9900X", "AMD", 65.0),
    ("i9-13900ks", "Intel Core i9-13900KS", "Intel", 65.0),
    ("u5-235", "Intel Core Ultra 5 235", "Intel", 64.0),
    ("r7-5800x3d", "AMD Ryzen 7 5800X3D", "AMD", 64.0),
    ("i9-14900kf", "Intel Core i9-14900KF", "Intel", 63.0),
    ("i9-14900k", "Intel Core i9-14900K", "Intel", 63.0),
    ("u7-265", "Intel Core Ultra 7 265", "Intel", 63.0),
    ("u5-245", "Intel Core Ultra 5 245", "Intel", 63.0),
    ("r7-5700x3d", "AMD Ryzen 7 5700X3D", "AMD", 62.0),
    ("i9-13900k", "Intel Core i9-13900K", "Intel", 60.0),
    ("i9-14900f", "Intel Core i9-14900F", "Intel", 59.0),
    ("i7-14700k", "Intel Core i7-14700K", "Intel", 58.0),
    ("i7-14700kf", "Intel Core i7-14700KF", "Intel", 58.0),
    ("i9-13900kf", "Intel Core i9-13900KF", "Intel", 58.0),
    ("u5-225", "Intel Core Ultra 5 225", "Intel", 57.0),
    ("r9-7900x", "AMD Ryzen 9 7900X", "AMD", 56.0),
    ("r5-9600x", "AMD Ryzen 5 9600X", "AMD", 56.0),
    ("r9-7900", "AMD Ryzen 9 7900", "AMD", 55.0),
    ("i7-13790f", "Intel Core i7-13790F", "Intel", 55.0),
    ("i5-14600k", "Intel Core i5-14600K", "Intel", 55.0),
    ("r9-9950x", "AMD Ryzen 9 9950X", "AMD", 54.0),
    ("i5-14600kf", "Intel Core i5-14600KF", "Intel", 54.0),
    ("i5-13600k", "Intel Core i5-13600K", "Intel", 49.0),
    ("i5-13600kf", "Intel Core i5-13600KF", "Intel", 49.0),
    ("i5-14600", "Intel Core i5-14600", "Intel", 49.0),
    ("r9-7950x", "AMD Ryzen 9 7950X", "AMD", 48.0),
    ("i7-14700", "Intel Core i7-14700", "Intel", 48.0),
    ("r5-7600x", "AMD Ryzen 5 7600X", "AMD", 48.0),
    ("r9-3950x", "AMD Ryzen 9 3950X", "AMD", 48.0),
    ("r7-9700f", "AMD Ryzen 7 9700F", "AMD", 48.0),
    ("r5-7500f", "AMD Ryzen 5 7500F", "AMD", 48.0),
    ("r7-7700g", "AMD Ryzen 7 7700G", "AMD", 47.0),
    ("i9-12900ks", "Intel Core i9-12900KS", "Intel", 47.0),
    ("u5-335", "Intel Core Ultra 5 335", "Intel", 46.0),
    ("r5-7600", "AMD Ryzen 5 7600", "AMD", 46.0),
    ("r5-8500ge", "AMD Ryzen 5 8500GE", "AMD", 46.0),
    ("i3-14100f", "Intel Core i3-14100F", "Intel", 44.0),
    ("r3-8300g", "AMD Ryzen 3 8300G", "AMD", 44.0),
    ("i3-14100", "Intel Core i3-14100", "Intel", 44.0),
    ("i5-13490f", "Intel Core i5-13490F", "Intel", 44.0),
    ("i7-13700f", "Intel Core i7-13700F", "Intel", 44.0),
    ("i9-12900k", "Intel Core i9-12900K", "Intel", 43.0),
    ("i5-14500", "Intel Core i5-14500", "Intel", 43.0),
    ("r5-8400f", "AMD Ryzen 5 8400F", "AMD", 43.0),
    ("r5-7400f", "AMD Ryzen 5 7400F", "AMD", 43.0),
    ("r7-7700x", "AMD Ryzen 7 7700X", "AMD", 43.0),
    ("i9-9900k", "Intel Core i9-9900K", "Intel", 34.0),
    ("r9-5900xt", "AMD Ryzen 9 5900XT", "AMD", 34.0),
    ("r5-5600x", "AMD Ryzen 5 5600X", "AMD", 34.0),
    ("r5-8600g", "AMD Ryzen 5 8600G", "AMD", 34.0),
    ("i7-9700k", "Intel Core i7-9700K", "Intel", 33.0),
    ("i7-9700kf", "Intel Core i7-9700KF", "Intel", 33.0),
    ("i7-8086k", "Intel Core i7-8086K", "Intel", 33.0),
    ("i5-10505", "Intel Core i5-10505", "Intel", 33.0),
    ("i5-10500", "Intel Core i5-10500", "Intel", 33.0),
    ("r9-5950x", "AMD Ryzen 9 5950X", "AMD", 32.0),
    ("r9-3900x", "AMD Ryzen 9 3900X", "AMD", 32.0),
    ("i7-9700", "Intel Core i7-9700", "Intel", 32.0),
    ("i7-12700", "Intel Core i7-12700", "Intel", 32.0),
    ("i5-12490f", "Intel Core i5-12490F", "Intel", 32.0),
    ("i7-9700f", "Intel Core i7-9700F", "Intel", 32.0),
    ("i3-9350k", "Intel Core i3-9350K", "Intel", 32.0),
    ("i5-9600k", "Intel Core i5-9600K", "Intel", 32.0),
    ("i7-8700k", "Intel Core i7-8700K", "Intel", 32.0),
    ("i5-9600kf", "Intel Core i5-9600KF", "Intel", 32.0),
    ("r5-4400g", "AMD Ryzen 5 4400G", "AMD", 32.0),
    ("r7-3800x", "AMD Ryzen 7 3800X", "AMD", 32.0),
    ("r5-8500g", "AMD Ryzen 5 8500G", "AMD", 31.0),
    ("i7-12700f", "Intel Core i7-12700F", "Intel", 31.0),
    ("i5-9600", "Intel Core i5-9600", "Intel", 31.0),
    ("i5-4470", "Intel Core i5-4470", "Intel", 19.0),
    ("i5-2400", "Intel Core i5-2400", "Intel", 18.0),
    ("i3-2130", "Intel Core i3-2130", "Intel", 18.0),
    ("i3-2140", "Intel Core i3-2140", "Intel", 18.0),
    ("i3-2120", "Intel Core i3-2120", "Intel", 18.0),
    ("r5-2600", "AMD Ryzen 5 2600", "AMD", 16.0),
    ("i5-10400f", "Intel Core i5-10400F", "Intel", 15.0),
    ("i7-7700k", "Intel Core i7-7700K", "Intel", 12.0),
    ("i5-8500", "Intel Core i5-8500", "Intel", 12.0),
    ("i5-9400f", "Intel Core i5-9400F", "Intel", 12.0),
    ("i5-9400", "Intel Core i5-9400", "Intel", 12.0),
    ("i7-4930k", "Intel Core i7-4930K", "Intel", 12.0),
    ("r5-2500x", "AMD Ryzen 5 2500X", "AMD", 12.0),
    ("i5-8400", "Intel Core i5-8400", "Intel", 12.0),
    ("r5-3350ge", "AMD Ryzen 5 3350GE", "AMD", 11.0),
    ("i7-6700k", "Intel Core i7-6700K", "Intel", 11.0),
    ("r5-3350g", "AMD Ryzen 5 3350G", "AMD", 11.0),
    ("i5-3170k", "Intel Core i5-3170K", "Intel", 11.0),
    ("i7-7700", "Intel Core i7-7700", "Intel", 11.0),
    ("i7-4790k", "Intel Core i7-4790K", "Intel", 10.0),
    ("i7-6700", "Intel Core i7-6700", "Intel", 10.0),
    ("i7-4790", "Intel Core i7-4790", "Intel", 9.0),
    ("i5-6400", "Intel Core i5-6400", "Intel", 6.0),
    ("i5-4460", "Intel Core i5-4460", "Intel", 6.0),
]

CPU_REFERENCE_ALIASES = {
    "i9-14900kf": "i9-14900k",
    "i7-14700kf": "i7-14700k",
    "i5-14600kf": "i5-14600k",
    "i5-12600k": "i5-12600kf",
    "i5-12400": "i5-12400f",
}

# R7 9850X3D is not present in the supplied Valorant charts. The maintained
# hardware ranking places it 3% above the chart-leading R7 9800X3D, so its
# game references are derived from that measured anchor rather than falling
# back to the generic estimator.
DERIVED_CPU_PERFORMANCE_PERCENT = {
    "r7-9850x3d": 103.0,
}


def valorant_cpu_average_fps(cpu_id: str, resolution: str) -> Optional[int]:
    reference_id = CPU_REFERENCE_ALIASES.get(cpu_id, cpu_id)
    rows = CPU_AVERAGE_FPS.get(resolution, {})
    exact = rows.get(reference_id)
    if exact is not None:
        return exact
    derived_percent = DERIVED_CPU_PERFORMANCE_PERCENT.get(reference_id)
    anchor = rows.get("r7-9800x3d")
    if derived_percent is None or anchor is None:
        return None
    return round(anchor * derived_percent / 100)


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
    ranking.extend(DERIVED_CPU_PERFORMANCE_PERCENT.items())
    return sorted(ranking, key=lambda row: (-row[1], row[0]))


def valorant_cpu_performance_percent(cpu_id: str) -> Optional[float]:
    reference_id = CPU_REFERENCE_ALIASES.get(cpu_id, cpu_id)
    return dict(valorant_cpu_performance_ranking()).get(reference_id)


def valorant_cpu_benchmark_score(cpu_id: str) -> Optional[float]:
    values = [
        valorant_cpu_average_fps(cpu_id, resolution)
        for resolution in CPU_AVERAGE_FPS
    ]
    if any(value is None for value in values):
        return None
    return round(mean(values), 1)
