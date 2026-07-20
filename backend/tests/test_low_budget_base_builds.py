import csv
import json
from pathlib import Path

import app.builds.low_budget_catalog as low_budget_catalog
from sqlalchemy import create_engine, func, select
from sqlalchemy.orm import Session
from app.builds.low_budget_catalog import (
    BUDGET_TIERS,
    CPU_PERFORMANCE,
    CPU_PRICE_PATH,
    DIRECTIONS,
    GPU_PERFORMANCE,
    GPU_PRICE_PATH,
    MOTHERBOARD_PRICE_PATH,
    PURCHASE_MODES,
    REQUIRED_PART_ROLES,
    SUPPORT_PART_PATH,
    generate_low_budget_templates,
    minimum_psu_watt,
    render_low_budget_markdown,
    write_low_budget_artifacts,
)
from app.builds.models import BuildTemplate
from app.builds.repository import upsert_build_templates
from app.builds.service import BuildTemplatePart
from app.builds.templates import read_build_template_inputs
from app.catalog.prices import read_approved_price_rows
from app.catalog.repository import (
    seed_component_prices,
    seed_hardware_components,
    update_recommended_components,
)
from app.catalog.seed import read_catalog_components
from app.db import Base


BACKEND_ROOT = Path(__file__).resolve().parents[1]
PROJECT_ROOT = BACKEND_ROOT.parent
DATA_DIR = BACKEND_ROOT / "data"
TEMPLATE_PATH = DATA_DIR / "low-budget-base-build-templates.json"
PRICE_PATH = DATA_DIR / "low-budget-base-reference-prices.csv"
RECOMMENDATION_PATH = DATA_DIR / "low-budget-base-recommendation-ids.txt"
AUDIT_PATH = DATA_DIR / "low-budget-base-audit.json"
MARKDOWN_PATH = PROJECT_ROOT / "docs" / "3000-7000-yuan-base-builds.md"
HIGH_TEMPLATE_PATH = DATA_DIR / "high-budget-base-build-templates.json"
HIGH_PRICE_PATH = DATA_DIR / "high-budget-base-reference-prices.csv"
SWIFT_CATALOG_PATH = PROJECT_ROOT / "May" / "May" / "Models" / "HardwareCatalog.swift"

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

KNOWN_IMPOSSIBLE_COMBINATIONS = {
    (budget, direction, purchase_mode)
    for budget in (3_000, 3_500)
    for direction in DIRECTIONS
    for purchase_mode in ("new", "mixed")
} | {(4_000, direction, "new") for direction in DIRECTIONS}
PENDING_REVIEW_CONDITION_PAIRS = set()


def generated_templates():
    return generate_low_budget_templates()


def generated_report():
    return low_budget_catalog.generate_low_budget_report()


def test_generates_every_low_budget_direction_with_only_feasible_modes() -> None:
    templates = generated_templates()
    keys = {
        (
            template.details.target_budget,
            template.details.direction,
            template.details.purchase_mode,
            template.details.gpu_vendor,
        )
        for template in templates
    }

    assert BUDGET_TIERS == list(range(3_000, 7_001, 500))
    assert len(templates) == 96
    assert len({template.id for template in templates}) == len(templates)
    assert len(keys) == len(templates)

    for budget in BUDGET_TIERS:
        assert {
            template.details.direction
            for template in templates
            if template.details.target_budget == budget
        } == set(DIRECTIONS)

    for template in templates:
        details = template.details
        expected_id = f"base-{details.target_budget}-{details.direction}-{details.purchase_mode}"
        if details.gpu_vendor == "amd" and details.target_budget >= 5_000 and details.direction != "fps":
            expected_id += "-amd"
        assert template.id == expected_id

    for budget in range(5_000, 7_001, 500):
        expected_combinations = {
            (direction, purchase_mode, gpu_vendor)
            for direction in ("aaa", "balanced")
            for purchase_mode in PURCHASE_MODES
            for gpu_vendor in ("nvidia", "amd")
        }
        assert {
            (
                template.details.direction,
                template.details.purchase_mode,
                template.details.gpu_vendor,
            )
            for template in templates
            if template.details.target_budget == budget
            and template.details.direction != "fps"
        } == expected_combinations


def test_every_template_has_eight_source_priced_parts_and_an_exact_total() -> None:
    source_prices = _source_prices()

    for template in generated_templates():
        details = template.details
        parts = {part.role: part for part in details.parts}

        assert len(details.parts) == len(REQUIRED_PART_ROLES)
        assert set(parts) == REQUIRED_PART_ROLES
        assert set(template.components) == REQUIRED_PART_ROLES
        assert template.components == {
            role: part.component_id for role, part in parts.items()
        }
        assert all(part.reference_price > 0 for part in parts.values())
        assert all(part.price_source for part in parts.values())
        assert all(part.price_date for part in parts.values())
        assert template.estimated_total == sum(
            part.reference_price for part in parts.values()
        )
        assert details.target_budget - 100 <= template.estimated_total
        max_overage = 330 if template.id == "base-6500-fps-mixed" else 300
        assert template.estimated_total <= details.target_budget + max_overage
        assert details.suitable_user

        for part in parts.values():
            price, source = source_prices[(part.component_id, part.condition)]
            assert part.reference_price == price
            assert part.price_source == source


def test_purchase_conditions_follow_the_three_exact_modes() -> None:
    for template in generated_templates():
        actual = {
            part.role: part.condition for part in template.details.parts
        }
        assert actual == EXPECTED_CONDITIONS[template.details.purchase_mode]


def test_generated_parts_are_compatible_and_new_slots_are_available() -> None:
    _, _, _, support_parts = low_budget_catalog._load_catalog()

    for template in generated_templates():
        parts = {part.role: part for part in template.details.parts}

        assert parts["cpu"].component_id in CPU_PERFORMANCE
        assert parts["gpu"].component_id in GPU_PERFORMANCE
        assert parts["cpu"].specs["socket"] == parts["motherboard"].specs[
            "socket"
        ]
        assert parts["motherboard"].specs["mem_type"] == parts["ram"].specs[
            "type"
        ]
        assert parts["ram"].specs["capacity_gb"] == 16
        required_psu_watt = minimum_psu_watt(
            parts["cpu"].component_id,
            parts["gpu"].component_id,
        )
        expected_psu = low_budget_catalog._smallest_psu(
            required_psu_watt,
            parts["psu"].condition,
            support_parts,
        )
        assert expected_psu is not None
        assert parts["psu"].component_id == expected_psu.component_id
        assert parts["storage"].component_id == "base-ssd-512gb-tlc"
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

        if "x3d" in parts["cpu"].component_id or parts["cpu"].component_id == "i5-13600kf":
            assert parts["cooler"].component_id == (
                "base-cooler-dual-tower-6-heatpipe"
            )


def test_6000_plus_builds_do_not_use_5600_series_cpus() -> None:
    for template in generated_templates():
        if template.details.target_budget < 6_000:
            continue
        cpu = next(part for part in template.details.parts if part.role == "cpu")
        assert cpu.component_id not in {"r5-5600", "r5-5600x"}, template.id


def test_new_aaa_builds_only_use_c36_when_c32_cannot_fit() -> None:
    for template in generated_templates():
        if template.details.direction != "aaa":
            continue
        ram = next(part for part in template.details.parts if part.role == "ram")
        if ram.condition == "new" and ram.specs["type"] == "DDR5":
            assert ram.specs["cas_latency"] in {32, 36}, template.id
            if ram.specs["cas_latency"] == 36:
                assert (
                    template.estimated_total + 400
                    > template.details.target_budget + 300
                ), template.id


def test_aaa_builds_only_step_up_motherboard_to_reach_budget_floor() -> None:
    _, motherboards, _, _ = low_budget_catalog._load_catalog()

    for template in generated_templates():
        if template.details.direction != "aaa":
            continue
        parts = {part.role: part for part in template.details.parts}
        expected = low_budget_catalog._cheapest_adequate_motherboard(
            parts["cpu"].component_id,
            str(parts["cpu"].specs["socket"]),
            parts["motherboard"].condition,
            motherboards,
        )
        assert expected is not None
        chosen_price = parts["motherboard"].reference_price
        cheapest_price = expected.price(parts["motherboard"].condition)
        assert cheapest_price is not None
        if template.id == "base-7000-aaa-mixed":
            assert parts["motherboard"].component_id == "asus-b850m-awy"
            continue
        assert chosen_price <= template.details.target_budget * 0.15
        assert chosen_price <= cheapest_price + 300
        if template.estimated_total - chosen_price + cheapest_price >= (
            template.details.target_budget - 100
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


def test_fps_and_aaa_allocations_follow_their_performance_priorities() -> None:
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

    for budget in BUDGET_TIERS:
        for purchase_mode in PURCHASE_MODES:
            fps = next(
                (
                    template
                    for template in generated_templates()
                    if template.details.target_budget == budget
                    and template.details.purchase_mode == purchase_mode
                    and template.details.direction == "fps"
                ),
                None,
            )
            aaa = (
                by_key.get(
                    (
                        budget,
                        purchase_mode,
                        "aaa",
                        fps.details.gpu_vendor,
                    )
                )
                if fps is not None
                else None
            )
            if fps is None or aaa is None:
                continue
            fps_parts = {part.role: part for part in fps.details.parts}
            aaa_parts = {part.role: part for part in aaa.details.parts}

            assert CPU_PERFORMANCE[fps_parts["cpu"].component_id] >= CPU_PERFORMANCE[
                aaa_parts["cpu"].component_id
            ]
            assert GPU_PERFORMANCE[aaa_parts["gpu"].component_id] >= GPU_PERFORMANCE[
                fps_parts["gpu"].component_id
            ]
            compared += 1

    assert compared >= len(BUDGET_TIERS)


def test_direction_scores_strictly_rank_cpu_and_gpu_priority() -> None:
    cpu_first = _ranking_candidate(cpu_performance=90, gpu_performance=50)
    gpu_first = _ranking_candidate(cpu_performance=60, gpu_performance=85)

    assert low_budget_catalog._score_candidate(
        cpu_first, "fps"
    ) > low_budget_catalog._score_candidate(gpu_first, "fps")
    assert low_budget_catalog._score_candidate(
        gpu_first, "aaa"
    ) > low_budget_catalog._score_candidate(cpu_first, "aaa")


def test_used_builds_at_5000_plus_avoid_legacy_mining_risk_gpus() -> None:
    legacy_prefixes = ("rtx-30", "rx-6")

    for template in generated_templates():
        if (
            template.details.target_budget < 5_000
            or template.details.purchase_mode != "used"
        ):
            continue
        gpu = next(part for part in template.details.parts if part.role == "gpu")
        assert not gpu.component_id.startswith(legacy_prefixes), template.id


def test_9800x3d_requires_at_least_5060ti_class_gpu() -> None:
    minimum_gpu_performance = GPU_PERFORMANCE["rtx-5060-ti"]

    for template in generated_templates():
        parts = {part.role: part for part in template.details.parts}
        if parts["cpu"].component_id == "r7-9800x3d":
            assert (
                GPU_PERFORMANCE[parts["gpu"].component_id]
                >= minimum_gpu_performance
            ), template.id


def test_7000_used_fps_build_drops_9800x3d_for_a_modern_gpu() -> None:
    template = next(
        template
        for template in generated_templates()
        if template.details.target_budget == 7_000
        and template.details.direction == "fps"
        and template.details.purchase_mode == "used"
    )
    parts = {part.role: part for part in template.details.parts}

    assert parts["cpu"].component_id == "r7-7800x3d"
    assert not parts["gpu"].component_id.startswith(("rtx-30", "rx-6"))
    assert 6_900 <= template.estimated_total <= 7_300


def test_7000_new_nvidia_aaa_build_spends_on_gpu_not_board_or_memory() -> None:
    template = next(
        template
        for template in generated_templates()
        if template.id == "base-7000-aaa-new"
    )
    parts = {part.role: part for part in template.details.parts}

    assert parts["cpu"].component_id == "r5-9600x"
    assert parts["motherboard"].component_id == "asus-prime-b650m-k"
    assert parts["gpu"].component_id == "rtx-5060-ti"
    assert parts["ram"].component_id == "base-ddr5-16gb-6000-c32"
    assert parts["storage"].component_id == "base-ssd-512gb-tlc"
    assert parts["psu"].component_id == "base-psu-650w-gold"
    assert parts["psu"].reference_price == 200
    assert template.estimated_total == 7_150


def test_7000_mixed_nvidia_aaa_build_prioritizes_5060ti() -> None:
    template = next(
        template
        for template in generated_templates()
        if template.id == "base-7000-aaa-mixed"
    )
    parts = {part.role: part for part in template.details.parts}

    assert parts["cpu"].component_id == "r5-9600x"
    assert parts["motherboard"].component_id == "asus-b850m-awy"
    assert parts["gpu"].component_id == "rtx-5060-ti"
    assert template.estimated_total == 7_199


def test_5500_mixed_nvidia_aaa_build_reaches_5060() -> None:
    template = next(
        template
        for template in generated_templates()
        if template.id == "base-5500-aaa-mixed"
    )
    parts = {part.role: part for part in template.details.parts}

    assert parts["gpu"].component_id == "rtx-5060"
    assert parts["gpu"].reference_price == 2_300
    assert template.estimated_total == 5_700


def test_6000_new_fps_build_moves_c28_saving_to_5060() -> None:
    template = next(
        template
        for template in generated_templates()
        if template.id == "base-6000-fps-new"
    )
    parts = {part.role: part for part in template.details.parts}

    assert parts["cpu"].component_id == "r5-9600x"
    assert parts["cpu"].reference_price == 1_050
    assert parts["ram"].component_id == "base-ddr5-16gb-6000-c36"
    assert parts["gpu"].component_id == "rtx-5060"
    assert template.estimated_total == 6_250


def test_6000_new_nvidia_aaa_build_reaches_5060() -> None:
    template = next(
        template
        for template in generated_templates()
        if template.id == "base-6000-aaa-new"
    )
    parts = {part.role: part for part in template.details.parts}

    assert parts["cpu"].component_id == "r5-7500f"
    assert parts["ram"].component_id == "base-ddr5-16gb-6000-c36"
    assert parts["gpu"].component_id == "rtx-5060-ti"
    assert parts["gpu"].reference_price == 2_800
    assert template.estimated_total == 6_300


def test_6000_new_balanced_build_matches_fps_base() -> None:
    template = next(
        template
        for template in generated_templates()
        if template.id == "base-6000-balanced-new"
    )
    parts = {part.role: part for part in template.details.parts}

    assert parts["cpu"].component_id == "r5-9600x"
    assert parts["ram"].component_id == "base-ddr5-16gb-6000-c36"
    assert parts["gpu"].component_id == "rtx-5060"
    assert template.estimated_total == 6_250


def test_6000_used_and_mixed_builds_keep_the_strongest_fitting_pair() -> None:
    expected = {
        "base-6000-fps-used": ("r7-7800x3d", "rtx-4060-ti", 6_180),
        "base-6000-fps-mixed": ("r5-9600x", "rtx-5060", 6_100),
        "base-6000-aaa-used": ("r5-9600x", "rtx-5060-ti", 6_250),
        "base-6000-aaa-used-amd": ("r5-9600x", "rx-9070-gre", 6_250),
        "base-6000-aaa-mixed": ("r5-7500f", "rtx-5060-ti", 6_200),
        "base-6000-aaa-mixed-amd": ("r5-7500f", "rx-7700-xt", 6_000),
        "base-6000-balanced-used": ("r5-9600x", "rtx-5060-ti", 6_250),
        "base-6000-balanced-used-amd": ("r5-9600x", "rx-9070-gre", 6_250),
        "base-6000-balanced-mixed": ("r5-7500f", "rtx-5060-ti", 6_200),
        "base-6000-balanced-mixed-amd": ("r5-7500f", "rx-7700-xt", 6_000),
    }
    templates = {template.id: template for template in generated_templates()}

    for template_id, (cpu_id, gpu_id, total) in expected.items():
        template = templates[template_id]
        parts = {part.role: part for part in template.details.parts}
        assert parts["cpu"].component_id == cpu_id
        assert parts["gpu"].component_id == gpu_id
        assert template.estimated_total == total


def test_6500_mixed_fps_build_spends_200_more_on_5060() -> None:
    template = next(
        template
        for template in generated_templates()
        if template.id == "base-6500-fps-mixed"
    )
    parts = {part.role: part for part in template.details.parts}

    assert parts["cpu"].component_id == "r7-7800x3d"
    assert parts["gpu"].component_id == "rtx-5060"
    assert parts["gpu"].reference_price == 2_300
    assert template.estimated_total == 6_830


def test_4070_ti_is_not_in_the_price_whitelist() -> None:
    _, _, gpus, _ = low_budget_catalog._load_catalog()
    assert "rtx-4070-ti" not in {gpu.component_id for gpu in gpus}


def test_value_am5_board_and_650w_psu_use_user_prices() -> None:
    _, motherboards, _, support_parts = low_budget_catalog._load_catalog()
    boards = {part.component_id: part for part in motherboards}

    assert boards["asus-prime-b650m-k"].new_price == 700
    assert boards["asus-prime-b650m-k"].used_price is None
    assert support_parts["base-psu-650w-gold"].new_price == 200


def test_rtx_4060_new_is_allowed_and_rtx_4060_ti_new_is_forbidden() -> None:
    _, _, gpus, _ = low_budget_catalog._load_catalog()
    by_id = {gpu.component_id: gpu for gpu in gpus}

    assert by_id["rtx-4060"].new_price == 2_100
    assert low_budget_catalog._condition_is_allowed(by_id["rtx-4060"], "new")
    assert by_id["rtx-4060-ti"].new_price is None
    assert low_budget_catalog._condition_is_allowed(by_id["rtx-4060-ti"], "used")


def test_selection_reports_over_budget_separately_from_no_candidate() -> None:
    cpus, motherboards, gpus, support_parts = low_budget_catalog._load_catalog()

    over_budget = low_budget_catalog._select_candidate(
        0,
        "fps",
        "used",
        cpus,
        motherboards,
        gpus,
        support_parts,
    )
    no_candidate = low_budget_catalog._select_candidate(
        3_000,
        "fps",
        "used",
        [],
        [],
        [],
        support_parts,
    )

    assert over_budget.candidate is None
    assert over_budget.skip_reason == "over_budget"
    assert no_candidate.candidate is None
    assert no_candidate.skip_reason == "no_feasible_candidate"


def test_reference_export_preserves_source_condition_prices(tmp_path) -> None:
    report = generated_report()
    templates = list(report.templates)
    paths = write_low_budget_artifacts(
        tmp_path,
        templates,
        source_parts=report.source_parts,
    )
    rows = _price_rows(paths.reference_prices_csv)
    referenced_ids = {
        part.component_id
        for template in report.templates
        for part in template.details.parts
    }
    source_by_id = {
        part.component_id: part
        for part in report.source_parts
        if part.component_id in referenced_ids
    }

    for component_id, row in rows.items():
        source = source_by_id[component_id]
        used_price = source.used_price
        new_price = source.new_price
        assert row["normal_price_min"] == (str(used_price) if used_price else "")
        assert row["normal_price_max"] == (str(new_price) if new_price else "")
        assert row["reference_price"] in {
            str(value) for value in (used_price, new_price) if value
        }


def test_unreferenced_pending_psu_condition_is_excluded_from_low_budget_artifacts(
    tmp_path,
) -> None:
    report = generated_report()
    templates = list(report.templates)
    template_pairs = {
        (part.component_id, part.condition)
        for template in templates
        for part in template.details.parts
    }
    assert PENDING_REVIEW_CONDITION_PAIRS.isdisjoint(template_pairs)

    paths = write_low_budget_artifacts(
        tmp_path,
        templates,
        source_parts=report.source_parts,
    )
    assert PENDING_REVIEW_CONDITION_PAIRS.isdisjoint(
        _exported_condition_pairs(paths.reference_prices_csv)
    )


def test_reference_export_uses_the_generated_snapshot_after_source_mutation(
    tmp_path,
    monkeypatch,
) -> None:
    report = generated_report()
    templates = list(report.templates)
    mutated_cpu_path = tmp_path / CPU_PRICE_PATH.name
    original = CPU_PRICE_PATH.read_text(encoding="utf-8")
    mutated = original.replace(
        "r5-5600x,R5 5600X,720,820",
        "r5-5600x,R5 5600X,1,2",
    )
    assert mutated != original
    mutated_cpu_path.write_text(mutated, encoding="utf-8")
    monkeypatch.setattr(low_budget_catalog, "CPU_PRICE_PATH", mutated_cpu_path)

    paths = write_low_budget_artifacts(
        tmp_path / "artifacts",
        templates,
        source_parts=report.source_parts,
    )
    row = _price_rows(paths.reference_prices_csv)["r5-5600x"]
    observed = {
        part.condition: part.reference_price
        for template in templates
        for part in template.details.parts
        if part.component_id == "r5-5600x"
    }

    assert row["normal_price_min"] == str(observed["used"])
    assert row["normal_price_max"] == str(observed["new"])


def test_empty_and_partial_artifacts_report_actual_completion(tmp_path) -> None:
    full_templates = generated_templates()
    cases = (
        ("empty", [], [], 0, 0),
        ("partial", [full_templates[0]], [], 1, 1),
    )
    for name, templates, completed_tiers, completed_pairs, visible_tiers in cases:
        paths = write_low_budget_artifacts(tmp_path / name, templates)
        audit = json.loads(paths.audit_json.read_text(encoding="utf-8"))
        markdown = paths.review_markdown.read_text(encoding="utf-8")

        assert audit["completed_tiers"] == completed_tiers
        assert audit["completed_tier_direction_count"] == completed_pairs
        assert audit["completed_template_count"] == len(templates)
        assert {item["reason"] for item in audit["skipped_combinations"]} == {
            "missing_evidence"
        }
        assert audit["missing_data"] == audit["skipped_combinations"]
        assert audit["failed_templates"] == []
        assert f"{len(completed_tiers)}/9个价位" in markdown
        assert (
            sum(line.startswith("## ") for line in markdown.splitlines())
            == visible_tiers
        )


def test_failed_template_audit_is_derived_from_skip_evidence(tmp_path) -> None:
    failed = low_budget_catalog.SkippedCombination(
        target_budget=3_000,
        direction="fps",
        purchase_mode="new",
        reason="generation_error",
    )
    paths = write_low_budget_artifacts(
        tmp_path,
        [],
        skipped_combinations=[failed],
    )
    audit = json.loads(paths.audit_json.read_text(encoding="utf-8"))

    assert audit["failed_templates"] == [failed.as_dict()]
    assert failed.as_dict() not in audit["missing_data"]


def test_known_impossible_modes_are_absent_and_audited_as_over_budget(
    tmp_path,
) -> None:
    report = generated_report()
    templates = list(report.templates)
    generated_keys = {
        (
            template.details.target_budget,
            template.details.direction,
            template.details.purchase_mode,
        )
        for template in templates
    }
    assert KNOWN_IMPOSSIBLE_COMBINATIONS.isdisjoint(generated_keys)

    paths = write_low_budget_artifacts(
        tmp_path,
        templates,
        skipped_combinations=report.skipped_combinations,
        source_parts=report.source_parts,
    )
    audit = json.loads(paths.audit_json.read_text(encoding="utf-8"))
    skip_reasons = {
        (
            item["target_budget"],
            item["direction"],
            item["purchase_mode"],
            item.get("gpu_vendor"),
        ): item["reason"]
        for item in audit["skipped_combinations"]
    }
    expected_skips = {(*key, None) for key in KNOWN_IMPOSSIBLE_COMBINATIONS}

    assert audit["completed_template_count"] == len(templates)
    assert audit["completed_tiers"] == BUDGET_TIERS
    assert audit["completed_tier_direction_count"] == 27
    assert len(audit["skipped_combinations"]) == len(expected_skips)
    assert {
        key for key, reason in skip_reasons.items() if reason == "over_budget"
    } == expected_skips
    assert audit["missing_data"] == []
    assert audit["failed_templates"] == []


def test_high_then_low_price_import_keeps_all_275_templates_valid() -> None:
    engine = create_engine("sqlite+pysqlite:///:memory:")
    Base.metadata.create_all(engine)
    components = [
        *read_catalog_components(SWIFT_CATALOG_PATH),
        *read_catalog_components(SUPPORT_PART_PATH),
    ]
    high_prices = read_approved_price_rows(
        HIGH_PRICE_PATH,
        approved_at="2026-07-12",
    )
    low_prices = read_approved_price_rows(
        PRICE_PATH,
        approved_at="2026-07-12",
    )
    high_templates = read_build_template_inputs(HIGH_TEMPLATE_PATH)
    low_templates = read_build_template_inputs(TEMPLATE_PATH)
    recommendation_ids = sorted(
        {
            component_id
            for template in [*high_templates, *low_templates]
            for component_id in template.components.values()
        }
    )

    with Session(engine) as session:
        seed_hardware_components(session, components)
        update_recommended_components(session, recommendation_ids)
        seed_component_prices(session, high_prices)
        seed_component_prices(session, low_prices)
        imported = upsert_build_templates(
            session,
            [*high_templates, *low_templates],
        )
        stored = session.scalar(select(func.count()).select_from(BuildTemplate))

    assert len(high_templates) == 179
    assert len(low_templates) == 96
    assert imported == 275
    assert stored == 275


def test_writes_deterministic_review_and_import_artifacts(tmp_path) -> None:
    report = generated_report()
    templates = list(report.templates)
    markdown = render_low_budget_markdown(
        templates,
        report.skipped_combinations,
    )
    paths = write_low_budget_artifacts(
        tmp_path,
        templates,
        skipped_combinations=report.skipped_combinations,
        source_parts=report.source_parts,
    )

    lines = markdown.splitlines()
    assert sum(line.startswith("## ") for line in lines) == len(BUDGET_TIERS)
    assert sum(line.startswith("### ") for line in lines) == len(templates)
    assert "**优点：**" not in markdown
    assert "**缺点：**" not in markdown
    assert "**风险：**" not in markdown

    payload = json.loads(paths.templates_json.read_text(encoding="utf-8"))
    assert len(payload) == len(templates)
    assert payload[0]["details"]["target_budget"] == 3_000
    assert all(
        {"advantages", "disadvantages", "risks"}.isdisjoint(item["details"])
        for item in payload
    )
    committed_payload = json.loads(TEMPLATE_PATH.read_text(encoding="utf-8"))
    assert all(
        {"advantages", "disadvantages", "risks"}.isdisjoint(item["details"])
        for item in committed_payload
    )
    assert paths.review_markdown.read_text(encoding="utf-8") == markdown
    assert paths.templates_json.read_bytes() == TEMPLATE_PATH.read_bytes()
    assert paths.reference_prices_csv.read_bytes() == PRICE_PATH.read_bytes()
    assert paths.recommendation_ids.read_bytes() == RECOMMENDATION_PATH.read_bytes()
    assert paths.audit_json.read_bytes() == AUDIT_PATH.read_bytes()
    assert markdown.encode() == MARKDOWN_PATH.read_bytes()


def _source_prices():
    prices = {}
    csv_sources = (
        (CPU_PRICE_PATH, "used_price", "new_tray_price"),
        (GPU_PRICE_PATH, "used_price", "new_price"),
        (MOTHERBOARD_PRICE_PATH, "used_price", "new_price"),
    )
    for path, used_column, new_column in csv_sources:
        with path.open(encoding="utf-8", newline="") as handle:
            for row in csv.DictReader(handle):
                if row.get(used_column):
                    prices[(row["target_id"], "used")] = (
                        int(row[used_column]),
                        path.name,
                    )
                if row.get(new_column):
                    prices[(row["target_id"], "new")] = (
                        int(row[new_column]),
                        path.name,
                    )

    for item in json.loads(SUPPORT_PART_PATH.read_text(encoding="utf-8")):
        if item.get("used_price"):
            prices[(item["id"], "used")] = (
                item["used_price"],
                item["used_source"],
            )
        if item.get("new_price"):
            prices[(item["id"], "new")] = (
                item["new_price"],
                item["new_source"],
            )
    return prices


def _ranking_candidate(cpu_performance: int, gpu_performance: int):
    gpu = BuildTemplatePart(
        role="gpu",
        component_id="rx-ranking-test",
        name="ranking test GPU",
        condition="used",
        reference_price=1,
        price_source="test",
        price_date="2026-07-12",
        specs={},
    )
    return low_budget_catalog.Candidate(
        parts=(gpu,),
        total=1,
        cpu_performance=cpu_performance,
        gpu_performance=gpu_performance,
    )


def _price_rows(path: Path):
    with path.open(encoding="utf-8", newline="") as handle:
        return {row["target_id"]: row for row in csv.DictReader(handle)}


def _exported_condition_pairs(path: Path):
    pairs = set()
    for component_id, row in _price_rows(path).items():
        if row["normal_price_min"]:
            pairs.add((component_id, "used"))
        if row["normal_price_max"]:
            pairs.add((component_id, "new"))
    return pairs
