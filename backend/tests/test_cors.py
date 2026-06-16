from fastapi.testclient import TestClient

from app.core.config import Settings
from app.main import create_app


def test_cors_is_not_open_by_default() -> None:
    client = TestClient(
        create_app(Settings(_env_file=None, postgres_url=None, redis_url=None))
    )

    response = client.options(
        "/health",
        headers={
            "Origin": "https://evil.example",
            "Access-Control-Request-Method": "GET",
        },
    )

    assert "access-control-allow-origin" not in response.headers


def test_cors_allows_configured_origin() -> None:
    client = TestClient(
        create_app(
            Settings(
                _env_file=None,
                postgres_url=None,
                redis_url=None,
                cors_allowed_origins="https://app.example.com, https://admin.example.com",
            )
        )
    )

    response = client.options(
        "/health",
        headers={
            "Origin": "https://app.example.com",
            "Access-Control-Request-Method": "GET",
        },
    )

    assert response.status_code == 200
    assert response.headers["access-control-allow-origin"] == "https://app.example.com"
