from app.perf.valorant_reference import (
    valorant_cpu_average_fps,
    valorant_cpu_performance_percent,
    valorant_cpu_performance_ranking,
)


def test_returns_exact_average_fps_for_supported_cpu_and_resolution() -> None:
    assert valorant_cpu_average_fps("r7-9800x3d", "1080p") == 712
    assert valorant_cpu_average_fps("r7-9800x3d", "2k") == 708
    assert valorant_cpu_average_fps("i5-12400f", "2k") == 286


def test_does_not_invent_unmeasured_cpu_or_4k_results() -> None:
    assert valorant_cpu_average_fps("r7-5700x", "1080p") is None
    assert valorant_cpu_average_fps("r7-9800x3d", "4k") is None


def test_combines_both_resolutions_into_a_normalized_cpu_ranking() -> None:
    ranking = valorant_cpu_performance_ranking()

    assert ranking[0] == ("r7-9850x3d", 103.0)
    assert ranking[-1] == ("i5-12400f", 40.6)
    assert valorant_cpu_performance_percent("r7-7800x3d") == 88.0


def test_9850x3d_is_derived_above_the_9800x3d_reference() -> None:
    assert valorant_cpu_average_fps("r7-9850x3d", "1080p") == 733
    assert valorant_cpu_average_fps("r7-9850x3d", "2k") == 729
    assert valorant_cpu_performance_percent("r7-9850x3d") == 103.0


def test_same_core_k_and_kf_variants_share_the_chart_reference() -> None:
    assert valorant_cpu_average_fps("i5-14600kf", "2k") == 431
    assert valorant_cpu_performance_percent("i9-14900kf") == 66.5
