import json
from typing import Generator, Tuple

from fastapi import APIRouter, Depends, File, HTTPException, Request, Response, UploadFile
from fastapi.responses import StreamingResponse
from sqlalchemy.orm import Session

from app.core.rate_limit import high_cost_rate_limit
from app.core.response_cache import response_cache_key
from app.db import get_session
from app.review.ocr import OCRTextNotFoundError, OCRUnavailableError, extract_text_from_image_bytes
from app.review.service import (
    ConfigReviewRequest,
    ConfigReviewResponse,
    analyze_configuration_text,
)


MAX_REVIEW_IMAGE_BYTES = 8 * 1024 * 1024
SUPPORTED_REVIEW_IMAGE_TYPES = {"image/jpeg", "image/png", "image/webp"}

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


@router.post("/analyze/image", response_model=ConfigReviewResponse)
async def analyze_review_image(
    http_request: Request,
    response: Response,
    image: UploadFile = File(...),
    session: Session = Depends(get_session),
) -> ConfigReviewResponse:
    if image.content_type not in SUPPORTED_REVIEW_IMAGE_TYPES:
        raise HTTPException(status_code=415, detail="仅支持 JPG、PNG 或 WebP 配置单图片")

    image_bytes = await image.read(MAX_REVIEW_IMAGE_BYTES + 1)
    if len(image_bytes) > MAX_REVIEW_IMAGE_BYTES:
        raise HTTPException(status_code=413, detail="图片不能超过 8MB")

    try:
        text = extract_text_from_image_bytes(image_bytes)
    except OCRUnavailableError as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc
    except OCRTextNotFoundError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc

    payload = ConfigReviewRequest(text=text)
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

    result = analyze_configuration_text(
        session,
        payload.text,
        http_request.app.state.settings,
    )
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
