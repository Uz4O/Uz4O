from __future__ import annotations

import json
from datetime import datetime, timezone
from unittest.mock import ANY

from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker
from sqlalchemy.pool import StaticPool

from app.catalog.repository import seed_hardware_components
from app.catalog.seed import CatalogComponent
from app.core.config import Settings
from app.db import Base, get_session
from app.main import create_app
from app.perf.models import GamePerformanceEstimate


APPROVED_GAME_IDS = [
    "valorant",
    "cs2",
    "pubg",
    "delta-force",
    "teamfight-tactics",
    "league-of-legends",
    "call-of-duty-warzone",
    "cyberpunk-2077",
    "red-dead-redemption-2",
    "gta-v",
    "black-myth-wukong",
    "forza-horizon-6",
    "elden-ring",
    "cities-skylines",
    "minecraft-java-edition",
]


def estimate_row(game_id: str, **overrides) -> GamePerformanceEstimate:
    payload = {
        "cpu_id": "i5-14600k",
        "gpu_id": "rtx-4060",
        "game_id": game_id,
        "resolution": "2k",
        "quality": "medium",
        "average_fps": 77,
        "minimum_fps": 66,
        "maximum_fps": 89,
        "bottleneck_type": "cpu",
        "bottleneck_percent": 11,
        "source_url": "https://pc-builds.com/example",
        "source_fetched_at": datetime(2026, 7, 12, tzinfo=timezone.utc),
        "import_batch": "test",
    }
    payload.update(overrides)
    return GamePerformanceEstimate(**payload)


def make_client(rows: list[GamePerformanceEstimate] | None = None) -> TestClient:
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
                    detail_raw="14代 · LGA1700",
                    specs={"tdp": 125},
                ),
                CatalogComponent(
                    id="rtx-4060",
                    category="gpu",
                    name="RTX 4060",
                    brand="NVIDIA",
                    detail_raw="8GB",
                    specs={"tdp": 115},
                ),
            ],
        )
        session.add_all(rows or [])
        session.commit()

    app = create_app(Settings(_env_file=None, postgres_url=None, redis_url=None))

    def override_session():
        with session_factory() as session:
            yield session

    app.dependency_overrides[get_session] = override_session
    return TestClient(app)


def post_estimate(client: TestClient, games: list[str], resolution: str = "2k"):
    return client.post(
        "/v1/perf/estimate",
        json={
            "hardware": {"cpu": "i5-14600k", "gpu": "rtx-4060"},
            "resolution": resolution,
            "games": games,
        },
    )


def test_perf_estimate_accepts_the_15_game_scope_and_rejects_16() -> None:
    client = make_client()

    assert post_estimate(client, APPROVED_GAME_IDS).status_code == 200
    assert post_estimate(client, APPROVED_GAME_IDS + ["extra-game"]).status_code == 422


def test_perf_estimate_ready_uses_exact_medium_quality_row() -> None:
    client = make_client(
        [
            estimate_row("cyberpunk-2077"),
            estimate_row(
                "cyberpunk-2077",
                resolution="1080p",
                average_fps=999,
                minimum_fps=999,
                maximum_fps=999,
            ),
        ]
    )

    response = post_estimate(client, ["cyberpunk-2077"])

    assert response.status_code == 200
    body = response.json()
    assert body == {
        "status": "ready",
        "average_fps": 77,
        "low_fps": 66,
        "maximum_fps": 89,
        "bottleneck": "cpu",
        "bottleneck_percent": 11,
        "confidence": "medium",
        "advice": "结果为中等画质下的性能估算。",
        "missing_data": [],
        "missing_games": [],
        "source_fetched_at": "2026-07-12T00:00:00Z",
        "game_results": [ANY],
    }
    assert body["game_results"] == [
        {
            "game": "cyberpunk-2077",
            "average_fps": 77,
            "low_fps": 66,
            "maximum_fps": 89,
            "bottleneck": "cpu",
            "bottleneck_percent": 11,
            "confidence": "medium",
            "source_fetched_at": "2026-07-12T00:00:00Z",
        }
    ]


def test_perf_estimate_partial_reports_missing_games() -> None:
    client = make_client([estimate_row("cyberpunk-2077")])

    body = post_estimate(client, ["cyberpunk-2077", "cs2"]).json()

    assert body["status"] == "partial"
    assert body["average_fps"] == 77
    assert body["missing_games"] == ["cs2"]
    assert [result["game"] for result in body["game_results"]] == ["cyberpunk-2077"]


def test_perf_estimate_needs_more_data_without_exact_rows() -> None:
    client = make_client([estimate_row("cyberpunk-2077")])

    body = post_estimate(client, ["cyberpunk-2077"], resolution="4k").json()

    assert body == {
        "status": "needs_more_data",
        "average_fps": None,
        "low_fps": None,
        "maximum_fps": None,
        "bottleneck": None,
        "bottleneck_percent": None,
        "confidence": "low",
        "advice": "当前硬件和游戏组合暂时没有可靠的 FPS 数据。",
        "missing_data": [],
        "missing_games": ["cyberpunk-2077"],
        "source_fetched_at": None,
        "game_results": [],
    }


def test_all_games_expands_only_the_approved_scope_and_aggregates_found_rows() -> None:
    client = make_client(
        [
            estimate_row(
                "valorant",
                average_fps=240,
                minimum_fps=200,
                maximum_fps=280,
                source_fetched_at=datetime(2026, 7, 12, tzinfo=timezone.utc),
            ),
            estimate_row(
                "call-of-duty-warzone",
                average_fps=80,
                minimum_fps=60,
                maximum_fps=100,
                bottleneck_type="gpu",
                bottleneck_percent=20,
                source_fetched_at=datetime(2026, 7, 11, tzinfo=timezone.utc),
            ),
            estimate_row("not-approved", average_fps=1000, minimum_fps=900, maximum_fps=1100),
        ]
    )

    body = post_estimate(client, ["all-games"]).json()

    assert body["status"] == "partial"
    assert body["average_fps"] == 160
    assert body["low_fps"] == 60
    assert body["maximum_fps"] == 280
    assert body["source_fetched_at"] == "2026-07-11T00:00:00Z"
    assert [result["game"] for result in body["game_results"]] == [
        "valorant",
        "call-of-duty-warzone",
    ]
    assert body["missing_games"] == [
        game_id
        for game_id in APPROVED_GAME_IDS
        if game_id not in {"valorant", "call-of-duty-warzone"}
    ]


def test_perf_estimate_rejects_oversized_hardware_ids() -> None:
    client = make_client()

    response = client.post(
        "/v1/perf/estimate",
        json={
            "hardware": {"cpu": "x" * 200, "gpu": "rtx-4060"},
            "resolution": "1080p",
            "games": ["cs2"],
        },
    )

    assert response.status_code == 422


def test_perf_estimate_stream_returns_exact_result_event() -> None:
    client = make_client([estimate_row("cs2")])

    response = client.post(
        "/v1/perf/estimate/stream",
        json={
            "hardware": {"cpu": "i5-14600k", "gpu": "rtx-4060"},
            "resolution": "2k",
            "games": ["cs2"],
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
    assert events[3]["data"]["average_fps"] == 77


def _sse_events(raw: str) -> list[dict]:
    events = []
    for chunk in raw.strip().split("\n\n"):
        lines = chunk.splitlines()
        event_name = next(line.removeprefix("event: ") for line in lines if line.startswith("event: "))
        data = next(line.removeprefix("data: ") for line in lines if line.startswith("data: "))
        events.append({"event": event_name, "data": json.loads(data)})
    return events
