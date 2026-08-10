from app.perf.pubg_reference import pubg_cpu_average_fps


def test_uses_exact_1080p_chart_rows() -> None:
    assert pubg_cpu_average_fps("r7-9800x3d") == 597
    assert pubg_cpu_average_fps("r7-7800x3d") == 538
    assert pubg_cpu_average_fps("i9-14900k") == 470


def test_scales_ranked_cpus_within_each_vendor() -> None:
    assert pubg_cpu_average_fps("r5-9600x") == 508
    assert pubg_cpu_average_fps("i7-14700k") == 462


def test_does_not_invent_unranked_cpu_results() -> None:
    assert pubg_cpu_average_fps("i3-10105") is None
