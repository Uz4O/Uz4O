import json
from typing import Generator, Tuple

from fastapi import APIRouter, Depends, Request, Response
from fastapi.responses import StreamingResponse
from sqlalchemy.orm import Session

from app.core.rate_limit import high_cost_rate_limit
from app.core.response_cache import response_cache_key
from app.db import get_session
from app.review.service import (
    ConfigReviewRequest,
    ConfigReviewResponse,
    analyze_configuration_text,
)


router = APIRouter(
    prefix="/v1/review",
    tags=["review"],
    dependencies=[Depends(high_cost_rate_limit)],
)


@router.post("/analyze", response_model=ConfigReviewResponse)
def analyze_review(
    payload: ConfigReviewRequest,
    http_request: Request,
    response: Response,
    session: Session = Depends(get_session),
) -> ConfigReviewResponse:
    result, cache_status = _cached_or_analyze(http_request, session, payload)
    response.headers["X-Cache"] = cache_status
    return result


@router.post("/analyze/stream")
def analyze_review_stream(
    payload: ConfigReviewRequest,
    http_request: Request,
    session: Session = Depends(get_session),
) -> StreamingResponse:
    def event_stream() -> Generator[str, None, None]:
        yield _sse("progress", {"stage": "received"})
        yield _sse("progress", {"stage": "analyzing"})
        result, cache_status = _cached_or_analyze(http_request, session, payload)
        yield _sse("cache", {"status": cache_status})
        yield _sse("result", result.model_dump(mode="json"))

    return StreamingResponse(event_stream(), media_type="text/event-stream")


def _cached_or_analyze(
    http_request: Request,
    session: Session,
    payload: ConfigReviewRequest,
) -> Tuple[ConfigReviewResponse, str]:
    cache_key = response_cache_key("review.analyze", payload)
    if http_request.app.state.settings.response_cache_enabled:
        cached = http_request.app.state.response_cache.get(cache_key)
        if cached is not None:
            http_request.app.state.high_cost_usage_metrics.record_cache_status(
                http_request.url.path,
                "HIT",
            )
            return ConfigReviewResponse.model_validate(cached), "HIT"

    result = analyze_configuration_text(session, payload.text)
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
