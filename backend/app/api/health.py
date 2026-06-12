from typing import Optional

from fastapi import APIRouter

from app.core.config import Settings


def create_health_router(settings: Settings) -> APIRouter:
    router = APIRouter()

    @router.get("/health")
    def health() -> dict:
        return {
            "status": "ok",
            "service": settings.service_name,
            "dependencies": {
                "postgres": _configuration_status(settings.postgres_url),
                "redis": _configuration_status(settings.redis_url),
            },
        }

    return router


def _configuration_status(value: Optional[str]) -> str:
    return "configured" if value else "not_configured"
