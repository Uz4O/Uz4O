import json
from collections import Counter
from pathlib import Path

import pytest
from sqlalchemy import create_engine, func, select
from sqlalchemy.orm import Session

from app.builds.high_budget_catalog import (
    generate_high_budget_report,
    generate_high_budget_templates,
    render_high_budget_markdown,
    write_high_budget_artifacts,
)
from app.builds.low_budget_catalog import generate_low_budget_templates
from app.builds.models import BuildTemplate
from app.builds.repository import upsert_build_templates
from app.builds.service import BuildRequest, match_build_template
from app.builds.templates import read_build_template_inputs
from app.catalog.models import HardwareComponent
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
TEMPLATE_PATH = DATA_DIR / "high-budget-base-build-templates.json"
PRICE_PATH = DATA_DIR / "high-budget-base-reference-prices.csv"
RECOMMENDATION_PATH = DATA_DIR / "high-budget-base-recommendation-ids.txt"
AUDIT_PATH = DATA_DIR / "high-budget-base-audit.json"
SUPPORT_PATH = DATA_DIR / "base-build-support-components-2026-07-12.json"
MARKDOWN_PATH = PROJECT_ROOT / "docs" / "7500-20000-yuan-base-builds.md"
SWIFT_CATALOG_PATH = PROJECT_ROOT / "May" / "May" / "Models" / "HardwareCatalog.swift"
LOW_TEMPLATE_PATH = DATA_DIR / "low-budget-base-build-templates.json"
LOW_PRICE_PATH = DATA_DIR / "low-budget-base-reference-prices.csv"
LOW_RECOMMENDATION_PATH = DATA_DIR / "low-budget-base-recommendation-ids.txt"


def test_committed_artifacts_match_the_deterministic_generator(tmp_path) -> None:
    report = generate_high_budget_report()
    generated = list(report.templates)
    committed = read_build_template_inputs(TEMPLATE_PATH)
    committed_payload = json.loads(TEMPLATE_PATH.read_text(encoding="utf-8"))
    generated_paths = write_high_budget_artifacts(tmp_path, report=report)

    assert len(committed_payload) == len(generated)
    assert all(
        {"advantages", "disadvantages", "risks"}.isdisjoint(item["details"])
        for item in committed_payload
    )
    assert [item.model_dump(mode="json") for item in committed] == [
        item.model_dump(mode="json") for item in generated
    ]
    assert MARKDOWN_PATH.read_text(encoding="utf-8") == render_high_budget_markdown(
        generated,
        report.failures,
    )
    assert generated_paths.templates_json.read_bytes() == TEMPLATE_PATH.read_bytes()
    assert generated_paths.reference_prices_csv.read_bytes() == PRICE_PATH.read_bytes()
    assert generated_paths.recommendation_ids.read_bytes() == RECOMMENDATION_PATH.read_bytes()
    assert generated_paths.audit_json.read_bytes() == AUDIT_PATH.read_bytes()


def test_imports_all_generated_templates_with_the_current_hardware_catalog() -> None:
    engine = create_engine("sqlite+pysqlite:///:memory:")
    Base.metadata.create_all(engine)
    components = [
        *read_catalog_components(SWIFT_CATALOG_PATH),
        *read_catalog_components(SUPPORT_PATH),
    ]
    prices = read_approved_price_rows(PRICE_PATH, approved_at="2026-07-12")
    recommendation_ids = [
        line.strip()
        for line in RECOMMENDATION_PATH.read_text(encoding="utf-8").splitlines()
        if line.strip()
    ]
    templates = read_build_template_inputs(TEMPLATE_PATH)

    with Session(engine) as session:
        seed_hardware_components(session, components)
        seed_component_prices(session, prices)
        recommendation_result = update_recommended_components(
            session,
            recommendation_ids,
        )
        imported_count = upsert_build_templates(session, templates)
        reimported_count = upsert_build_templates(session, templates)
        stored_count = session.scalar(select(func.count()).select_from(BuildTemplate))
        stored_templates = list(session.scalars(select(BuildTemplate)))
        first = session.get(BuildTemplate, "base-7500-fps-new")
        last = session.get(BuildTemplate, "base-30000-fps-new")
        direction_tokens = {"fps": "FPS", "aaa": "3A", "balanced": "均衡"}
        purchase_tokens = {
            "new": "全新优先",
            "used": "二手到底",
            "mixed": "部分配件二手",
        }
        matching_cases = [
            (
                BuildRequest(
                    budget=template.details.target_budget,
                    use_case="游戏",
                    preferences=[direction_tokens[template.details.direction]],
                    purchase_preference=purchase_tokens[
                        template.details.purchase_mode
                    ],
                    gpu_preference=template.details.gpu_vendor,
                ),
                template.id,
            )
            for template in templates
        ]
        matched_ids = [
            match_build_template(request, stored_templates).id
            for request, _ in matching_cases
        ]
        reversed_matched_ids = [
            match_build_template(request, list(reversed(stored_templates))).id
            for request, _ in matching_cases
        ]
        expected_matched_ids = [expected for _, expected in matching_cases]
        default_request = BuildRequest(budget=10_000, use_case="游戏")
        default_match = match_build_template(default_request, stored_templates).id
        reversed_default_match = match_build_template(
            default_request,
            list(reversed(stored_templates)),
        ).id

    assert recommendation_result.missing_ids == []
    assert recommendation_result.updated_count == len(recommendation_ids)
    assert imported_count == len(templates)
    assert reimported_count == len(templates)
    assert stored_count == len(templates)
    assert first.details["target_budget"] == 7_500
    assert last.details["target_budget"] == 30_000
    assert matched_ids == expected_matched_ids
    assert reversed_matched_ids == expected_matched_ids
    assert default_match == "base-10000-balanced-new-amd"
    assert reversed_default_match == "base-10000-balanced-new-amd"


def test_combined_catalog_artifacts_are_complete_and_conflict_free() -> None:
    low_templates = read_build_template_inputs(LOW_TEMPLATE_PATH)
    high_templates = read_build_template_inputs(TEMPLATE_PATH)
    combined_templates = [*low_templates, *high_templates]
    template_ids = [template.id for template in combined_templates]
    referenced_ids = {
        component_id
        for template in combined_templates
        for component_id in template.components.values()
    }
    recommendation_ids = {
        *_read_component_ids(LOW_RECOMMENDATION_PATH),
        *_read_component_ids(RECOMMENDATION_PATH),
    }
    low_prices = {
        row.component_id: row
        for row in read_approved_price_rows(LOW_PRICE_PATH, approved_at="2026-07-12")
    }
    high_prices = {
        row.component_id: row
        for row in read_approved_price_rows(PRICE_PATH, approved_at="2026-07-12")
    }

    assert low_templates
    assert high_templates
    assert len(template_ids) == len(set(template_ids))
    target_budgets = {template.details.target_budget for template in combined_templates}
    assert set(range(3_500, 10_001, 500)) <= target_budgets
    assert 30_000 in target_budgets
    assert 25_000 in target_budgets
    assert max(
        Counter(template.details.target_budget for template in high_templates).values()
    ) == 15
    assert referenced_ids <= recommendation_ids
    assert all(
        template.details is not None and len(template.details.parts) == 8
        for template in combined_templates
    )

    for component_id in low_prices.keys() & high_prices.keys():
        low_price = low_prices[component_id]
        high_price = high_prices[component_id]
        assert (
            low_price.reference_price,
            low_price.price_range_low,
            low_price.price_range_high,
        ) == (
            high_price.reference_price,
            high_price.price_range_low,
            high_price.price_range_high,
        )


def test_all_generated_cpu_gpu_rule_specs_match_seeded_hardware_catalog() -> None:
    engine = create_engine("sqlite+pysqlite:///:memory:")
    Base.metadata.create_all(engine)
    components = [
        *read_catalog_components(SWIFT_CATALOG_PATH),
        *read_catalog_components(SUPPORT_PATH),
    ]
    templates = [
        *generate_low_budget_templates(),
        *generate_high_budget_templates(),
    ]

    with Session(engine) as session:
        seed_hardware_components(session, components)

        assert len(templates) == len(
            generate_low_budget_templates() + generate_high_budget_templates()
        )
        for template in templates:
            for part in template.details.parts:
                if part.role not in {"cpu", "gpu"}:
                    continue
                component = session.get(HardwareComponent, part.component_id)
                assert component is not None
                for field in ("perf_index", "tdp"):
                    assert part.specs.get(field) == component.specs.get(field), (
                        f"{template.id}: {part.component_id} {field} differs"
                    )


@pytest.mark.parametrize("catalog_order", [("low", "high"), ("high", "low")])
def test_catalog_import_order_keeps_all_generated_templates_valid(
    catalog_order: tuple[str, str],
) -> None:
    engine = create_engine("sqlite+pysqlite:///:memory:")
    Base.metadata.create_all(engine)
    components = [
        *read_catalog_components(SWIFT_CATALOG_PATH),
        *read_catalog_components(SUPPORT_PATH),
    ]
    catalogs = {
        "low": {
            "prices": read_approved_price_rows(
                LOW_PRICE_PATH,
                approved_at="2026-07-12",
            ),
            "recommendation_ids": _read_component_ids(LOW_RECOMMENDATION_PATH),
            "templates": read_build_template_inputs(LOW_TEMPLATE_PATH),
        },
        "high": {
            "prices": read_approved_price_rows(
                PRICE_PATH,
                approved_at="2026-07-12",
            ),
            "recommendation_ids": _read_component_ids(RECOMMENDATION_PATH),
            "templates": read_build_template_inputs(TEMPLATE_PATH),
        },
    }
    expected_templates = {
        template.id: template
        for catalog in catalogs.values()
        for template in catalog["templates"]
    }

    with Session(engine) as session:
        seed_hardware_components(session, components)
        imported_counts = []
        missing_recommendation_ids = []
        for catalog_name in catalog_order:
            catalog = catalogs[catalog_name]
            seed_component_prices(session, catalog["prices"])
            recommendation_result = update_recommended_components(
                session,
                catalog["recommendation_ids"],
            )
            missing_recommendation_ids.extend(recommendation_result.missing_ids)
            imported_counts.append(
                upsert_build_templates(session, catalog["templates"])
            )

        revalidated_count = upsert_build_templates(
            session,
            expected_templates.values(),
        )
        stored_templates = {
            template.id: template for template in session.scalars(select(BuildTemplate))
        }

    assert imported_counts == [
        len(catalogs[catalog_name]["templates"])
        for catalog_name in catalog_order
    ]
    assert missing_recommendation_ids == []
    assert revalidated_count == len(expected_templates)
    assert len(stored_templates) == len(expected_templates)
    assert {
        template_id: template.details
        for template_id, template in stored_templates.items()
    } == {
        template_id: template.details.model_dump(mode="json")
        for template_id, template in expected_templates.items()
    }


def _read_component_ids(path: Path) -> list[str]:
    return [
        line.strip()
        for line in path.read_text(encoding="utf-8").splitlines()
        if line.strip()
    ]
