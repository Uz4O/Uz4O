from typing import Optional

from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.core.config import Settings
from app.db import Base, get_session
from app.main import create_app


def make_client(
    ops_token: Optional[str] = "ops-secret",
    max_requests: int = 10,
    estimated_cost_cents: int = 0,
) -> TestClient:
    engine = create_engine(
        "sqlite+pysqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(engine)
    session_factory = sessionmaker(bind=engine)

    app = create_app(
        Settings(
            _env_file=None,
            postgres_url=None,
            redis_url=None,
            ops_token=ops_token,
            high_cost_rate_limit_max_requests=max_requests,
            high_cost_estimated_cost_cents=estimated_cost_cents,
            response_cache_ttl_seconds=60,
            response_cache_max_entries=20,
        )
    )

    def override_session():
        with session_factory() as session:
            yield session

    app.dependency_overrides[get_session] = override_session
    return TestClient(app)


def test_ops_usage_is_unavailable_without_configured_token() -> None:
    client = make_client(ops_token=None)

    response = client.get("/v1/ops/usage")

    assert response.status_code == 404


def test_ops_usage_requires_matching_token() -> None:
    client = make_client(ops_token="ops-secret")

    missing = client.get("/v1/ops/usage")
    wrong = client.get("/v1/ops/usage", headers={"X-Ops-Token": "wrong"})

    assert missing.status_code == 401
    assert wrong.status_code == 401


def test_ops_usage_tracks_high_cost_requests_cache_and_rate_limits() -> None:
    client = make_client(ops_token="ops-secret", max_requests=2, estimated_cost_cents=7)
    payload = {"text": "i7-14700F + RTX4060 + H610 主板 + 500W 电源，商家报价 6999"}

    first = client.post("/v1/review/analyze", json=payload)
    second = client.post("/v1/review/analyze", json=payload)
    limited = client.post("/v1/review/analyze", json=payload)

    assert first.status_code == 200
    assert first.headers["x-cache"] == "MISS"
    assert second.status_code == 200
    assert second.headers["x-cache"] == "HIT"
    assert limited.status_code == 429

    response = client.get("/v1/ops/usage", headers={"X-Ops-Token": "ops-secret"})

    assert response.status_code == 200
    body = response.json()
    high_cost = body["high_cost"]
    assert high_cost["total_requests"] == 2
    assert high_cost["rate_limited_requests"] == 1
    assert high_cost["cache_hits"] == 1
    assert high_cost["cache_misses"] == 1
    assert high_cost["estimated_cost_cents"] == 7
    assert high_cost["actual_ai_cost_cents"] == 0
    assert high_cost["external_ai_failures"] == 0
    assert high_cost["by_endpoint"]["/v1/review/analyze"] == {
        "requests": 2,
        "rate_limited_requests": 1,
        "cache_hits": 1,
        "cache_misses": 1,
        "estimated_cost_cents": 7,
        "actual_ai_cost_cents": 0,
        "external_ai_failures": 0,
    }


def test_ops_usage_reports_actual_ai_cost_and_failures() -> None:
    client = make_client(ops_token="ops-secret")
    client.app.state.high_cost_usage_metrics.record_actual_ai_cost(
        "/v1/build/generate",
        123,
    )
    client.app.state.high_cost_usage_metrics.record_external_ai_failure(
        "/v1/build/generate",
    )

    response = client.get("/v1/ops/usage", headers={"X-Ops-Token": "ops-secret"})

    assert response.status_code == 200
    high_cost = response.json()["high_cost"]
    assert high_cost["actual_ai_cost_cents"] == 123
    assert high_cost["external_ai_failures"] == 1
    assert high_cost["by_endpoint"]["/v1/build/generate"] == {
        "requests": 0,
        "rate_limited_requests": 0,
        "cache_hits": 0,
        "cache_misses": 0,
        "estimated_cost_cents": 0,
        "actual_ai_cost_cents": 123,
        "external_ai_failures": 1,
    }
