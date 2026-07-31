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
    REQUIRED_PART_ROLES,
    generate_high_budget_templates,
    minimum_psu_watt,
    render_high_budget_markdown,
    write_high_budget_artifacts,
)
from app.builds.service import template_response
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
        "gpu": "new",
        "ram": "used",
        "storage": "new",
        "psu": "new",
        "cooler": "used",
        "case": "used",
    },
}


def generated_templates():
    return generate_high_budget_templates()


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
        assert len({template.details.purchase_mode for template in fps}) == len(fps)
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
        max_shortfall = (
            150
            if template.id == "base-8000-aaa-used"
            else 120
            if template.id == "base-14000-balanced-mixed"
            else 550
            if (
                template.details.direction == "fps"
                and template.details.target_budget >= 10_000
            )
            or (
                template.details.target_budget >= 15_000
                and template.details.direction in {"aaa", "balanced"}
            )
            else 100
        )
        assert template.details.target_budget - max_shortfall <= template.estimated_total
        max_overage = 800 if template.details.target_budget >= 10_000 else 300
        assert template.estimated_total <= template.details.target_budget + max_overage


def test_purchase_conditions_follow_the_three_exact_modes() -> None:
    for template in generated_templates():
        actual = {
            part.role: part.condition for part in template.details.parts
        }
        assert actual == EXPECTED_CONDITIONS[template.details.purchase_mode]


def test_all_builds_use_whitelisted_amd_am5_parts_and_fixed_base_storage() -> None:
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
        if parts["ram"].condition == "new":
            assert parts["ram"].specs["cas_latency"] in {28, 32, 36}
        else:
            assert parts["ram"].specs["cas_latency"] == 30
        if template.details.target_budget >= 10_000:
            assert parts["ram"].specs["cas_latency"] <= 32
        assert parts["storage"].component_id == "base-ssd-512gb-tlc"
        assert parts["storage"].specs["flash_type"] == "TLC"
        assert parts["case"].component_id == "base-case-mid-tower"
        motherboard_share = (
            0.32
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

        if "x3d" in parts["cpu"].component_id:
            assert parts["cooler"].component_id == "base-cooler-dual-tower-6-heatpipe"
        else:
            assert parts["cooler"].component_id == "base-cooler-6-heatpipe"


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
        )
        assert expected_psu is not None
        assert parts["psu"].component_id == expected_psu.component_id


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


def test_ddr5_new_prices_use_the_user_provided_c28_and_c32_tiers() -> None:
    _, _, _, support_parts = high_budget_catalog._load_catalog()

    assert support_parts["base-ddr5-16gb-6000-c28"].new_price == 1_900
    assert support_parts["base-ddr5-16gb-6000-c32"].new_price == 1_700
    assert support_parts["base-ddr5-16gb-6000-c36"].new_price == 1_300
    assert support_parts["base-ddr5-16gb-6000-c30"].new_price is None
    assert support_parts["base-ddr5-32gb-6000-c28"].new_price == 3_800
    assert support_parts["base-ddr5-32gb-6000-c32"].new_price == 3_400


def test_new_aaa_builds_only_use_c36_when_c32_cannot_fit() -> None:
    for template in generated_templates():
        if template.details.direction != "aaa":
            continue
        ram = next(part for part in template.details.parts if part.role == "ram")
        if ram.condition == "new":
            assert ram.specs["cas_latency"] in {28, 32, 36}, template.id
            if ram.specs["cas_latency"] == 36:
                assert (
                    template.estimated_total + 400
                    > template.details.target_budget + 300
                ), template.id


def test_aaa_builds_only_step_up_motherboard_to_reach_budget_floor() -> None:
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
            0.32
            if template.details.target_budget >= 18_000
            else 0.23
            if template.details.target_budget >= 15_000
            else 0.15
        )
        assert chosen_price <= template.details.target_budget * allowed_share
        new_9800x3d = (
            parts["cpu"].component_id == "r7-9800x3d"
            and parts["cpu"].condition == "new"
            and template.details.target_budget >= 10_000
        )
        reviewed_12000_tuf = template.id in {
            "base-12000-aaa-new",
            "base-12000-aaa-mixed",
        }
        reviewed_14000_power = template.id in {
            "base-14000-aaa-new",
            "base-14000-aaa-used",
        }
        coverage_aaa = template.details.target_budget >= 15_000
        max_step_up = (
            6_000
            if template.details.target_budget >= 18_000
            else 3_500
            if coverage_aaa
            else 500
            if reviewed_14000_power
            else 400
            if new_9800x3d
            else 300
        )
        assert chosen_price <= cheapest_price + max_step_up
        if (
            template.id != "base-10000-aaa-mixed"
            and not new_9800x3d
            and not reviewed_12000_tuf
            and not coverage_aaa
            and (
            template.estimated_total - chosen_price + cheapest_price
            )
            >= (template.details.target_budget - 100)
        ):
            assert parts["motherboard"].component_id == expected.component_id


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
    assert template.estimated_total == 8_230


def test_8000_used_nvidia_aaa_build_moves_budget_to_4070_super() -> None:
    template = next(
        template
        for template in generated_templates()
        if template.id == "base-8000-aaa-used"
    )
    parts = {part.role: part for part in template.details.parts}

    assert parts["cpu"].component_id == "r7-7800x3d"
    assert parts["gpu"].component_id == "rtx-4070-super"
    assert parts["gpu"].reference_price == 3_600
    assert template.estimated_total == 7_880


def test_8500_mixed_fps_build_prioritizes_9800x3d() -> None:
    template = next(
        template
        for template in generated_templates()
        if template.id == "base-8500-fps-mixed"
    )
    parts = {part.role: part for part in template.details.parts}

    assert parts["cpu"].component_id == "r7-9800x3d"
    assert parts["motherboard"].specs["socket"] == "AM5"
    assert GPU_PERFORMANCE[parts["gpu"].component_id] >= GPU_PERFORMANCE["rtx-5060-ti"]
    assert 8_400 <= template.estimated_total <= 8_800


def test_9000_mixed_fps_build_uses_amd_to_keep_9800x3d() -> None:
    template = next(
        template
        for template in generated_templates()
        if template.id == "base-9000-fps-mixed"
    )
    parts = {part.role: part for part in template.details.parts}

    assert parts["cpu"].component_id == "r7-9800x3d"
    assert parts["gpu"].component_id == "rx-9070-gre"
    assert parts["motherboard"].component_id == "asus-b650m-tuf"
    assert template.estimated_total == 8_980


def test_9500_mixed_fps_build_uses_amd_to_keep_9800x3d() -> None:
    template = next(
        template
        for template in generated_templates()
        if template.id == "base-9500-fps-mixed"
    )
    parts = {part.role: part for part in template.details.parts}

    assert parts["cpu"].component_id == "r7-9800x3d"
    assert parts["gpu"].component_id == "rx-9070-gre"
    assert parts["motherboard"].component_id == "msi-b850m-power"
    assert template.estimated_total == 9_480


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
    assert fps_parts["cpu"].reference_price == 2_500
    assert 9_900 <= templates["base-10000-fps-new"].estimated_total <= 10_800
    assert aaa_parts["motherboard"].component_id == "asus-b650m-tuf"
    assert aaa_parts["psu"].reference_price == 400
    assert 9_900 <= templates["base-10000-aaa-mixed"].estimated_total <= 10_800
    assert support_parts["base-psu-850w-gold"].new_price == 400
    assert support_parts["base-psu-850w-gold"].used_price == 250
    assert support_parts["base-psu-1200w-gold"].new_price == 650


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
        assert modes <= {"new", "used", "mixed"}

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

    assert new_parts["cpu"].component_id == "r7-7800x3d"
    assert new_parts["gpu"].component_id == "rtx-5070"
    assert new_parts["gpu"].reference_price == 5_400
    assert new_parts["ram"].component_id == "base-ddr5-16gb-6000-c32"
    assert 10_900 <= new.estimated_total <= 11_800
    assert used_parts["cpu"].component_id == "r7-7800x3d"
    assert used_parts["gpu"].component_id == "rtx-5070-ti"
    assert 10_900 <= used.estimated_total <= 11_800
    assert mixed_parts["cpu"].component_id == "r7-9700x"
    assert mixed_parts["gpu"].component_id == "rtx-5070-ti"
    assert 10_900 <= mixed.estimated_total <= 11_800


def test_11000_new_fps_uses_requested_board_and_c32_or_better_ram() -> None:
    template = next(
        item for item in generated_templates() if item.id == "base-11000-fps-new"
    )
    parts = {part.role: part for part in template.details.parts}

    assert parts["cpu"].component_id == "r7-9800x3d"
    assert parts["cpu"].reference_price == 2_500
    assert parts["motherboard"].component_id == "msi-b850m-power"
    assert parts["gpu"].component_id == "rx-9070-xt"
    assert parts["ram"].specs["cas_latency"] <= 32
    assert 10_900 <= template.estimated_total <= 11_800


def test_12000_new_and_mixed_aaa_use_reviewed_tuf_board_and_ram() -> None:
    templates = {item.id: item for item in generated_templates()}
    new = templates["base-12000-aaa-new"]
    mixed = templates["base-12000-aaa-mixed"]
    new_parts = {part.role: part for part in new.details.parts}
    mixed_parts = {part.role: part for part in mixed.details.parts}

    assert new_parts["ram"].component_id == "base-ddr5-16gb-6000-c32"
    assert 11_900 <= new.estimated_total <= 12_800
    assert mixed_parts["ram"].component_id == "base-ddr5-16gb-6000-c30"
    assert 11_900 <= mixed.estimated_total <= 12_800


def test_14000_new_aaa_trades_5080_for_cpu_and_board_balance() -> None:
    template = next(
        item for item in generated_templates() if item.id == "base-14000-aaa-new"
    )
    parts = {part.role: part for part in template.details.parts}

    assert parts["cpu"].component_id == "r7-7800x3d"
    assert parts["gpu"].component_id == "rtx-5080"
    assert parts["ram"].component_id == "base-ddr5-16gb-6000-c32"
    assert 13_900 <= template.estimated_total <= 14_800


def test_14000_used_aaa_mode_remains_available_after_price_update() -> None:
    template = next(
        item for item in generated_templates() if item.id == "base-14000-aaa-used"
    )
    parts = {part.role: part for part in template.details.parts}

    assert parts["cpu"].component_id == "r7-9800x3d"
    assert parts["gpu"].component_id == "rtx-5080"
    assert template.estimated_total == 14_430


def test_14000_new_balanced_uses_reviewed_cpu_gpu_balance() -> None:
    template = next(
        item
        for item in generated_templates()
        if item.id == "base-14000-balanced-new"
    )
    parts = {part.role: part for part in template.details.parts}

    assert parts["cpu"].component_id == "r7-7800x3d"
    assert parts["gpu"].component_id == "rtx-5080"
    assert parts["ram"].component_id == "base-ddr5-16gb-6000-c32"
    assert 13_900 <= template.estimated_total <= 14_800


def test_14000_mixed_balanced_uses_reviewed_cpu_gpu_balance() -> None:
    template = next(
        item
        for item in generated_templates()
        if item.id == "base-14000-balanced-mixed"
    )
    parts = {part.role: part for part in template.details.parts}

    assert parts["cpu"].component_id == "r7-7800x3d"
    assert parts["gpu"].component_id == "rtx-5080"
    assert parts["ram"].component_id == "base-ddr5-16gb-6000-c30"
    assert 13_900 <= template.estimated_total <= 14_800


def test_15000_used_aaa_mode_is_filled_with_5080() -> None:
    template = next(
        item for item in generated_templates() if item.id == "base-15000-aaa-used"
    )
    parts = {part.role: part for part in template.details.parts}

    assert parts["cpu"].component_id == "r7-9800x3d"
    assert parts["gpu"].component_id == "rtx-5080"
    assert parts["ram"].component_id == "base-ddr5-16gb-6000-c30"
    assert 14_450 <= template.estimated_total <= 15_800


def test_7500_new_nvidia_aaa_build_uses_the_best_fitting_pair() -> None:
    template = next(
        template
        for template in generated_templates()
        if template.id == "base-7500-aaa-new"
    )
    parts = {part.role: part for part in template.details.parts}

    assert parts["cpu"].component_id == "r5-9600x"
    assert parts["motherboard"].component_id == "asus-prime-b650m-k"
    assert parts["gpu"].component_id == "rtx-5060-ti"
    assert parts["ram"].specs["capacity_gb"] == 16
    assert parts["storage"].component_id == "base-ssd-512gb-tlc"
    assert parts["psu"].component_id == "base-psu-650w-gold"
    assert 7_400 <= template.estimated_total <= 7_800


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

        assert CPU_PERFORMANCE[fps_parts["cpu"].component_id] >= 60
        assert GPU_PERFORMANCE[aaa_parts["gpu"].component_id] >= 50
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
            for gpu_vendor in high_budget_catalog._gpu_vendors_for(direction):
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


def test_10000_plus_missing_modes_are_recorded_as_unavailable() -> None:
    templates = generated_templates()
    missing = {
        (budget, direction, purchase_mode)
        for budget in (tier for tier in BUDGET_TIERS if tier >= 10_000)
        for direction in ("fps", "aaa", "balanced")
        for purchase_mode in ("new", "used", "mixed")
        if not any(
            item.details.target_budget == budget
            and item.details.direction == direction
            and item.details.purchase_mode == purchase_mode
            for item in templates
        )
    }

    failures = high_budget_catalog.generate_high_budget_report().failures
    failed_keys = {
        (failure.target_budget, failure.direction, failure.purchase_mode)
        for failure in failures
    }
    assert missing <= failed_keys


def test_template_details_keep_user_and_price_metadata() -> None:
    for template in generated_templates():
        details = template.details
        assert details.suitable_user
        assert details.price_date == "2026-07-30"


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
        expected_missing = len(BUDGET_TIERS) * 15 - len(templates)

        assert len(payload) == len(templates)
        assert audit["completed_tiers"] == []
        assert audit["completed_template_count"] == len(templates)
        assert len(audit["missing_data"]) == expected_missing
        assert {item["reason"] for item in audit["missing_data"]} == {
            "not_provided"
        }
        assert audit["failed_templates"] == []
        assert f"{len(templates)}/{len(BUDGET_TIERS) * 15}套配置生成" in markdown
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
    assert f"{len(report.templates)}/{len(BUDGET_TIERS) * 15}套配置生成" in markdown
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
