from datetime import datetime, timezone

import pytest

from app.builds.customization import (
    CustomizationError,
    customize_template,
    deterministic_customization,
)
from app.builds.models import BuildTemplate
from app.builds.service import BuildRequest
from app.catalog.models import ComponentPrice, HardwareComponent


def test_customization_applies_storage_and_wifi_without_exceeding_low_budget_limit() -> None:
    components, prices = catalog()
    components["base-ssd-1tb-tlc"].is_recommended = False
    option = customize_template(
        BuildRequest(
            budget=6500,
            use_case="游戏",
            direction="balanced",
            storage_size="1TB",
            needs_wireless_network=True,
        ),
        base_template(),
        {},
        components,
        prices,
        source="template",
    )

    parts = {part.role: part for part in option.details.parts}
    assert option.estimated_total == 7000
    assert parts["storage"].component_id == "base-ssd-1tb-tlc"
    assert parts["motherboard"].name.endswith(" WIFI")
    assert parts["motherboard"].reference_price == 750


def test_customization_adds_separate_adapter_for_a520m_k() -> None:
    components, prices = catalog(motherboard_id="asus-a520m-k")
    option = customize_template(
        BuildRequest(
            budget=6500,
            use_case="游戏",
            direction="balanced",
            needs_wireless_network=True,
        ),
        base_template(motherboard_id="asus-a520m-k"),
        {},
        components,
        prices,
        source="template",
    )

    motherboard = next(part for part in option.details.parts if part.role == "motherboard")
    assert motherboard.reference_price == 700
    assert option.details.extras[0].id == "wifi-bluetooth-adapter"
    assert option.details.extras[0].reference_price == 50


def test_customization_rejects_requirement_over_budget_ceiling() -> None:
    components, prices = catalog()
    with pytest.raises(CustomizationError, match="超过预算上限"):
        customize_template(
            BuildRequest(
                budget=6500,
                use_case="游戏",
                direction="balanced",
                memory_size="32GB",
                storage_size="2TB",
            ),
            base_template(),
            {},
            components,
            prices,
            source="template",
        )


def test_customization_marks_user_gpu_owned_and_excludes_its_price() -> None:
    components, prices = catalog()
    option = customize_template(
        BuildRequest(
            budget=6500,
            use_case="游戏",
            direction="fps",
            no_gpu_build=True,
            owned_gpu_model="RTX 5060",
        ),
        base_template(direction="fps"),
        {},
        components,
        prices,
        source="template",
    )

    gpu = next(part for part in option.details.parts if part.role == "gpu")
    assert gpu.condition == "owned"
    assert gpu.reference_price == 0
    assert option.estimated_total == 4350


def test_fallback_preserves_direction_performance_before_price_proximity() -> None:
    components, prices = catalog()
    weaker = base_template(direction="fps")
    stronger = base_template(direction="fps")
    stronger.id = "base-7000-fps-new"
    stronger.details["parts"][0]["specs"]["perf_index"] = 90
    stronger.details["parts"][1]["reference_price"] = 1400
    stronger.estimated_total = 7350

    option = deterministic_customization(
        BuildRequest(
            budget=7000,
            use_case="游戏",
            direction="fps",
            needs_wireless_network=True,
        ),
        [weaker, stronger],
        components,
        prices,
    )

    assert option is not None
    assert option.template_id == "base-7000-fps-new"
    assert option.estimated_total == 7400


def base_template(
    *,
    direction: str = "balanced",
    motherboard_id: str = "asus-prime-b650m-k",
) -> BuildTemplate:
    parts = [
        part("cpu", "r5-9600x", "R5 9600X", 1050, {"socket": "AM5", "perf_index": 72, "tdp": 105}),
        part(
            "motherboard",
            motherboard_id,
            "ASUS B650M-K",
            700,
            {"socket": "AM5", "mem_type": "DDR5", "chipset": "B650"},
        ),
        part("gpu", "rtx-5060", "RTX 5060", 2300, {"vendor": "NVIDIA", "perf_index": 50, "tdp": 145}),
        part(
            "ram",
            "base-ddr5-16gb-6000-c32",
            "DDR5 16GB 6000 C32",
            1700,
            {"type": "DDR5", "capacity_gb": 16, "speed_mhz": 6000, "cas_latency": 32},
        ),
        part("storage", "base-ssd-512gb-tlc", "512GB TLC SSD", 500, {"capacity_gb": 512}),
        part("psu", "base-psu-650w-gold", "650W Gold", 200, {"watt": 650}),
        part("cooler", "base-cooler-6-heatpipe", "6 Heatpipe Cooler", 100, {}),
        part("case", "base-case-mid-tower", "Mid Tower Case", 100, {}),
    ]
    return BuildTemplate(
        id=f"base-6500-{direction}-new",
        title="6500 元全新基底",
        budget_min=6500,
        budget_max=6999,
        use_cases=["游戏"],
        tags=["全新"],
        components={item["role"]: item["component_id"] for item in parts},
        estimated_total=6650,
        explanation="人工审核基底",
        details={
            "target_budget": 6500,
            "direction": direction,
            "purchase_mode": "new",
            "gpu_vendor": "nvidia",
            "parts": parts,
            "suitable_user": "游戏",
            "price_date": "2026-07-20",
        },
        status="active",
    )


def part(role: str, component_id: str, name: str, price: int, specs: dict) -> dict:
    return {
        "role": role,
        "component_id": component_id,
        "name": name,
        "condition": "new",
        "reference_price": price,
        "price_source": "manual",
        "price_date": "2026-07-20",
        "specs": specs,
    }


def catalog(
    *,
    motherboard_id: str = "asus-prime-b650m-k",
) -> tuple[dict[str, HardwareComponent], dict[str, ComponentPrice]]:
    rows = [
        component("r5-9600x", "cpu", "R5 9600X", {"socket": "AM5", "perf_index": 72, "tdp": 105}),
        component(
            motherboard_id,
            "motherboard",
            "ASUS B650M-K",
            {"socket": "AM5", "mem_type": "DDR5", "chipset": "B650"},
        ),
        component("rtx-5060", "gpu", "RTX 5060", {"vendor": "NVIDIA", "perf_index": 50, "tdp": 145}),
        component(
            "base-ddr5-16gb-6000-c32",
            "ram",
            "DDR5 16GB 6000 C32",
            {"type": "DDR5", "capacity_gb": 16, "speed_mhz": 6000, "cas_latency": 32},
        ),
        component(
            "base-ddr5-32gb-6000-c32",
            "ram",
            "DDR5 32GB 6000 C32",
            {"type": "DDR5", "capacity_gb": 32, "speed_mhz": 6000, "cas_latency": 32},
        ),
        component("base-ssd-512gb-tlc", "storage", "512GB TLC SSD", {"capacity_gb": 512}),
        component("base-ssd-1tb-tlc", "storage", "1TB TLC SSD", {"capacity_gb": 1024}),
        component("base-ssd-2tb-tlc", "storage", "2TB TLC SSD", {"capacity_gb": 2048}),
        component("base-psu-650w-gold", "psu", "650W Gold", {"watt": 650}),
        component("base-cooler-6-heatpipe", "cooler", "6 Heatpipe Cooler", {}),
        component("base-case-mid-tower", "case", "Mid Tower Case", {}),
    ]
    new_prices = {
        "r5-9600x": 1050,
        motherboard_id: 700,
        "rtx-5060": 2300,
        "base-ddr5-16gb-6000-c32": 1700,
        "base-ddr5-32gb-6000-c32": 3400,
        "base-ssd-512gb-tlc": 500,
        "base-ssd-1tb-tlc": 800,
        "base-ssd-2tb-tlc": 1600,
        "base-psu-650w-gold": 200,
        "base-cooler-6-heatpipe": 100,
        "base-case-mid-tower": 100,
    }
    return (
        {row.id: row for row in rows},
        {component_id: price(component_id, value) for component_id, value in new_prices.items()},
    )


def component(component_id: str, category: str, name: str, specs: dict) -> HardwareComponent:
    return HardwareComponent(
        id=component_id,
        category=category,
        name=name,
        brand="test",
        detail_raw=name,
        specs=specs,
        is_recommended=True,
        status="active",
    )


def price(component_id: str, new_price: int) -> ComponentPrice:
    return ComponentPrice(
        component_id=component_id,
        reference_price=new_price,
        price_range_low=max(new_price - 100, 1),
        price_range_high=new_price,
        source="manual",
        accepted_count=1,
        rejected_count=0,
        review_reasons=[],
        approved_at=datetime.now(timezone.utc),
    )
