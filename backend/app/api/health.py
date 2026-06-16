from typing import List, Optional
from urllib.parse import urlparse

from fastapi import APIRouter

from app.catalog.readiness import DataReadiness, build_data_readiness
from app.core.config import Settings
from app.db import create_session_factory

POSTGRES_SCHEMES = {"postgresql", "postgresql+psycopg"}
REDIS_SCHEMES = {"redis", "rediss", "unix"}


def create_health_router(settings: Settings) -> APIRouter:
    router = APIRouter()

    @router.get("/health")
    def health() -> dict:
        data_readiness = _production_data_readiness(settings)
        blocking_items = _production_blocking_items(settings, data_readiness)
        return {
            "status": "ok",
            "service": settings.service_name,
            "dependencies": {
                "postgres": _url_status(settings.postgres_url, POSTGRES_SCHEMES),
                "redis": _url_status(settings.redis_url, REDIS_SCHEMES),
            },
            "data": data_readiness,
            "security": {
                "auth_token_secret": _auth_secret_status(settings.auth_token_secret),
                "ai_provider_api_key": _configuration_status(settings.ai_provider_api_key),
                "ai_provider_base_url": settings.ai_provider_base_url_status,
                "apple_login": _configuration_status(settings.apple_login_client_id),
                "ops_token": _configuration_status(settings.ops_token),
                "community_image_upload": _community_image_upload_status(settings),
                "cors_allowed_origins": settings.cors_allowed_origins_status,
                "api_docs": "enabled" if settings.api_docs_enabled else "disabled",
                "sms_debug": "enabled" if settings.auth_sms_debug else "disabled",
                "sms_provider": "debug" if settings.auth_sms_debug else "not_configured",
                "max_request_body_bytes": settings.max_request_body_bytes,
            },
            "production": {
                "ready": not blocking_items,
                "blocking_items": blocking_items,
            },
        }

    return router


def _configuration_status(value: Optional[str]) -> str:
    return "configured" if value else "not_configured"


def _url_status(value: Optional[str], allowed_schemes: set[str]) -> str:
    if not value:
        return "not_configured"
    parsed = urlparse(value)
    if parsed.scheme not in allowed_schemes:
        return "invalid"
    if parsed.scheme == "unix":
        return "configured" if parsed.path else "invalid"
    return "configured" if parsed.hostname else "invalid"


def _auth_secret_status(value: str) -> str:
    if value == "dev-only-change-me":
        return "default"
    if len(value) < 32:
        return "weak"
    return "configured"


def _production_data_readiness(settings: Settings) -> dict:
    if not settings.production_data_readiness_required:
        return {"production_data_readiness": "not_checked"}
    if _url_status(settings.postgres_url, POSTGRES_SCHEMES) != "configured":
        return {"production_data_readiness": "not_checked"}

    try:
        session_factory = create_session_factory(settings)
        with session_factory() as session:
            readiness = build_data_readiness(session)
    except Exception:
        return {"production_data_readiness": "unavailable"}

    return _data_readiness_response(readiness)


def _data_readiness_response(readiness: DataReadiness) -> dict:
    return {
        "production_data_readiness": "ready" if readiness.ready else "not_ready",
        "component_count": readiness.component_count,
        "price_count": readiness.price_count,
        "active_template_count": readiness.active_template_count,
        "missing_recommended_categories": readiness.missing_recommended_categories,
        "missing_priced_recommended_categories": readiness.missing_priced_recommended_categories,
    }


def _production_blocking_items(settings: Settings, data_readiness: dict) -> List[str]:
    blocking_items = []
    postgres_status = _url_status(settings.postgres_url, POSTGRES_SCHEMES)
    redis_status = _url_status(settings.redis_url, REDIS_SCHEMES)
    if postgres_status == "not_configured":
        blocking_items.append("postgres_not_configured")
    if postgres_status == "invalid":
        blocking_items.append("postgres_url_invalid")
    if redis_status == "invalid":
        blocking_items.append("redis_url_invalid")
    auth_secret_status = _auth_secret_status(settings.auth_token_secret)
    if auth_secret_status == "default":
        blocking_items.append("auth_token_secret_default")
    if auth_secret_status == "weak":
        blocking_items.append("auth_token_secret_weak")
    if settings.auth_sms_debug:
        blocking_items.append("sms_debug_enabled")
    if not settings.auth_sms_debug:
        blocking_items.append("sms_provider_not_configured")
    if not settings.ai_provider_api_key:
        blocking_items.append("ai_provider_api_key_not_configured")
    if settings.ai_provider_base_url_status == "invalid":
        blocking_items.append("ai_provider_base_url_invalid")
    if not settings.apple_login_client_id:
        blocking_items.append("apple_login_not_configured")
    if not settings.ops_token:
        blocking_items.append("ops_token_not_configured")
    community_image_upload_status = _community_image_upload_status(settings)
    if community_image_upload_status == "not_configured":
        blocking_items.append("community_image_upload_not_configured")
    if community_image_upload_status == "incomplete":
        blocking_items.append("community_image_upload_incomplete")
    if settings.cors_allowed_origins_status == "invalid":
        blocking_items.append("cors_allowed_origins_invalid")
    if settings.api_docs_enabled:
        blocking_items.append("api_docs_enabled")
    if data_readiness["production_data_readiness"] == "not_ready":
        blocking_items.append("production_data_not_ready")
    if data_readiness["production_data_readiness"] == "unavailable":
        blocking_items.append("production_data_readiness_unavailable")
    return blocking_items


def _community_image_upload_status(settings: Settings) -> str:
    if settings.community_image_upload_configured:
        return "configured"
    if settings.community_image_upload_enabled:
        return "incomplete"
    return "not_configured"
