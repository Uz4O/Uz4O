from pathlib import Path

from app.catalog.seed import extract_catalog_components
from app.perf.generated_estimator import (
    generated_average_fps,
    hardware_performance_score,
)


CATALOG_PATH = (
    Path(__file__).resolve().parents[2]
    / "May/May/Models/HardwareCatalog.swift"
)


def test_reference_hardware_reproduces_the_baseline_average_fps() -> None:
    assert generated_average_fps("cyberpunk-2077", "1080p", 100, 40) == 77
    assert generated_average_fps("cs2", "2k", 100, 40) == 210
    assert generated_average_fps("valorant", "4k", 100, 40) == 317
    assert generated_average_fps("elden-ring", "1080p", 130, 110) == 60


def test_cpu_and_gpu_limits_follow_the_game_load_type() -> None:
    assert generated_average_fps("valorant", "1080p", 100, 40) > (
        generated_average_fps("valorant", "1080p", 50, 40)
    )
    assert generated_average_fps("cyberpunk-2077", "4k", 100, 95) > (
        generated_average_fps("cyberpunk-2077", "4k", 100, 40)
    )


def test_every_catalog_cpu_and_gpu_has_a_generated_score() -> None:
    hardware = [
        component
        for component in extract_catalog_components(CATALOG_PATH)
        if component.category in {"cpu", "gpu"}
    ]

    scores = [
        hardware_performance_score(
            component.id,
            component.category,
            component.name,
            component.specs,
        )
        for component in hardware
    ]

    assert len(hardware) == 178
    assert all(score is not None and score > 0 for score in scores)
