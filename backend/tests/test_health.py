from fastapi.testclient import TestClient

from app.core.config import Settings
from app.main import create_app


def test_application_metadata() -> None:
    app = create_app(Settings(_env_file=None, postgres_url=None, redis_url=None))

    assert app.title == "AI PC Builder API"
    assert app.version == "0.1.0"


def test_health_reports_unconfigured_optional_dependencies() -> None:
    app = create_app(Settings(_env_file=None, postgres_url=None, redis_url=None))
    client = TestClient(app)

    response = client.get("/health")

    assert response.status_code == 200
    assert response.json() == {
        "status": "ok",
        "service": "ai-pc-builder-api",
        "dependencies": {
            "postgres": "not_configured",
            "redis": "not_configured",
        },
    }


def test_health_reports_configured_optional_dependencies() -> None:
    settings = Settings(
        _env_file=None,
        postgres_url="postgresql://app:app@localhost:5432/app",
        redis_url="redis://localhost:6379/0",
    )
    client = TestClient(create_app(settings))

    response = client.get("/health")

    assert response.status_code == 200
    assert response.json()["dependencies"] == {
        "postgres": "configured",
        "redis": "configured",
    }
