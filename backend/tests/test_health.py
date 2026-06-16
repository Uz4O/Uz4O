import pytest
from fastapi.testclient import TestClient

from app.catalog.readiness import DataReadiness
from app.core.config import Settings
from app.main import create_app


IMAGE_UPLOAD_CONFIG = {
    "community_image_upload_enabled": True,
    "community_image_oss_bucket": "ai-pc-community",
    "community_image_oss_region": "cn-hangzhou",
    "community_image_oss_access_key_id": "oss-key-id",
    "community_image_oss_access_key_secret": "oss-key-secret",
}


def test_application_metadata() -> None:
    app = create_app(Settings(_env_file=None, postgres_url=None, redis_url=None))

    assert app.title == "AI PC Builder API"
    assert app.version == "0.1.0"


def test_settings_reads_app_env_from_unprefixed_environment(monkeypatch) -> None:
    monkeypatch.setenv("APP_ENV", "production")

    settings = Settings(_env_file=None, postgres_url=None, redis_url=None)

    assert settings.app_env == "production"


def test_production_app_rejects_default_auth_token_secret() -> None:
    with pytest.raises(RuntimeError, match="APP_ENV=production"):
        create_app(
            Settings(
                _env_file=None,
                app_env="production",
                postgres_url=None,
                redis_url=None,
            )
        )


def test_production_app_allows_configured_auth_token_secret() -> None:
    app = create_app(
        Settings(
            _env_file=None,
            app_env="production",
            postgres_url=None,
            redis_url=None,
            auth_token_secret="production-secret-with-at-least-32-bytes",
        )
    )

    assert app.title == "AI PC Builder API"


def test_development_app_allows_default_auth_token_secret() -> None:
    app = create_app(
        Settings(
            _env_file=None,
            app_env="development",
            postgres_url=None,
            redis_url=None,
        )
    )

    assert app.title == "AI PC Builder API"


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
        "data": {
            "production_data_readiness": "not_checked",
        },
        "security": {
            "auth_token_secret": "default",
            "ai_provider_api_key": "not_configured",
            "ai_provider_base_url": "configured",
            "apple_login": "not_configured",
            "ops_token": "not_configured",
            "community_image_upload": "not_configured",
            "cors_allowed_origins": "not_configured",
            "api_docs": "disabled",
            "sms_debug": "enabled",
            "sms_provider": "debug",
            "max_request_body_bytes": 1000000,
        },
        "production": {
            "ready": False,
            "blocking_items": [
                "postgres_not_configured",
                "auth_token_secret_default",
                "sms_debug_enabled",
                "ai_provider_api_key_not_configured",
                "apple_login_not_configured",
                "ops_token_not_configured",
                "community_image_upload_not_configured",
            ],
        },
    }


def test_health_reports_configured_optional_dependencies() -> None:
    settings = Settings(
        _env_file=None,
        postgres_url="postgresql://app:app@localhost:5432/app",
        redis_url="redis://localhost:6379/0",
        auth_token_secret="production-like-secret-with-enough-entropy",
        auth_sms_debug=False,
        ai_provider_api_key="deepseek-secret",
        apple_login_client_id="com.example.app",
        ops_token="ops-secret",
        max_request_body_bytes=2048,
        production_data_readiness_required=False,
        **IMAGE_UPLOAD_CONFIG,
    )
    client = TestClient(create_app(settings))

    response = client.get("/health")

    assert response.status_code == 200
    assert response.json()["dependencies"] == {
        "postgres": "configured",
        "redis": "configured",
    }
    assert response.json()["security"] == {
        "auth_token_secret": "configured",
        "ai_provider_api_key": "configured",
        "ai_provider_base_url": "configured",
        "apple_login": "configured",
        "ops_token": "configured",
        "community_image_upload": "configured",
        "cors_allowed_origins": "not_configured",
        "api_docs": "disabled",
        "sms_debug": "disabled",
        "sms_provider": "not_configured",
        "max_request_body_bytes": 2048,
    }
    assert response.json()["production"] == {
        "ready": False,
        "blocking_items": ["sms_provider_not_configured"],
    }


def test_health_blocks_enabled_community_upload_with_missing_oss_config() -> None:
    settings = Settings(
        _env_file=None,
        postgres_url="postgresql://app:app@localhost:5432/app",
        redis_url=None,
        auth_token_secret="production-like-secret-with-enough-entropy",
        auth_sms_debug=False,
        ai_provider_api_key="deepseek-secret",
        apple_login_client_id="com.example.app",
        ops_token="ops-secret",
        community_image_upload_enabled=True,
    )
    client = TestClient(create_app(settings))

    response = client.get("/health")

    assert response.status_code == 200
    assert response.json()["security"]["community_image_upload"] == "incomplete"
    assert response.json()["production"] == {
        "ready": False,
        "blocking_items": [
            "sms_provider_not_configured",
            "community_image_upload_incomplete",
        ],
    }


def test_health_blocks_unsafe_ai_provider_base_url_without_exposing_value() -> None:
    unsafe_url = "http://127.0.0.1:9000"
    settings = Settings(
        _env_file=None,
        postgres_url="postgresql://app:app@localhost:5432/app",
        redis_url=None,
        auth_token_secret="production-like-secret-with-enough-entropy",
        auth_sms_debug=False,
        ai_provider_api_key="deepseek-secret",
        ai_provider_base_url=unsafe_url,
        apple_login_client_id="com.example.app",
        ops_token="ops-secret",
        **IMAGE_UPLOAD_CONFIG,
    )
    client = TestClient(create_app(settings))

    response = client.get("/health")

    assert response.status_code == 200
    assert response.json()["security"]["ai_provider_base_url"] == "invalid"
    assert response.json()["production"] == {
        "ready": False,
        "blocking_items": [
            "sms_provider_not_configured",
            "ai_provider_base_url_invalid",
        ],
    }
    assert unsafe_url not in response.text


def test_health_blocks_unready_production_data_when_check_is_enabled(monkeypatch) -> None:
    class FakeSession:
        def __enter__(self):
            return self

        def __exit__(self, exc_type, exc, tb):
            return False

    def fake_create_session_factory(settings):
        return lambda: FakeSession()

    def fake_build_data_readiness(session):
        return DataReadiness(
            ready=False,
            component_count=715,
            price_count=1,
            active_template_count=0,
            recommended_counts={
                "cpu": 0,
                "gpu": 0,
                "motherboard": 0,
                "ram": 0,
                "storage": 0,
                "psu": 0,
            },
            priced_recommended_counts={
                "cpu": 0,
                "gpu": 0,
                "motherboard": 0,
                "ram": 0,
                "storage": 0,
                "psu": 0,
            },
            missing_recommended_categories=["cpu", "gpu"],
            missing_priced_recommended_categories=["cpu", "gpu"],
        )

    monkeypatch.setattr("app.api.health.create_session_factory", fake_create_session_factory)
    monkeypatch.setattr("app.api.health.build_data_readiness", fake_build_data_readiness)
    settings = Settings(
        _env_file=None,
        postgres_url="postgresql://app:app@localhost:5432/app",
        redis_url=None,
        auth_token_secret="production-like-secret-with-enough-entropy",
        auth_sms_debug=False,
        ai_provider_api_key="deepseek-secret",
        apple_login_client_id="com.example.app",
        ops_token="ops-secret",
        production_data_readiness_required=True,
        **IMAGE_UPLOAD_CONFIG,
    )
    client = TestClient(create_app(settings))

    response = client.get("/health")

    assert response.status_code == 200
    assert response.json()["data"] == {
        "production_data_readiness": "not_ready",
        "component_count": 715,
        "price_count": 1,
        "active_template_count": 0,
        "missing_recommended_categories": ["cpu", "gpu"],
        "missing_priced_recommended_categories": ["cpu", "gpu"],
    }
    assert response.json()["production"] == {
        "ready": False,
        "blocking_items": ["sms_provider_not_configured", "production_data_not_ready"],
    }


def test_health_blocks_invalid_dependency_urls_without_exposing_values() -> None:
    postgres_url = "mysql://app:secret@localhost/app"
    redis_url = "http://redis-secret@example.com"
    settings = Settings(
        _env_file=None,
        postgres_url=postgres_url,
        redis_url=redis_url,
        auth_token_secret="production-like-secret-with-enough-entropy",
        auth_sms_debug=False,
        ai_provider_api_key="deepseek-secret",
        apple_login_client_id="com.example.app",
        ops_token="ops-secret",
        **IMAGE_UPLOAD_CONFIG,
    )
    client = TestClient(create_app(settings))

    response = client.get("/health")

    assert response.status_code == 200
    assert response.json()["dependencies"] == {
        "postgres": "invalid",
        "redis": "invalid",
    }
    assert response.json()["production"] == {
        "ready": False,
        "blocking_items": [
            "postgres_url_invalid",
            "redis_url_invalid",
            "sms_provider_not_configured",
        ],
    }
    assert postgres_url not in response.text
    assert redis_url not in response.text


def test_health_blocks_wildcard_cors_and_app_does_not_enable_it() -> None:
    settings = Settings(
        _env_file=None,
        postgres_url="postgresql://app:app@localhost:5432/app",
        redis_url=None,
        auth_token_secret="production-like-secret-with-enough-entropy",
        auth_sms_debug=False,
        ai_provider_api_key="deepseek-secret",
        apple_login_client_id="com.example.app",
        ops_token="ops-secret",
        cors_allowed_origins="*",
        **IMAGE_UPLOAD_CONFIG,
    )
    client = TestClient(create_app(settings))

    health = client.get("/health")
    preflight = client.options(
        "/health",
        headers={
            "Origin": "https://evil.example",
            "Access-Control-Request-Method": "GET",
        },
    )

    assert health.status_code == 200
    assert health.json()["security"]["cors_allowed_origins"] == "invalid"
    assert health.json()["production"] == {
        "ready": False,
        "blocking_items": ["sms_provider_not_configured", "cors_allowed_origins_invalid"],
    }
    assert "access-control-allow-origin" not in preflight.headers


def test_health_blocks_enabled_api_docs_for_production() -> None:
    settings = Settings(
        _env_file=None,
        postgres_url="postgresql://app:app@localhost:5432/app",
        redis_url=None,
        auth_token_secret="production-like-secret-with-enough-entropy",
        auth_sms_debug=False,
        ai_provider_api_key="deepseek-secret",
        apple_login_client_id="com.example.app",
        ops_token="ops-secret",
        api_docs_enabled=True,
        **IMAGE_UPLOAD_CONFIG,
    )
    client = TestClient(create_app(settings))

    response = client.get("/health")

    assert response.status_code == 200
    assert response.json()["security"]["api_docs"] == "enabled"
    assert response.json()["production"] == {
        "ready": False,
        "blocking_items": ["sms_provider_not_configured", "api_docs_enabled"],
    }


def test_health_blocks_weak_auth_token_secret_without_exposing_value() -> None:
    weak_secret = "short-secret"
    settings = Settings(
        _env_file=None,
        postgres_url="postgresql://app:app@localhost:5432/app",
        redis_url=None,
        auth_token_secret=weak_secret,
        auth_sms_debug=False,
        ai_provider_api_key="deepseek-secret",
        apple_login_client_id="com.example.app",
        ops_token="ops-secret",
        **IMAGE_UPLOAD_CONFIG,
    )
    client = TestClient(create_app(settings))

    response = client.get("/health")

    assert response.status_code == 200
    assert response.json()["security"]["auth_token_secret"] == "weak"
    assert response.json()["production"] == {
        "ready": False,
        "blocking_items": ["auth_token_secret_weak", "sms_provider_not_configured"],
    }
    assert weak_secret not in response.text


def test_health_does_not_expose_secret_values() -> None:
    secret = "super-sensitive-secret-value"
    ai_key = "deepseek-sensitive-key"
    ops_token = "ops-sensitive-token"
    oss_secret = "oss-sensitive-secret"
    client = TestClient(
        create_app(
            Settings(
                _env_file=None,
                postgres_url=None,
                redis_url=None,
                auth_token_secret=secret,
                ai_provider_api_key=ai_key,
                ops_token=ops_token,
                community_image_upload_enabled=True,
                community_image_oss_bucket="ai-pc-community",
                community_image_oss_region="cn-hangzhou",
                community_image_oss_access_key_id="oss-key-id",
                community_image_oss_access_key_secret=oss_secret,
            )
        )
    )

    response = client.get("/health")

    assert response.status_code == 200
    assert secret not in response.text
    assert ai_key not in response.text
    assert ops_token not in response.text
    assert oss_secret not in response.text
