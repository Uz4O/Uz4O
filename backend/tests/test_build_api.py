from datetime import datetime, timedelta, timezone
from typing import Optional

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker
from sqlalchemy.pool import StaticPool

from app.builds.models import BuildTemplate
from app.builds import service as build_service
from app.builds.ai_provider import AIProviderError, AIProviderResult
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
OPTION_SPECS = {
    "i5-14600k": {"socket": "LGA1700", "tdp": 125, "perf_index": 78},
    "b760m": {"socket": "LGA1700", "mem_type": "DDR5", "chipset": "B760"},
    "am5-board": {"socket": "AM5", "mem_type": "DDR5", "chipset": "B650"},
    "rtx-4060": {"vendor": "NVIDIA", "tdp": 115, "perf_index": 72},
    "rx-7800-xt": {"vendor": "AMD", "tdp": 263, "perf_index": 82},
    "ram-6000-cl30": {
        "type": "DDR5",
        "capacity_gb": 16,
        "speed_mhz": 6000,
        "cas_latency": 30,
    },
    "ssd-1tb": {"capacity_gb": 1024},
    "psu-750w": {"watt": 750},
    "cooler-air": {"cooling_type": "air"},
    "case-mid-tower": {"form_factor": "atx_mid_tower"},
}


def build_option_template(
    direction: str,
    purchase_mode: str,
    *,
    budget: int,
    gpu_vendor: str = "nvidia",
    structured: bool = True,
    compatible: bool = True,
    template_id: Optional[str] = None,
) -> BuildTemplate:
    components = dict(OPTION_COMPONENTS)
    if gpu_vendor == "amd":
        components["gpu"] = "rx-7800-xt"
    if not compatible:
        components["motherboard"] = "am5-board"
    details = {}
    if structured:
        details = {
            "target_budget": budget,
            "direction": direction,
            "purchase_mode": purchase_mode,
            "gpu_vendor": gpu_vendor,
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
                    "specs": OPTION_SPECS[component_id],
                }
                for role, component_id in components.items()
            ],
            "suitable_user": "测试用户",
            "price_date": "2026-07-12",
        }
    return BuildTemplate(
        id=template_id
        or f"base-{budget}-{direction}-{purchase_mode}"
        + ("-amd" if gpu_vendor == "amd" else ""),
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
    vendor_option_templates: tuple[tuple[str, str, str], ...] = (),
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
                    id="rx-7800-xt",
                    category="gpu",
                    name="RX 7800 XT",
                    brand="AMD",
                    detail_raw="16GB · RDNA 3",
                    specs={"tdp": 263, "perf_index": 82},
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
        for direction, purchase_mode, gpu_vendor in vendor_option_templates:
            session.add(
                build_option_template(
                    direction,
                    purchase_mode,
                    budget=option_budget,
                    gpu_vendor=gpu_vendor,
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
            or vendor_option_templates
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
        assert {
            "advantages",
            "disadvantages",
            "risks",
        }.isdisjoint(option["details"])
        assert "compatibility" not in option


def test_build_options_defaults_to_nvidia_for_aaa_when_ray_tracing_is_absent() -> None:
    templates = tuple(
        ("aaa", purchase_mode, gpu_vendor)
        for purchase_mode in ("used", "new", "mixed")
        for gpu_vendor in ("nvidia", "amd")
    )
    client = make_client(
        with_template=False,
        vendor_option_templates=templates,
    )

    response = client.post(
        "/v1/build/options",
        json={
            "budget": 7500,
            "use_case": "游戏",
            "game_categories": ["黑神话悟空"],
        },
    )

    assert response.status_code == 200
    body = response.json()
    assert [option["details"]["gpu_vendor"] for option in body["options"]] == [
        "nvidia",
        "nvidia",
        "nvidia",
    ]


def test_build_options_falls_back_to_amd_for_a_mode_without_nvidia() -> None:
    client = make_client(
        with_template=False,
        vendor_option_templates=(
            ("aaa", "used", "nvidia"),
            ("aaa", "new", "nvidia"),
            ("aaa", "mixed", "amd"),
        ),
        option_budget=5_000,
    )

    response = client.post(
        "/v1/build/options",
        json={
            "budget": 5_000,
            "use_case": "游戏",
            "game_categories": ["黑神话悟空"],
        },
    )

    assert response.status_code == 200
    body = response.json()
    assert [
        (option["details"]["purchase_mode"], option["details"]["gpu_vendor"])
        for option in body["options"]
    ] == [
        ("used", "nvidia"),
        ("new", "nvidia"),
        ("mixed", "amd"),
    ]
    assert body["unavailable_modes"] == []


def test_build_options_returns_nvidia_and_amd_when_ray_tracing_is_off() -> None:
    templates = tuple(
        ("aaa", purchase_mode, gpu_vendor)
        for purchase_mode in ("used", "new", "mixed")
        for gpu_vendor in ("nvidia", "amd")
    )
    client = make_client(
        with_template=False,
        vendor_option_templates=templates,
    )

    response = client.post(
        "/v1/build/options",
        json={
            "budget": 7500,
            "useCase": "游戏",
            "gameCategories": ["黑神话悟空"],
            "rayTracing": False,
        },
    )

    assert response.status_code == 200
    body = response.json()
    assert [
        (option["details"]["purchase_mode"], option["details"]["gpu_vendor"])
        for option in body["options"]
    ] == [
        ("used", "nvidia"),
        ("used", "amd"),
        ("new", "nvidia"),
        ("new", "amd"),
        ("mixed", "nvidia"),
        ("mixed", "amd"),
    ]
    assert body["unavailable_modes"] == []


def test_build_options_returns_only_nvidia_when_ray_tracing_is_on() -> None:
    templates = tuple(
        ("balanced", purchase_mode, gpu_vendor)
        for purchase_mode in ("used", "new", "mixed")
        for gpu_vendor in ("nvidia", "amd")
    )
    client = make_client(
        with_template=False,
        vendor_option_templates=templates,
    )

    response = client.post(
        "/v1/build/options",
        json={
            "budget": 7500,
            "use_case": "游戏",
            "game_categories": ["什么都玩"],
            "ray_tracing": True,
        },
    )

    assert response.status_code == 200
    body = response.json()
    assert len(body["options"]) == 3
    assert all(
        option["details"]["gpu_vendor"] == "nvidia"
        for option in body["options"]
    )


def test_build_options_ignores_ray_tracing_branch_for_fps() -> None:
    client = make_client(
        with_template=False,
        vendor_option_templates=(
            ("fps", "used", "nvidia"),
            ("fps", "used", "amd"),
        ),
    )

    response = client.post(
        "/v1/build/options",
        json={
            "budget": 7500,
            "use_case": "游戏",
            "game_categories": ["CS2"],
            "ray_tracing": False,
        },
    )

    assert response.status_code == 200
    body = response.json()
    assert len(body["options"]) == 1
    assert body["options"][0]["details"]["gpu_vendor"] == "nvidia"


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
    assert all("compatibility" not in option for option in body["options"])
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


def test_build_options_respects_explicit_direction_override() -> None:
    client = make_client(
        with_template=False,
        option_templates=(
            ("fps", "used"),
            ("aaa", "used"),
            ("balanced", "used"),
        ),
    )

    response = client.post(
        "/v1/build/options",
        json={
            "budget": 7500,
            "use_case": "游戏",
            "game_categories": ["CS2"],
            "direction": "aaa",
        },
    )

    assert response.status_code == 200
    body = response.json()
    assert body["direction"] == "aaa"
    assert body["options"][0]["details"]["direction"] == "aaa"


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


def test_generate_build_never_asks_deepseek_to_create_a_build_from_catalog(monkeypatch) -> None:
    client = make_client(
        with_template=False,
        with_recommended_prices=True,
        ai_provider_api_key="deepseek-secret",
    )

    def forbidden_provider(*args, **kwargs):
        raise AssertionError("DeepSeek must start from an approved base template")

    monkeypatch.setattr("app.api.builds.select_build_with_deepseek", forbidden_provider, raising=False)

    response = client.post(
        "/v1/build/generate",
        json={"budget": 7000, "use_case": "gaming", "preferences": ["2k"]},
    )

    assert response.status_code == 200
    body = response.json()
    assert body["status"] == "ready"
    assert body["source"] == "rules_fallback"

    usage = client.app.state.high_cost_usage_metrics.snapshot()
    assert usage["external_ai_failures"] == 0


def test_build_options_retries_ai_once_then_uses_customized_base_fallback(monkeypatch) -> None:
    client = make_client(
        with_template=False,
        ai_provider_api_key="deepseek-secret",
        option_templates=(("fps", "used"), ("fps", "new"), ("fps", "mixed")),
    )
    calls = {"count": 0}

    def failing_provider(*args, **kwargs):
        calls["count"] += 1
        raise AIProviderError("invalid controlled output")

    monkeypatch.setattr("app.api.builds.select_build_with_deepseek", failing_provider, raising=False)

    response = client.post(
        "/v1/build/options",
        json={
            "budget": 7500,
            "use_case": "游戏",
            "game_categories": ["CS2"],
            "needs_wireless_network": True,
        },
    )

    assert response.status_code == 200
    body = response.json()
    assert calls["count"] == 6
    assert len(body["options"]) == 3
    assert all(option["source"] == "template" for option in body["options"])
    assert all(
        option["details"]["parts"][1]["name"].endswith(" WIFI")
        for option in body["options"]
    )

    usage = client.app.state.high_cost_usage_metrics.snapshot()
    assert usage["external_ai_failures"] == 3


def test_build_options_can_apply_controlled_base_patch(monkeypatch) -> None:
    client = make_client(
        with_template=False,
        with_recommended_prices=True,
        ai_provider_api_key="deepseek-secret",
        option_templates=(("fps", "used"),),
    )

    def successful_provider(*args, **kwargs):
        return AIProviderResult(
            base_template_id="base-7500-fps-used",
            patches={"cpu": "i5-14600k"},
            reasons=["保留 FPS 的 CPU 性能并增加无线网络。"],
            actual_cost_cents=12,
        )

    monkeypatch.setattr("app.api.builds.select_build_with_deepseek", successful_provider, raising=False)

    response = client.post(
        "/v1/build/options",
        json={
            "budget": 7500,
            "use_case": "游戏",
            "game_categories": ["CS2"],
            "needs_wireless_network": True,
        },
    )

    assert response.status_code == 200
    body = response.json()
    assert len(body["options"]) == 1
    option = body["options"][0]
    assert option["source"] == "ai_provider"
    assert option["components"]["cpu"] == "i5-14600k"
    assert option["estimated_total"] == 8000
    assert option["details"]["parts"][1]["name"].endswith(" WIFI")

    usage = client.app.state.high_cost_usage_metrics.snapshot()
    assert usage["actual_ai_cost_cents"] == 12


def test_unselected_build_options_are_not_reused(monkeypatch) -> None:
    client = make_client(
        with_template=False,
        ai_provider_api_key="deepseek-secret",
        option_templates=(("fps", "used"), ("fps", "new"), ("fps", "mixed")),
    )
    calls = {"count": 0}

    def provider(request, candidates, *args, **kwargs):
        calls["count"] += 1
        return AIProviderResult(
            base_template_id=candidates[0].id,
            patches={},
            reasons=["使用审核基底满足无线需求。"],
        )

    monkeypatch.setattr("app.api.builds.select_build_with_deepseek", provider)
    payload = {
        "budget": 7500,
        "use_case": "游戏",
        "game_categories": ["CS2"],
        "needs_wireless_network": True,
    }

    first = client.post("/v1/build/options", json=payload)
    second = client.post("/v1/build/options", json=payload)

    assert first.status_code == second.status_code == 200
    assert calls["count"] == 6
    assert all(option["selection_id"] for option in first.json()["options"])
    assert all(option["source"] == "ai_provider" for option in second.json()["options"])


def test_selected_option_is_reused_without_ai_for_the_same_requirements(monkeypatch) -> None:
    client = make_client(
        with_template=False,
        ai_provider_api_key="deepseek-secret",
        option_templates=(("fps", "used"), ("fps", "new"), ("fps", "mixed")),
    )
    calls = {"count": 0}

    def provider(request, candidates, *args, **kwargs):
        calls["count"] += 1
        return AIProviderResult(
            base_template_id=candidates[0].id,
            patches={},
            reasons=["使用审核基底满足无线需求。"],
        )

    monkeypatch.setattr("app.api.builds.select_build_with_deepseek", provider)
    payload = {
        "budget": 7500,
        "use_case": "游戏",
        "game_categories": ["CS2"],
        "needs_wireless_network": True,
    }
    first = client.post("/v1/build/options", json=payload)
    selected = first.json()["options"][0]

    confirmation = client.post(
        f"/v1/build/options/{selected['selection_id']}/select",
        json={},
    )
    second = client.post("/v1/build/options", json=payload)

    assert confirmation.status_code == 200
    assert confirmation.json()["selected_count"] == 1
    assert calls["count"] == 5
    assert second.status_code == 200
    assert second.json()["options"][0]["source"] == "selection_cache"
    assert second.json()["options"][0]["components"] == selected["components"]


def test_selected_option_cache_invalidates_after_catalog_change(monkeypatch) -> None:
    client = make_client(
        with_template=False,
        ai_provider_api_key="deepseek-secret",
        option_templates=(("fps", "used"), ("fps", "new"), ("fps", "mixed")),
    )
    calls = {"count": 0}

    def provider(request, candidates, *args, **kwargs):
        calls["count"] += 1
        return AIProviderResult(
            base_template_id=candidates[0].id,
            patches={},
            reasons=["使用审核基底满足无线需求。"],
        )

    monkeypatch.setattr("app.api.builds.select_build_with_deepseek", provider)
    payload = {
        "budget": 7500,
        "use_case": "游戏",
        "game_categories": ["CS2"],
        "needs_wireless_network": True,
    }
    first = client.post("/v1/build/options", json=payload)
    selection_id = first.json()["options"][0]["selection_id"]
    assert client.post(f"/v1/build/options/{selection_id}/select", json={}).status_code == 200

    session_override = client.app.dependency_overrides[get_session]()
    session = next(session_override)
    component = session.get(HardwareComponent, "i5-14600k")
    component.updated_at = datetime.now(timezone.utc) + timedelta(seconds=1)
    session.commit()
    with pytest.raises(StopIteration):
        next(session_override)

    second = client.post("/v1/build/options", json=payload)

    assert second.status_code == 200
    assert calls["count"] == 6
    assert all(option["source"] == "ai_provider" for option in second.json()["options"])


def test_select_build_option_rejects_unknown_selection_id() -> None:
    client = make_client(with_template=False)

    response = client.post(
        "/v1/build/options/00000000-0000-0000-0000-000000000000/select",
        json={},
    )

    assert response.status_code == 404


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
