import math
import re
from typing import Dict, Optional


CPU_RULE_SPECS = {
    "r5-5600": {"perf_index": 50, "tdp": 65},
    "r5-5600x": {"perf_index": 52, "tdp": 65},
    "r5-7500f": {"perf_index": 60, "tdp": 88},
    "r5-9600x": {"perf_index": 72, "tdp": 105},
    "i5-12600kf": {"perf_index": 68, "tdp": 150},
    "r7-9700x": {"perf_index": 80, "tdp": 120},
    "r7-7800x3d": {"perf_index": 90, "tdp": 120},
    "r7-9800x3d": {"perf_index": 100, "tdp": 120},
    "r7-9850x3d": {"perf_index": 103, "tdp": 120},
}

GPU_RULE_SPECS = {
    "rtx-3060-ti": {"perf_index": 50, "tdp": 200},
    "rx-6750-gre": {"perf_index": 43, "tdp": 250},
    "rx-7700-xt": {"perf_index": 55, "tdp": 245},
    "rx-7650-gre": {"perf_index": 43, "tdp": 230},
    "rx-7800-xt": {"perf_index": 65, "tdp": 263},
    "rx-9060-xt-8gb": {"perf_index": 50, "tdp": 180},
    "rx-9060-xt-12gb": {"perf_index": 55, "tdp": 200},
    "rx-9070-gre": {"perf_index": 75, "tdp": 220},
    "rx-9070-xt": {"perf_index": 85, "tdp": 304},
    "rtx-3070-ti": {"perf_index": 55, "tdp": 290},
    "rtx-3080": {"perf_index": 60, "tdp": 320},
    "rtx-3080-ti": {"perf_index": 65, "tdp": 350},
    "rtx-4060": {"perf_index": 40, "tdp": 115},
    "rtx-4060-ti": {"perf_index": 50, "tdp": 160},
    "rtx-4070": {"perf_index": 60, "tdp": 200},
    "rtx-4070-super": {"perf_index": 75, "tdp": 220},
    "rtx-4070-ti-super": {"perf_index": 80, "tdp": 285},
    "rtx-4090": {"perf_index": 100, "tdp": 450},
    "rtx-4090-d": {"perf_index": 98, "tdp": 425},
    "rx-7900-xt": {"perf_index": 75, "tdp": 315},
    "rx-7900-xtx": {"perf_index": 85, "tdp": 355},
    "rtx-5060": {"perf_index": 50, "tdp": 145},
    "rtx-5060-ti": {"perf_index": 60, "tdp": 180},
    "rtx-5070": {"perf_index": 75, "tdp": 250},
    "rtx-5070-ti": {"perf_index": 85, "tdp": 300},
    "rtx-5080": {"perf_index": 95, "tdp": 360},
    "rtx-5090-d-v2": {"perf_index": 105, "tdp": 575},
    "rtx-5090-d": {"perf_index": 105, "tdp": 575},
    "rtx-5090": {"perf_index": 110, "tdp": 575},
}

# Intel Arc is cataloged for office-only productivity builds. Keeping these
# separate prevents the gaming base generators from treating Arc as AMD.
OFFICE_ONLY_GPU_RULE_SPECS = {
    "arc-a580-8gb": {"perf_index": 40, "tdp": 185},
    "arc-a770-16gb": {"perf_index": 50, "tdp": 225},
    "arc-b570-10gb": {"perf_index": 45, "tdp": 150},
    "arc-b580-12gb": {"perf_index": 50, "tdp": 190},
}

CPU_PERFORMANCE = {
    component_id: specs["perf_index"]
    for component_id, specs in CPU_RULE_SPECS.items()
}
CPU_TDP = {
    component_id: specs["tdp"] for component_id, specs in CPU_RULE_SPECS.items()
}
GPU_PERFORMANCE = {
    component_id: specs["perf_index"]
    for component_id, specs in GPU_RULE_SPECS.items()
}
GPU_TDP = {
    component_id: specs["tdp"] for component_id, specs in GPU_RULE_SPECS.items()
}

GPU_MINIMUM_PSU_WATT = {
    "rtx-3070-ti": 750,
    "rtx-4090": 850,
    "rtx-4090-d": 850,
    "rtx-5070-ti": 750,
    "rtx-5080": 850,
    "rtx-5090-d-v2": 1_000,
    "rtx-5090-d": 1_000,
    "rtx-5090": 1_000,
    "rx-7700-xt": 750,
    "rx-7800-xt": 750,
    "rx-7900-xt": 750,
    "rx-7900-xtx": 850,
    "rx-9070-xt": 750,
}

PSU_RECOMMENDATION_TIERS = (550, 650, 750, 850, 1_000, 1_200, 1_600)

NATIVE_600W_GPU_CONNECTOR_IDS = {
    "rtx-5090-d-v2",
    "rtx-5090-d",
    "rtx-5090",
}


def psu_supports_gpu_power_connector(
    gpu_id: str,
    psu_specs: Dict[str, object],
) -> bool:
    if gpu_id not in NATIVE_600W_GPU_CONNECTOR_IDS:
        return True
    atx_version = psu_specs.get("atx_version")
    connector_watt = psu_specs.get("gpu_connector_max_watt")
    if (
        not isinstance(atx_version, (int, float))
        or atx_version < 3.0
        or psu_specs.get("gpu_connector") != "12V-2x6"
        or type(connector_watt) is not int
        or connector_watt < 600
    ):
        return False
    if psu_specs.get("cables_sold_separately") is True:
        return psu_specs.get("price_includes_compatible_cable_kit") is True
    return True


def minimum_psu_watt_for_specs(
    cpu_tdp: int,
    gpu_id: str,
    gpu_tdp: int,
) -> int:
    # The reviewed 550W exception only applies to 65W-class CPUs. It must not
    # leak into 12600KF and other higher-power combinations.
    if gpu_id == "rx-7650-gre" and cpu_tdp <= 65:
        return 550
    required = math.ceil((cpu_tdp + gpu_tdp) * 1.5 + 100)
    if gpu_tdp >= 140:
        required = max(required, 650)
    return max(required, GPU_MINIMUM_PSU_WATT.get(gpu_id, 0))


def recommended_psu_watt_for_specs(
    cpu_tdp: int,
    gpu_id: str,
    gpu_tdp: int,
) -> int:
    required = minimum_psu_watt_for_specs(cpu_tdp, gpu_id, gpu_tdp)
    return next(
        (tier for tier in PSU_RECOMMENDATION_TIERS if tier >= required),
        math.ceil(required / 100) * 100,
    )


def minimum_psu_watt(cpu_id: str, gpu_id: str) -> int:
    return minimum_psu_watt_for_specs(
        CPU_TDP[cpu_id],
        gpu_id,
        GPU_TDP[gpu_id],
    )

# CPU/GPU pairing tiers follow the user-reviewed gaming balance table. These
# tiers are only for pairing validation, not a general CPU performance ranking.
CPU_GPU_PAIRING_TIER = {
    "r5-7500f": 0,
    "i5-12600kf": 0,
    "r5-9600x": 1,
    "r7-9700x": 2,
    "r7-7800x3d": 3,
    "r7-9800x3d": 4,
    "r7-9850x3d": 4,
}
SPECIAL_5600_CPU_IDS = {"r5-5600", "r5-5600x"}
GPU_PAIRING_TIER = {
    "rx-6750-gre": 0,
    "rx-7650-gre": 0,
    "rtx-4060": 0,
    "rtx-3060-ti": 1,
    "rtx-4060-ti": 1,
    "rtx-5060": 1,
    "rx-9060-xt-8gb": 1,
    "rx-7700-xt": 2,
    "rx-9060-xt-12gb": 2,
    "rtx-3070-ti": 2,
    "rtx-3080": 2,
    "rtx-4070": 2,
    "rtx-5060-ti": 2,
    "rtx-3080-ti": 3,
    "rx-9070-gre": 3,
    "rx-9070-xt": 5,
    "rx-7800-xt": 6,
    "rtx-4070-super": 6,
    "rtx-4070-ti-super": 6,
    "rtx-5070": 6,
    "rx-7900-xt": 7,
    "rtx-5070-ti": 7,
    "rx-7900-xtx": 8,
    "rtx-5080": 8,
    "rtx-4090-d": 8,
    "rtx-4090": 8,
    "rtx-5090-d-v2": 9,
    "rtx-5090-d": 9,
    "rtx-5090": 9,
}
GPU_PAIRING_CPU_TIER_BOUNDS = {
    0: (0, 0),
    1: (0, 2),
    2: (0, 3),
    3: (0, 2),
    4: (0, 3),
    5: (1, 5),
    6: (1, 5),
    7: (1, 5),
    8: (2, 5),
    9: (4, 5),
}


def is_cpu_gpu_pairing_allowed(cpu_id: str, gpu_id: str) -> bool:
    gpu_tier = GPU_PAIRING_TIER.get(gpu_id)
    if gpu_tier is None:
        return False
    if cpu_id in SPECIAL_5600_CPU_IDS:
        return gpu_tier <= 2
    cpu_tier = CPU_GPU_PAIRING_TIER.get(cpu_id)
    if cpu_tier is None:
        return False
    minimum_cpu_tier, maximum_cpu_tier = GPU_PAIRING_CPU_TIER_BOUNDS[gpu_tier]
    return minimum_cpu_tier <= cpu_tier <= maximum_cpu_tier


GPU_MIN_CPU_PERFORMANCE = {
    component_id: CPU_PERFORMANCE["r5-9600x"]
    for component_id in (
        "rx-9070-xt",
        "rx-7800-xt",
        "rtx-4070-super",
        "rtx-4070-ti-super",
        "rtx-5070",
        "rx-7900-xt",
        "rtx-5070-ti",
    )
}
GPU_MIN_CPU_PERFORMANCE.update(
    {
        component_id: CPU_PERFORMANCE["r7-9700x"]
        for component_id in (
            "rx-7900-xtx",
            "rtx-5080",
            "rtx-4090-d",
            "rtx-4090",
        )
    }
)
GPU_MIN_CPU_PERFORMANCE.update(
    {
        component_id: CPU_PERFORMANCE["r7-9800x3d"]
        for component_id in (
            "rtx-5090-d-v2",
            "rtx-5090-d",
            "rtx-5090",
        )
    }
)


def get_rule_specs(
    category: str,
    *,
    component_id: str = "",
    name: str = "",
) -> Optional[Dict[str, int]]:
    specs_by_id = {
        "cpu": CPU_RULE_SPECS,
        "gpu": {**GPU_RULE_SPECS, **OFFICE_ONLY_GPU_RULE_SPECS},
    }.get(category)
    if specs_by_id is None:
        return None
    for candidate in (component_id.strip().lower(), _component_key(name)):
        if candidate in specs_by_id:
            return dict(specs_by_id[candidate])
    return None


def _component_key(name: str) -> str:
    return re.sub(r"[^a-z0-9]+", "-", name.lower()).strip("-")
