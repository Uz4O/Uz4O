from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.auth import router as auth_router
from app.api.builds import router as build_router
from app.api.catalog import router as catalog_router
from app.api.community import router as community_router
from app.api.compat import router as compat_router
from app.api.guide import router as guide_router
from app.api.health import create_health_router
from app.api.ops import router as ops_router
from app.api.perf import router as perf_router
from app.api.profile import router as profile_router
from app.api.progress import create_progress_router
from app.api.review import router as review_router
from app.api.saved_builds import router as saved_builds_router
from app.api.upgrade import router as upgrade_router
from app.core.config import Settings
from app.core.rate_limit import create_rate_limiter
from app.core.request_size import RequestBodySizeLimitMiddleware
from app.core.response_cache import ResponseCache
from app.core.security_headers import SecurityHeadersMiddleware
from app.core.usage_metrics import HighCostUsageMetrics


def create_app(settings: Settings) -> FastAPI:
    if settings.app_env == "production" and settings.auth_token_secret == "dev-only-change-me":
        raise RuntimeError("APP_ENV=production 下禁止使用默认 auth_token_secret，请配置生产密钥后再启动。")

    app = FastAPI(
        title="AI PC Builder API",
        version="0.1.0",
        docs_url="/docs" if settings.api_docs_enabled else None,
        redoc_url="/redoc" if settings.api_docs_enabled else None,
        openapi_url="/openapi.json" if settings.api_docs_enabled else None,
    )
    if settings.cors_origin_list:
        app.add_middleware(
            CORSMiddleware,
            allow_origins=settings.cors_origin_list,
            allow_credentials=True,
            allow_methods=["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
            allow_headers=["Authorization", "Content-Type"],
        )
    app.add_middleware(
        RequestBodySizeLimitMiddleware,
        max_body_bytes=settings.max_request_body_bytes,
    )
    app.add_middleware(SecurityHeadersMiddleware)
    app.state.settings = settings
    app.state.high_cost_rate_limiter = create_rate_limiter(
        max_requests=settings.high_cost_rate_limit_max_requests,
        window_seconds=settings.high_cost_rate_limit_window_seconds,
        namespace="high-cost",
        redis_url=settings.redis_url,
    )
    app.state.auth_sms_rate_limiter = create_rate_limiter(
        max_requests=settings.auth_sms_rate_limit_max_requests,
        window_seconds=settings.auth_rate_limit_window_seconds,
        namespace="auth-sms",
        redis_url=settings.redis_url,
    )
    app.state.auth_login_rate_limiter = create_rate_limiter(
        max_requests=settings.auth_login_rate_limit_max_requests,
        window_seconds=settings.auth_rate_limit_window_seconds,
        namespace="auth-login",
        redis_url=settings.redis_url,
    )
    app.state.community_write_rate_limiter = create_rate_limiter(
        max_requests=settings.community_write_rate_limit_max_requests,
        window_seconds=settings.community_write_rate_limit_window_seconds,
        namespace="community-write",
        redis_url=settings.redis_url,
    )
    app.state.high_cost_usage_metrics = HighCostUsageMetrics()
    app.state.response_cache = ResponseCache(
        ttl_seconds=settings.response_cache_ttl_seconds,
        max_entries=settings.response_cache_max_entries,
    )
    app.include_router(auth_router)
    app.include_router(build_router)
    app.include_router(catalog_router)
    app.include_router(community_router)
    app.include_router(compat_router)
    app.include_router(guide_router)
    app.include_router(ops_router)
    app.include_router(profile_router)
    app.include_router(review_router)
    app.include_router(saved_builds_router)
    app.include_router(upgrade_router)
    app.include_router(perf_router)
    app.include_router(create_health_router(settings))
    app.include_router(create_progress_router())
    return app


app = create_app(Settings())
