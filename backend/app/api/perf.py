import json
from typing import Generator, Tuple

from fastapi import APIRouter, Depends, Request, Response
from fastapi.responses import StreamingResponse
from sqlalchemy.orm import Session

from app.core.rate_limit import high_cost_rate_limit
from app.core.response_cache import response_cache_key
from app.db import get_session
from app.perf.service import PerfEstimateRequest, PerfEstimateResponse, estimate_performance


router = APIRouter(
    prefix="/v1/perf",
    tags=["performance"],
    dependencies=[Depends(high_cost_rate_limit)],
)


@router.post("/estimate", response_model=PerfEstimateResponse)
def estimate_perf(
    payload: PerfEstimateRequest,
    http_request: Request,
    response: Response,
    session: Session = Depends(get_session),
) -> PerfEstimateResponse:
    result, cache_status = _cached_or_estimate(http_request, session, payload)
    response.headers["X-Cache"] = cache_status
    return result


@router.post("/estimate/stream")
def estimate_perf_stream(
    payload: PerfEstimateRequest,
    http_request: Request,
    session: Session = Depends(get_session),
) -> StreamingResponse:
    def event_stream() -> Generator[str, None, None]:
        yield _sse("progress", {"stage": "received"})
        yield _sse("progress", {"stage": "estimating"})
        result, cache_status = _cached_or_estimate(http_request, session, payload)
        yield _sse("cache", {"status": cache_status})
        yield _sse("result", result.model_dump(mode="json"))

    return StreamingResponse(event_stream(), media_type="text/event-stream")


def _cached_or_estimate(
    http_request: Request,
    session: Session,
    payload: PerfEstimateRequest,
) -> Tuple[PerfEstimateResponse, str]:
    cache_key = response_cache_key("perf.estimate", payload)
    if http_request.app.state.settings.response_cache_enabled:
        cached = http_request.app.state.response_cache.get(cache_key)
        if cached is not None:
            http_request.app.state.high_cost_usage_metrics.record_cache_status(
                http_request.url.path,
                "HIT",
            )
            return PerfEstimateResponse.model_validate(cached), "HIT"

    result = estimate_performance(session, payload)
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
