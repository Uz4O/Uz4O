from app.perf.cs2_reference import cs2_cpu_average_fps


def test_uses_the_users_9700x_measurement_as_the_1080p_anchor() -> None:
    assert cs2_cpu_average_fps("r7-9700x", "1080p") == 432


def test_scales_ranked_cpus_from_the_9700x_anchor() -> None:
    assert cs2_cpu_average_fps("r7-9800x3d", "1080p") == 470
    assert cs2_cpu_average_fps("r7-7800x3d", "1080p") == 413
    assert cs2_cpu_average_fps("i9-14900ks", "1080p") == 309


def test_preserves_chart_only_cpus_and_same_core_kf_variants() -> None:
    assert cs2_cpu_average_fps("i9-13900ks", "1080p") == 309
    assert cs2_cpu_average_fps("i5-14600kf", "1080p") == 280
    assert cs2_cpu_average_fps("i5-13600kf", "1080p") == 259


def test_does_not_invent_a_result_for_cpu_without_ranking_data() -> None:
    assert cs2_cpu_average_fps("i3-10105", "1080p") is None


def test_does_not_apply_the_1080p_measurement_to_other_resolutions() -> None:
    assert cs2_cpu_average_fps("r7-9700x", "2k") is None
    assert cs2_cpu_average_fps("r7-9700x", "4k") is None
