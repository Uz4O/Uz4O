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
    for budget in (3_000, 3_500, 4_000)
    for direction in DIRECTIONS
    for purchase_mode in ("new", "mixed")
}
PENDING_REVIEW_CONDITION_PAIRS = {("base-psu-850w-gold", "used")}


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
        )
        for template in templates
    }

    assert BUDGET_TIERS == list(range(3_000, 7_001, 500))
    assert len(templates) >= len(BUDGET_TIERS) * len(DIRECTIONS)
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
        assert template.id == (
            f"base-{details.target_budget}-{details.direction}-{details.purchase_mode}"
        )


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
        assert template.estimated_total <= details.target_budget + 200
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
        assert parts["psu"].specs["watt"] >= minimum_psu_watt(
            parts["cpu"].component_id,
            parts["gpu"].component_id,
        )
        if parts["gpu"].condition == "new":
            assert not parts["gpu"].component_id.startswith("rtx-40")

        if "x3d" in parts["cpu"].component_id or parts["cpu"].component_id == "i5-13600kf":
            assert parts["cooler"].component_id == (
                "base-cooler-dual-tower-6-heatpipe"
            )


def test_fps_and_aaa_allocations_follow_their_performance_priorities() -> None:
    by_key = {
        (
            template.details.target_budget,
            template.details.purchase_mode,
            template.details.direction,
        ): template
        for template in generated_templates()
    }
    compared = 0

    for budget in BUDGET_TIERS:
        for purchase_mode in PURCHASE_MODES:
            fps = by_key.get((budget, purchase_mode, "fps"))
            aaa = by_key.get((budget, purchase_mode, "aaa"))
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
        used_price = (
            None
            if (component_id, "used") in PENDING_REVIEW_CONDITION_PAIRS
            else source.used_price
        )
        new_price = (
            None
            if (component_id, "new") in PENDING_REVIEW_CONDITION_PAIRS
            else source.new_price
        )
        assert row["normal_price_min"] == (str(used_price) if used_price else "")
        assert row["normal_price_max"] == (str(new_price) if new_price else "")
        assert row["reference_price"] in {
            str(value) for value in (used_price, new_price) if value
        }


def test_pending_review_condition_is_excluded_from_templates_and_prices(
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
        ): item["reason"]
        for item in audit["skipped_combinations"]
    }

    assert audit["completed_template_count"] == len(templates)
    assert audit["completed_tiers"] == BUDGET_TIERS
    assert audit["completed_tier_direction_count"] == 27
    assert len(audit["skipped_combinations"]) == len(
        KNOWN_IMPOSSIBLE_COMBINATIONS
    )
    assert {
        key for key, reason in skip_reasons.items() if reason == "over_budget"
    } == KNOWN_IMPOSSIBLE_COMBINATIONS
    assert audit["missing_data"] == []
    assert audit["failed_templates"] == []


def test_high_then_low_price_import_keeps_all_297_templates_valid() -> None:
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

    assert len(high_templates) == 234
    assert len(low_templates) == 63
    assert imported == 297
    assert stored == 297


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
