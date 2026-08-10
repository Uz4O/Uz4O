from app.perf.delta_force_reference import delta_force_average_fps


def test_2k_uses_the_lower_measured_cpu_or_gpu_limit() -> None:
    assert delta_force_average_fps("r7-9850x3d", "rtx-5080", "2k") == 351
    assert delta_force_average_fps("r5-5500", "rtx-5090-d", "2k") == 135


def test_1080p_uses_only_combinations_covered_by_both_charts() -> None:
    assert delta_force_average_fps("r5-5600", "arc-a580-8gb", "1080p") == 128
    assert delta_force_average_fps("r5-5600", "rtx-5080", "1080p") is None


def test_4k_keeps_the_chart_fixed_cpu_instead_of_inventing_cpu_scaling() -> None:
    assert delta_force_average_fps("r7-9850x3d", "rtx-5070", "4k") == 154
    assert delta_force_average_fps("r5-5600", "rtx-5070", "4k") == 154


def test_gpu_reference_remains_available_when_cpu_is_not_on_the_ladder() -> None:
    assert delta_force_average_fps("i9-14900k", "rtx-5080", "2k") == 351
