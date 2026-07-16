import json
from pathlib import Path
import re
from typing import Dict, Optional


CPU_RULE_SPECS = {
    "r5-5600": {"perf_index": 50, "tdp": 65},
    "r5-5600x": {"perf_index": 52, "tdp": 65},
    "r5-7500f": {"perf_index": 60, "tdp": 88},
    "r5-9600x": {"perf_index": 72, "tdp": 105},
    "i5-13600kf": {"perf_index": 78, "tdp": 181},
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

MOTHERBOARD_RULE_SPECS = {
    row["component_id"]: {
        **({"legacy_name": row["legacy_name"]} if row.get("legacy_name") else {}),
        **(
            {
                "cpu_power_phases": row["cpu_power_phases"],
                "phase_watts": row["phase_watts"],
                "cpu_power_limit": row["cpu_power_limit"],
            }
            if row.get("status") == "exact" and row.get("cpu_power_phases") is not None
            else {}
        ),
    }
    for row in json.loads(
        (Path(__file__).resolve().parents[2] / "data" / "motherboard-official-specs.json").read_text(
            encoding="utf-8"
        )
    )
    if row.get("legacy_name")
    or (row.get("status") == "exact" and row.get("cpu_power_phases") is not None)
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


def get_rule_specs(
    category: str,
    *,
    component_id: str = "",
    name: str = "",
) -> Optional[Dict[str, object]]:
    specs_by_id = {
        "cpu": CPU_RULE_SPECS,
        "gpu": GPU_RULE_SPECS,
        "motherboard": MOTHERBOARD_RULE_SPECS,
    }.get(category)
    if specs_by_id is None:
        return None
    for candidate in (component_id.strip().lower(), _component_key(name)):
        if candidate in specs_by_id:
            return dict(specs_by_id[candidate])
    return None


def _component_key(name: str) -> str:
    return re.sub(r"[^a-z0-9]+", "-", name.lower()).strip("-")
