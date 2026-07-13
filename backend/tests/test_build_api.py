from datetime import datetime, timezone
from typing import Optional

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker
from sqlalchemy.pool import StaticPool

from app.builds.models import BuildTemplate
from app.builds import service as build_service
from app.builds.ai_provider import AIProviderResult
from app.catalog.models import ComponentPrice, HardwareComponent
from app.catalog.repository import seed_hardware_components
from app.catalog.seed import CatalogComponent
from app.compat.engine import CompatibilityResult
from app.core.config import Settings
from app.db import Base, get_session
from app.main import create_app


OPTION_COMPONENTS = {
    "cpu": "i5-14600k",
    "motherboard": "b760m",
    "gpu": "rtx-4060",
    "ram": "ram-6000-cl30",
    "storage": "ssd-1tb",
    "psu": "psu-750w",
    "cooler": "cooler-air",
    "case": "case-mid-tower",
}
MIXED_USED_ROLES = {"cpu", "ram", "cooler", "case"}


def build_option_template(
    direction: str,
    purchase_mode: str,
    *,
    budget: int,
    structured: bool = True,
    compatible: bool = True,
    template_id: Optional[str] = None,
) -> BuildTemplate:
    components = dict(OPTION_COMPONENTS)
    if not compatible:
        components["motherboard"] = "am5-board"
    details = {}
    if structured:
        details = {
            "target_budget": budget,
            "direction": direction,
            "purchase_mode": purchase_mode,
            "parts": [
                {
                    "role": role,
                    "component_id": component_id,
                    "name": component_id,
                    "condition": (
                        "used"
                        if purchase_mode == "used"
                        or purchase_mode == "mixed" and role in MIXED_USED_ROLES
                        else "new"
                    ),
                    "reference_price": 900,
                    "price_source": "test-seed",
                    "price_date": "2026-07-12",
                    "specs": {},
                }
                for role, component_id in components.items()
            ],
            "advantages": ["测试优点"],
            "disadvantages": ["测试缺点"],
            "risks": ["测试风险"],
            "suitable_user": "测试用户",
            "price_date": "2026-07-12",
        }
    return BuildTemplate(
        id=template_id or f"base-{budget}-{direction}-{purchase_mode}",
        title=f"{budget} 元 {direction} {purchase_mode} 基底配置",
        budget_min=budget,
        budget_max=budget + 499,
        use_cases=["游戏"],
        tags=[
            {"fps": "FPS", "aaa": "3A", "balanced": "均衡"}[direction],
            {"new": "全新", "used": "二手", "mixed": "混合采购"}[purchase_mode],
        ],
        components=components,
        estimated_total=7200,
        explanation="结构化测试模板。",
        details=details,
    )


def make_client(
    with_template: bool,
    with_recommended_prices: bool = False,
    ai_provider_api_key: Optional[str] = None,
    option_templates: tuple[tuple[str, str], ...] = (),
    detail_less_option_templates: tuple[tuple[str, str], ...] = (),
    incompatible_option_templates: tuple[tuple[str, str], ...] = (),
    ranked_option_templates: tuple[tuple[str, str, str, bool], ...] = (),
    invalid_ranked_option_templates: tuple[tuple[str, str, str, str], ...] = (),
    option_budget: int = 7500,
) -> TestClient:
    engine = create_engine(
        "sqlite+pysqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(engine)
    session_factory = sessionmaker(bind=engine)
    with Session(engine) as session:
        seed_hardware_components(
            session,
            [
                CatalogComponent(
                    id="i5-14600k",
                    category="cpu",
                    name="i5-14600K",
                    brand="Intel",
                    detail_raw="14代 Raptor Lake Refresh · LGA1700",
                    specs={"socket": "LGA1700", "tdp": 125, "perf_index": 78},
                ),
                CatalogComponent(
                    id="rtx-4060",
                    category="gpu",
                    name="RTX 4060",
                    brand="NVIDIA",
                    detail_raw="8GB · Ada",
                    specs={"tdp": 115, "perf_index": 72},
                ),
                CatalogComponent(
                    id="b760m",
                    category="motherboard",
                    name="B760M AORUS ELITE",
                    brand="技嘉",
                    detail_raw="Intel · LGA1700 · B760",
                    specs={"socket": "LGA1700", "mem_type": "DDR5"},
                ),
                CatalogComponent(
                    id="am5-board",
                    category="motherboard",
                    name="AM5 Board",
                    brand="AMD",
                    detail_raw="AMD · AM5",
                    specs={"socket": "AM5", "mem_type": "DDR5"},
                ),
                CatalogComponent(
                    id="ram-6000-cl30",
                    category="ram",
                    name="DDR5-6000 CL30",
                    brand="芝奇",
                    detail_raw="DDR5 · 32GB",
                    specs={"type": "DDR5"},
                ),
                CatalogComponent(
                    id="ssd-1tb",
                    category="storage",
                    name="1TB NVMe SSD",
                    brand="致态",
                    detail_raw="PCIe 4.0 · 1TB",
                    specs={"capacity_gb": 1000},
                ),
                CatalogComponent(
                    id="psu-750w",
                    category="psu",
                    name="750W Gold",
                    brand="Corsair",
                    detail_raw="750W · 80+ Gold",
                    specs={"watt": 750},
                ),
                CatalogComponent(
                    id="cooler-air",
                    category="cooler",
                    name="Air Cooler",
                    brand="Thermalright",
                    detail_raw="Air cooler",
                    specs={},
                ),
                CatalogComponent(
                    id="case-mid-tower",
                    category="case",
                    name="Mid Tower Case",
                    brand="Montech",
                    detail_raw="ATX mid tower",
                    specs={"form_factor": "atx_mid_tower"},
                ),
            ],
        )
        if with_template:
            session.add(
                BuildTemplate(
                    id="gaming-7000-2k",
                    title="7000 元 2K 游戏配置",
                    budget_min=6500,
                    budget_max=7500,
                    use_cases=["gaming"],
                    tags=["2k", "quiet"],
                    components={
                        "cpu": "i5-14600k",
                        "motherboard": "b760m",
                        "ram": "ram-6000-cl30",
                        "psu": "psu-750w",
                    },
                    estimated_total=7000,
                    explanation="这套优先保证 2K 游戏体验。",
                )
            )
            session.commit()
        for direction, purchase_mode in option_templates:
            session.add(
                build_option_template(
                    direction,
                    purchase_mode,
                    budget=option_budget,
                )
            )
        for direction, purchase_mode in detail_less_option_templates:
            session.add(
                build_option_template(
                    direction,
                    purchase_mode,
                    budget=option_budget,
                    structured=False,
                )
            )
        for direction, purchase_mode in incompatible_option_templates:
            session.add(
                build_option_template(
                    direction,
                    purchase_mode,
                    budget=option_budget,
                    compatible=False,
                )
            )
        for template_id, direction, purchase_mode, compatible in ranked_option_templates:
            session.add(
                build_option_template(
                    direction,
                    purchase_mode,
                    budget=option_budget,
                    compatible=compatible,
                    template_id=template_id,
                )
            )
        for template_id, direction, purchase_mode, invalid_kind in invalid_ranked_option_templates:
            template = build_option_template(
                direction,
                purchase_mode,
                budget=option_budget,
                template_id=template_id,
            )
            if invalid_kind == "incomplete":
                template.details["parts"].pop()
            elif invalid_kind == "malformed":
                template.details.pop("parts")
            else:
                raise ValueError(f"Unknown invalid detail kind: {invalid_kind}")
            session.add(template)
        if (
            option_templates
            or detail_less_option_templates
            or incompatible_option_templates
            or ranked_option_templates
            or invalid_ranked_option_templates
        ):
            session.commit()
        if with_recommended_prices:
            for component_id, price in [
                ("i5-14600k", 1700),
                ("rtx-4060", 2200),
                ("b760m", 800),
                ("ram-6000-cl30", 550),
                ("ssd-1tb", 450),
                ("psu-750w", 500),
            ]:
                session.get(HardwareComponent, component_id).is_recommended = True
                session.add(
                    ComponentPrice(
                        component_id=component_id,
                        reference_price=price,
                        price_range_low=price - 50,
                        price_range_high=price + 80,
                        source="manual",
                        accepted_count=3,
                        rejected_count=0,
                        review_reasons=[],
                        approved_at=datetime.now(timezone.utc),
                    )
                )
            session.commit()

    app = create_app(
        Settings(
            _env_file=None,
            postgres_url=None,
            redis_url=None,
            ai_provider_api_key=ai_provider_api_key,
        )
    )

    def override_session():
        with session_factory() as session:
            yield session

    app.dependency_overrides[get_session] = override_session
    return TestClient(app)


def test_generate_build_returns_matching_template_plan() -> None:
    client = make_client(with_template=True)

    response = client.post(
        "/v1/build/generate",
        json={"budget": 7000, "use_case": "gaming", "preferences": ["2k", "quiet"]},
    )

    assert response.status_code == 200
    body = response.json()
    assert body["status"] == "ready"
    assert body["source"] == "template"
    assert body["template_id"] == "gaming-7000-2k"
    assert body["components"]["cpu"] == "i5-14600k"
    assert body["compatibility"]["compatible"] is True


def test_generate_build_accepts_frontend_payload_aliases() -> None:
    client = make_client(with_template=True)

    response = client.post(
        "/v1/build/generate",
        json={
            "budget": 7000,
            "useCase": "gaming",
            "gameCategories": ["2k"],
            "purchasePreference": "全新优先",
            "chassisColorPreference": "曜石黑",
            "cpuPreference": "任意",
        },
    )

    assert response.status_code == 200
    body = response.json()
    assert body["status"] == "ready"
    assert body["source"] == "template"
    assert body["template_id"] == "gaming-7000-2k"


def test_build_options_returns_full_high_budget_modes_in_approved_order() -> None:
    client = make_client(
        with_template=False,
        option_templates=(("fps", "new"), ("fps", "mixed"), ("fps", "used")),
    )

    response = client.post(
        "/v1/build/options",
        json={"budget": 7500, "use_case": "游戏", "game_categories": ["CS2"]},
    )

    assert response.status_code == 200
    body = response.json()
    assert body["direction"] == "fps"
    assert [option["details"]["purchase_mode"] for option in body["options"]] == [
        "used",
        "new",
        "mixed",
    ]
    assert body["unavailable_modes"] == []
    for option in body["options"]:
        assert option["status"] == "ready"
        assert option["source"] == "template"
        assert option["template_id"] is not None
        assert option["details"] is not None
        assert len(option["details"]["parts"]) == 8
        assert len(option["components"]) == 8
        assert option["compatibility"]["compatible"] is True


@pytest.mark.parametrize("use_case", ["游戏", "游戏兼办公", "办公"])
def test_build_options_normalizes_frontend_use_cases_and_ignores_conflicting_tokens(
    use_case: str,
) -> None:
    client = make_client(
        with_template=False,
        option_templates=(("fps", "used"), ("fps", "new"), ("fps", "mixed")),
    )

    response = client.post(
        "/v1/build/options",
        json={
            "budget": 7500,
            "useCase": use_case,
            "gameCategories": ["瓦罗兰特"],
            "preferences": ["3A", "混合采购", "32GB"],
            "purchasePreference": "全新优先",
            "chassisColorPreference": "曜石黑",
        },
    )

    assert response.status_code == 200
    body = response.json()
    assert body["direction"] == "fps"
    assert [option["details"]["purchase_mode"] for option in body["options"]] == [
        "used",
        "new",
        "mixed",
    ]
    assert all(option["details"]["direction"] == "fps" for option in body["options"])


def test_build_options_returns_partial_low_budget_modes_and_marks_missing_details() -> None:
    client = make_client(
        with_template=False,
        option_templates=(("aaa", "new"), ("aaa", "used")),
        detail_less_option_templates=(("aaa", "mixed"),),
        option_budget=7000,
    )

    response = client.post(
        "/v1/build/options",
        json={"budget": 7000, "use_case": "游戏", "game_categories": ["黑神话悟空"]},
    )

    assert response.status_code == 200
    body = response.json()
    assert body["direction"] == "aaa"
    assert [option["details"]["purchase_mode"] for option in body["options"]] == [
        "used",
        "new",
    ]
    assert body["unavailable_modes"] == ["mixed"]


def test_build_options_marks_one_incompatible_mode_unavailable() -> None:
    client = make_client(
        with_template=False,
        option_templates=(("fps", "used"), ("fps", "new")),
        incompatible_option_templates=(("fps", "mixed"),),
    )

    response = client.post(
        "/v1/build/options",
        json={"budget": 7500, "use_case": "游戏", "game_categories": ["CS2"]},
    )

    assert response.status_code == 200
    body = response.json()
    assert [option["details"]["purchase_mode"] for option in body["options"]] == [
        "used",
        "new",
    ]
    assert all(option["compatibility"]["compatible"] is True for option in body["options"])
    assert body["unavailable_modes"] == ["mixed"]


def test_build_options_tries_next_ranked_template_when_first_is_incompatible() -> None:
    client = make_client(
        with_template=False,
        ranked_option_templates=(
            ("a-bad", "fps", "used", False),
            ("z-good", "fps", "used", True),
        ),
    )

    response = client.post(
        "/v1/build/options",
        json={"budget": 7500, "use_case": "游戏", "game_categories": ["CS2"]},
    )

    assert response.status_code == 200
    body = response.json()
    assert [option["template_id"] for option in body["options"]] == ["z-good"]
    assert body["unavailable_modes"] == ["new", "mixed"]


@pytest.mark.parametrize("invalid_kind", ["incomplete", "malformed"])
def test_build_options_tries_next_ranked_template_when_details_are_invalid(
    invalid_kind: str,
) -> None:
    client = make_client(
        with_template=False,
        ranked_option_templates=(("z-good", "fps", "used", True),),
        invalid_ranked_option_templates=(("a-bad", "fps", "used", invalid_kind),),
    )

    response = client.post(
        "/v1/build/options",
        json={"budget": 7500, "use_case": "游戏", "game_categories": ["CS2"]},
    )

    assert response.status_code == 200
    body = response.json()
    assert [option["template_id"] for option in body["options"]] == ["z-good"]
    assert body["unavailable_modes"] == ["new", "mixed"]


def test_build_options_returns_503_when_all_modes_are_incompatible() -> None:
    client = make_client(
        with_template=False,
        incompatible_option_templates=(
            ("fps", "used"),
            ("fps", "new"),
            ("fps", "mixed"),
        ),
    )

    response = client.post(
        "/v1/build/options",
        json={"budget": 7500, "use_case": "游戏", "game_categories": ["CS2"]},
    )

    assert response.status_code == 503
    assert "结构化配置方案" in response.json()["detail"]


def test_build_options_returns_503_when_no_structured_mode_exists() -> None:
    client = make_client(with_template=False, with_recommended_prices=True)

    response = client.post(
        "/v1/build/options",
        json={"budget": 7500, "use_case": "游戏", "game_categories": ["CS2"]},
    )

    assert response.status_code == 503
    assert "结构化配置方案" in response.json()["detail"]


def test_build_options_uses_balanced_templates_for_cross_category_games() -> None:
    client = make_client(
        with_template=False,
        option_templates=(
            ("fps", "used"),
            ("fps", "new"),
            ("fps", "mixed"),
            ("balanced", "used"),
            ("balanced", "new"),
            ("balanced", "mixed"),
        ),
    )

    response = client.post(
        "/v1/build/options",
        json={
            "budget": 7500,
            "use_case": "游戏",
            "game_categories": ["瓦罗兰特", "黑神话悟空"],
        },
    )

    assert response.status_code == 200
    body = response.json()
    assert body["direction"] == "balanced"
    assert all("-balanced-" in option["template_id"] for option in body["options"])
    assert all(
        option["details"]["direction"] == "balanced" for option in body["options"]
    )


def test_generate_build_returns_ai_pending_when_no_template_and_no_api_key() -> None:
    client = make_client(with_template=False)

    response = client.post(
        "/v1/build/generate",
        json={"budget": 4200, "use_case": "creator", "preferences": ["white", "itx"]},
    )

    assert response.status_code == 200
    body = response.json()
    assert body["status"] == "needs_ai_generation"
    assert body["source"] == "ai_pending"
    assert body["components"] == {}
    assert body["compatibility"] is None
    assert "AI API Key" in body["explanation"]


def test_generate_build_does_not_freely_generate_when_ai_key_exists_but_no_controlled_data() -> None:
    client = make_client(with_template=False, ai_provider_api_key="deepseek-secret")

    response = client.post(
        "/v1/build/generate",
        json={"budget": 4200, "use_case": "creator", "preferences": ["white", "itx"]},
    )

    assert response.status_code == 200
    body = response.json()
    assert body["status"] == "needs_ai_generation"
    assert body["source"] == "ai_pending"
    assert body["components"] == {}
    assert body["compatibility"] is None
    assert "审核配置模板" in body["explanation"]
    assert "候选" in body["explanation"]


def test_generate_build_rejects_invalid_budget_and_too_many_preferences() -> None:
    client = make_client(with_template=False)

    negative_budget = client.post(
        "/v1/build/generate",
        json={"budget": -1, "use_case": "gaming", "preferences": []},
    )
    too_many_preferences = client.post(
        "/v1/build/generate",
        json={
            "budget": 7000,
            "use_case": "gaming",
            "preferences": [f"pref-{index}" for index in range(40)],
        },
    )

    assert negative_budget.status_code == 422
    assert too_many_preferences.status_code == 422


def test_generate_build_rejects_blank_use_case() -> None:
    client = make_client(with_template=False)

    response = client.post(
        "/v1/build/generate",
        json={"budget": 7000, "use_case": "   ", "preferences": []},
    )

    assert response.status_code == 422


def test_generate_build_rejects_blank_duplicate_and_oversized_preferences() -> None:
    client = make_client(with_template=False)

    blank_preference = client.post(
        "/v1/build/generate",
        json={"budget": 7000, "use_case": "gaming", "preferences": ["2k", "   "]},
    )
    duplicate_preference = client.post(
        "/v1/build/generate",
        json={"budget": 7000, "use_case": "gaming", "preferences": ["quiet", " Quiet "]},
    )
    oversized_preference = client.post(
        "/v1/build/generate",
        json={"budget": 7000, "use_case": "gaming", "preferences": ["x" * 65]},
    )

    assert blank_preference.status_code == 422
    assert duplicate_preference.status_code == 422
    assert oversized_preference.status_code == 422


def test_generate_build_rejects_oversized_frontend_preference_fields() -> None:
    client = make_client(with_template=False)

    too_many_game_categories = client.post(
        "/v1/build/generate",
        json={
            "budget": 7000,
            "useCase": "游戏",
            "gameCategories": [f"game-{index}" for index in range(40)],
        },
    )
    oversized_purchase_preference = client.post(
        "/v1/build/generate",
        json={
            "budget": 7000,
            "useCase": "游戏",
            "purchasePreference": "x" * 65,
        },
    )

    assert too_many_game_categories.status_code == 422
    assert oversized_purchase_preference.status_code == 422


def test_generate_build_falls_back_to_recommended_priced_catalog_when_no_template() -> None:
    client = make_client(with_template=False, with_recommended_prices=True)

    response = client.post(
        "/v1/build/generate",
        json={"budget": 7000, "use_case": "gaming", "preferences": ["2k"]},
    )

    assert response.status_code == 200
    body = response.json()
    assert body["status"] == "ready"
    assert body["source"] == "rules_fallback"


def test_generate_build_degrades_to_rules_fallback_when_ai_provider_fails(monkeypatch) -> None:
    client = make_client(
        with_template=False,
        with_recommended_prices=True,
        ai_provider_api_key="deepseek-secret",
    )

    def failing_provider(*args, **kwargs):
        raise RuntimeError("provider timeout")

    monkeypatch.setattr("app.api.builds.select_build_with_deepseek", failing_provider, raising=False)

    response = client.post(
        "/v1/build/generate",
        json={"budget": 7000, "use_case": "gaming", "preferences": ["2k"]},
    )

    assert response.status_code == 200
    body = response.json()
    assert body["status"] == "ready"
    assert body["source"] == "rules_fallback"
    assert "外部 AI 暂不可用" in body["explanation"]

    usage = client.app.state.high_cost_usage_metrics.snapshot()
    assert usage["external_ai_failures"] == 1
    assert usage["by_endpoint"]["/v1/build/generate"]["external_ai_failures"] == 1


def test_generate_build_rejects_ai_provider_components_outside_candidate_pool(monkeypatch) -> None:
    client = make_client(
        with_template=False,
        with_recommended_prices=True,
        ai_provider_api_key="deepseek-secret",
    )

    def invented_provider(*args, **kwargs):
        return AIProviderResult(
            components={
                "cpu": "invented-cpu",
                "motherboard": "b760m",
                "ram": "ram-6000-cl30",
                "gpu": "rtx-4060",
                "storage": "ssd-1tb",
                "psu": "psu-750w",
            },
            explanation="模型返回了候选池外型号。",
            actual_cost_cents=0,
        )

    monkeypatch.setattr("app.api.builds.select_build_with_deepseek", invented_provider, raising=False)

    response = client.post(
        "/v1/build/generate",
        json={"budget": 7000, "use_case": "gaming", "preferences": ["2k"]},
    )

    assert response.status_code == 200
    body = response.json()
    assert body["status"] == "ready"
    assert body["source"] == "rules_fallback"
    assert "invented-cpu" not in body["components"].values()

    usage = client.app.state.high_cost_usage_metrics.snapshot()
    assert usage["external_ai_failures"] == 1


def test_generate_build_can_use_ai_provider_when_selection_is_controlled(monkeypatch) -> None:
    client = make_client(
        with_template=False,
        with_recommended_prices=True,
        ai_provider_api_key="deepseek-secret",
    )

    def successful_provider(*args, **kwargs):
        return AIProviderResult(
            components={
                "cpu": "i5-14600k",
                "motherboard": "b760m",
                "ram": "ram-6000-cl30",
                "gpu": "rtx-4060",
                "storage": "ssd-1tb",
                "psu": "psu-750w",
            },
            explanation="从候选池中选择的受控配置。",
            actual_cost_cents=12,
        )

    monkeypatch.setattr("app.api.builds.select_build_with_deepseek", successful_provider, raising=False)

    response = client.post(
        "/v1/build/generate",
        json={"budget": 7000, "use_case": "gaming", "preferences": ["2k"]},
    )

    assert response.status_code == 200
    body = response.json()
    assert body["status"] == "ready"
    assert body["source"] == "ai_provider"
    assert body["components"]["cpu"] == "i5-14600k"
    assert body["compatibility"]["compatible"] is True

    usage = client.app.state.high_cost_usage_metrics.snapshot()
    assert usage["actual_ai_cost_cents"] == 12


def test_fallback_candidates_keep_only_top_four_per_role() -> None:
    components = [
        component(f"cpu-{index}", "cpu", perf_index=index)
        for index in range(6)
    ]
    prices = {
        item.id: component_price(item.id, 100 + index)
        for index, item in enumerate(components)
    }

    candidates = build_service.fallback_candidates_by_role(components, prices)

    assert [item.id for item in candidates["cpu"]] == [
        "cpu-5",
        "cpu-4",
        "cpu-3",
        "cpu-2",
    ]


def test_rules_fallback_stops_after_defensive_combination_limit(monkeypatch) -> None:
    components = [
        component(f"{category}-{index}", category, perf_index=index)
        for category in ["cpu", "motherboard", "ram", "psu", "gpu", "storage"]
        for index in range(6)
    ]
    prices = [component_price(item.id, 100) for item in components]
    calls = {"count": 0}

    def compatible_result(*args, **kwargs):
        calls["count"] += 1
        return CompatibilityResult(
            compatible=True,
            summary="compatible",
            findings=[],
            finding_counts={"pass": 0, "warning": 0, "error": 0},
            checked_rule_codes=[],
        )

    monkeypatch.setattr(build_service, "FALLBACK_MAX_CANDIDATES_PER_ROLE", 6)
    monkeypatch.setattr(build_service, "FALLBACK_MAX_COMBINATIONS_TO_EVALUATE", 5, raising=False)
    monkeypatch.setattr(build_service, "evaluate_compatibility", compatible_result)

    response = build_service.rules_fallback_response(
        build_service.BuildRequest(budget=10_000, use_case="gaming"),
        components,
        prices,
    )

    assert response is not None
    assert calls["count"] == 5


def component(component_id: str, category: str, perf_index: int) -> HardwareComponent:
    return HardwareComponent(
        id=component_id,
        category=category,
        name=component_id,
        brand="brand",
        detail_raw="detail",
        specs={"perf_index": perf_index},
        is_recommended=True,
        status="active",
    )


def component_price(component_id: str, price: int) -> ComponentPrice:
    return ComponentPrice(
        component_id=component_id,
        reference_price=price,
        price_range_low=price,
        price_range_high=price,
        source="manual",
        accepted_count=1,
        rejected_count=0,
        review_reasons=[],
        approved_at=datetime.now(timezone.utc),
    )
