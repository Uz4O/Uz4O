from datetime import datetime, timezone
import json

from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker
from sqlalchemy.pool import StaticPool

from app.catalog.models import ComponentPrice
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
                    id="i7-14700f",
                    category="cpu",
                    name="i7-14700F",
                    brand="Intel",
                    detail_raw="14代 Raptor Lake Refresh · LGA1700",
                    specs={"socket": "LGA1700", "tdp": 219},
                ),
                CatalogComponent(
                    id="rtx-4060",
                    category="gpu",
                    name="RTX 4060",
                    brand="NVIDIA",
                    detail_raw="8GB · Ada",
                    specs={"tdp": 115},
                ),
                CatalogComponent(
                    id="h610m",
                    category="motherboard",
                    name="H610M",
                    brand="华硕",
                    detail_raw="Intel · LGA1700 · H610",
                    specs={"socket": "LGA1700"},
                ),
                CatalogComponent(
                    id="psu-500w",
                    category="psu",
                    name="500W 电源",
                    brand="未知",
                    detail_raw="500W",
                    specs={"watt": 500},
                ),
            ],
        )
        session.add_all(
            [
                ComponentPrice(
                    component_id="i7-14700f",
                    reference_price=2100,
                    price_range_low=2000,
                    price_range_high=2300,
                    source="manual",
                    accepted_count=3,
                    rejected_count=0,
                    review_reasons=[],
                    approved_at=datetime.now(timezone.utc),
                ),
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
                    component_id="h610m",
                    reference_price=450,
                    price_range_low=400,
                    price_range_high=550,
                    source="manual",
                    accepted_count=3,
                    rejected_count=0,
                    review_reasons=[],
                    approved_at=datetime.now(timezone.utc),
                ),
                ComponentPrice(
                    component_id="psu-500w",
                    reference_price=180,
                    price_range_low=160,
                    price_range_high=220,
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


def test_review_analyze_flags_unbalanced_seller_configuration() -> None:
    client = make_client()

    response = client.post(
        "/v1/review/analyze",
        json={"text": "i7-14700F + RTX4060 + H610 主板 + 500W 电源，商家报价 6999"},
    )

    assert response.status_code == 200
    body = response.json()
    assert body["risk_level"] == "error"
    assert body["seller_price"] == 6999
    assert body["reference_total"] == 4930
    assert "不建议直接买" in body["summary"]
    assert body["detected_components"]["cpu"]["component_id"] == "i7-14700f"
    assert body["detected_components"]["gpu"]["component_id"] == "rtx-4060"
    assert body["detected_components"]["motherboard"]["component_id"] == "h610m"
    assert any(finding["code"] == "cpu_gpu_imbalance" for finding in body["findings"])
    assert any(finding["code"] == "low_end_board_for_i7" for finding in body["findings"])
    assert any(finding["code"] == "seller_price_high" for finding in body["findings"])
    assert "具体品牌和型号" in body["questions_for_seller"][0]
    assert "重新配一套" not in body["reply_text"]


def test_review_analyze_rejects_too_short_input() -> None:
    client = make_client()

    response = client.post("/v1/review/analyze", json={"text": "RTX4060"})

    assert response.status_code == 422


def test_review_analyze_stream_returns_progress_and_result_events() -> None:
    client = make_client()

    response = client.post(
        "/v1/review/analyze/stream",
        json={"text": "i7-14700F + RTX4060 + H610 主板 + 500W 电源，商家报价 6999"},
    )

    assert response.status_code == 200
    assert response.headers["content-type"].startswith("text/event-stream")
    events = _sse_events(response.text)
    assert [event["event"] for event in events] == ["progress", "progress", "cache", "result"]
    assert events[0]["data"]["stage"] == "received"
    assert events[1]["data"]["stage"] == "analyzing"
    assert events[2]["data"] == {"status": "MISS"}
    assert events[3]["data"]["risk_level"] == "error"
    assert events[3]["data"]["seller_price"] == 6999


def test_review_analyze_stream_reuses_cached_result() -> None:
    client = make_client()
    payload = {"text": "i7-14700F + RTX4060 + H610 主板 + 500W 电源，商家报价 6999"}

    first = client.post("/v1/review/analyze/stream", json=payload)
    second = client.post("/v1/review/analyze/stream", json=payload)

    assert first.status_code == 200
    assert second.status_code == 200
    assert _sse_events(first.text)[2]["data"] == {"status": "MISS"}
    assert _sse_events(second.text)[2]["data"] == {"status": "HIT"}


def _sse_events(raw: str) -> list[dict]:
    events = []
    for chunk in raw.strip().split("\n\n"):
        lines = chunk.splitlines()
        event_name = next(line.removeprefix("event: ") for line in lines if line.startswith("event: "))
        data = next(line.removeprefix("data: ") for line in lines if line.startswith("data: "))
        events.append({"event": event_name, "data": json.loads(data)})
    return events
