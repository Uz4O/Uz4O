import re
from math import pow
from typing import Mapping, Optional

from app.catalog.rule_specs import get_rule_specs
from app.perf.profiles import APPROVED_GAME_PROFILES, GameLoadType


REFERENCE_CPU_SCORE = 100
REFERENCE_GPU_SCORE = 40

# R7 9800X3D + RTX 4060 at medium settings. Public-reference values are used
# where available; remaining games are conservative AI estimates.
BASE_FPS = {
    "valorant": (465, 397, 317),
    "cs2": (317, 210, 117),
    "pubg": (180, 145, 95),
    "delta-force": (150, 115, 75),
    "teamfight-tactics": (300, 250, 180),
    "league-of-legends": (400, 330, 240),
    "call-of-duty-warzone": (208, 185, 157),
    "cyberpunk-2077": (77, 58, 38),
    "red-dead-redemption-2": (82, 61, 41),
    "gta-v": (149, 101, 58),
    "black-myth-wukong": (70, 52, 32),
    "forza-horizon-6": (105, 80, 52),
    "elden-ring": (60, 60, 55),
    "cities-skylines": (105, 90, 65),
    "minecraft-java-edition": (365, 231, 121),
}

RESOLUTION_INDEX = {"1080p": 0, "2k": 1, "4k": 2}


def generated_average_fps(
    game_id: str,
    resolution: str,
    cpu_score: int,
    gpu_score: int,
) -> int:
    base = BASE_FPS[game_id][RESOLUTION_INDEX[resolution]]
    index = RESOLUTION_INDEX[resolution]
    load_type = APPROVED_GAME_PROFILES[game_id].load_type

    if load_type is GameLoadType.CPU:
        cpu_limit = base * pow(cpu_score / REFERENCE_CPU_SCORE, 0.8)
        gpu_limit = base * (1.6, 1.25, 1.0)[index] * pow(
            gpu_score / REFERENCE_GPU_SCORE,
            (0.35, 0.65, 0.9)[index],
        )
    elif load_type is GameLoadType.GPU:
        cpu_limit = base * (2.2, 2.5, 3.0)[index] * pow(
            cpu_score / REFERENCE_CPU_SCORE,
            (0.65, 0.5, 0.35)[index],
        )
        gpu_limit = base * pow(
            gpu_score / REFERENCE_GPU_SCORE,
            (0.75, 0.9, 1.0)[index],
        )
    else:
        cpu_limit = base * (1.5, 1.8, 2.2)[index] * pow(
            cpu_score / REFERENCE_CPU_SCORE,
            (0.75, 0.6, 0.45)[index],
        )
        gpu_limit = base * pow(
            gpu_score / REFERENCE_GPU_SCORE,
            (0.55, 0.75, 0.9)[index],
        )

    estimated = max(1, min(round(min(cpu_limit, gpu_limit)), 2000))
    fps_cap = APPROVED_GAME_PROFILES[game_id].fps_cap
    return min(estimated, fps_cap) if fps_cap is not None else estimated


def hardware_performance_score(
    component_id: str,
    category: str,
    name: str,
    specs: Mapping[str, object],
) -> Optional[int]:
    if category == "cpu":
        return _bounded_score(specs.get("perf_index"), 20, 130)
    if category != "gpu":
        return None

    rule_specs = get_rule_specs(
        "gpu",
        component_id=component_id,
        name=name,
    )
    if rule_specs is not None:
        return rule_specs["perf_index"]
    return _gpu_name_score(name) or _bounded_score(
        specs.get("perf_index"),
        10,
        110,
    )


def _gpu_name_score(name: str) -> Optional[int]:
    normalized = name.lower().replace("-", " ")
    nvidia = re.search(r"(gtx|rtx)\s*(\d{4})", normalized)
    if nvidia:
        model = int(nvidia.group(2))
        generation, tier = divmod(model, 100)
        scores = {
            10: {50: 18, 60: 25, 70: 32, 80: 40},
            16: {50: 25, 60: 30},
            20: {60: 32, 70: 40, 80: 50},
            30: {50: 32, 60: 42, 70: 50, 80: 60, 90: 75},
            40: {60: 40, 70: 60, 80: 85, 90: 100},
            50: {50: 45, 60: 50, 70: 75, 80: 95, 90: 110},
        }
        base = scores.get(generation, {}).get(tier)
        if base is not None:
            return min(base + _gpu_suffix_bonus(normalized), 110)

    amd = re.search(r"rx\s*(\d{4})", normalized)
    if amd:
        model = int(amd.group(1))
        generation = model // 1000
        tier = (model % 1000) // 100
        generation_base = {5: 20, 6: 30, 7: 35, 9: 45}.get(generation)
        if generation_base is not None and 5 <= tier <= 9:
            return min(
                generation_base + (tier - 5) * 10 + _gpu_suffix_bonus(normalized),
                110,
            )
    return None


def _gpu_suffix_bonus(name: str) -> int:
    bonus = 5 if re.search(r"\bti\b", name) else 0
    if "super" in name:
        bonus += 4
    if "xtx" in name:
        bonus += 8
    elif re.search(r"\bxt\b", name):
        bonus += 5
    if "gre" in name:
        bonus += 3
    return bonus


def _bounded_score(value: object, minimum: int, maximum: int) -> Optional[int]:
    if isinstance(value, bool) or not isinstance(value, int):
        return None
    return max(minimum, min(value, maximum))
