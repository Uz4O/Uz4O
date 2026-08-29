import csv
import json
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


DATA_DIR = Path(__file__).resolve().parents[1] / "data"
PROJECT_ROOT = DATA_DIR.parents[1]
COMPONENTS_PATH = DATA_DIR / "aesthetic-style-components-2026-08-24.json"
PRICES_PATH = DATA_DIR / "aesthetic-style-reference-prices-2026-08-24.csv"


def test_aesthetic_catalog_has_unique_priced_formal_skus() -> None:
    components = json.loads(COMPONENTS_PATH.read_text(encoding="utf-8"))
    price_rows = list(csv.DictReader(PRICES_PATH.open(encoding="utf-8", newline="")))
    component_ids = [component["id"] for component in components]
    price_ids = [row["target_id"] for row in price_rows]

    assert len(components) == 236
    assert len(component_ids) == len(set(component_ids))
    assert len(price_ids) == len(set(price_ids))
    assert set(component_ids) == set(price_ids)
    assert all(component_id.startswith("aesthetic-") for component_id in component_ids)
    assert all(int(row["reference_price"]) > 0 for row in price_rows)
    assert all(row["reference_price"] == row["normal_price_min"] for row in price_rows)
    assert all(row["reference_price"] == row["normal_price_max"] for row in price_rows)
    assert len(read_catalog_components(COMPONENTS_PATH)) == len(components)
    assert len(read_approved_price_rows(PRICES_PATH, "2026-08-24")) == len(price_rows)


def test_aesthetic_catalog_covers_all_42_styles_in_both_colors() -> None:
    components = json.loads(COMPONENTS_PATH.read_text(encoding="utf-8"))
    case_styles_by_color = {"black": set(), "white": set()}
    style_names: dict[str, set[str]] = {}

    for component in components:
        specs = component["specs"]
        for style_id, style_name in specs["aesthetic_styles"].items():
            style_names.setdefault(style_id, set()).add(style_name)
        if component["category"] == "case":
            case_styles_by_color[specs["color"]].update(specs["aesthetic_styles"])

    assert len(case_styles_by_color["black"]) == 42
    assert case_styles_by_color["white"] == case_styles_by_color["black"]
    assert all(len(names) == 1 for names in style_names.values())


def test_aesthetic_catalog_omits_ai_cooler_placeholders_and_keeps_safe_cooling_rules() -> None:
    components = json.loads(COMPONENTS_PATH.read_text(encoding="utf-8"))
    jungle_fan_sets = [
        component
        for component in components
        if component["name"].startswith("丛林豹星际积木 V4（带屏")
    ]
    assert jungle_fan_sets
    assert all(
        component["specs"]["display_category"] == "风扇套装"
        for component in jungle_fan_sets
    )
    forbidden_name_tokens = ("由 AI", "任意", "外观匹配", "展示机箱")
    assert not [
        component["name"]
        for component in components
        if any(token in component["name"] for token in forbidden_name_tokens)
    ]

    coolers = [component for component in components if component["category"] == "cooler"]
    cooler_style_ids = {
        style_id
        for component in coolers
        for style_id in component["specs"]["aesthetic_styles"]
    }
    assert {"hangjiaS960", "jonsboTK1"}.isdisjoint(cooler_style_ids)

    unsupported = [
        component
        for component in coolers
        if not component["specs"]["supports_hot_cpu"]
    ]
    assert {(component["name"], component["specs"]["color"]) for component in unsupported} == {
        ("酷冷至尊挑战者 V4", "black"),
        ("酷冷至尊挑战者 V4", "white"),
    }


def test_real_catalog_generates_three_aesthetic_options_and_keeps_ai_cooler() -> None:
    engine = create_engine(
        "sqlite+pysqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(engine)
    session_factory = sessionmaker(bind=engine)
    base_catalog_path = PROJECT_ROOT / "May" / "May" / "Models" / "HardwareCatalog.swift"
    support_path = DATA_DIR / "base-build-support-components-2026-07-12.json"
    low_price_path = DATA_DIR / "low-budget-base-reference-prices.csv"
    high_price_path = DATA_DIR / "high-budget-base-reference-prices.csv"
    low_template_path = DATA_DIR / "low-budget-base-build-templates.json"
    high_template_path = DATA_DIR / "high-budget-base-build-templates.json"
    recommendation_paths = (
        DATA_DIR / "low-budget-base-recommendation-ids.txt",
        DATA_DIR / "high-budget-base-recommendation-ids.txt",
    )

    with Session(engine) as session:
        seed_hardware_components(
            session,
            [
                *read_catalog_components(base_catalog_path),
                *read_catalog_components(support_path),
                *read_catalog_components(COMPONENTS_PATH),
            ],
        )
        seed_component_prices(
            session,
            [
                *read_approved_price_rows(high_price_path, "2026-08-24"),
                *read_approved_price_rows(low_price_path, "2026-08-24"),
                *read_approved_price_rows(PRICES_PATH, "2026-08-24"),
            ],
        )
        recommendation_ids = {
            component_id
            for path in recommendation_paths
            for component_id in path.read_text(encoding="utf-8").splitlines()
            if component_id
        }
        assert update_recommended_components(session, recommendation_ids).missing_ids == []
        templates = [
            *read_build_template_inputs(low_template_path),
            *read_build_template_inputs(high_template_path),
        ]
        assert upsert_build_templates(session, templates) == len(templates)

    components = json.loads(COMPONENTS_PATH.read_text(encoding="utf-8"))
    selected_parts = []
    canonical_total = 0
    prices = {
        row["target_id"]: int(row["reference_price"])
        for row in csv.DictReader(PRICES_PATH.open(encoding="utf-8", newline=""))
    }
    for component in components:
        specs = component["specs"]
        if specs["color"] != "black" or "hangjiaS960" not in specs["aesthetic_styles"]:
            continue
        selected_parts.append(
            {
                "component_id": component["id"],
                "role": specs["aesthetic_role"],
                "category": "伪造分类",
                "name": "伪造名称",
                "condition": specs["condition"],
                "reference_price": 1,
                "supports_hot_cpu": True,
            }
        )
        canonical_total += prices[component["id"]]

    app = create_app(
        Settings(
            _env_file=None,
            postgres_url=None,
            redis_url=None,
            high_cost_rate_limit_enabled=False,
        )
    )

    def override_session():
        with session_factory() as session:
            yield session

    app.dependency_overrides[get_session] = override_session
    client = TestClient(app)
    payload = {
        "budget": 7500,
        "use_case": "游戏",
        "game_categories": ["CS2"],
        "direction": "fps",
        "memory_size": "16GB",
        "storage_size": "512GB",
        "aesthetic_style": {
            "style_id": "hangjiaS960",
            "style_name": "伪造方案名",
            "color": "black",
            "price_date": "2099-01-01",
            "parts": selected_parts,
        },
    }

    response = client.post("/v1/build/options", json=payload)

    assert response.status_code == 200
    options = response.json()["options"]
    assert {option["details"]["purchase_mode"] for option in options} == {
        "new",
        "used",
        "mixed",
    }
    assert canonical_total == 248
    assert len(selected_parts) == 2
    for option in options:
        details = option["details"]
        parts = {part["role"]: part for part in details["parts"]}
        assert details["aesthetic_style_name"] == "航嘉 S960"
        assert details["appearance_total"] == canonical_total
        assert details["price_date"] == "2026-08-26"
        assert parts["case"]["component_id"].startswith("aesthetic-case-")
        assert not parts["cooler"]["component_id"].startswith("aesthetic-")
        assert details["extras"][-1]["name"] == "棱镜 8 Pro × 9"
        assert details["extras"][-1]["reference_price"] == 89
        assert option["estimated_total"] < details["performance_total"] + canonical_total

    selected = options[0]
    assert client.post(f"/v1/build/options/{selected['selection_id']}/select").status_code == 200
    cached = client.post("/v1/build/options", json=payload)
    assert cached.status_code == 200
    assert cached.json()["options"][0]["source"] == "selection_cache"
