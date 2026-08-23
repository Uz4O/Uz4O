from pathlib import Path

from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker
from sqlalchemy.pool import StaticPool

from app.builds.models import BuildTemplate
from app.builds.office_catalog import (
    BASE_SUPPORT_PATH,
    OFFICE_CPU_IDS,
    OFFICE_MOTHERBOARD_IDS,
    OFFICE_SUPPORT_PATH,
    SWIFT_CATALOG_PATH,
    generate_office_templates,
)
from app.builds.repository import upsert_build_templates
from app.builds.service import BuildRequest, rank_build_templates
from app.catalog.prices import read_approved_price_rows
from app.catalog.repository import (
    seed_component_prices,
    seed_hardware_components,
    update_recommended_components,
)
from app.catalog.seed import extract_catalog_components, read_catalog_components
from app.catalog.rule_specs import minimum_psu_watt_for_specs
from app.core.config import Settings
from app.db import Base, get_session
from app.main import create_app


DATA_DIR = Path(__file__).resolve().parents[1] / "data"
PRICE_PATH = DATA_DIR / "office-base-reference-prices.csv"
RECOMMENDATION_PATH = DATA_DIR / "office-base-recommendation-ids.txt"


def test_office_templates_follow_platform_capacity_and_workload_rules() -> None:
    templates = generate_office_templates()

    assert templates
    assert {template.budget_min for template in templates if "strongest" in template.id} == {
        3000,
        4000,
        5000,
    }
    assert all(template.use_cases == ["办公"] for template in templates)

    for template in templates:
        details = template.details
        assert details is not None
        parts = {part.role: part for part in details.parts}
        assert len(parts) == 8
        assert parts["ram"].specs["capacity_gb"] == 16
        assert parts["storage"].specs["capacity_gb"] == 512
        if template.budget_min <= 5_000:
            assert (
                parts["storage"].component_id
                == "base-ssd-fanxiang-s500-pro-512gb"
            )
        else:
            assert parts["storage"].component_id == "base-ssd-512gb-tlc"

        required_psu = minimum_psu_watt_for_specs(
            parts["cpu"].specs["tdp"],
            parts["gpu"].component_id,
            parts["gpu"].specs["tdp"],
        )
        assert parts["psu"].specs["watt"] >= required_psu
        if (
            parts["gpu"].specs["tdp"] >= 140
            and parts["gpu"].component_id != "rx-7650-gre"
        ):
            assert parts["psu"].specs["watt"] >= 650

        if template.budget_min <= 5000:
            assert "strongest" in template.id
            continue
        assert "耕升" not in parts["gpu"].name
        assert parts["cpu"].component_id in OFFICE_CPU_IDS
        assert parts["motherboard"].component_id in OFFICE_MOTHERBOARD_IDS
        assert not parts["gpu"].component_id.startswith("rx-")
        if "office-cuda" in template.tags:
            assert parts["gpu"].component_id.startswith("rtx-")
        if details.purchase_mode == "new":
            assert parts["ram"].component_id == "office-ddr5-16gb-7200-c36"
        else:
            assert parts["ram"].component_id == "base-ddr5-16gb-6000-c30"


def test_office_template_ranges_cover_every_supported_request_budget() -> None:
    templates = generate_office_templates()

    for budget in range(6000, 30_001, 1000):
        for profile in ("general", "media", "cuda"):
            for purchase_mode in ("new", "used", "mixed"):
                matching = [
                    template
                    for template in templates
                    if template.budget_min <= budget <= template.budget_max
                    and f"office-{profile}" in template.tags
                    and template.details
                    and template.details.purchase_mode == purchase_mode
                ]
                if (
                    budget in {6000, 7000}
                    and profile == "cuda"
                    and purchase_mode == "new"
                ):
                    assert matching == []
                else:
                    assert len(matching) == 1


def test_office_workload_tags_select_the_correct_base() -> None:
    rows = [
        BuildTemplate(
            id=template.id,
            title=template.title,
            budget_min=template.budget_min,
            budget_max=template.budget_max,
            use_cases=template.use_cases,
            tags=template.tags,
            components=template.components,
            estimated_total=template.estimated_total,
            explanation=template.explanation,
            details=template.details.model_dump(mode="json") if template.details else {},
            status="active",
        )
        for template in generate_office_templates()
    ]

    premiere = rank_build_templates(
        BuildRequest(
            budget=7000,
            use_case="办公",
            office_apps=["Premiere"],
            preferences=["均衡", "全新"],
        ),
        rows,
    )
    blender = rank_build_templates(
        BuildRequest(
            budget=7000,
            use_case="办公",
            office_apps=["Blender"],
            preferences=["均衡", "二手"],
        ),
        rows,
    )

    assert premiere[0].id == "office-7000-media-new"
    assert blender[0].id == "office-7000-cuda-used"


def test_office_default_capacity_request_does_not_call_ai_customization() -> None:
    request = BuildRequest(
        budget=7000,
        use_case="办公",
        office_apps=["Premiere"],
        memory_size="16GB",
        storage_size="512GB",
    )
    mixed_use = request.model_copy(update={"use_case": "游戏兼办公"})

    assert request.requires_customization is False
    assert mixed_use.requires_customization is True


def test_office_price_artifact_includes_expansion_storage() -> None:
    prices = {
        row.component_id: row.reference_price
        for row in read_approved_price_rows(PRICE_PATH, approved_at="2026-08-05")
    }

    assert prices["base-ssd-512gb-tlc"] == 699
    assert prices["base-ssd-1tb-tlc"] == 1_199
    assert prices["base-ssd-2tb-tlc"] == 2_398
    assert prices["base-ssd-fanxiang-s500-pro-512gb"] == 509
    assert prices["base-ssd-fanxiang-s790e-1tb"] == 968


def test_office_artifacts_import_and_public_option_flow() -> None:
    engine = create_engine(
        "sqlite+pysqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(engine)
    session_factory = sessionmaker(bind=engine)

    with Session(engine) as session:
        seed_hardware_components(session, extract_catalog_components(SWIFT_CATALOG_PATH))
        seed_hardware_components(session, read_catalog_components(BASE_SUPPORT_PATH))
        seed_hardware_components(session, read_catalog_components(OFFICE_SUPPORT_PATH))
        seed_component_prices(
            session,
            read_approved_price_rows(PRICE_PATH, approved_at="2026-07-20"),
        )
        recommendation_ids = [
            line
            for line in RECOMMENDATION_PATH.read_text(encoding="utf-8").splitlines()
            if line
        ]
        result = update_recommended_components(session, recommendation_ids)
        assert result.missing_ids == []
        templates = generate_office_templates()
        assert upsert_build_templates(session, templates) == len(templates)

    app = create_app(Settings(_env_file=None, postgres_url=None, redis_url=None))

    def override_session():
        with session_factory() as session:
            yield session

    app.dependency_overrides[get_session] = override_session
    client = TestClient(app)

    response = client.post(
        "/v1/build/options",
        json={
            "budget": 6000,
            "useCase": "办公",
            "officeApps": ["Office"],
            "direction": "balanced",
            "memorySize": "16GB",
            "storageSize": "512GB",
        },
    )

    assert response.status_code == 200
    body = response.json()
    assert len(body["options"]) == 3
    assert all(option["template_id"].startswith("office-") for option in body["options"])
    assert all(option["source"] == "template" for option in body["options"])

    incomplete = client.post(
        "/v1/build/options",
        json={
            "budget": 7000,
            "useCase": "办公",
            "officeApps": ["Blender"],
            "direction": "balanced",
        },
    )
    assert incomplete.status_code == 503
    assert "必须同时提供全新、二手和混合采购三套方案" in incomplete.json()[
        "detail"
    ]
