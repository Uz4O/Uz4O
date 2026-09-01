import csv
import json
from collections import Counter

import app.builds.high_budget_catalog as high_budget_catalog
from app.builds.models import BuildTemplate
from app.builds.high_budget_catalog import (
    BUDGET_TIERS,
    CPU_PERFORMANCE,
    GPU_PERFORMANCE,
    GPU_PRICE_PATH,
    PRICE_DATE,
    REQUIRED_PART_ROLES,
    generate_high_budget_templates,
    minimum_psu_watt,
    render_high_budget_markdown,
    write_high_budget_artifacts,
)
from app.builds.service import template_response
from app.catalog.rule_specs import (
    is_cpu_gpu_pairing_allowed,
    psu_supports_gpu_power_connector,
)
from app.compat.engine import CompatibilityResult


EXPECTED_VENDOR_COMBINATIONS = {
    (direction, purchase_mode, gpu_vendor)
    for direction in ("aaa", "balanced")
    for purchase_mode in ("new", "used", "mixed")
    for gpu_vendor in ("nvidia", "amd")
}

EXPECTED_CONDITIONS = {
    "new": {role: "new" for role in REQUIRED_PART_ROLES},
    "used": {role: "used" for role in REQUIRED_PART_ROLES},
    "mixed": {
        "cpu": "used",
        "motherboard": "new",
        "gpu": "used",
        "ram": "used",
        "storage": "new",
        "psu": "new",
        "cooler": "used",
        "case": "used",
    },
}


def generated_templates():
    return generate_high_budget_templates()


def expected_template_count() -> int:
    return sum(
        len(
            high_budget_catalog._gpu_vendors_for(
                budget, direction, purchase_mode
            )
        )
        for budget in BUDGET_TIERS
        for direction in ("fps", "aaa", "balanced")
        for purchase_mode in ("new", "used", "mixed")
    )


def test_high_budget_vendor_split_thresholds() -> None:
    assert high_budget_catalog._gpu_vendors_for(7_500, "aaa", "new") == (None,)
    assert high_budget_catalog._gpu_vendors_for(7_500, "aaa", "used") == (
        "nvidia",
        "amd",
    )
    assert high_budget_catalog._gpu_vendors_for(7_500, "aaa", "mixed") == (
        "nvidia",
        "amd",
    )
    assert high_budget_catalog._gpu_vendors_for(8_000, "aaa", "new") == (
        "nvidia",
        "amd",
    )
    assert high_budget_catalog._gpu_vendors_for(9_500, "fps", "new") == (None,)
    assert high_budget_catalog._gpu_vendors_for(10_000, "fps", "new") == (
        "nvidia",
        "amd",
    )


def test_generates_high_budget_templates_through_30000() -> None:
    templates = generated_templates()

    assert BUDGET_TIERS == [
        *range(7_500, 10_001, 500),
        *range(11_000, 30_001, 1_000),
    ]
    assert templates
    assert len({template.id for template in templates}) == len(templates)
    counts = Counter(template.details.target_budget for template in templates)
    assert counts[7_500] > 0
    assert counts[30_000] > 0

    for budget in BUDGET_TIERS:
        fps = [
            template
            for template in templates
            if template.details.target_budget == budget
            and template.details.direction == "fps"
        ]
        if budget < 10_000:
            assert len({template.details.purchase_mode for template in fps}) == len(fps)
        else:
            fps_vendor_combinations = {
                (template.details.purchase_mode, template.details.gpu_vendor)
                for template in fps
            }
            assert {
                (purchase_mode, "nvidia")
                for purchase_mode in ("new", "used", "mixed")
            }.issubset(fps_vendor_combinations)
        vendor_combinations = {
            (
                template.details.direction,
                template.details.purchase_mode,
                template.details.gpu_vendor,
            )
            for template in templates
            if template.details.target_budget == budget
            and template.details.direction != "fps"
        }
        assert vendor_combinations <= EXPECTED_VENDOR_COMBINATIONS


def test_every_template_has_eight_priced_parts_and_an_exact_total() -> None:
    for template in generated_templates():
        parts = {part.role: part for part in template.details.parts}

        assert set(template.components) == REQUIRED_PART_ROLES
        assert set(parts) == REQUIRED_PART_ROLES
        assert template.components == {
            role: part.component_id for role, part in parts.items()
        }
        assert all(part.reference_price > 0 for part in parts.values())
        assert all(part.price_source for part in parts.values())
        assert all(part.price_date for part in parts.values())
        assert template.estimated_total == sum(
            part.reference_price for part in parts.values()
        )
        assert template.details.target_budget - 200 <= template.estimated_total
        max_overage = 800 if template.details.target_budget >= 10_000 else 500
        assert template.estimated_total <= template.details.target_budget + max_overage


def test_purchase_conditions_follow_the_three_exact_modes() -> None:
    for template in generated_templates():
        actual = {
            part.role: part.condition for part in template.details.parts
        }
        assert actual == EXPECTED_CONDITIONS[template.details.purchase_mode]


def test_all_builds_use_whitelisted_amd_am5_parts_and_only_upgrade_storage_for_coverage() -> None:
    _, _, _, support_parts = high_budget_catalog._load_catalog()

    for template in generated_templates():
        parts = {part.role: part for part in template.details.parts}

        assert parts["cpu"].component_id in CPU_PERFORMANCE
        assert parts["cpu"].component_id.startswith(("r5-", "r7-", "r9-"))
        assert parts["motherboard"].specs["socket"] == "AM5"
        assert parts["ram"].specs["type"] == "DDR5"
        expected_ram_capacity = (
            32 if template.details.target_budget >= 18_000 else 16
        )
        assert parts["ram"].specs["capacity_gb"] == expected_ram_capacity
        assert parts["ram"].specs["speed_mhz"] == 6000
        assert parts["ram"].specs["cas_latency"] == 28
        assert parts["storage"].component_id in {
            "base-ssd-512gb-tlc",
            "base-ssd-1tb-tlc",
            "base-ssd-2tb-tlc",
        }
        assert parts["storage"].specs["flash_type"] == "TLC"
        if parts["storage"].component_id != "base-ssd-512gb-tlc":
            base_price = support_parts["base-ssd-512gb-tlc"].price(
                parts["storage"].condition
            )
            assert base_price is not None
            total_with_512gb = (
                template.estimated_total
                - parts["storage"].reference_price
                + base_price
            )
            assert total_with_512gb < template.details.target_budget
        assert parts["case"].component_id == "base-case-mid-tower"
        motherboard_share = (
            0.65
            if template.details.target_budget >= 13_000
            and template.details.direction == "aaa"
            else 0.32
            if template.details.target_budget >= 18_000
            else 0.23
            if template.details.target_budget >= 15_000
            and template.details.direction in {"aaa", "balanced"}
            else 0.23
            if template.details.direction == "fps"
            and template.details.target_budget >= 10_000
            else 0.16
            if template.details.direction == "fps"
            else 0.15
        )
        assert parts["motherboard"].reference_price <= (
            template.details.target_budget * motherboard_share
        )
        if parts["motherboard"].reference_price >= 5_000:
            assert CPU_PERFORMANCE[parts["cpu"].component_id] >= CPU_PERFORMANCE[
                "r7-9800x3d"
            ], template.id
        expected_vendor = (
            "nvidia" if parts["gpu"].component_id.startswith("rtx-") else "amd"
        )
        assert template.details.gpu_vendor == expected_vendor
        if parts["gpu"].condition == "new" and parts["gpu"].component_id.startswith(
            "rtx-40"
        ):
            assert parts["gpu"].component_id == "rtx-4060"
        assert not (
            parts["gpu"].condition == "new"
            and parts["gpu"].component_id == "rtx-4060-ti"
        )

        assert parts["cooler"].component_id == high_budget_catalog.COOLER_BY_CPU_ID[
            parts["cpu"].component_id
        ]


def test_aaa_uses_cpu_then_motherboard_after_gpu_and_caps_cpu_at_9800x3d() -> None:
    templates = generated_templates()
    aaa_templates = [
        template
        for template in templates
        if template.details.direction == "aaa"
    ]

    assert aaa_templates
    assert any(
        template.components["cpu"] == "r7-9850x3d"
        for template in aaa_templates
    )
    for purchase_mode in ("used", "mixed"):
        template = next(
            item
            for item in aaa_templates
            if item.details.target_budget == 13_000
            and item.details.purchase_mode == purchase_mode
            and item.details.gpu_vendor == "nvidia"
        )
        parts = {part.role: part for part in template.details.parts}
        assert parts["cpu"].component_id == "r7-9800x3d"
        assert parts["gpu"].component_id == "rtx-5070-ti"
        assert parts["motherboard"].component_id != "asus-prime-b650m-k"
        assert 12_900 <= template.estimated_total <= 13_800

    for template_id in (
        "base-22000-aaa-mixed",
        "base-23000-aaa-used",
    ):
        template = next(item for item in aaa_templates if item.id == template_id)
        parts = {part.role: part for part in template.details.parts}
        assert parts["gpu"].component_id == "rtx-4090-d"
        assert (
            CPU_PERFORMANCE[parts["cpu"].component_id]
            >= CPU_PERFORMANCE["r7-7800x3d"]
        )


def test_user_confirmed_high_end_gpu_order_and_value_gate() -> None:
    templates = generated_templates()

    assert (
        GPU_PERFORMANCE["rtx-5090-d-v2"]
        > GPU_PERFORMANCE["rtx-4090"]
        > GPU_PERFORMANCE["rtx-4090-d"]
        > GPU_PERFORMANCE["rtx-5080"]
    )
    assert any(
        template.components["gpu"] == "rtx-4090-d"
        for template in templates
    )
    assert all(
        template.components["gpu"] != "rtx-4090"
        for template in templates
    )


def test_psu_uses_the_smallest_available_wattage_that_meets_the_formula() -> None:
    _, _, _, support_parts = high_budget_catalog._load_catalog()

    for template in generated_templates():
        parts = {part.role: part for part in template.details.parts}
        required_watt = minimum_psu_watt(
            parts["cpu"].component_id,
            parts["gpu"].component_id,
        )
        expected_psu = high_budget_catalog._smallest_psu(
            required_watt,
            parts["psu"].condition,
            support_parts,
            parts["gpu"].component_id,
        )
        assert expected_psu is not None
        assert parts["psu"].component_id == expected_psu.component_id
        if high_budget_catalog.GPU_TDP[parts["gpu"].component_id] >= 140:
            assert parts["psu"].component_id != "base-psu-550w"


def test_every_new_gpu_uses_the_whitelist_new_price() -> None:
    with GPU_PRICE_PATH.open(encoding="utf-8", newline="") as handle:
        new_prices = {
            row["target_id"]: int(row["new_price"])
            for row in csv.DictReader(handle)
            if row.get("new_price")
        }

    for template in generated_templates():
        gpu = next(part for part in template.details.parts if part.role == "gpu")
        if gpu.condition == "new":
            assert gpu.component_id in new_prices
            assert gpu.reference_price == new_prices[gpu.component_id]


def test_9850x3d_uses_updated_whitelist_prices() -> None:
    with high_budget_catalog.CPU_PRICE_PATH.open(encoding="utf-8", newline="") as handle:
        row = next(row for row in csv.DictReader(handle) if row["target_id"] == "r7-9850x3d")
    assert row["used_price"] == "2550"
    assert row["new_tray_price"] == "2799"


def test_high_budget_templates_never_use_excluded_gpu_brand() -> None:
    for template in generated_templates():
        gpu = next(part for part in template.details.parts if part.role == "gpu")
        assert "耕升" not in gpu.name


def test_every_9800x3d_has_at_least_5060ti_class_gpu() -> None:
    minimum_gpu_performance = GPU_PERFORMANCE["rtx-5060-ti"]

    for template in generated_templates():
        parts = {part.role: part for part in template.details.parts}
        if parts["cpu"].component_id == "r7-9800x3d":
            assert (
                GPU_PERFORMANCE[parts["gpu"].component_id]
                >= minimum_gpu_performance
            ), template.id


def test_every_high_budget_build_respects_the_cpu_gpu_pairing_table() -> None:
    for template in generated_templates():
        parts = {part.role: part for part in template.details.parts}
        assert is_cpu_gpu_pairing_allowed(
            parts["cpu"].component_id,
            parts["gpu"].component_id,
        ), template.id


def test_5070ti_and_faster_nvidia_gpus_use_9700x_class_or_faster_cpu() -> None:
    for template in generated_templates():
        parts = {part.role: part for part in template.details.parts}
        minimum_cpu_performance = high_budget_catalog.GPU_MIN_CPU_PERFORMANCE.get(
            parts["gpu"].component_id
        )
        if minimum_cpu_performance is None:
            continue
        assert (
            CPU_PERFORMANCE[parts["cpu"].component_id]
            >= minimum_cpu_performance
        ), template.id


def test_am5_c28_prices_use_the_user_confirmed_new_and_used_values() -> None:
    _, _, _, support_parts = high_budget_catalog._load_catalog()

    assert support_parts["base-ddr5-16gb-6000-c28"].used_price == 1_350
    assert support_parts["base-ddr5-16gb-6000-c28"].new_price == 1_650
    assert support_parts["base-ddr5-16gb-6000-c32"].new_price == 1_700
    assert support_parts["base-ddr5-16gb-6000-c36"].new_price == 1_300
    assert support_parts["base-ddr5-16gb-6000-c30"].new_price is None
    assert support_parts["base-ddr5-32gb-6000-c28"].used_price == 2_700
    assert support_parts["base-ddr5-32gb-6000-c28"].new_price == 3_300
    assert support_parts["base-ddr5-32gb-6000-c32"].new_price == 3_400


def test_aaa_motherboard_fill_stays_within_whitelist_budget_caps() -> None:
    _, motherboards, _, _ = high_budget_catalog._load_catalog()

    for template in generated_templates():
        if template.details.direction != "aaa":
            continue
        parts = {part.role: part for part in template.details.parts}
        expected = high_budget_catalog._cheapest_adequate_motherboard(
            parts["cpu"].component_id,
            parts["motherboard"].condition,
            motherboards,
            max_price=(template.details.target_budget * 0.15),
        )
        assert expected is not None
        chosen_price = parts["motherboard"].reference_price
        cheapest_price = expected.price(parts["motherboard"].condition)
        assert cheapest_price is not None
        allowed_share = (
            0.65
            if template.details.target_budget >= 13_000
            else 0.23
            if template.details.target_budget >= 15_000
            else 0.15
        )
        assert chosen_price <= template.details.target_budget * allowed_share
        max_step_up = 10_000
        assert chosen_price <= cheapest_price + max_step_up


def test_b850_builds_only_use_user_approved_models() -> None:
    for template in generated_templates():
        motherboard = next(
            part for part in template.details.parts if part.role == "motherboard"
        )
        if motherboard.specs["chipset"] == "B850":
            assert motherboard.component_id in {
                "msi-b850m-power",
                "asus-b850m-awy",
            }


def test_8000_used_fps_build_uses_b850m_power() -> None:
    template = next(
        template
        for template in generated_templates()
        if template.id == "base-8000-fps-used"
    )
    parts = {part.role: part for part in template.details.parts}

    assert parts["motherboard"].component_id == "msi-b850m-power"
    assert 7_800 <= template.estimated_total <= 8_500


def test_8000_used_nvidia_aaa_build_moves_budget_to_4070_super() -> None:
    template = next(
        template
        for template in generated_templates()
        if template.id == "base-8000-aaa-used"
    )
    parts = {part.role: part for part in template.details.parts}

    assert parts["cpu"].component_id == "r7-7800x3d"
    assert parts["gpu"].component_id == "rtx-4070-super"
    assert parts["gpu"].reference_price == 3_700
    assert template.estimated_total == 8_278


def test_8500_mixed_fps_build_prioritizes_a_table_valid_x3d_pair() -> None:
    template = next(
        template
        for template in generated_templates()
        if template.id == "base-8500-fps-mixed"
    )
    parts = {part.role: part for part in template.details.parts}

    assert parts["cpu"].component_id == "r7-7800x3d"
    assert parts["gpu"].component_id == "rtx-4070-super"
    assert parts["motherboard"].specs["socket"] == "AM5"
    assert GPU_PERFORMANCE[parts["gpu"].component_id] >= GPU_PERFORMANCE["rtx-5060-ti"]
    assert 8_400 <= template.estimated_total <= 9_000


def test_9000_mixed_fps_build_keeps_a_modern_table_valid_pair() -> None:
    template = next(
        template
        for template in generated_templates()
        if template.id == "base-9000-fps-mixed"
    )
    parts = {part.role: part for part in template.details.parts}

    assert parts["cpu"].component_id == "r7-7800x3d"
    assert parts["gpu"].component_id == "rtx-4070-super"
    assert parts["gpu"].condition == "used"
    assert parts["motherboard"].component_id == "asus-b650m-tuf"
    assert template.estimated_total == 8_887


def test_9500_mixed_fps_build_uses_nvidia_with_9800x3d() -> None:
    template = next(
        template
        for template in generated_templates()
        if template.id == "base-9500-fps-mixed"
    )
    parts = {part.role: part for part in template.details.parts}

    assert parts["cpu"].component_id == "r7-9800x3d"
    assert parts["gpu"].component_id == "rtx-4070-super"
    assert parts["gpu"].condition == "used"
    assert parts["motherboard"].component_id == "asus-b650m-tuf"
    assert template.estimated_total == 9_637


def test_10000_requested_board_and_psu_prices_are_preserved() -> None:
    templates = {template.id: template for template in generated_templates()}

    fps_parts = {
        part.role: part
        for part in templates["base-10000-fps-new"].details.parts
    }
    aaa_parts = {
        part.role: part
        for part in templates["base-10000-aaa-mixed"].details.parts
    }
    _, _, _, support_parts = high_budget_catalog._load_catalog()

    assert fps_parts["motherboard"].component_id == "msi-b850m-power"
    assert fps_parts["cpu"].reference_price == 1_800
    assert 9_800 <= templates["base-10000-fps-new"].estimated_total <= 10_800
    assert aaa_parts["motherboard"].component_id == "asus-b650m-tuf"
    assert aaa_parts["psu"].reference_price == 299
    assert 9_800 <= templates["base-10000-aaa-mixed"].estimated_total <= 10_800
    assert support_parts["base-psu-850w-gold"].name == "安耐美 PX850DF 850W"
    assert support_parts["base-psu-850w-gold"].new_price == 659
    assert support_parts["base-psu-850w-gold"].used_price == 659
    assert support_parts["base-psu-1000w-gold"].name == "安耐美 PX1000DF 1000W"
    assert support_parts["base-psu-1000w-gold"].new_price == 859
    assert support_parts["base-psu-1200w-gold"].new_price == 650
    assert support_parts["base-psu-1200w-platinum"].name == (
        "追风者 REVOLT 1200W 白金电源 PH-P1200PR_BK01C（含兼容线组）"
    )
    assert support_parts["base-psu-1200w-platinum"].used_price == 799
    assert support_parts["base-psu-1200w-platinum"].new_price is None


def test_5090d_v2_used_builds_use_the_used_1200w_platinum_psu() -> None:
    templates = generated_templates()
    used_5090d_v2 = [
        template
        for template in templates
        if template.details.purchase_mode == "used"
        and template.components["gpu"] == "rtx-5090-d-v2"
    ]

    assert used_5090d_v2
    for template in used_5090d_v2:
        psu = next(part for part in template.details.parts if part.role == "psu")
        assert psu.component_id == "base-psu-1200w-platinum"
        assert psu.reference_price == 799
        assert psu.specs["model_number"] == "PH-P1200PR_BK01C"
        assert psu.specs["gpu_connector"] == "12V-2x6"
        assert psu.specs["gpu_connector_max_watt"] == 600
        assert psu.specs["price_includes_compatible_cable_kit"] is True


def test_5090_power_path_rejects_wattage_without_native_connector_or_cables() -> None:
    assert not psu_supports_gpu_power_connector(
        "rtx-5090-d-v2",
        {"watt": 1200},
    )
    assert not psu_supports_gpu_power_connector(
        "rtx-5090-d-v2",
        {
            "watt": 1200,
            "atx_version": 3.0,
            "gpu_connector": "12V-2x6",
            "gpu_connector_max_watt": 600,
            "cables_sold_separately": True,
            "price_includes_compatible_cable_kit": False,
        },
    )
    assert psu_supports_gpu_power_connector(
        "rtx-5090-d-v2",
        {
            "watt": 1200,
            "atx_version": 3.0,
            "gpu_connector": "12V-2x6",
            "gpu_connector_max_watt": 600,
            "cables_sold_separately": True,
            "price_includes_compatible_cable_kit": True,
        },
    )


def test_28000_used_balanced_does_not_trade_cpu_performance_for_motherboard() -> None:
    template = next(
        item
        for item in generated_templates()
        if item.id == "base-28000-balanced-used"
    )
    parts = {part.role: part for part in template.details.parts}

    assert parts["cpu"].component_id == "r7-9850x3d"
    assert parts["gpu"].component_id == "rtx-5090-d-v2"
    assert 27_800 <= template.estimated_total <= 28_800


def test_11000_and_higher_fps_modes_are_filled() -> None:
    templates = generated_templates()
    modes_by_budget = {
        budget: {
            template.details.purchase_mode
            for template in templates
            if template.details.target_budget == budget
            and template.details.direction == "fps"
        }
        for budget in BUDGET_TIERS
        if budget >= 11_000
    }
    for budget, modes in modes_by_budget.items():
        assert modes == {"new", "used", "mixed"}

    used_11000 = next(
        template for template in templates if template.id == "base-11000-fps-used"
    )
    assert 10_900 <= used_11000.estimated_total <= 11_800


def test_11000_aaa_keeps_valid_new_used_and_mixed_modes() -> None:
    new = next(
        item for item in generated_templates() if item.id == "base-11000-aaa-new"
    )
    used = next(
        item for item in generated_templates() if item.id == "base-11000-aaa-used"
    )
    mixed = next(
        item for item in generated_templates() if item.id == "base-11000-aaa-mixed"
    )
    new_parts = {part.role: part for part in new.details.parts}
    used_parts = {part.role: part for part in used.details.parts}
    mixed_parts = {part.role: part for part in mixed.details.parts}

    assert new_parts["cpu"].component_id == "r5-9600x"
    assert new_parts["gpu"].component_id == "rtx-5070"
    assert new_parts["gpu"].reference_price == 6_999
    assert new_parts["ram"].component_id == "base-ddr5-16gb-6000-c28"
    assert 10_900 <= new.estimated_total <= 11_800
    assert used_parts["cpu"].component_id == "r7-7800x3d"
    assert used_parts["gpu"].component_id == "rtx-5070-ti"
    assert used_parts["motherboard"].component_id == "asus-prime-b650m-k"
    assert 10_900 <= used.estimated_total <= 11_800
    assert mixed_parts["cpu"].component_id == "r5-9600x"
    assert mixed_parts["gpu"].component_id == "rtx-5070-ti"
    assert mixed_parts["motherboard"].component_id == "asus-b650m-tuf"
    assert 10_900 <= mixed.estimated_total <= 11_800


def test_11000_new_fps_uses_requested_board_and_c28_ram() -> None:
    template = next(
        item for item in generated_templates() if item.id == "base-11000-fps-new"
    )
    parts = {part.role: part for part in template.details.parts}

    assert parts["cpu"].component_id == "r7-7800x3d"
    assert parts["motherboard"].component_id == "msi-b850m-power"
    assert GPU_PERFORMANCE[parts["gpu"].component_id] >= GPU_PERFORMANCE["rtx-5060-ti"]
    assert parts["ram"].component_id == "base-ddr5-16gb-6000-c28"
    assert 10_900 <= template.estimated_total <= 11_800


def test_12000_new_and_mixed_aaa_use_c28_ram() -> None:
    templates = {item.id: item for item in generated_templates()}
    new = templates["base-12000-aaa-new"]
    mixed = templates["base-12000-aaa-mixed"]
    new_parts = {part.role: part for part in new.details.parts}
    mixed_parts = {part.role: part for part in mixed.details.parts}

    assert new_parts["ram"].component_id == "base-ddr5-16gb-6000-c28"
    assert 11_900 <= new.estimated_total <= 12_800
    assert mixed_parts["ram"].component_id == "base-ddr5-16gb-6000-c28"
    assert 11_900 <= mixed.estimated_total <= 12_800


def test_14000_new_aaa_uses_updated_5070_ti_price_without_underspending() -> None:
    template = next(
        item for item in generated_templates() if item.id == "base-14000-aaa-new"
    )
    parts = {part.role: part for part in template.details.parts}

    assert parts["cpu"].component_id == "r5-9600x"
    assert parts["gpu"].component_id == "rtx-5070-ti"
    assert parts["motherboard"].component_id == "asus-b650m-tuf"
    assert parts["ram"].component_id == "base-ddr5-16gb-6000-c28"
    assert 13_800 <= template.estimated_total <= 14_800


def test_14000_used_aaa_mode_remains_available_after_price_update() -> None:
    template = next(
        item for item in generated_templates() if item.id == "base-14000-aaa-used"
    )
    parts = {part.role: part for part in template.details.parts}

    assert parts["cpu"].component_id == "r7-9800x3d"
    assert parts["gpu"].component_id == "rtx-5070-ti"
    assert 13_800 <= template.estimated_total <= 14_800


def test_14000_new_balanced_preserves_the_stronger_weaker_side() -> None:
    template = next(
        item
        for item in generated_templates()
        if item.id == "base-14000-balanced-new"
    )
    parts = {part.role: part for part in template.details.parts}

    assert min(
        CPU_PERFORMANCE[parts["cpu"].component_id],
        GPU_PERFORMANCE[parts["gpu"].component_id],
    ) >= GPU_PERFORMANCE["rtx-5070"]
    assert parts["motherboard"].component_id == "asus-prime-b650m-k"
    assert parts["ram"].component_id == "base-ddr5-16gb-6000-c28"
    assert 13_800 <= template.estimated_total <= 14_800


def test_14000_mixed_balanced_uses_reviewed_cpu_gpu_balance() -> None:
    template = next(
        item
        for item in generated_templates()
        if item.id == "base-14000-balanced-mixed"
    )
    parts = {part.role: part for part in template.details.parts}

    assert parts["gpu"].component_id == "rtx-5070-ti"
    assert min(
        CPU_PERFORMANCE[parts["cpu"].component_id],
        GPU_PERFORMANCE[parts["gpu"].component_id],
    ) >= GPU_PERFORMANCE["rtx-5070-ti"]
    assert parts["ram"].component_id == "base-ddr5-16gb-6000-c28"
    assert 13_900 <= template.estimated_total <= 14_800


def test_15000_used_aaa_mode_is_filled_with_5080() -> None:
    template = next(
        item for item in generated_templates() if item.id == "base-15000-aaa-used"
    )
    parts = {part.role: part for part in template.details.parts}

    assert parts["cpu"].component_id == "r7-7800x3d"
    assert parts["gpu"].component_id == "rtx-5080"
    assert parts["ram"].component_id == "base-ddr5-16gb-6000-c28"
    assert 14_450 <= template.estimated_total <= 15_800


def test_7500_new_aaa_build_uses_nvidia_after_the_9070_gre_price_increase() -> None:
    template = next(
        template
        for template in generated_templates()
        if template.id == "base-7500-aaa-new"
    )
    parts = {part.role: part for part in template.details.parts}

    assert parts["cpu"].component_id == "r5-7500f"
    assert parts["motherboard"].component_id == "asus-b650m-tuf"
    assert parts["gpu"].component_id == "rtx-5060-ti"
    assert parts["ram"].specs["capacity_gb"] == 16
    assert parts["storage"].component_id == "base-ssd-512gb-tlc"
    assert parts["psu"].component_id == "base-psu-650w-gold"
    assert 7_400 <= template.estimated_total <= 8_000


def test_direction_allocations_have_valid_comparisons_when_both_options_exist() -> None:
    by_key = {
        (
            template.details.target_budget,
            template.details.purchase_mode,
            template.details.direction,
            template.details.gpu_vendor,
        ): template
        for template in generated_templates()
    }

    compared = 0
    for fps in (
        template
        for template in generated_templates()
        if template.details.direction == "fps"
    ):
        aaa = by_key.get(
            (
                fps.details.target_budget,
                fps.details.purchase_mode,
                "aaa",
                fps.details.gpu_vendor,
            )
        )
        if aaa is None:
            continue
        fps_parts = {part.role: part for part in fps.details.parts}
        aaa_parts = {part.role: part for part in aaa.details.parts}

        fps_cpu = CPU_PERFORMANCE[fps_parts["cpu"].component_id]
        fps_gpu = GPU_PERFORMANCE[fps_parts["gpu"].component_id]
        aaa_cpu = CPU_PERFORMANCE[aaa_parts["cpu"].component_id]
        aaa_gpu = GPU_PERFORMANCE[aaa_parts["gpu"].component_id]

        assert not (fps_cpu < aaa_cpu and fps_gpu > aaa_gpu), fps.id
        compared += 1

    assert compared > 0


def test_9500_plus_fps_and_aaa_keep_direction_specific_floors() -> None:
    for template in generated_templates():
        if template.details.target_budget < 9_500:
            continue
        parts = {part.role: part for part in template.details.parts}
        cpu_performance = CPU_PERFORMANCE[parts["cpu"].component_id]
        gpu_performance = GPU_PERFORMANCE[parts["gpu"].component_id]

        if template.details.direction == "fps":
            assert cpu_performance >= CPU_PERFORMANCE["r7-7800x3d"], template.id
        if (
            template.details.direction == "aaa"
            and parts["cpu"].component_id in {"r7-9800x3d", "r7-9850x3d"}
            and template.id != "base-11000-aaa-new"
        ):
            assert gpu_performance >= GPU_PERFORMANCE["rtx-5070-ti"], template.id


def test_10000_plus_used_and_mixed_match_new_focus_performance() -> None:
    templates = generated_templates()
    by_key = {
        (
            template.details.target_budget,
            template.details.direction,
            template.details.purchase_mode,
            template.details.gpu_vendor if template.details.direction != "fps" else None,
        ): template
        for template in templates
    }

    for budget in (tier for tier in BUDGET_TIERS if tier >= 10_000):
        for direction in ("fps", "aaa", "balanced"):
            for gpu_vendor in high_budget_catalog._gpu_vendors_for(
                budget, direction, "new"
            ):
                new_template = by_key.get((budget, direction, "new", gpu_vendor))
                if new_template is None:
                    continue
                new_parts = {
                    part.role: part for part in new_template.details.parts
                }
                if direction == "fps":
                    performance_floor = CPU_PERFORMANCE[
                        new_parts["cpu"].component_id
                    ]
                elif direction == "aaa":
                    performance_floor = GPU_PERFORMANCE[
                        new_parts["gpu"].component_id
                    ]
                else:
                    performance_floor = min(
                        CPU_PERFORMANCE[new_parts["cpu"].component_id],
                        GPU_PERFORMANCE[new_parts["gpu"].component_id],
                    )

                for purchase_mode in ("used", "mixed"):
                    template = by_key.get(
                        (budget, direction, purchase_mode, gpu_vendor)
                    )
                    if template is None:
                        continue
                    parts = {part.role: part for part in template.details.parts}
                    if direction == "fps":
                        actual = CPU_PERFORMANCE[parts["cpu"].component_id]
                    elif direction == "aaa":
                        actual = GPU_PERFORMANCE[parts["gpu"].component_id]
                    else:
                        actual = min(
                            CPU_PERFORMANCE[parts["cpu"].component_id],
                            GPU_PERFORMANCE[parts["gpu"].component_id],
                        )
                    assert actual >= performance_floor, template.id


def test_every_high_budget_direction_returns_all_three_purchase_modes() -> None:
    templates = generated_templates()
    for budget in BUDGET_TIERS:
        for direction in ("fps", "aaa", "balanced"):
            assert {
                item.details.purchase_mode
                for item in templates
                if item.details.target_budget == budget
                and item.details.direction == direction
            } == {"new", "used", "mixed"}


def test_template_details_keep_user_and_price_metadata() -> None:
    for template in generated_templates():
        details = template.details
        assert details.suitable_user
        assert details.price_date == PRICE_DATE


def test_writes_review_markdown_and_backend_json(tmp_path) -> None:
    templates = generated_templates()
    markdown = render_high_budget_markdown(templates)

    lines = markdown.splitlines()
    assert sum(line.startswith("## ") for line in lines) == len(
        {template.details.target_budget for template in templates}
    )
    assert sum(line.startswith("### ") for line in lines) == len(templates)
    assert "**优点：**" not in markdown
    assert "**缺点：**" not in markdown
    assert "**风险：**" not in markdown

    paths = write_high_budget_artifacts(tmp_path, templates)
    payload = json.loads(paths.templates_json.read_text(encoding="utf-8"))

    assert len(payload) == len(templates)
    assert payload[0]["details"]["target_budget"] == 7_500
    assert all(
        {"advantages", "disadvantages", "risks"}.isdisjoint(item["details"])
        for item in payload
    )
    assert paths.review_markdown.read_text(encoding="utf-8") == markdown
    assert paths.reference_prices_csv.exists()
    assert paths.recommendation_ids.exists()
    audit = json.loads(paths.audit_json.read_text(encoding="utf-8"))
    assert audit["completed_template_count"] == len(templates)
    assert audit["completed_tiers"]
    assert audit["public_completed_tiers"] == BUDGET_TIERS
    assert audit["pending_review"] == []
    assert audit["missing_data"]
    assert audit["failed_templates"] == []


def test_empty_and_partial_artifacts_report_actual_completion(tmp_path) -> None:
    cases = [[], generated_templates()[:1]]

    for index, templates in enumerate(cases):
        paths = write_high_budget_artifacts(tmp_path / str(index), templates)
        payload = json.loads(paths.templates_json.read_text(encoding="utf-8"))
        audit = json.loads(paths.audit_json.read_text(encoding="utf-8"))
        markdown = paths.review_markdown.read_text(encoding="utf-8")
        expected_missing = expected_template_count() - len(templates)

        assert len(payload) == len(templates)
        assert audit["completed_tiers"] == []
        assert audit["public_completed_tiers"] == []
        assert audit["completed_template_count"] == len(templates)
        assert len(audit["missing_data"]) == expected_missing
        assert {item["reason"] for item in audit["missing_data"]} == {
            "not_provided"
        }
        assert audit["failed_templates"] == []
        assert f"{len(templates)}/{expected_template_count()}套配置生成" in markdown
        assert f"不可用配置{expected_missing}套" in markdown
        assert f"{len(BUDGET_TIERS)}/{len(BUDGET_TIERS)}个价位完成" not in markdown


def test_artifacts_use_the_generation_report_price_snapshot(
    tmp_path,
    monkeypatch,
) -> None:
    report = high_budget_catalog.generate_high_budget_report()
    source_case = next(
        part
        for part in report.source_parts
        if part.component_id == "base-case-mid-tower"
    )
    support_parts = json.loads(
        high_budget_catalog.SUPPORT_PART_PATH.read_text(encoding="utf-8")
    )
    mutated_case = next(
        item for item in support_parts if item["id"] == "base-case-mid-tower"
    )
    mutated_case["used_price"] = 1
    mutated_case["new_price"] = 2
    mutated_support_path = tmp_path / "mutated-support-components.json"
    mutated_support_path.write_text(
        json.dumps(support_parts, ensure_ascii=False),
        encoding="utf-8",
    )
    monkeypatch.setattr(
        high_budget_catalog,
        "SUPPORT_PART_PATH",
        mutated_support_path,
    )

    paths = write_high_budget_artifacts(tmp_path / "artifacts", report=report)
    with paths.reference_prices_csv.open(encoding="utf-8", newline="") as handle:
        rows = {row["target_id"]: row for row in csv.DictReader(handle)}

    assert rows["base-case-mid-tower"]["normal_price_min"] == str(
        source_case.used_price
    )
    assert rows["base-case-mid-tower"]["normal_price_max"] == str(
        source_case.new_price
    )


def test_generation_report_records_the_actual_selection_failure(
    tmp_path,
    monkeypatch,
) -> None:
    original_select_candidate = high_budget_catalog._select_candidate

    def fail_one_combination(*args, **kwargs):
        if (
            kwargs["budget"],
            kwargs["direction"],
            kwargs["purchase_mode"],
        ) == (7_500, "fps", "new"):
            raise ValueError("fixture selection failure")
        return original_select_candidate(*args, **kwargs)

    monkeypatch.setattr(
        high_budget_catalog,
        "_select_candidate",
        fail_one_combination,
    )
    high_budget_catalog.generate_high_budget_report.cache_clear()
    try:
        report = high_budget_catalog.generate_high_budget_report()
        paths = write_high_budget_artifacts(tmp_path, report=report)
        audit = json.loads(paths.audit_json.read_text(encoding="utf-8"))
        markdown = paths.review_markdown.read_text(encoding="utf-8")
    finally:
        high_budget_catalog.generate_high_budget_report.cache_clear()

    assert report.templates
    assert audit["completed_template_count"] == len(report.templates)
    assert audit["failed_templates"] == [
        {
            "target_budget": 7_500,
            "direction": "fps",
            "purchase_mode": "new",
            "error": "fixture selection failure",
        }
    ]
    assert f"{len(report.templates)}/{expected_template_count()}套配置生成" in markdown
    assert "失败配置1套" in markdown


def test_reference_export_does_not_invent_a_missing_condition_price(
    tmp_path,
) -> None:
    template = next(
        template
        for template in generated_templates()
        if template.details.purchase_mode == "used"
    )
    case = next(
        part
        for part in template.details.parts
        if part.component_id == "base-case-mid-tower"
    )

    paths = write_high_budget_artifacts(tmp_path / "artifacts", [template])
    with paths.reference_prices_csv.open(encoding="utf-8", newline="") as handle:
        rows = {row["target_id"]: row for row in csv.DictReader(handle)}

    assert rows["base-case-mid-tower"]["normal_price_min"] == str(
        case.reference_price
    )
    assert rows["base-case-mid-tower"]["normal_price_max"] == ""


def test_template_api_response_includes_structured_details() -> None:
    generated = generated_templates()[0]
    row = BuildTemplate(
        id=generated.id,
        title=generated.title,
        budget_min=generated.budget_min,
        budget_max=generated.budget_max,
        use_cases=generated.use_cases,
        tags=generated.tags,
        components=generated.components,
        estimated_total=generated.estimated_total,
        explanation=generated.explanation,
        details=generated.details.model_dump(mode="json"),
    )
    compatibility = CompatibilityResult(
        compatible=True,
        summary="ok",
        findings=[],
        finding_counts={"pass": 0, "warning": 0, "error": 0},
        checked_rule_codes=[],
    )

    response = template_response(row, compatibility)

    assert response.details.target_budget == 7_500
    assert len(response.details.parts) == 8
    assert response.details.parts[0].reference_price > 0
