from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

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
    app = create_app(Settings(_env_file=None, postgres_url=None, redis_url=None))

    def override_session():
        with session_factory() as session:
            yield session

    app.dependency_overrides[get_session] = override_session
    return TestClient(app)


def test_public_responses_include_basic_security_headers() -> None:
    client = make_client()

    progress = client.get("/progress")
    health = client.get("/health")

    for response in (progress, health):
        assert response.headers["x-content-type-options"] == "nosniff"
        assert response.headers["x-frame-options"] == "DENY"
        assert response.headers["referrer-policy"] == "no-referrer"


def test_sensitive_api_responses_are_not_cached() -> None:
    client = make_client()

    responses = [
        client.get("/v1/auth/me"),
        client.get("/v1/profile/onboarding"),
        client.get("/v1/builds"),
        client.get("/v1/ops/usage"),
    ]

    for response in responses:
        assert response.headers["cache-control"] == "no-store"
        assert response.headers["pragma"] == "no-cache"
