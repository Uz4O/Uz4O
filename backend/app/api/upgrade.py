import json
from typing import Generator, Tuple

from fastapi import APIRouter, Depends, Request, Response
from fastapi.responses import StreamingResponse
from sqlalchemy.orm import Session

from app.core.rate_limit import high_cost_rate_limit
from app.core.response_cache import response_cache_key
from app.db import get_session
from app.upgrade.service import UpgradePlanRequest, UpgradePlanResponse, generate_upgrade_plan


router = APIRouter(
    prefix="/v1/upgrade",
    tags=["upgrade"],
    dependencies=[Depends(high_cost_rate_limit)],
)


@router.post("/plan", response_model=UpgradePlanResponse)
def plan_upgrade(
    payload: UpgradePlanRequest,
    http_request: Request,
    response: Response,
    session: Session = Depends(get_session),
) -> UpgradePlanResponse:
    result, cache_status = _cached_or_plan(http_request, session, payload)
    response.headers["X-Cache"] = cache_status
    return result


@router.post("/plan/stream")
def plan_upgrade_stream(
    payload: UpgradePlanRequest,
    http_request: Request,
    session: Session = Depends(get_session),
) -> StreamingResponse:
    def event_stream() -> Generator[str, None, None]:
        yield _sse("progress", {"stage": "received"})
        yield _sse("progress", {"stage": "planning"})
        result, cache_status = _cached_or_plan(http_request, session, payload)
        yield _sse("cache", {"status": cache_status})
        yield _sse("result", result.model_dump(mode="json"))

    return StreamingResponse(event_stream(), media_type="text/event-stream")


def _cached_or_plan(
    http_request: Request,
    session: Session,
    payload: UpgradePlanRequest,
) -> Tuple[UpgradePlanResponse, str]:
    cache_key = response_cache_key("upgrade.plan", payload)
    if http_request.app.state.settings.response_cache_enabled:
        cached = http_request.app.state.response_cache.get(cache_key)
        if cached is not None:
            http_request.app.state.high_cost_usage_metrics.record_cache_status(
                http_request.url.path,
                "HIT",
            )
            return UpgradePlanResponse.model_validate(cached), "HIT"

    result = generate_upgrade_plan(session, payload)
    if http_request.app.state.settings.response_cache_enabled:
        http_request.app.state.response_cache.set(cache_key, result.model_dump(mode="json"))
    http_request.app.state.high_cost_usage_metrics.record_cache_status(
        http_request.url.path,
        "MISS",
    )
    http_request.app.state.high_cost_usage_metrics.record_estimated_cost(
        http_request.url.path,
        http_request.app.state.settings.high_cost_estimated_cost_cents,
    )
    return result, "MISS"


def _sse(event: str, data: dict) -> str:
    encoded = json.dumps(data, ensure_ascii=False, separators=(",", ":"))
    return f"event: {event}\ndata: {encoded}\n\n"
