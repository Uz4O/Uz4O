from pathlib import Path

from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker
from sqlalchemy.pool import StaticPool

from app.builds.repository import upsert_build_templates
from app.builds.templates import read_build_template_inputs
from app.catalog.prices import read_approved_price_rows
from app.catalog.repository import (
    seed_component_prices,
    seed_hardware_components,
    update_recommended_components,
)
from app.catalog.seed import read_catalog_components
from app.core.config import Settings
from app.db import Base, get_session
from app.main import create_app


BACKEND_ROOT = Path(__file__).resolve().parents[1]
PROJECT_ROOT = BACKEND_ROOT.parent
DATA_DIR = BACKEND_ROOT / "data"
SWIFT_CATALOG_PATH = PROJECT_ROOT / "May" / "May" / "Models" / "HardwareCatalog.swift"
SUPPORT_PATH = DATA_DIR / "base-build-support-components-2026-07-12.json"
TEMPLATE_PATHS = [
    DATA_DIR / "low-budget-base-build-templates.json",
    DATA_DIR / "high-budget-base-build-templates.json",
]
PRICE_PATHS = [
    DATA_DIR / "low-budget-base-reference-prices.csv",
    DATA_DIR / "high-budget-base-reference-prices.csv",
]
RECOMMENDATION_PATHS = [
    DATA_DIR / "low-budget-base-recommendation-ids.txt",
    DATA_DIR / "high-budget-base-recommendation-ids.txt",
]


def test_upgrade_matrix_uses_real_reviewed_template_artifacts() -> None:
    engine = create_engine(
        "sqlite+pysqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(engine)
    session_factory = sessionmaker(bind=engine)
    templates = [
        template
        for path in TEMPLATE_PATHS
        for template in read_build_template_inputs(path)
    ]
    recommendation_ids = sorted(
        {
            component_id
            for path in RECOMMENDATION_PATHS
            for component_id in path.read_text(encoding="utf-8").splitlines()
            if component_id
        }
    )

    with Session(engine) as session:
        seed_hardware_components(
            session,
            [
                *read_catalog_components(SWIFT_CATALOG_PATH),
                *read_catalog_components(SUPPORT_PATH),
            ],
        )
        seed_component_prices(
            session,
            [
                row
                for path in PRICE_PATHS
                for row in read_approved_price_rows(path, approved_at="2026-08-24")
            ],
        )
        recommendation_result = update_recommended_components(
            session,
            recommendation_ids,
        )
        imported_count = upsert_build_templates(session, templates)

    assert recommendation_result.missing_ids == []
    assert imported_count == len(templates)

    app = create_app(Settings(_env_file=None, postgres_url=None, redis_url=None))

    def override_session():
        with session_factory() as session:
            yield session

    app.dependency_overrides[get_session] = override_session
    client = TestClient(app)
    template_by_id = {template.id: template for template in templates}
    base = template_by_id["base-5000-balanced-new-amd"]
    base_parts = {part.role: part.component_id for part in base.details.parts}
    current = {
        role: base_parts[role]
        for role in ("cpu", "gpu", "motherboard", "ram", "psu")
    }

    sufficient = _request_plan(client, current, ["cs2"], "2k", 60, 12_000)
    fps = _request_plan(client, current, ["cs2"], "2k", 240, 12_000)
    aaa = _request_plan(
        client,
        current,
        ["cyberpunk-2077"],
        "4k",
        90,
        12_000,
    )
    balanced = _request_plan(
        client,
        current,
        ["cs2", "cyberpunk-2077"],
        "2k",
        144,
        12_000,
    )
    closest = _request_plan(
        client,
        current,
        ["cyberpunk-2077"],
        "4k",
        180,
        3_000,
    )
    no_plan = _request_plan(client, current, ["cs2"], "2k", 500, 500)

    assert sufficient["status"] == "already_sufficient"
    assert sufficient["steps"] == []
    assert sufficient["total_estimated_price"] == 0

    assert fps["status"] == "ready"
    assert fps["direction"] == "fps"
    assert {step["bundle_id"] for step in fps["steps"]} == {
        "platform",
        "graphics",
    }

    assert aaa["status"] == "ready"
    assert aaa["direction"] == "aaa"
    assert aaa["target_met"] is True

    assert balanced["status"] == "ready"
    assert balanced["direction"] == "balanced"
    assert balanced["target_met"] is False
    assert len(balanced["game_results"]) == 2

    assert closest["status"] == "no_plan"
    assert closest["steps"] == []

    assert no_plan["status"] == "no_plan"
    assert no_plan["steps"] == []

    for plan in (fps, aaa, balanced):
        anchor = template_by_id[plan["anchor_template_id"]]
        anchor_parts = {part.role: part.component_id for part in anchor.details.parts}
        assert all(
            step["to_component_id"] == anchor_parts[step["role"]]
            for step in plan["steps"]
        )


def _request_plan(
    client: TestClient,
    current: dict[str, str],
    games: list[str],
    resolution: str,
    target_fps: int,
    budget: int,
) -> dict:
    response = client.post(
        "/v1/upgrade/plan",
        json={
            "budget": budget,
            "need": "游戏帧率和画质",
            "games": games,
            "resolution": resolution,
            "target_fps": target_fps,
            "current": current,
        },
    )
    assert response.status_code == 200
    return response.json()
