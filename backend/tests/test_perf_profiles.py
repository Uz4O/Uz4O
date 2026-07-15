from app.perf.profiles import (
    APPROVED_GAME_PROFILES,
    GameLoadType,
    GPUCapabilities,
    RenderMode,
    render_mode_for,
)


def test_profiles_cover_the_approved_15_games() -> None:
    assert list(APPROVED_GAME_PROFILES) == [
        "valorant",
        "cs2",
        "pubg",
        "delta-force",
        "teamfight-tactics",
        "league-of-legends",
        "call-of-duty-warzone",
        "cyberpunk-2077",
        "red-dead-redemption-2",
        "gta-v",
        "black-myth-wukong",
        "forza-horizon-6",
        "elden-ring",
        "cities-skylines",
        "minecraft-java-edition",
    ]
    assert APPROVED_GAME_PROFILES["valorant"].load_type is GameLoadType.CPU
    assert APPROVED_GAME_PROFILES["cyberpunk-2077"].load_type is GameLoadType.GPU
    assert APPROVED_GAME_PROFILES["pubg"].load_type is GameLoadType.MIXED
    assert APPROVED_GAME_PROFILES["elden-ring"].fps_cap == 60


def test_render_mode_uses_supported_quality_upscaling_and_standard_fg() -> None:
    cyberpunk = APPROVED_GAME_PROFILES["cyberpunk-2077"]
    dlss_fg = GPUCapabilities(True, True, True)
    dlss_only = GPUCapabilities(True, True, False)
    fsr_fg = GPUCapabilities(False, True, True)
    fsr_only = GPUCapabilities(False, True, False)

    assert render_mode_for(cyberpunk, dlss_fg) is RenderMode.DLSS_QUALITY_FG
    assert render_mode_for(cyberpunk, dlss_only) is RenderMode.DLSS_QUALITY
    assert render_mode_for(cyberpunk, fsr_fg) is RenderMode.FSR_QUALITY_FG
    assert render_mode_for(cyberpunk, fsr_only) is RenderMode.FSR_QUALITY
    assert (
        render_mode_for(APPROVED_GAME_PROFILES["valorant"], dlss_fg)
        is RenderMode.NATIVE
    )
    assert (
        render_mode_for(APPROVED_GAME_PROFILES["cs2"], dlss_fg)
        is RenderMode.NATIVE
    )
