from fastapi import FastAPI

from app.api.catalog import router as catalog_router
from app.api.health import create_health_router
from app.api.progress import create_progress_router
from app.core.config import Settings


def create_app(settings: Settings) -> FastAPI:
    app = FastAPI(title="AI PC Builder API", version="0.1.0")
    app.include_router(catalog_router)
    app.include_router(create_health_router(settings))
    app.include_router(create_progress_router())
    return app


app = create_app(Settings())
