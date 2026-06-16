import json

from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker
from sqlalchemy.pool import StaticPool

from app.catalog.repository import seed_hardware_components
from app.catalog.seed import CatalogComponent
from app.core.config import Settings
from app.db import Base, get_session
from app.main import create_app


def make_client(with_perf_indexes: bool = True) -> TestClient:
    engine = create_engine(
        "sqlite+pysqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(engine)
    session_factory = sessionmaker(bind=engine)
    cpu_specs = {"perf_index": 78, "tdp": 125} if with_perf_indexes else {"tdp": 125}
    gpu_specs = {"perf_index": 72, "tdp": 115} if with_perf_indexes else {"tdp": 115}
    with Session(engine) as session:
        seed_hardware_components(
            session,
            [
                CatalogComponent(
                    id="i5-14600k",
                    category="cpu",
                    name="i5-14600K",
                    brand="Intel",
                    detail_raw="14代 · LGA1700",
                    specs=cpu_specs,
                ),
                CatalogComponent(
                    id="rtx-4060",
                    category="gpu",
                    name="RTX 4060",
                    brand="NVIDIA",
                    detail_raw="8GB",
                    specs=gpu_specs,
                ),
            ],
        )

    app = create_app(Settings(_env_file=None, postgres_url=None, redis_url=None))

    def override_session():
        with session_factory() as session:
            yield session

    app.dependency_overrides[get_session] = override_session
    return TestClient(app)


def test_perf_estimate_returns_fps_bottleneck_and_advice() -> None:
    client = make_client()

    response = client.post(
        "/v1/perf/estimate",
        json={
            "hardware": {"cpu": "i5-14600k", "gpu": "rtx-4060"},
            "resolution": "2k",
            "games": ["CS2", "PUBG"],
        },
    )

    assert response.status_code == 200
    body = response.json()
    assert body["status"] == "ready"
    assert body["average_fps"] > 0
    assert body["low_fps"] < body["average_fps"]
    assert body["bottleneck"] == "gpu"
    assert body["confidence"] == "medium"
    assert len(body["game_results"]) == 2
    assert body["game_results"][0]["game"] == "CS2"
    assert "显卡" in body["advice"]


def test_perf_estimate_needs_more_data_without_perf_indexes() -> None:
    client = make_client(with_perf_indexes=False)

    response = client.post(
        "/v1/perf/estimate",
        json={
            "hardware": {"cpu": "i5-14600k", "gpu": "rtx-4060"},
            "resolution": "1080p",
            "games": ["CS2"],
        },
    )

    assert response.status_code == 200
    body = response.json()
    assert body["status"] == "needs_more_data"
    assert body["game_results"] == []
    assert "perf_index" in body["missing_data"]


def test_perf_estimate_rejects_oversized_hardware_ids() -> None:
    client = make_client()

    response = client.post(
        "/v1/perf/estimate",
        json={
            "hardware": {"cpu": "x" * 200, "gpu": "rtx-4060"},
            "resolution": "1080p",
            "games": ["CS2"],
        },
    )

    assert response.status_code == 422


def test_perf_estimate_stream_returns_progress_and_result_events() -> None:
    client = make_client()

    response = client.post(
        "/v1/perf/estimate/stream",
        json={
            "hardware": {"cpu": "i5-14600k", "gpu": "rtx-4060"},
            "resolution": "2k",
            "games": ["CS2"],
        },
    )

    assert response.status_code == 200
    assert response.headers["content-type"].startswith("text/event-stream")
    events = _sse_events(response.text)
    assert [event["event"] for event in events] == ["progress", "progress", "cache", "result"]
    assert events[0]["data"]["stage"] == "received"
    assert events[1]["data"]["stage"] == "estimating"
    assert events[2]["data"] == {"status": "MISS"}
    assert events[3]["data"]["status"] == "ready"
    assert events[3]["data"]["bottleneck"] == "gpu"


def _sse_events(raw: str) -> list[dict]:
    events = []
    for chunk in raw.strip().split("\n\n"):
        lines = chunk.splitlines()
        event_name = next(line.removeprefix("event: ") for line in lines if line.startswith("event: "))
        data = next(line.removeprefix("data: ") for line in lines if line.startswith("data: "))
        events.append({"event": event_name, "data": json.loads(data)})
    return events
