from datetime import datetime, timezone

import pytest

from app.builds.customization import (
    CustomizationError,
    _validate_cooler,
    _validate_gpu_vendor,
    customization_candidates,
    customize_template,
    customized_budget_limit,
    deterministic_customization,
)
from app.builds.models import BuildTemplate
from app.builds.selection_cache import request_identity
from app.builds.service import BuildRequest
from app.builds.service import BuildTemplatePart
from app.catalog.models import ComponentPrice, HardwareComponent


def test_customized_budget_limit_uses_default_and_flexible_low_budget_ceiling() -> None:
    default_request = BuildRequest(budget=6000, use_case="游戏")
    flexible_request = BuildRequest(
        budget=6000,
        use_case="游戏",
        allows_flexible_budget=True,
    )

    assert customized_budget_limit(default_request) == 6300
    assert customized_budget_limit(flexible_request) == 6500
    assert customized_budget_limit(BuildRequest(budget=10_000, use_case="游戏")) == 10_800
    assert request_identity(default_request)[0] != request_identity(flexible_request)[0]


def test_explicit_default_capacity_still_requires_exact_customization() -> None:
    request = BuildRequest(
        budget=20_000,
        use_case="游戏",
        memory_size="16GB",
        storage_size="512GB",
    )

    assert request.requires_customization is True


def test_customization_rejects_entry_board_for_high_end_x3d_cpu() -> None:
    components, prices = catalog()
    template = base_template(direction="fps")
    cpu = template.details["parts"][0]
    cpu.update(
        {
            "component_id": "r7-9800x3d",
            "name": "R7 9800X3D",
            "reference_price": 2_500,
            "specs": {"socket": "AM5", "perf_index": 100, "tdp": 120},
        }
    )
    gpu = template.details["parts"][2]
    gpu.update(
        {
            "component_id": "rtx-5080",
            "name": "RTX 5080",
            "reference_price": 10_500,
            "specs": {"vendor": "NVIDIA", "perf_index": 95, "tdp": 360},
        }
    )

    with pytest.raises(CustomizationError, match="B650M-K"):
        customize_template(
            BuildRequest(budget=10_000, use_case="游戏", direction="fps"),
            template,
            {},
            components,
            prices,
            source="template",
            validate_budget=False,
        )


def test_customization_only_enforces_ray_tracing_vendor_from_10000() -> None:
    amd_gpu = BuildTemplatePart.model_validate(
        part(
            "gpu",
            "rx-7800-xt",
            "RX 7800 XT",
            4000,
            {"vendor": "AMD", "perf_index": 82, "tdp": 263},
        )
    )

    _validate_gpu_vendor(
        BuildRequest(budget=9999, use_case="游戏", ray_tracing=True),
        amd_gpu,
    )
    with pytest.raises(CustomizationError, match="开启光追时只能使用 NVIDIA 显卡"):
        _validate_gpu_vendor(
            BuildRequest(budget=10_000, use_case="游戏", ray_tracing=True),
            amd_gpu,
        )


def test_hot_cpu_requires_dual_tower_six_heatpipe_cooler() -> None:
    cpu = BuildTemplatePart.model_validate(
        part(
            "cpu",
            "r7-9800x3d",
            "R7 9800X3D",
            2500,
            {"socket": "AM5", "perf_index": 100, "tdp": 120},
        )
    )
    cooler = BuildTemplatePart.model_validate(
        part(
            "cooler",
            "base-cooler-6-heatpipe",
            "六热管单塔散热器",
            100,
            {"heatpipes": 6, "towers": 1},
        )
    )

    with pytest.raises(CustomizationError, match="双塔六热管"):
        _validate_cooler({"cpu": cpu, "cooler": cooler})


def test_customization_rejects_option_more_than_200_below_budget() -> None:
    components, prices = catalog()

    with pytest.raises(CustomizationError, match="低于预算下限"):
        customize_template(
            BuildRequest(
                budget=7000,
                use_case="游戏",
                direction="balanced",
            ),
            base_template(),
            {},
            components,
            prices,
            source="template",
        )


def test_customization_allows_total_exactly_200_below_budget() -> None:
    components, prices = catalog()

    option = customize_template(
        BuildRequest(
            budget=6800,
            use_case="游戏",
            direction="balanced",
        ),
        base_template(),
        {},
        components,
        prices,
        source="template",
    )

    assert option.estimated_total == 6600


def test_customization_rejects_non_c28_memory_on_am5() -> None:
    components, prices = catalog()
    template = base_template()
    ram = next(part for part in template.details["parts"] if part["role"] == "ram")
    ram["specs"]["cas_latency"] = 32

    with pytest.raises(CustomizationError, match="AM5 平台必须使用 DDR5 6000 C28"):
        customize_template(
            BuildRequest(budget=6650, use_case="游戏", direction="balanced"),
            template,
            {},
            components,
            prices,
            source="template",
        )


def test_customization_rejects_5600x_at_7000_unless_explicitly_requested() -> None:
    components, prices = catalog()
    template = am4_template()

    with pytest.raises(CustomizationError, match="6000元及以上"):
        customize_template(
            BuildRequest(budget=7000, use_case="游戏", direction="fps"),
            template,
            {},
            components,
            prices,
            source="template",
            validate_budget=False,
        )

    option = customize_template(
        BuildRequest(
            budget=7000,
            use_case="游戏",
            direction="fps",
            specified_cpu="R5 5600X",
        ),
        template,
        {},
        components,
        prices,
        source="template",
        validate_budget=False,
    )

    assert option.components["cpu"] == "r5-5600x"


def test_customization_rejects_single_channel_ddr4_memory() -> None:
    components, prices = catalog()
    template = am4_template()
    ram = next(part for part in template.details["parts"] if part["role"] == "ram")
    ram["specs"]["modules"] = 1

    with pytest.raises(CustomizationError, match="DDR4 内存必须使用双通道"):
        customize_template(
            BuildRequest(
                budget=5000,
                use_case="游戏",
                direction="fps",
                specified_cpu="R5 5600X",
            ),
            template,
            {},
            components,
            prices,
            source="template",
            validate_budget=False,
        )


def test_customization_rejects_base_that_ignores_specified_cpu() -> None:
    components, prices = catalog()

    with pytest.raises(CustomizationError, match="指定的 CPU 型号"):
        customize_template(
            BuildRequest(
                budget=6500,
                use_case="游戏",
                direction="balanced",
                specified_cpu="R7 9800X3D",
            ),
            base_template(),
            {},
            components,
            prices,
            source="template",
            validate_budget=False,
        )


def test_customization_candidates_include_adjacent_higher_reviewed_tier() -> None:
    components, prices = catalog()
    templates = []
    for target_budget in range(3000, 8500, 500):
        template = base_template()
        template.id = f"base-{target_budget}-balanced-new"
        template.budget_min = target_budget
        template.budget_max = target_budget + 499
        template.details["target_budget"] = target_budget
        templates.append(template)

    candidates = customization_candidates(
        BuildRequest(budget=7000, use_case="游戏", direction="balanced"),
        templates,
        components,
        prices,
        purchase_mode="new",
        gpu_vendor="nvidia",
    )

    assert len(candidates) == 10
    assert {template.details["target_budget"] for template in candidates} == set(
        range(3000, 8000, 500)
    )


def test_deterministic_customization_fills_budget_without_changing_locked_capacity() -> None:
    components, prices = catalog()

    option = deterministic_customization(
        BuildRequest(
            budget=7500,
            use_case="游戏",
            direction="balanced",
            memory_size="16GB",
            storage_size="1TB",
        ),
        [base_template()],
        components,
        prices,
    )

    assert option is not None
    parts = {part.role: part for part in option.details.parts}
    assert parts["ram"].specs["capacity_gb"] == 16
    assert parts["storage"].specs["capacity_gb"] == 1024
    assert parts["gpu"].component_id == "rtx-5060-ti"
    assert 7300 <= option.estimated_total <= 7800


def test_customization_uses_lower_budget_base_to_meet_hard_capacity_requirements() -> None:
    components, prices = catalog()
    prices["base-ddr5-32gb-6000-c28"].price_range_high = 750
    current_tier = base_template(direction="fps")
    current_tier.id = "base-6000-balanced-new"
    current_tier.details["target_budget"] = 6000
    current_tier.details["parts"][1]["reference_price"] += 300
    current_tier.details["parts"][0]["specs"]["perf_index"] += 20
    lower_tier = base_template(direction="fps")
    lower_tier.id = "base-5500-balanced-new"
    lower_tier.details["target_budget"] = 5500
    lower_tier.details["parts"][0]["reference_price"] -= 368
    lower_tier.details["parts"][0]["specs"]["perf_index"] -= 10

    current_tier_only = deterministic_customization(
        BuildRequest(
            budget=6000,
            use_case="游戏",
            direction="fps",
            memory_size="32GB",
            storage_size="1TB",
        ),
        [current_tier],
        components,
        prices,
    )

    option = deterministic_customization(
        BuildRequest(
            budget=6000,
            use_case="游戏",
            direction="fps",
            memory_size="32GB",
            storage_size="1TB",
        ),
        [current_tier, lower_tier],
        components,
        prices,
    )

    assert current_tier_only is None
    assert option is not None
    assert option.estimated_total == 6168
    assert {part.role: part.name for part in option.details.parts}["ram"] == "DDR5 32GB 6000 C28"


def test_customization_does_not_lower_core_performance_to_buy_a_pricier_board() -> None:
    components, prices = catalog()
    components["rtx-5060-ti"].is_recommended = False
    stronger = base_template(direction="fps")
    stronger.id = "stronger-below-floor"
    stronger.details["parts"][0]["specs"]["perf_index"] = 90
    stronger.details["parts"][1]["reference_price"] += 100
    weaker = base_template(direction="fps")
    weaker.id = "weaker-in-window"
    weaker.details["parts"][1]["reference_price"] += 400

    option = deterministic_customization(
        BuildRequest(budget=7_000, use_case="游戏", direction="fps"),
        [stronger, weaker],
        components,
        prices,
    )

    assert option is None


def test_mixed_search_can_buy_new_cooler_and_case_to_reach_budget_floor() -> None:
    components, prices = catalog()
    mixed = base_template(direction="balanced")
    mixed.id = "base-6000-balanced-mixed"
    mixed.details["purchase_mode"] = "mixed"
    for item in mixed.details["parts"]:
        if item["role"] in {"cpu", "gpu", "ram", "cooler", "case"}:
            item["condition"] = "used"
            item["reference_price"] = prices[item["component_id"]].price_range_low
    mixed.estimated_total = sum(
        item["reference_price"] for item in mixed.details["parts"]
    )

    option = deterministic_customization(
        BuildRequest(
            budget=6400,
            use_case="游戏",
            direction="balanced",
        ),
        [mixed],
        components,
        prices,
    )

    assert option is not None
    assert option.estimated_total == 6300
    parts = {part.role: part for part in option.details.parts}
    assert parts["cooler"].condition == "new"
    assert parts["case"].condition == "new"


def test_customization_applies_storage_and_wifi_without_exceeding_low_budget_limit() -> None:
    components, prices = catalog()
    components["base-ssd-fanxiang-s790e-1tb"].is_recommended = False
    option = customize_template(
        BuildRequest(
            budget=6700,
            use_case="游戏",
            direction="balanced",
            storage_size="1TB",
            needs_wireless_network=True,
            allows_flexible_budget=True,
        ),
        base_template(),
        {},
        components,
        prices,
        source="template",
        validate_budget=False,
    )

    parts = {part.role: part for part in option.details.parts}
    assert option.estimated_total == 7118
    assert parts["storage"].component_id == "base-ssd-fanxiang-s790e-1tb"
    assert parts["motherboard"].name.endswith(" WIFI")
    assert parts["motherboard"].reference_price == 750


def test_customization_adds_separate_adapter_for_a520m_k() -> None:
    components, prices = catalog(motherboard_id="asus-a520m-k")
    option = customize_template(
        BuildRequest(
            budget=4000,
            use_case="游戏",
            direction="balanced",
            needs_wireless_network=True,
        ),
        base_template(motherboard_id="asus-a520m-k"),
        {},
        components,
        prices,
        source="template",
        validate_budget=False,
    )

    motherboard = next(part for part in option.details.parts if part.role == "motherboard")
    assert motherboard.reference_price == 700
    assert option.details.extras[0].id == "wifi-bluetooth-adapter"
    assert option.details.extras[0].reference_price == 50


def test_customization_rejects_a520_at_4500_and_above() -> None:
    components, prices = catalog(motherboard_id="asus-a520m-k")

    with pytest.raises(CustomizationError, match="4500元及以上"):
        customize_template(
            BuildRequest(
                budget=4500,
                use_case="游戏",
                direction="balanced",
            ),
            base_template(motherboard_id="asus-a520m-k"),
            {},
            components,
            prices,
            source="template",
            validate_budget=False,
        )


def test_customization_does_not_charge_again_for_integrated_wifi() -> None:
    motherboard_id = "msi-pro-b860m-a"
    components, prices = catalog(motherboard_id=motherboard_id)
    template = base_template(motherboard_id=motherboard_id)
    template.details["parts"][1]["name"] = "微星 PRO B860M-A WIFI"

    option = customize_template(
        BuildRequest(
            budget=6500,
            use_case="游戏",
            direction="balanced",
            needs_wireless_network=True,
        ),
        template,
        {},
        components,
        prices,
        source="template",
    )

    motherboard = next(part for part in option.details.parts if part.role == "motherboard")
    assert motherboard.name == "微星 PRO B860M-A WIFI"
    assert motherboard.reference_price == 700
    assert option.estimated_total == 6600


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


def test_customization_rejects_high_cpu_low_gpu_pairing() -> None:
    components, prices = catalog()

    with pytest.raises(CustomizationError, match="高U低显或低U高显"):
        customize_template(
            BuildRequest(
                budget=10_000,
                use_case="游戏",
                direction="balanced",
            ),
            base_template(),
            {"cpu": "r7-9800x3d", "gpu": "rtx-5060-ti"},
            components,
            prices,
            source="ai",
            validate_budget=False,
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
        validate_budget=False,
    )

    gpu = next(part for part in option.details.parts if part.role == "gpu")
    assert gpu.condition == "owned"
    assert gpu.reference_price == 0
    assert option.estimated_total == 4300


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
            allows_flexible_budget=True,
        ),
        [weaker, stronger],
        components,
        prices,
    )

    assert option is not None
    assert option.template_id == "base-7000-fps-new"
    assert option.estimated_total == 7350


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
            "base-ddr5-16gb-6000-c28",
            "DDR5 16GB 6000 C28",
            1650,
            {"type": "DDR5", "capacity_gb": 16, "speed_mhz": 6000, "cas_latency": 28},
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
        estimated_total=6600,
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


def am4_template() -> BuildTemplate:
    template = base_template(direction="fps")
    parts = {part["role"]: part for part in template.details["parts"]}
    parts["cpu"].update(
        {
            "component_id": "r5-5600x",
            "name": "R5 5600X",
            "reference_price": 600,
            "specs": {"socket": "AM4", "perf_index": 45, "tdp": 65},
        }
    )
    parts["motherboard"].update(
        {
            "component_id": "test-b550m",
            "name": "B550M",
            "reference_price": 500,
            "specs": {"socket": "AM4", "mem_type": "DDR4", "chipset": "B550"},
        }
    )
    parts["ram"].update(
        {
            "component_id": "base-ddr4-16gb-3200",
            "name": "DDR4 8GB×2 3200",
            "reference_price": 500,
            "specs": {
                "type": "DDR4",
                "capacity_gb": 16,
                "speed_mhz": 3200,
                "modules": 2,
            },
        }
    )
    template.components = {
        role: part["component_id"] for role, part in parts.items()
    }
    template.estimated_total = sum(part["reference_price"] for part in parts.values())
    return template


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
        component("r5-5600x", "cpu", "R5 5600X", {"socket": "AM4", "perf_index": 45, "tdp": 65}),
        component(
            "test-b550m",
            "motherboard",
            "B550M",
            {"socket": "AM4", "mem_type": "DDR4", "chipset": "B550"},
        ),
        component(
            "base-ddr4-16gb-3200",
            "ram",
            "DDR4 8GB×2 3200",
            {"type": "DDR4", "capacity_gb": 16, "speed_mhz": 3200, "modules": 2},
        ),
        component("r5-9600x", "cpu", "R5 9600X", {"socket": "AM5", "perf_index": 72, "tdp": 105}),
        component(
            motherboard_id,
            "motherboard",
            "ASUS B650M-K",
            {"socket": "AM5", "mem_type": "DDR5", "chipset": "B650"},
        ),
        component("rtx-5060", "gpu", "RTX 5060", {"vendor": "NVIDIA", "perf_index": 50, "tdp": 145}),
        component("r7-9800x3d", "cpu", "R7 9800X3D", {"socket": "AM5", "perf_index": 100, "tdp": 120}),
        component("rtx-5060-ti", "gpu", "RTX 5060 Ti", {"vendor": "NVIDIA", "perf_index": 60, "tdp": 180}),
        component(
            "base-ddr5-16gb-6000-c28",
            "ram",
            "DDR5 16GB 6000 C28",
            {"type": "DDR5", "capacity_gb": 16, "speed_mhz": 6000, "cas_latency": 28},
        ),
        component(
            "base-ddr5-32gb-6000-c28",
            "ram",
            "DDR5 32GB 6000 C28",
            {"type": "DDR5", "capacity_gb": 32, "speed_mhz": 6000, "cas_latency": 28},
        ),
        component("base-ssd-512gb-tlc", "storage", "512GB TLC SSD", {"capacity_gb": 512}),
        component("base-ssd-1tb-tlc", "storage", "1TB TLC SSD", {"capacity_gb": 1024}),
        component("base-ssd-2tb-tlc", "storage", "2TB TLC SSD", {"capacity_gb": 2048}),
        component(
            "base-ssd-fanxiang-s500-pro-512gb",
            "storage",
            "梵想 S500 Pro 512GB",
            {"capacity_gb": 512},
        ),
        component(
            "base-ssd-fanxiang-s790e-1tb",
            "storage",
            "梵想 S790E 1TB",
            {"capacity_gb": 1024},
        ),
        component("base-psu-650w-gold", "psu", "650W Gold", {"watt": 650}),
        component("base-cooler-6-heatpipe", "cooler", "6 Heatpipe Cooler", {}),
        component("base-case-mid-tower", "case", "Mid Tower Case", {}),
    ]
    new_prices = {
        "r5-5600x": 600,
        "test-b550m": 500,
        "base-ddr4-16gb-3200": 500,
        "r5-9600x": 1050,
        motherboard_id: 700,
        "rtx-5060": 2300,
        "r7-9800x3d": 2500,
        "rtx-5060-ti": 3000,
        "base-ddr5-16gb-6000-c28": 1650,
        "base-ddr5-32gb-6000-c28": 3300,
        "base-ssd-512gb-tlc": 500,
        "base-ssd-1tb-tlc": 800,
        "base-ssd-2tb-tlc": 1600,
        "base-ssd-fanxiang-s500-pro-512gb": 509,
        "base-ssd-fanxiang-s790e-1tb": 968,
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
