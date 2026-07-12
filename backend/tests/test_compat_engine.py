from app.catalog.models import HardwareComponent
from app.compat.engine import BuildSelection, evaluate_compatibility


def component(
    component_id: str,
    category: str,
    name: str,
    specs: dict,
) -> HardwareComponent:
    return HardwareComponent(
        id=component_id,
        category=category,
        name=name,
        brand="测试",
        detail_raw=name,
        specs=specs,
    )


def test_reports_missing_required_core_parts() -> None:
    result = evaluate_compatibility(BuildSelection(components={}), {})

    assert result.compatible is False
    assert {finding.code for finding in result.findings if finding.level == "error"} == {
        "missing_cpu",
        "missing_motherboard",
        "missing_ram",
        "missing_psu",
    }
    assert result.summary == "这套配置有硬性兼容问题，需要先调整。"


def test_reports_unknown_component_ids() -> None:
    result = evaluate_compatibility(
        BuildSelection(components={"cpu": "not-real"}),
        {},
    )

    assert result.compatible is False
    assert result.findings[0].code == "unknown_component"
    assert result.findings[0].detail == "没有在硬件库里找到 not-real，不能用它做兼容性判断。"


def test_checks_cpu_and_motherboard_socket_match() -> None:
    result = evaluate_compatibility(
        BuildSelection(
            components={
                "cpu": "i5-14600k",
                "motherboard": "b650m",
                "ram": "ram-ddr5",
                "psu": "psu-750w",
            }
        ),
        {
            "i5-14600k": component("i5-14600k", "cpu", "i5-14600K", {"socket": "LGA1700"}),
            "b650m": component("b650m", "motherboard", "B650M MORTAR", {"socket": "AM5"}),
            "ram-ddr5": component("ram-ddr5", "ram", "DDR5 32GB", {"type": "DDR5"}),
            "psu-750w": component("psu-750w", "psu", "750W Gold", {"watt": 750}),
        },
    )

    socket_finding = next(finding for finding in result.findings if finding.code == "cpu_motherboard_socket")
    assert result.compatible is False
    assert socket_finding.level == "error"
    assert socket_finding.detail == "i5-14600K 是 LGA1700，B650M MORTAR 是 AM5，插槽不匹配。"


def test_passes_when_cpu_and_motherboard_socket_match() -> None:
    result = evaluate_compatibility(
        BuildSelection(
            components={
                "cpu": "i5-14600k",
                "motherboard": "b760m",
                "ram": "ram-ddr5",
                "psu": "psu-750w",
            }
        ),
        {
            "i5-14600k": component("i5-14600k", "cpu", "i5-14600K", {"socket": "LGA1700"}),
            "b760m": component("b760m", "motherboard", "B760M AORUS ELITE", {"socket": "LGA1700"}),
            "ram-ddr5": component("ram-ddr5", "ram", "DDR5 32GB", {"type": "DDR5"}),
            "psu-750w": component("psu-750w", "psu", "750W Gold", {"watt": 750}),
        },
    )

    socket_finding = next(finding for finding in result.findings if finding.code == "cpu_motherboard_socket")
    assert result.compatible is True
    assert socket_finding.level == "pass"
    assert socket_finding.detail == "i5-14600K 可以安装在 B760M AORUS ELITE 上。"


def test_checks_ram_type_when_motherboard_mem_type_is_known() -> None:
    result = evaluate_compatibility(
        BuildSelection(
            components={
                "cpu": "i5-14600k",
                "motherboard": "b760m-d4",
                "ram": "ram-ddr5",
                "psu": "psu-750w",
            }
        ),
        {
            "i5-14600k": component("i5-14600k", "cpu", "i5-14600K", {"socket": "LGA1700"}),
            "b760m-d4": component(
                "b760m-d4",
                "motherboard",
                "B760M DDR4",
                {"socket": "LGA1700", "mem_type": "DDR4"},
            ),
            "ram-ddr5": component("ram-ddr5", "ram", "DDR5 32GB", {"type": "DDR5"}),
            "psu-750w": component("psu-750w", "psu", "750W Gold", {"watt": 750}),
        },
    )

    memory_finding = next(finding for finding in result.findings if finding.code == "motherboard_ram_type")
    assert result.compatible is False
    assert memory_finding.level == "error"
    assert memory_finding.detail == "B760M DDR4 需要 DDR4 内存，但你选的是 DDR5。"


def test_warns_when_psu_headroom_is_low() -> None:
    result = evaluate_compatibility(
        BuildSelection(
            components={
                "cpu": "cpu-125w",
                "gpu": "gpu-300w",
                "motherboard": "b760m",
                "ram": "ram-ddr5",
                "psu": "psu-500w",
            }
        ),
        {
            "cpu-125w": component("cpu-125w", "cpu", "125W CPU", {"socket": "LGA1700", "tdp": 125}),
            "gpu-300w": component("gpu-300w", "gpu", "300W GPU", {"tdp": 300}),
            "b760m": component("b760m", "motherboard", "B760M", {"socket": "LGA1700"}),
            "ram-ddr5": component("ram-ddr5", "ram", "DDR5 32GB", {"type": "DDR5"}),
            "psu-500w": component("psu-500w", "psu", "500W Bronze", {"watt": 500}),
        },
    )

    psu_finding = next(finding for finding in result.findings if finding.code == "psu_headroom")
    assert result.compatible is True
    assert psu_finding.level == "warning"
    assert psu_finding.detail == "预计功耗约 425W，500W 电源余量偏紧，建议换更高瓦数。"
    assert result.finding_counts["warning"] == 1


def test_psu_headroom_ignores_unselected_catalog_components() -> None:
    selected = {
        "cpu": "selected-cpu",
        "gpu": "selected-gpu",
        "motherboard": "b650m",
        "ram": "ram-ddr5",
        "psu": "psu-650w",
    }
    components = {
        "selected-cpu": component(
            "selected-cpu", "cpu", "Selected CPU", {"socket": "AM5", "tdp": 100}
        ),
        "selected-gpu": component("selected-gpu", "gpu", "Selected GPU", {"tdp": 200}),
        "b650m": component("b650m", "motherboard", "B650M", {"socket": "AM5"}),
        "ram-ddr5": component("ram-ddr5", "ram", "DDR5 16GB", {"type": "DDR5"}),
        "psu-650w": component("psu-650w", "psu", "650W Gold", {"watt": 650}),
        "unselected-cpu": component("unselected-cpu", "cpu", "Other CPU", {"tdp": 500}),
        "unselected-gpu": component("unselected-gpu", "gpu", "Other GPU", {"tdp": 500}),
    }

    result = evaluate_compatibility(BuildSelection(components=selected), components)

    psu_finding = next(finding for finding in result.findings if finding.code == "psu_headroom")
    assert result.compatible is True
    assert psu_finding.level == "pass"
    assert "预计功耗约 300W" in psu_finding.detail


def test_warns_for_high_cpu_low_gpu_imbalance() -> None:
    result = evaluate_compatibility(
        BuildSelection(
            components={
                "cpu": "i7",
                "gpu": "entry-gpu",
                "motherboard": "b760m",
                "ram": "ram-ddr5",
                "psu": "psu-750w",
            }
        ),
        {
            "i7": component("i7", "cpu", "i7 CPU", {"socket": "LGA1700", "perf_index": 92}),
            "entry-gpu": component("entry-gpu", "gpu", "Entry GPU", {"tdp": 120, "perf_index": 45}),
            "b760m": component("b760m", "motherboard", "B760M", {"socket": "LGA1700"}),
            "ram-ddr5": component("ram-ddr5", "ram", "DDR5 32GB", {"type": "DDR5"}),
            "psu-750w": component("psu-750w", "psu", "750W Gold", {"watt": 750}),
        },
    )

    balance_finding = next(finding for finding in result.findings if finding.code == "cpu_gpu_balance")
    assert result.compatible is True
    assert balance_finding.level == "warning"
    assert "CPU 明显强于显卡" in balance_finding.detail


def test_warns_for_high_cpu_with_entry_motherboard_chipset() -> None:
    result = evaluate_compatibility(
        BuildSelection(
            components={
                "cpu": "i9",
                "motherboard": "h610",
                "ram": "ram-ddr4",
                "psu": "psu-750w",
            }
        ),
        {
            "i9": component("i9", "cpu", "i9 CPU", {"socket": "LGA1700", "perf_index": 99}),
            "h610": component("h610", "motherboard", "H610M", {"socket": "LGA1700", "chipset": "H610"}),
            "ram-ddr4": component("ram-ddr4", "ram", "DDR4 32GB", {"type": "DDR4"}),
            "psu-750w": component("psu-750w", "psu", "750W Gold", {"watt": 750}),
        },
    )

    board_finding = next(finding for finding in result.findings if finding.code == "cpu_motherboard_tier")
    assert result.compatible is True
    assert board_finding.level == "warning"
    assert "入门主板" in board_finding.detail
