from datetime import datetime, timedelta, timezone
from typing import Optional

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker
from sqlalchemy.pool import StaticPool

from app.builds.models import BuildSelectionCache, BuildTemplate
from app.builds import service as build_service
from app.catalog.models import ComponentPrice, HardwareComponent
from app.catalog.repository import seed_hardware_components
from app.catalog.seed import CatalogComponent
from app.compat.engine import CompatibilityResult
from app.core.config import Settings
from app.db import Base, get_session
from app.main import create_app


OPTION_COMPONENTS = {
    "cpu": "i5-12600kf",
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
    "i5-12600kf": {"socket": "LGA1700", "tdp": 150, "perf_index": 68},
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
    "cooler-air": {"cooling_type": "air", "heatpipes": 6, "towers": 2},
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
    total: Optional[int] = None,
) -> BuildTemplate:
    components = dict(OPTION_COMPONENTS)
    if gpu_vendor == "amd":
        components["gpu"] = "rx-7800-xt"
    if not compatible:
        components["motherboard"] = "am5-board"
    component_total = total if total is not None else budget
    base_part_price, remainder = divmod(component_total, len(components))
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
                    "reference_price": base_part_price + (1 if index < remainder else 0),
                    "price_source": "test-seed",
                    "price_date": "2026-07-12",
                    "specs": OPTION_SPECS[component_id],
                }
                for index, (role, component_id) in enumerate(components.items())
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
        estimated_total=component_total,
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
    option_total: Optional[int] = None,
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
                    id="i5-12600kf",
                    category="cpu",
                    name="i5-12600KF",
                    brand="Intel",
                    detail_raw="12代 Alder Lake · LGA1700",
                    specs={"socket": "LGA1700", "tdp": 150, "perf_index": 68},
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
                    specs={"cooling_type": "air", "heatpipes": 6, "towers": 2},
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
                        "cpu": "i5-12600kf",
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
                    total=option_total,
                )
            )
        for direction, purchase_mode, gpu_vendor in vendor_option_templates:
            session.add(
                build_option_template(
                    direction,
                    purchase_mode,
                    budget=option_budget,
                    gpu_vendor=gpu_vendor,
                    total=option_total,
                )
            )
        for direction, purchase_mode in detail_less_option_templates:
            session.add(
                build_option_template(
                    direction,
                    purchase_mode,
                    budget=option_budget,
                    structured=False,
                    total=option_total,
                )
            )
        for direction, purchase_mode in incompatible_option_templates:
            session.add(
                build_option_template(
                    direction,
                    purchase_mode,
                    budget=option_budget,
                    compatible=False,
                    total=option_total,
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
                    total=option_total,
                )
            )
        for template_id, direction, purchase_mode, invalid_kind in invalid_ranked_option_templates:
            template = build_option_template(
                direction,
                purchase_mode,
                budget=option_budget,
                template_id=template_id,
                total=option_total,
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
                ("i5-12600kf", 1700),
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


def seed_aesthetic_parts(
    client: TestClient,
    parts: list[dict],
    prices: dict[str, int],
    *,
    color: str,
    style_id: str,
    style_name: str,
    supports_hot_cpu_by_id: Optional[dict[str, bool]] = None,
) -> None:
    override_session = client.app.dependency_overrides[get_session]
    session_generator = override_session()
    session = next(session_generator)
    try:
        for part in parts:
            session.add(
                HardwareComponent(
                    id=part["component_id"],
                    category={
                        "case": "case",
                        "cooler": "cooler",
                        "extra": "aesthetic_extra",
                    }[part["role"]],
                    name=part["name"],
                    brand="test",
                    detail_raw=part["category"],
                    specs={
                        "condition": part.get("condition", "new"),
                        "color": color,
                        "display_category": part["category"],
                        "supports_hot_cpu": (supports_hot_cpu_by_id or {}).get(
                            part["component_id"],
                            part.get("supports_hot_cpu", False),
                        ),
                        "aesthetic_role": part["role"],
                        "aesthetic_styles": {style_id: style_name},
                    },
                )
            )
            canonical_price = prices[part["component_id"]]
            session.add(
                ComponentPrice(
                    component_id=part["component_id"],
                    reference_price=canonical_price,
                    price_range_low=canonical_price,
                    price_range_high=canonical_price,
                    source="test-aesthetic-catalog",
                    accepted_count=1,
                    rejected_count=0,
                    review_reasons=[],
                    approved_at=datetime(2026, 8, 24, tzinfo=timezone.utc),
                )
            )
        session.commit()
    finally:
        session.close()
        session_generator.close()


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
    assert body["components"]["cpu"] == "i5-12600kf"
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


def test_build_options_locks_aesthetic_parts_without_double_counting() -> None:
    client = make_client(
        with_template=False,
        option_templates=(("fps", "used"), ("fps", "new"), ("fps", "mixed")),
    )
    payload = {
        "budget": 7500,
        "use_case": "游戏",
        "game_categories": ["CS2"],
        "aesthetic_style": {
            "style_id": "vision-compact",
            "style_name": "伪造方案名",
            "color": "black",
            "price_date": "2099-01-01",
            "parts": [
                {
                    "component_id": "aesthetic-case-vision-black",
                    "role": "case",
                    "category": "机箱",
                    "name": "联立 VISION COMPACT 黑色",
                    "condition": "new",
                    "reference_price": 1,
                },
                {
                    "component_id": "aesthetic-cooler-se360",
                    "role": "cooler",
                    "category": "一体式水冷",
                    "name": "展域 SE360",
                    "condition": "new",
                    "reference_price": 1,
                    "supports_hot_cpu": True,
                },
                {
                    "component_id": "aesthetic-extra-fans-v4",
                    "role": "extra",
                    "category": "风扇套装",
                    "name": "积木风扇套装",
                    "condition": "new",
                    "reference_price": 1,
                },
            ],
        },
    }
    seed_aesthetic_parts(
        client,
        payload["aesthetic_style"]["parts"],
        {
            "aesthetic-case-vision-black": 600,
            "aesthetic-cooler-se360": 500,
            "aesthetic-extra-fans-v4": 100,
        },
        color="black",
        style_id="vision-compact",
        style_name="联立 VISION COMPACT",
    )

    first = client.post("/v1/build/options", json=payload)

    assert first.status_code == 200
    for option in first.json()["options"]:
        details = option["details"]
        parts = {part["role"]: part for part in details["parts"]}
        assert option["components"]["case"] == "aesthetic-case-vision-black"
        assert option["components"]["cooler"] == "aesthetic-cooler-se360"
        assert parts["case"]["condition"] == "new"
        assert parts["cooler"]["condition"] == "new"
        assert parts["case"]["price_date"] == "2026-08-24"
        assert details["performance_total"] == 7500
        assert details["appearance_total"] == 1200
        assert details["aesthetic_style_name"] == "联立 VISION COMPACT"
        assert details["aesthetic_color"] == "black"
        assert details["price_date"] == "2026-08-24"
        assert option["estimated_total"] == 7500 - 937 - 937 + 1200
        assert details["extras"][-1] == {
            "id": "aesthetic-extra-fans-v4",
            "name": "积木风扇套装",
            "condition": "new",
            "reference_price": 100,
            "category": "风扇套装",
        }

    selected = first.json()["options"][0]
    assert client.post(f"/v1/build/options/{selected['selection_id']}/select").status_code == 200
    second = client.post("/v1/build/options", json=payload)
    assert second.status_code == 200
    assert second.json()["options"][0]["source"] == "selection_cache"
    assert second.json()["options"][0]["estimated_total"] == selected["estimated_total"]


def test_build_options_rejects_client_forged_hot_cpu_support() -> None:
    client = make_client(
        with_template=False,
        option_templates=(("fps", "used"), ("fps", "new"), ("fps", "mixed")),
    )
    parts = [
        {
            "component_id": "aesthetic-case-mf400",
            "role": "case",
            "category": "机箱",
            "name": "酷冷至尊 MF400 Mesh",
            "condition": "new",
            "reference_price": 299,
        },
        {
            "component_id": "aesthetic-cooler-challenger-v4",
            "role": "cooler",
            "category": "CPU 散热器",
            "name": "酷冷至尊挑战者 V4",
            "condition": "new",
            "reference_price": 169,
            "supports_hot_cpu": True,
        },
    ]
    seed_aesthetic_parts(
        client,
        parts,
        {"aesthetic-case-mf400": 299, "aesthetic-cooler-challenger-v4": 169},
        color="black",
        style_id="coolermasterMF400Mesh",
        style_name="酷冷至尊 MF400 Mesh",
        supports_hot_cpu_by_id={"aesthetic-cooler-challenger-v4": False},
    )

    response = client.post(
        "/v1/build/options",
        json={
            "budget": 7500,
            "use_case": "游戏",
            "game_categories": ["CS2"],
            "aesthetic_style": {
                "style_id": "coolermasterMF400Mesh",
                "style_name": "伪造方案名",
                "color": "black",
                "price_date": "2099-01-01",
                "parts": parts,
            },
        },
    )

    assert response.status_code == 422
    assert "无法安全支持当前高热 CPU" in response.text


def test_build_options_rejects_aesthetic_style_without_exactly_one_case() -> None:
    client = make_client(with_template=False)

    response = client.post(
        "/v1/build/options",
        json={
            "budget": 7500,
            "use_case": "游戏",
            "aesthetic_style": {
                "style_id": "invalid",
                "style_name": "无机箱方案",
                "color": "black",
                "price_date": "2026-08-24",
                "parts": [
                    {
                        "component_id": "fan-only",
                        "role": "extra",
                        "category": "风扇套装",
                        "name": "风扇",
                        "reference_price": 100,
                    }
                ],
            },
        },
    )

    assert response.status_code == 422
    assert "必须且只能锁定一个机箱" in response.text


def test_build_options_rejects_base_option_more_than_200_below_budget() -> None:
    client = make_client(
        with_template=False,
        option_templates=(("fps", "new"),),
        option_budget=7500,
        option_total=7200,
    )

    response = client.post(
        "/v1/build/options",
        json={
            "budget": 7500,
            "use_case": "游戏",
            "game_categories": ["CS2"],
        },
    )

    assert response.status_code == 503
    assert "所有采购方式均暂不可用" in response.json()["detail"]


def test_build_options_rejects_exact_tier_base_above_budget_ceiling() -> None:
    client = make_client(
        with_template=False,
        option_templates=(
            ("fps", "used"),
            ("fps", "new"),
            ("fps", "mixed"),
        ),
        option_budget=5000,
        option_total=5500,
    )

    response = client.post(
        "/v1/build/options",
        json={
            "budget": 5000,
            "use_case": "游戏",
            "game_categories": ["CS2"],
        },
    )

    assert response.status_code == 503
    assert "最低审核配置约为 5500 元" in response.json()["detail"]
    assert "预算上限 5300 元" in response.json()["detail"]


def test_build_options_uses_adjacent_reviewed_tier_for_in_between_budget() -> None:
    client = make_client(
        with_template=False,
        option_templates=(
            ("balanced", "used"),
            ("balanced", "new"),
            ("balanced", "mixed"),
        ),
        option_budget=10_000,
        option_total=10_000,
    )

    response = client.post(
        "/v1/build/options",
        json={
            "budget": 9999,
            "use_case": "游戏",
            "direction": "balanced",
            "ray_tracing": True,
        },
    )

    assert response.status_code == 200
    body = response.json()
    assert {option["details"]["purchase_mode"] for option in body["options"]} == {
        "new",
        "used",
        "mixed",
    }
    assert all(option["estimated_total"] == 10_000 for option in body["options"])


def test_build_options_compares_current_and_adjacent_tiers_before_selecting() -> None:
    client = make_client(
        with_template=False,
        ranked_option_templates=(
            ("base-9500-fps-used", "fps", "used", True),
            ("base-9500-fps-new", "fps", "new", True),
            ("base-9500-fps-mixed", "fps", "mixed", True),
        ),
        option_budget=9500,
        option_total=9800,
    )
    session_provider = client.app.dependency_overrides[get_session]
    session_iterator = session_provider()
    session = next(session_iterator)
    try:
        session.add(
            build_option_template(
                "fps",
                "used",
                budget=10_000,
                template_id="base-10000-fps-used",
                total=10_000,
            )
        )
        session.commit()
    finally:
        session_iterator.close()

    response = client.post(
        "/v1/build/options",
        json={"budget": 9999, "use_case": "游戏", "game_categories": ["CS2"]},
    )

    assert response.status_code == 200
    assert response.json()["options"][0]["template_id"] == "base-10000-fps-used"


def test_build_options_uses_the_stronger_aaa_gpu_below_10000_when_ray_tracing_is_absent() -> None:
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
        "amd",
        "amd",
        "amd",
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


def test_build_options_below_10000_can_fall_back_to_amd_when_ray_tracing_is_on() -> None:
    client = make_client(
        with_template=False,
        vendor_option_templates=tuple(
            ("balanced", purchase_mode, "amd")
            for purchase_mode in ("used", "new", "mixed")
        ),
        option_budget=9500,
        option_total=9900,
    )

    response = client.post(
        "/v1/build/options",
        json={
            "budget": 9999,
            "use_case": "游戏",
            "game_categories": ["什么都玩"],
            "ray_tracing": True,
        },
    )

    assert response.status_code == 200
    body = response.json()
    assert len(body["options"]) == 3
    assert all(option["details"]["gpu_vendor"] == "amd" for option in body["options"])


@pytest.mark.parametrize("direction", ["fps", "balanced"])
def test_build_options_returns_only_nvidia_from_10000_when_ray_tracing_is_on(
    direction: str,
) -> None:
    templates = tuple(
        (direction, purchase_mode, gpu_vendor)
        for purchase_mode in ("used", "new", "mixed")
        for gpu_vendor in ("nvidia", "amd")
    )
    client = make_client(
        with_template=False,
        vendor_option_templates=templates,
        option_budget=10_000,
    )

    response = client.post(
        "/v1/build/options",
        json={
            "budget": 10_000,
            "use_case": "游戏",
            "game_categories": ["什么都玩"],
            "direction": direction,
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
        option_budget=4000,
    )

    response = client.post(
        "/v1/build/options",
        json={
            "budget": 4000,
            "use_case": "游戏",
            "game_categories": ["CS2"],
            "ray_tracing": False,
        },
    )

    assert response.status_code == 200
    body = response.json()
    assert len(body["options"]) == 1
    assert body["options"][0]["details"]["gpu_vendor"] == "nvidia"


def test_nvidia_optimized_games_force_nvidia_only_at_stable_three_mode_thresholds() -> None:
    from app.api.builds import _option_gpu_vendors

    pubg_below_threshold = build_service.BuildRequest(
        budget=7800,
        use_case="游戏",
        game_categories=["PUBG"],
    )
    pubg_threshold = pubg_below_threshold.model_copy(update={"budget": 7900})
    delta_below_threshold = build_service.BuildRequest(
        budget=7400,
        use_case="游戏",
        game_categories=["三角洲行动"],
    )
    delta_threshold = delta_below_threshold.model_copy(update={"budget": 7500})

    assert _option_gpu_vendors(pubg_below_threshold, "fps") == (None,)
    assert _option_gpu_vendors(pubg_threshold, "fps") == ("nvidia",)
    assert _option_gpu_vendors(delta_below_threshold, "aaa") == ("nvidia", "amd")
    assert _option_gpu_vendors(delta_threshold, "aaa") == ("nvidia",)


def test_game_plus_office_only_returns_nvidia_options() -> None:
    client = make_client(
        with_template=False,
        vendor_option_templates=(
            ("fps", "used", "nvidia"),
            ("fps", "used", "amd"),
            ("fps", "new", "nvidia"),
            ("fps", "mixed", "nvidia"),
        ),
    )

    response = client.post(
        "/v1/build/options",
        json={
            "budget": 7500,
            "use_case": "游戏兼办公",
            "game_categories": ["CS2"],
            "office_apps": ["Premiere"],
        },
    )

    assert response.status_code == 200
    body = response.json()
    assert len(body["options"]) == 3
    assert all(
        option["details"]["gpu_vendor"] == "nvidia"
        for option in body["options"]
    )


@pytest.mark.parametrize("use_case", ["游戏", "游戏兼办公"])
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


def test_build_options_rejects_partial_modes_from_4500() -> None:
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

    assert response.status_code == 503
    assert "必须同时提供全新、二手和混合采购三套方案" in response.json()["detail"]


def test_build_options_rejects_one_incompatible_mode_from_4500() -> None:
    client = make_client(
        with_template=False,
        option_templates=(("fps", "used"), ("fps", "new")),
        incompatible_option_templates=(("fps", "mixed"),),
    )

    response = client.post(
        "/v1/build/options",
        json={"budget": 7500, "use_case": "游戏", "game_categories": ["CS2"]},
    )

    assert response.status_code == 503
    assert "必须同时提供全新、二手和混合采购三套方案" in response.json()["detail"]


def test_build_options_tries_next_ranked_template_when_first_is_incompatible() -> None:
    client = make_client(
        with_template=False,
        ranked_option_templates=(
            ("a-bad", "fps", "used", False),
            ("z-good", "fps", "used", True),
        ),
        option_budget=4000,
    )

    response = client.post(
        "/v1/build/options",
        json={"budget": 4000, "use_case": "游戏", "game_categories": ["CS2"]},
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
        option_budget=4000,
    )

    response = client.post(
        "/v1/build/options",
        json={"budget": 4000, "use_case": "游戏", "game_categories": ["CS2"]},
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
            ("aaa", "new"),
            ("aaa", "mixed"),
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


def test_build_options_does_not_call_deepseek_for_structured_customization(monkeypatch) -> None:
    client = make_client(
        with_template=False,
        ai_provider_api_key="deepseek-secret",
        option_templates=(("fps", "used"), ("fps", "new"), ("fps", "mixed")),
    )
    def forbidden_provider(*args, **kwargs):
        raise AssertionError("DeepSeek must not decide whether structured generation succeeds")

    monkeypatch.setattr("app.api.builds.select_build_with_deepseek", forbidden_provider, raising=False)

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
    assert len(body["options"]) == 3
    assert all(option["source"] == "template" for option in body["options"])
    assert all(
        option["details"]["parts"][1]["name"].endswith(" WIFI")
        for option in body["options"]
    )

    usage = client.app.state.high_cost_usage_metrics.snapshot()
    assert usage["external_ai_failures"] == 0


def test_build_options_reports_minimum_feasible_total_when_requirement_is_over_budget() -> None:
    client = make_client(
        with_template=False,
        option_templates=(("fps", "new"),),
        option_budget=6000,
        option_total=7200,
    )

    response = client.post(
        "/v1/build/options",
        json={
            "budget": 6000,
            "use_case": "游戏",
            "game_categories": ["CS2"],
            "needs_wireless_network": True,
        },
    )

    assert response.status_code == 503
    assert "最低审核配置约为 7250 元" in response.json()["detail"]
    assert "预算上限 6300 元" in response.json()["detail"]


def test_build_options_reports_missing_approved_capacity_price() -> None:
    client = make_client(
        with_template=False,
        option_templates=(("fps", "new"),),
        option_budget=6000,
    )

    response = client.post(
        "/v1/build/options",
        json={
            "budget": 6000,
            "use_case": "游戏",
            "game_categories": ["CS2"],
            "memory_size": "32GB",
        },
    )

    assert response.status_code == 503
    assert "缺少对应的审核价格" in response.json()["detail"]


def test_unselected_build_options_are_recalculated_without_selection_cache() -> None:
    client = make_client(
        with_template=False,
        option_templates=(("fps", "used"), ("fps", "new"), ("fps", "mixed")),
    )
    payload = {
        "budget": 7500,
        "use_case": "游戏",
        "game_categories": ["CS2"],
        "needs_wireless_network": True,
    }

    first = client.post("/v1/build/options", json=payload)
    second = client.post("/v1/build/options", json=payload)

    assert first.status_code == second.status_code == 200
    assert all(option["selection_id"] for option in first.json()["options"])
    assert all(option["source"] == "template" for option in second.json()["options"])


def test_selected_option_is_reused_for_the_same_requirements() -> None:
    client = make_client(
        with_template=False,
        option_templates=(("fps", "used"), ("fps", "new"), ("fps", "mixed")),
    )
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
    assert second.status_code == 200
    assert second.json()["options"][0]["source"] == "selection_cache"
    assert second.json()["options"][0]["components"] == selected["components"]


def test_selected_option_cache_rejects_total_below_budget_floor() -> None:
    client = make_client(
        with_template=False,
        option_templates=(("fps", "used"), ("fps", "new"), ("fps", "mixed")),
    )
    payload = {
        "budget": 7500,
        "use_case": "游戏",
        "game_categories": ["CS2"],
        "needs_wireless_network": True,
    }
    first = client.post("/v1/build/options", json=payload)
    selected = first.json()["options"][0]
    confirmation = client.post(
        f"/v1/build/options/{selected['selection_id']}/select"
    )
    assert confirmation.status_code == 200

    session_provider = client.app.dependency_overrides[get_session]
    session_iterator = session_provider()
    session = next(session_iterator)
    try:
        row = session.get(BuildSelectionCache, selected["selection_id"])
        cached_payload = dict(row.response_payload)
        cached_payload["estimated_total"] = 7299
        row.response_payload = cached_payload
        session.commit()
    finally:
        session_iterator.close()

    second = client.post("/v1/build/options", json=payload)

    assert second.status_code == 200
    assert second.json()["options"][0]["source"] == "template"
    assert second.json()["options"][0]["estimated_total"] >= 7300


def test_selected_option_cache_invalidates_after_catalog_change() -> None:
    client = make_client(
        with_template=False,
        option_templates=(("fps", "used"), ("fps", "new"), ("fps", "mixed")),
    )
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
    component = session.get(HardwareComponent, "i5-12600kf")
    component.updated_at = datetime.now(timezone.utc) + timedelta(seconds=1)
    session.commit()
    with pytest.raises(StopIteration):
        next(session_override)

    second = client.post("/v1/build/options", json=payload)

    assert second.status_code == 200
    assert all(option["source"] == "template" for option in second.json()["options"])


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
