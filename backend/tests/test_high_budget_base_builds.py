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


EXPECTED_COMBINATIONS = {
    (direction, purchase_mode)
    for direction in ("fps", "aaa", "balanced")
    for purchase_mode in ("new", "used", "mixed")
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


def test_generates_26_budget_tiers_and_234_unique_templates() -> None:
    templates = generated_templates()

    assert BUDGET_TIERS == list(range(7_500, 20_001, 500))
    assert len(templates) == 234
    assert len({template.id for template in templates}) == 234
    assert Counter(template.details.target_budget for template in templates) == {
        budget: 9 for budget in BUDGET_TIERS
    }

    for budget in BUDGET_TIERS:
        combinations = {
            (template.details.direction, template.details.purchase_mode)
            for template in templates
            if template.details.target_budget == budget
        }
        assert combinations == EXPECTED_COMBINATIONS


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
        assert template.estimated_total <= template.details.target_budget + 200


def test_purchase_conditions_follow_the_three_exact_modes() -> None:
    for template in generated_templates():
        actual = {
            part.role: part.condition for part in template.details.parts
        }
        assert actual == EXPECTED_CONDITIONS[template.details.purchase_mode]


def test_all_builds_use_whitelisted_amd_am5_parts_and_fixed_baselines() -> None:
    for template in generated_templates():
        parts = {part.role: part for part in template.details.parts}

        assert parts["cpu"].component_id in CPU_PERFORMANCE
        assert parts["cpu"].component_id.startswith(("r5-", "r7-", "r9-"))
        assert parts["cpu"].component_id != "r7-9700x"
        assert parts["motherboard"].specs["socket"] == "AM5"
        assert parts["ram"].component_id == "base-ddr5-16gb-6000-c30"
        assert parts["ram"].specs == {
            "type": "DDR5",
            "capacity_gb": 16,
            "speed_mhz": 6000,
            "cas_latency": 30,
        }
        assert parts["storage"].component_id == "base-ssd-512gb-tlc"
        assert parts["storage"].specs["capacity_gb"] == 512
        assert parts["storage"].specs["flash_type"] == "TLC"
        assert parts["case"].component_id == "base-case-mid-tower"
        if parts["gpu"].condition == "new":
            assert not parts["gpu"].component_id.startswith("rtx-40")

        if "x3d" in parts["cpu"].component_id:
            assert parts["cooler"].component_id == "base-cooler-dual-tower-6-heatpipe"
        else:
            assert parts["cooler"].component_id == "base-cooler-6-heatpipe"


def test_psu_meets_the_project_headroom_formula() -> None:
    for template in generated_templates():
        parts = {part.role: part for part in template.details.parts}
        required_watt = minimum_psu_watt(
            parts["cpu"].component_id,
            parts["gpu"].component_id,
        )
        assert parts["psu"].specs["watt"] >= required_watt


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


def test_direction_allocations_are_consistent_with_fps_and_aaa_priorities() -> None:
    by_key = {
        (
            template.details.target_budget,
            template.details.purchase_mode,
            template.details.direction,
        ): template
        for template in generated_templates()
    }

    for budget in BUDGET_TIERS:
        for purchase_mode in ("new", "used", "mixed"):
            fps = by_key[(budget, purchase_mode, "fps")]
            aaa = by_key[(budget, purchase_mode, "aaa")]
            fps_parts = {part.role: part for part in fps.details.parts}
            aaa_parts = {part.role: part for part in aaa.details.parts}

            assert CPU_PERFORMANCE[fps_parts["cpu"].component_id] >= CPU_PERFORMANCE[
                aaa_parts["cpu"].component_id
            ]
            assert GPU_PERFORMANCE[aaa_parts["gpu"].component_id] >= GPU_PERFORMANCE[
                fps_parts["gpu"].component_id
            ]


def test_explanations_and_used_risks_are_present() -> None:
    for template in generated_templates():
        details = template.details
        assert details.advantages
        assert details.disadvantages
        assert details.risks
        assert details.suitable_user
        assert details.price_date == "2026-07-12"
        if details.purchase_mode == "used":
            joined_risks = " ".join(details.risks)
            assert "电源" in joined_risks
            assert "SSD" in joined_risks
            assert "显卡" in joined_risks


def test_writes_review_markdown_and_backend_json(tmp_path) -> None:
    templates = generated_templates()
    markdown = render_high_budget_markdown(templates)

    lines = markdown.splitlines()
    assert sum(line.startswith("## ") for line in lines) == 26
    assert sum(line.startswith("### ") for line in lines) == 234

    paths = write_high_budget_artifacts(tmp_path, templates)
    payload = json.loads(paths.templates_json.read_text(encoding="utf-8"))

    assert len(payload) == 234
    assert payload[0]["details"]["target_budget"] == 7_500
    assert paths.review_markdown.read_text(encoding="utf-8") == markdown
    assert paths.reference_prices_csv.exists()
    assert paths.recommendation_ids.exists()
    audit = json.loads(paths.audit_json.read_text(encoding="utf-8"))
    assert audit["completed_template_count"] == 234
    assert audit["completed_tiers"] == BUDGET_TIERS
    assert audit["pending_review"][0]["component_id"] == "base-psu-850w-gold"
    assert audit["missing_data"] == []
    assert audit["failed_templates"] == []


def test_empty_and_partial_artifacts_report_actual_completion(tmp_path) -> None:
    cases = [[], generated_templates()[:1]]

    for index, templates in enumerate(cases):
        paths = write_high_budget_artifacts(tmp_path / str(index), templates)
        payload = json.loads(paths.templates_json.read_text(encoding="utf-8"))
        audit = json.loads(paths.audit_json.read_text(encoding="utf-8"))
        markdown = paths.review_markdown.read_text(encoding="utf-8")
        expected_missing = 234 - len(templates)

        assert len(payload) == len(templates)
        assert audit["completed_tiers"] == []
        assert audit["completed_template_count"] == len(templates)
        assert len(audit["missing_data"]) == expected_missing
        assert {item["reason"] for item in audit["missing_data"]} == {
            "not_provided"
        }
        assert audit["failed_templates"] == []
        assert f"{len(templates)}/234套配置生成" in markdown
        assert f"缺失配置{expected_missing}套" in markdown
        assert "26/26个价位完成" not in markdown


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

    assert len(report.templates) == 233
    assert audit["completed_tiers"] == BUDGET_TIERS[1:]
    assert audit["completed_template_count"] == 233
    assert audit["missing_data"] == []
    assert audit["failed_templates"] == [
        {
            "target_budget": 7_500,
            "direction": "fps",
            "purchase_mode": "new",
            "error": "fixture selection failure",
        }
    ]
    assert "233/234套配置生成" in markdown
    assert "缺失配置0套" in markdown
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
