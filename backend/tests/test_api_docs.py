from fastapi.testclient import TestClient

from app.core.config import Settings
from app.main import create_app


def test_api_docs_are_disabled_by_default() -> None:
    client = TestClient(
        create_app(Settings(_env_file=None, postgres_url=None, redis_url=None))
    )

    assert client.get("/docs").status_code == 404
    assert client.get("/openapi.json").status_code == 404


def test_api_docs_can_be_enabled_for_development() -> None:
    client = TestClient(
        create_app(
            Settings(
                _env_file=None,
                postgres_url=None,
                redis_url=None,
                api_docs_enabled=True,
            )
        )
    )

    assert client.get("/docs").status_code == 200
    assert client.get("/openapi.json").status_code == 200
