from datetime import datetime, timezone
import json

from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker
from sqlalchemy.pool import StaticPool

from app.catalog.models import ComponentPrice, HardwareComponent
from app.catalog.repository import seed_hardware_components
from app.catalog.seed import CatalogComponent
from app.core.config import Settings
from app.db import Base, get_session
from app.main import create_app


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
                    specs={"socket": "LGA1200"},
                ),
                CatalogComponent(
                    id="psu-550w",
                    category="psu",
                    name="550W Gold",
                    brand="Corsair",
                    detail_raw="550W",
                    specs={"watt": 550},
                ),
            ],
        )
        session.get(HardwareComponent, "rtx-4060").is_recommended = True
        session.get(HardwareComponent, "rtx-4070").is_recommended = True
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
            ]
        )
        session.commit()

    app = create_app(Settings(_env_file=None, postgres_url=None, redis_url=None))

    def override_session():
        with session_factory() as session:
            yield session

    app.dependency_overrides[get_session] = override_session
    return TestClient(app)


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
