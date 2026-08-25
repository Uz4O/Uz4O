from datetime import datetime, timezone
import json

from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker
from sqlalchemy.pool import StaticPool

from app.catalog.models import (
    CPUWhitelistPrice,
    ComponentPrice,
    GPUWhitelistPrice,
    HardwareComponent,
)
from app.catalog.repository import seed_hardware_components
from app.catalog.seed import CatalogComponent
from app.core.config import Settings
from app.db import Base, get_session
from app.main import create_app
from app.builds.models import BuildTemplate
from app.upgrade.service import UpgradeGameResult, _improves_target


def make_client() -> TestClient:
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
                    id="i5-10400f",
                    category="cpu",
                    name="i5-10400F",
                    brand="Intel",
                    detail_raw="10代 · LGA1200",
                    specs={"socket": "LGA1200", "perf_index": 55, "tdp": 65},
                ),
                CatalogComponent(
                    id="gtx-1660-super",
                    category="gpu",
                    name="GTX 1660 Super",
                    brand="NVIDIA",
                    detail_raw="6GB",
                    specs={"perf_index": 45, "tdp": 125},
                ),
                CatalogComponent(
                    id="rtx-4060",
                    category="gpu",
                    name="RTX 4060",
                    brand="NVIDIA",
                    detail_raw="8GB",
                    specs={"perf_index": 72, "tdp": 115},
                ),
                CatalogComponent(
                    id="rtx-4070",
                    category="gpu",
                    name="RTX 4070",
                    brand="NVIDIA",
                    detail_raw="12GB",
                    specs={"perf_index": 93, "tdp": 200},
                ),
                CatalogComponent(
                    id="b460m",
                    category="motherboard",
                    name="B460M Mortar",
                    brand="微星",
                    detail_raw="Intel · LGA1200 · B460",
                    specs={"socket": "LGA1200", "mem_type": "DDR4"},
                ),
                CatalogComponent(
                    id="psu-550w",
                    category="psu",
                    name="550W Gold",
                    brand="Corsair",
                    detail_raw="550W",
                    specs={"watt": 550},
                ),
                CatalogComponent(
                    id="test-am5-cpu",
                    category="cpu",
                    name="Test AM5 CPU",
                    brand="AMD",
                    detail_raw="AM5",
                    specs={"socket": "AM5", "perf_index": 90, "tdp": 120},
                ),
                CatalogComponent(
                    id="test-b650",
                    category="motherboard",
                    name="Test B650",
                    brand="Test",
                    detail_raw="AM5 · DDR5",
                    specs={"socket": "AM5", "mem_type": "DDR5"},
                ),
                CatalogComponent(
                    id="test-uncurated-b650",
                    category="motherboard",
                    name="Test Uncurated B650",
                    brand="Test",
                    detail_raw="AM5 · DDR5",
                    specs={"socket": "AM5", "mem_type": "DDR5"},
                ),
                CatalogComponent(
                    id="test-ddr5-16gb",
                    category="ram",
                    name="Test DDR5 16GB",
                    brand="Test",
                    detail_raw="DDR5 · 16GB",
                    specs={"type": "DDR5", "capacity_gb": 16},
                ),
                CatalogComponent(
                    id="test-ddr4-16gb",
                    category="ram",
                    name="Test DDR4 16GB",
                    brand="Test",
                    detail_raw="DDR4 · 16GB",
                    specs={"type": "DDR4", "capacity_gb": 16, "modules": 2},
                ),
                CatalogComponent(
                    id="test-storage-512gb",
                    category="storage",
                    name="Test TLC SSD 512GB",
                    brand="Test",
                    detail_raw="512GB · TLC",
                    specs={"capacity_gb": 512, "flash_type": "TLC"},
                ),
                CatalogComponent(
                    id="test-cooler-6-heatpipe",
                    category="cooler",
                    name="Test 6 Heatpipe Cooler",
                    brand="Test",
                    detail_raw="6 heatpipes",
                    specs={"heatpipes": 6, "towers": 1},
                ),
                CatalogComponent(
                    id="test-hot-cpu-cooler",
                    category="cooler",
                    name="Test Dual Tower Cooler",
                    brand="Test",
                    detail_raw="dual tower · 6 heatpipes",
                    specs={"heatpipes": 6, "towers": 2},
                ),
                CatalogComponent(
                    id="test-case",
                    category="case",
                    name="Test Mid Tower Case",
                    brand="Test",
                    detail_raw="ATX mid tower",
                    specs={"form_factor": "atx_mid_tower"},
                ),
                CatalogComponent(
                    id="test-gpu-400w",
                    category="gpu",
                    name="Test GPU 400W",
                    brand="Test",
                    detail_raw="400W",
                    specs={"perf_index": 100, "tdp": 400},
                ),
                CatalogComponent(
                    id="test-psu-850w",
                    category="psu",
                    name="Test 850W PSU",
                    brand="Test",
                    detail_raw="850W",
                    specs={"watt": 850},
                ),
                CatalogComponent(
                    id="test-used-only-cpu",
                    category="cpu",
                    name="Test Used Only CPU",
                    brand="Test",
                    detail_raw="AM5",
                    specs={"socket": "AM5", "perf_index": 120, "tdp": 120},
                ),
                CatalogComponent(
                    id="test-used-only-gpu",
                    category="gpu",
                    name="Test Used Only GPU",
                    brand="Test",
                    detail_raw="200W",
                    specs={"perf_index": 80, "tdp": 200},
                ),
            ],
        )
        session.get(HardwareComponent, "rtx-4060").is_recommended = True
        session.get(HardwareComponent, "rtx-4070").is_recommended = True
        for component_id in (
            "test-am5-cpu",
            "test-b650",
            "test-ddr5-16gb",
            "test-ddr4-16gb",
            "test-storage-512gb",
            "test-cooler-6-heatpipe",
            "test-hot-cpu-cooler",
            "test-case",
            "test-gpu-400w",
            "test-psu-850w",
        ):
            session.get(HardwareComponent, component_id).is_recommended = True
        session.add_all(
            [
                ComponentPrice(
                    component_id="rtx-4060",
                    reference_price=2200,
                    price_range_low=2100,
                    price_range_high=2400,
                    source="manual",
                    accepted_count=3,
                    rejected_count=0,
                    review_reasons=[],
                    approved_at=datetime.now(timezone.utc),
                ),
                ComponentPrice(
                    component_id="rtx-4070",
                    reference_price=4300,
                    price_range_low=4100,
                    price_range_high=4600,
                    source="manual",
                    accepted_count=3,
                    rejected_count=0,
                    review_reasons=[],
                    approved_at=datetime.now(timezone.utc),
                ),
                ComponentPrice(
                    component_id="test-am5-cpu",
                    reference_price=2000,
                    source="manual",
                    accepted_count=3,
                    rejected_count=0,
                    review_reasons=[],
                    approved_at=datetime.now(timezone.utc),
                ),
                ComponentPrice(
                    component_id="test-b650",
                    reference_price=1200,
                    source="manual",
                    accepted_count=3,
                    rejected_count=0,
                    review_reasons=[],
                    approved_at=datetime.now(timezone.utc),
                ),
                ComponentPrice(
                    component_id="test-uncurated-b650",
                    reference_price=100,
                    source="crawler",
                    accepted_count=3,
                    rejected_count=0,
                    review_reasons=[],
                    approved_at=datetime.now(timezone.utc),
                ),
                ComponentPrice(
                    component_id="test-ddr5-16gb",
                    reference_price=600,
                    source="manual",
                    accepted_count=3,
                    rejected_count=0,
                    review_reasons=[],
                    approved_at=datetime.now(timezone.utc),
                ),
                ComponentPrice(
                    component_id="test-ddr4-16gb",
                    reference_price=400,
                    source="manual",
                    accepted_count=3,
                    rejected_count=0,
                    review_reasons=[],
                    approved_at=datetime.now(timezone.utc),
                ),
                ComponentPrice(
                    component_id="test-storage-512gb",
                    reference_price=300,
                    source="manual",
                    accepted_count=3,
                    rejected_count=0,
                    review_reasons=[],
                    approved_at=datetime.now(timezone.utc),
                ),
                ComponentPrice(
                    component_id="test-cooler-6-heatpipe",
                    reference_price=100,
                    source="manual",
                    accepted_count=3,
                    rejected_count=0,
                    review_reasons=[],
                    approved_at=datetime.now(timezone.utc),
                ),
                ComponentPrice(
                    component_id="test-hot-cpu-cooler",
                    reference_price=200,
                    source="manual",
                    accepted_count=3,
                    rejected_count=0,
                    review_reasons=[],
                    approved_at=datetime.now(timezone.utc),
                ),
                ComponentPrice(
                    component_id="test-case",
                    reference_price=100,
                    source="manual",
                    accepted_count=3,
                    rejected_count=0,
                    review_reasons=[],
                    approved_at=datetime.now(timezone.utc),
                ),
                ComponentPrice(
                    component_id="test-gpu-400w",
                    reference_price=5000,
                    source="manual",
                    accepted_count=3,
                    rejected_count=0,
                    review_reasons=[],
                    approved_at=datetime.now(timezone.utc),
                ),
                ComponentPrice(
                    component_id="test-psu-850w",
                    reference_price=800,
                    source="manual",
                    accepted_count=3,
                    rejected_count=0,
                    review_reasons=[],
                    approved_at=datetime.now(timezone.utc),
                ),
                ComponentPrice(
                    component_id="test-used-only-cpu",
                    reference_price=500,
                    source="manual",
                    accepted_count=3,
                    rejected_count=0,
                    review_reasons=[],
                    approved_at=datetime.now(timezone.utc),
                ),
                ComponentPrice(
                    component_id="test-used-only-gpu",
                    reference_price=1000,
                    source="manual",
                    accepted_count=3,
                    rejected_count=0,
                    review_reasons=[],
                    approved_at=datetime.now(timezone.utc),
                ),
            ]
        )
        session.add_all(
            [
                CPUWhitelistPrice(
                    component_id="test-used-only-cpu",
                    name="Test Used Only CPU",
                    used_price=500,
                    new_tray_price=None,
                    source="manual",
                    approved_at=datetime.now(timezone.utc),
                ),
                GPUWhitelistPrice(
                    component_id="test-used-only-gpu",
                    name="Test Used Only GPU",
                    used_price=1000,
                    new_price=None,
                    source="manual",
                    approved_at=datetime.now(timezone.utc),
                ),
            ]
        )
        session.add_all(_reviewed_upgrade_templates())
        session.commit()

    app = create_app(Settings(_env_file=None, postgres_url=None, redis_url=None))

    def override_session():
        with session_factory() as session:
            yield session

    app.dependency_overrides[get_session] = override_session
    return TestClient(app)


def _reviewed_upgrade_templates() -> list[BuildTemplate]:
    base_parts = {
        "cpu": ("i5-10400f", "i5-10400F", 800),
        "motherboard": ("b460m", "B460M Mortar", 500),
        "gpu": ("rtx-4060", "RTX 4060", 2200),
        "ram": ("test-ddr4-16gb", "Test DDR4 16GB", 400),
        "storage": ("test-storage-512gb", "Test TLC SSD 512GB", 300),
        "psu": ("psu-550w", "550W Gold", 500),
        "cooler": ("test-cooler-6-heatpipe", "Test 6 Heatpipe Cooler", 100),
        "case": ("test-case", "Test Mid Tower Case", 100),
    }
    templates = [
        _reviewed_template(f"test-basic-{direction}", direction, base_parts)
        for direction in ("fps", "aaa", "balanced")
    ]
    templates.append(
        _reviewed_template(
            "test-fps-platform",
            "fps",
            {
                **base_parts,
                "cpu": ("test-am5-cpu", "Test AM5 CPU", 2000),
                "motherboard": ("test-b650", "Test B650", 1200),
                "gpu": ("gtx-1660-super", "GTX 1660 Super", 1000),
                "ram": ("test-ddr5-16gb", "Test DDR5 16GB", 600),
                "cooler": ("test-hot-cpu-cooler", "Test Dual Tower Cooler", 200),
            },
        )
    )
    templates.append(
        _reviewed_template(
            "test-aaa-high-gpu",
            "aaa",
            {
                **base_parts,
                "gpu": ("test-gpu-400w", "Test GPU 400W", 5000),
                "psu": ("test-psu-850w", "Test 850W PSU", 800),
            },
        )
    )
    return templates


def _reviewed_template(
    template_id: str,
    direction: str,
    parts: dict[str, tuple[str, str, int]],
) -> BuildTemplate:
    part_rows = [
        {
            "role": role,
            "component_id": component_id,
            "name": name,
            "condition": "new",
            "reference_price": price,
            "price_source": "manual-test-anchor",
            "price_date": "2026-08-24",
            "specs": {},
        }
        for role, (component_id, name, price) in parts.items()
    ]
    return BuildTemplate(
        id=template_id,
        title=f"Test {direction} reviewed anchor",
        budget_min=5000,
        budget_max=5500,
        use_cases=["游戏"],
        tags=[direction, "new"],
        components={role: values[0] for role, values in parts.items()},
        estimated_total=sum(values[2] for values in parts.values()),
        explanation="reviewed test anchor",
        details={
            "target_budget": 5000,
            "direction": direction,
            "purchase_mode": "new",
            "gpu_vendor": "nvidia",
            "parts": part_rows,
            "suitable_user": "test",
            "price_date": "2026-08-24",
        },
        status="active",
    )


def test_upgrade_plan_recommends_best_gpu_upgrade_within_budget() -> None:
    client = make_client()

    response = client.post(
        "/v1/upgrade/plan",
        json={
            "budget": 3000,
            "need": "提升游戏性能",
            "games": ["CS2", "PUBG"],
            "current": {
                "cpu": "i5-10400f",
                "gpu": "gtx-1660-super",
                "motherboard": "b460m",
                "psu": "psu-550w",
            },
        },
    )

    assert response.status_code == 200
    body = response.json()
    assert body["status"] == "ready"
    assert body["total_estimated_price"] == 2200
    assert body["primary_bottleneck"] == "gpu"
    assert body["steps"][0]["role"] == "gpu"
    assert body["steps"][0]["from_component_id"] == "gtx-1660-super"
    assert body["steps"][0]["to_component_id"] == "rtx-4060"
    assert body["steps"][0]["estimated_price"] == 2200
    assert "预算内" in body["summary"]


def test_upgrade_plan_requests_missing_core_configuration() -> None:
    client = make_client()

    response = client.post(
        "/v1/upgrade/plan",
        json={"budget": 3000, "current": {"cpu": "i5-10400f"}},
    )

    assert response.status_code == 200
    body = response.json()
    assert body["status"] == "needs_more_info"
    assert body["steps"] == []
    assert "显卡" in body["missing_fields"]


def test_upgrade_plan_does_not_spend_when_current_hardware_meets_target() -> None:
    client = make_client()

    response = client.post(
        "/v1/upgrade/plan",
        json={
            "budget": 4000,
            "need": "游戏帧率和画质",
            "games": ["cs2"],
            "resolution": "2k",
            "target_fps": 60,
            "current": {
                "cpu": "i5-10400f",
                "gpu": "gtx-1660-super",
                "motherboard": "b460m",
                "psu": "psu-550w",
            },
        },
    )

    assert response.status_code == 200
    body = response.json()
    assert body["status"] == "already_sufficient"
    assert body["total_estimated_price"] == 0
    assert body["steps"] == []
    assert body["target_met"] is True
    assert body["game_results"][0]["before_fps"] == body["game_results"][0]["after_fps"]


def test_upgrade_plan_groups_reviewed_platform_dependencies_together() -> None:
    client = make_client()

    response = client.post(
        "/v1/upgrade/plan",
        json={
            "budget": 4000,
            "need": "游戏帧率和画质",
            "games": ["cs2"],
            "resolution": "2k",
            "target_fps": 160,
            "current": {
                "cpu": "i5-10400f",
                "gpu": "gtx-1660-super",
                "motherboard": "b460m",
                "psu": "psu-550w",
            },
        },
    )

    assert response.status_code == 200
    body = response.json()
    assert body["status"] == "ready"
    assert body["target_met"] is True
    assert body["anchor_template_id"] == "test-fps-platform"
    assert body["price_date"] == "2026-08-24"
    assert [step["role"] for step in body["steps"]] == [
        "cpu",
        "motherboard",
        "ram",
        "cooler",
    ]
    assert {step["bundle_id"] for step in body["steps"]} == {"platform"}
    assert all(step["required_together"] for step in body["steps"])


def test_reviewed_gpu_anchor_keeps_a_stronger_owned_cpu() -> None:
    client = make_client()

    response = client.post(
        "/v1/upgrade/plan",
        json={
            "budget": 6000,
            "need": "游戏帧率和画质",
            "games": ["cyberpunk-2077"],
            "resolution": "4k",
            "target_fps": 120,
            "current": {
                "cpu": "test-am5-cpu",
                "gpu": "gtx-1660-super",
                "motherboard": "test-b650",
                "ram": "test-ddr5-16gb",
                "psu": "psu-550w",
            },
        },
    )

    assert response.status_code == 200
    body = response.json()
    assert body["status"] == "ready"
    assert body["anchor_template_id"] == "test-basic-aaa"
    assert [step["role"] for step in body["steps"]] == ["gpu"]
    assert all(step["role"] != "cpu" for step in body["steps"])
    assert any("显卡长度" in note and "机箱" in note for note in body["notes"])


def test_reviewed_cpu_anchor_keeps_a_stronger_owned_gpu() -> None:
    client = make_client()

    response = client.post(
        "/v1/upgrade/plan",
        json={
            "budget": 4000,
            "need": "游戏帧率和画质",
            "games": ["cs2"],
            "resolution": "2k",
            "target_fps": 500,
            "current": {
                "cpu": "i5-10400f",
                "gpu": "rtx-4070",
                "motherboard": "b460m",
                "ram": "test-ddr4-16gb",
                "psu": "test-psu-850w",
            },
        },
    )

    assert response.status_code == 200
    body = response.json()
    assert body["status"] == "ready"
    assert body["anchor_template_id"] == "test-fps-platform"
    assert [step["role"] for step in body["steps"]] == [
        "cpu",
        "motherboard",
        "ram",
        "cooler",
    ]
    assert all(step["role"] != "gpu" for step in body["steps"])


def test_closest_plan_must_improve_the_hardest_selected_game() -> None:
    current = [
        UpgradeGameResult(
            game="cs2",
            before_fps=219,
            after_fps=219,
            target_fps=500,
            met=False,
        )
    ]
    unchanged = [
        UpgradeGameResult(
            game="cs2",
            before_fps=219,
            after_fps=219,
            target_fps=500,
            met=False,
        )
    ]
    improved = [
        UpgradeGameResult(
            game="cs2",
            before_fps=219,
            after_fps=240,
            target_fps=500,
            met=False,
        )
    ]

    assert _improves_target(current, unchanged) is False
    assert _improves_target(current, improved) is True


def test_upgrade_no_plan_response_keeps_current_schema() -> None:
    client = make_client()

    response = client.post(
        "/v1/upgrade/plan",
        json={
            "budget": 0,
            "need": "提升游戏性能",
            "games": ["cs2"],
            "resolution": "1080p",
            "target_fps": 500,
            "current": {
                "cpu": "i5-10400f",
                "gpu": "gtx-1660-super",
                "motherboard": "b460m",
                "psu": "psu-550w",
            },
        },
    )

    assert response.status_code == 200
    body = response.json()
    assert body["status"] == "no_plan"
    assert body["resolution"] == "1080p"
    assert body["target_fps"] == 500
    assert body["target_met"] is None
    assert body["game_results"] == []


def test_upgrade_plan_adds_board_and_ram_when_cpu_changes_platform() -> None:
    client = make_client()

    response = client.post(
        "/v1/upgrade/plan",
        json={
            "budget": 4000,
            "need": "帮我找短板",
            "current": {
                "cpu": "i5-10400f",
                "gpu": "gtx-1660-super",
                "motherboard": "b460m",
                "psu": "psu-550w",
            },
        },
    )

    assert response.status_code == 200
    body = response.json()
    assert body["status"] == "ready"
    assert body["total_estimated_price"] == 3800
    assert [step["role"] for step in body["steps"]] == ["cpu", "motherboard", "ram"]


def test_upgrade_plan_adds_psu_when_gpu_requires_more_power() -> None:
    client = make_client()

    response = client.post(
        "/v1/upgrade/plan",
        json={
            "budget": 6000,
            "need": "提升游戏性能",
            "games": ["cyberpunk-2077"],
            "resolution": "4k",
            "target_fps": 120,
            "current": {
                "cpu": "i5-10400f",
                "gpu": "gtx-1660-super",
                "motherboard": "b460m",
                "psu": "psu-550w",
            },
        },
    )

    assert response.status_code == 200
    body = response.json()
    assert body["status"] == "ready"
    assert body["total_estimated_price"] == 5800
    assert [step["role"] for step in body["steps"]] == ["gpu", "psu"]
    assert {step["bundle_id"] for step in body["steps"]} == {"graphics"}
    assert all(step["required_together"] for step in body["steps"])
    assert body["anchor_template_id"] == "test-aaa-high-gpu"
    assert body["target_met"] is False
    assert body["game_results"][0]["after_fps"] > body["game_results"][0]["before_fps"]


def test_upgrade_plan_uses_all_games_and_returns_closest_honest_result() -> None:
    client = make_client()

    response = client.post(
        "/v1/upgrade/plan",
        json={
            "budget": 3000,
            "need": "提升游戏性能",
            "games": ["valorant", "cyberpunk-2077"],
            "resolution": "4k",
            "target_fps": 144,
            "current": {
                "cpu": "i5-10400f",
                "gpu": "gtx-1660-super",
                "motherboard": "b460m",
                "psu": "psu-550w",
            },
        },
    )

    assert response.status_code == 200
    body = response.json()
    assert body["status"] == "ready"
    assert body["target_met"] is False
    assert {result["game"] for result in body["game_results"]} == {
        "valorant",
        "cyberpunk-2077",
    }
    assert any(not result["met"] for result in body["game_results"])
    assert "最接近" in body["summary"]


def test_upgrade_plan_rejects_oversized_current_hardware_fields() -> None:
    client = make_client()

    response = client.post(
        "/v1/upgrade/plan",
        json={
            "budget": 3000,
            "need": "提升游戏性能",
            "games": ["CS2"],
            "current": {
                "cpu": "x" * 200,
                "gpu": "gtx-1660-super",
                "motherboard": "b460m",
                "psu": "psu-550w",
            },
        },
    )

    assert response.status_code == 422


def test_upgrade_plan_stream_returns_progress_and_result_events() -> None:
    client = make_client()

    response = client.post(
        "/v1/upgrade/plan/stream",
        json={
            "budget": 3000,
            "need": "提升游戏性能",
            "games": ["CS2", "PUBG"],
            "current": {
                "cpu": "i5-10400f",
                "gpu": "gtx-1660-super",
                "motherboard": "b460m",
                "psu": "psu-550w",
            },
        },
    )

    assert response.status_code == 200
    assert response.headers["content-type"].startswith("text/event-stream")
    events = _sse_events(response.text)
    assert [event["event"] for event in events] == ["progress", "progress", "cache", "result"]
    assert events[0]["data"]["stage"] == "received"
    assert events[1]["data"]["stage"] == "planning"
    assert events[2]["data"] == {"status": "MISS"}
    assert events[3]["data"]["status"] == "ready"
    assert events[3]["data"]["primary_bottleneck"] == "gpu"


def _sse_events(raw: str) -> list[dict]:
    events = []
    for chunk in raw.strip().split("\n\n"):
        lines = chunk.splitlines()
        event_name = next(line.removeprefix("event: ") for line in lines if line.startswith("event: "))
        data = next(line.removeprefix("data: ") for line in lines if line.startswith("data: "))
        events.append({"event": event_name, "data": json.loads(data)})
    return events
