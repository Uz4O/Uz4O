from app.catalog.rule_specs import is_cpu_gpu_pairing_allowed


def test_user_reviewed_pairing_examples() -> None:
    assert is_cpu_gpu_pairing_allowed("r5-9600x", "rtx-5060-ti")
    assert is_cpu_gpu_pairing_allowed("r7-9700x", "rtx-5070")
    assert is_cpu_gpu_pairing_allowed("r7-7800x3d", "rtx-5070-ti")
    assert not is_cpu_gpu_pairing_allowed("r7-9800x3d", "rtx-5060-ti")
    assert not is_cpu_gpu_pairing_allowed("i5-12600kf", "rtx-5070-ti")


def test_user_provided_pairing_aliases() -> None:
    for cpu_id in ("r5-7500f", "i5-12600kf"):
        assert is_cpu_gpu_pairing_allowed(cpu_id, "rtx-5060")
        assert not is_cpu_gpu_pairing_allowed(cpu_id, "rtx-5070")

    for gpu_id in ("rx-7800-xt", "rtx-4070-super", "rtx-5070"):
        assert is_cpu_gpu_pairing_allowed("r5-9600x", gpu_id)
        assert not is_cpu_gpu_pairing_allowed("r5-7500f", gpu_id)


def test_5600_series_stops_at_5060_ti_class() -> None:
    for cpu_id in ("r5-5600", "r5-5600x"):
        assert is_cpu_gpu_pairing_allowed(cpu_id, "rtx-5060-ti")
        assert not is_cpu_gpu_pairing_allowed(cpu_id, "rx-9070-gre")
        assert not is_cpu_gpu_pairing_allowed(cpu_id, "rtx-5070")


def test_extreme_gpu_pairing_floors() -> None:
    assert not is_cpu_gpu_pairing_allowed("r5-9600x", "rtx-5080")
    assert is_cpu_gpu_pairing_allowed("r7-9700x", "rtx-5080")
    assert not is_cpu_gpu_pairing_allowed("r7-7800x3d", "rtx-5090")
    assert is_cpu_gpu_pairing_allowed("r7-9800x3d", "rtx-5090")
