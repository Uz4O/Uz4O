from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.core.config import Settings
from app.db import Base, get_session
from app.main import create_app


def make_client(max_request_body_bytes: int) -> TestClient:
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
            max_request_body_bytes=max_request_body_bytes,
        )
    )

    def override_session():
        with session_factory() as session:
            yield session

    app.dependency_overrides[get_session] = override_session
    return TestClient(app)


def test_oversized_request_body_is_rejected_before_route_processing() -> None:
    client = make_client(max_request_body_bytes=16)

    response = client.post("/v1/auth/sms/send", json={"phone": "13800138000"})

    assert response.status_code == 413
    assert response.json()["detail"] == "Request body too large"


def test_request_body_within_limit_is_allowed() -> None:
    client = make_client(max_request_body_bytes=128)

    response = client.post("/v1/auth/sms/send", json={"phone": "13800138000"})

    assert response.status_code == 200
    assert response.json()["sent"] is True
