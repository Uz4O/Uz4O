from dataclasses import dataclass
from enum import Enum
from typing import Dict, Optional


class GameLoadType(str, Enum):
    CPU = "cpu"
    GPU = "gpu"
    MIXED = "mixed"


class RenderMode(str, Enum):
    NATIVE = "native"
    DLSS_QUALITY = "dlss_quality"
    DLSS_QUALITY_FG = "dlss_quality_fg"
    FSR_QUALITY = "fsr_quality"
    FSR_QUALITY_FG = "fsr_quality_fg"


@dataclass(frozen=True)
class GameProfile:
    game_id: str
    load_type: GameLoadType
    supports_dlss: bool = False
    supports_fsr: bool = False
    supports_frame_generation: bool = False
    fps_cap: Optional[int] = None


@dataclass(frozen=True)
class GPUCapabilities:
    supports_dlss: bool
    supports_fsr: bool
    supports_standard_frame_generation: bool


APPROVED_GAME_PROFILES: Dict[str, GameProfile] = {
    "valorant": GameProfile("valorant", GameLoadType.CPU),
    "cs2": GameProfile("cs2", GameLoadType.CPU),
    "pubg": GameProfile("pubg", GameLoadType.MIXED, supports_dlss=True),
    "delta-force": GameProfile(
        "delta-force",
        GameLoadType.MIXED,
        supports_dlss=True,
        supports_fsr=True,
        supports_frame_generation=True,
    ),
    "teamfight-tactics": GameProfile("teamfight-tactics", GameLoadType.CPU),
    "league-of-legends": GameProfile("league-of-legends", GameLoadType.CPU),
    "call-of-duty-warzone": GameProfile(
        "call-of-duty-warzone",
        GameLoadType.MIXED,
        supports_dlss=True,
        supports_fsr=True,
        supports_frame_generation=True,
    ),
    "cyberpunk-2077": GameProfile(
        "cyberpunk-2077",
        GameLoadType.GPU,
        supports_dlss=True,
        supports_fsr=True,
        supports_frame_generation=True,
    ),
    "red-dead-redemption-2": GameProfile(
        "red-dead-redemption-2",
        GameLoadType.GPU,
        supports_dlss=True,
        supports_fsr=True,
    ),
    "gta-v": GameProfile("gta-v", GameLoadType.MIXED),
    "black-myth-wukong": GameProfile(
        "black-myth-wukong",
        GameLoadType.GPU,
        supports_dlss=True,
        supports_fsr=True,
        supports_frame_generation=True,
    ),
    "forza-horizon-6": GameProfile("forza-horizon-6", GameLoadType.GPU),
    "elden-ring": GameProfile("elden-ring", GameLoadType.GPU, fps_cap=60),
    "cities-skylines": GameProfile("cities-skylines", GameLoadType.CPU),
    "minecraft-java-edition": GameProfile(
        "minecraft-java-edition",
        GameLoadType.CPU,
    ),
}


def render_mode_for(profile: GameProfile, gpu: GPUCapabilities) -> RenderMode:
    if profile.supports_dlss and gpu.supports_dlss:
        if (
            profile.supports_frame_generation
            and gpu.supports_standard_frame_generation
        ):
            return RenderMode.DLSS_QUALITY_FG
        return RenderMode.DLSS_QUALITY
    if profile.supports_fsr and gpu.supports_fsr:
        if (
            profile.supports_frame_generation
            and gpu.supports_standard_frame_generation
        ):
            return RenderMode.FSR_QUALITY_FG
        return RenderMode.FSR_QUALITY
    return RenderMode.NATIVE
