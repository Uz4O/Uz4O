import logging
from typing import Optional
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Request
from pydantic import ValidationError
from sqlalchemy.orm import Session

from app.builds.ai_provider import AIProviderError, select_build_with_deepseek
from app.builds.gpu_rules import gpu_brand_allowed_for_budget
from app.builds.customization import (
    CustomizationError,
    customization_candidates,
    customize_template,
    deterministic_customization,
    find_owned_gpu,
)
from app.builds.repository import list_build_templates
from app.builds.selection_cache import (
    current_cache_version,
    mark_option_selected,
    option_cache_key,
    request_identity,
    selected_option,
    store_pending_option,
)
from app.builds.service import (
    BuildGenerationResponse,
    BuildOptionResponse,
    BuildOptionsResponse,
    BuildRequest,
    BuildSelectionConfirmationResponse,
    ai_pending_response,
    classify_game_direction,
    match_build_template,
    rank_build_templates,
    rules_fallback_response,
    template_response,
)
from app.catalog.repository import (
    get_components_by_ids,
    list_component_prices,
    list_components,
    list_gpu_whitelist_prices,
)
from app.compat.engine import BuildSelection, evaluate_compatibility
from app.core.rate_limit import high_cost_rate_limit
from app.db import get_session


router = APIRouter(
    prefix="/v1/build",
    tags=["build"],
    dependencies=[Depends(high_cost_rate_limit)],
)
logger = logging.getLogger(__name__)
BUILD_OPTION_MODES = ("used", "new", "mixed")
BUILD_DIRECTION_TOKENS = {"fps": "FPS", "aaa": "3A", "balanced": "均衡"}
BUILD_PURCHASE_TOKENS = {"used": "二手", "new": "全新", "mixed": "混合采购"}
BUILD_GPU_VENDOR_TOKENS = {"nvidia": "NVIDIA", "amd": "AMD", "intel": "Intel"}


@router.post("/options", response_model=BuildOptionsResponse)
def get_build_options(
    http_request: Request,
    request: BuildRequest,
    session: Session = Depends(get_session),
) -> BuildOptionsResponse:
    direction = request.direction or classify_game_direction(request.game_categories)
    request = request.model_copy(update={"direction": direction})
    templates = list_build_templates(session)
    components = list_components(session) if request.requires_customization else []
    prices = list_component_prices(session) if request.requires_customization else []
    components_by_id = {component.id: component for component in components}
    price_by_component_id = {price.component_id: price for price in prices}
    request_hash = request_payload = cache_version = None
    if request.requires_customization:
        request_hash, request_payload = request_identity(request)
        cache_version = current_cache_version(session)
        if request.budget > 5_000 and not request.no_gpu_build:
            excluded_gpu_ids = {
                row.component_id
                for row in list_gpu_whitelist_prices(session)
                if not gpu_brand_allowed_for_budget(row.name, request.budget)
            }
            components = [
                component
                for component in components
                if component.id not in excluded_gpu_ids
            ]
            components_by_id = {component.id: component for component in components}
    if request.no_gpu_build:
        try:
            find_owned_gpu(request.owned_gpu_model or "", components)
        except CustomizationError as exc:
            raise HTTPException(status_code=422, detail=str(exc)) from exc

    options = []
    unavailable_modes = []
    for purchase_mode in BUILD_OPTION_MODES:
        mode_option_count = 0
        for gpu_vendor in _option_gpu_vendors(request, direction):
            cache_key = option_cache_key(purchase_mode, gpu_vendor)
            forced_request = request.model_copy(
                update={
                    "use_case": "办公" if request.use_case == "办公" else "游戏",
                    "preferences": [
                        BUILD_DIRECTION_TOKENS[direction],
                        BUILD_PURCHASE_TOKENS[purchase_mode],
                    ],
                    "purchase_preference": None,
                    "gpu_preference": (
                        BUILD_GPU_VENDOR_TOKENS[gpu_vendor] if gpu_vendor else None
                    ),
                }
            )
            if request.requires_customization:
                cached = selected_option(
                    session,
                    forced_request,
                    request_hash,
                    cache_key,
                    cache_version,
                    purchase_mode=purchase_mode,
                    gpu_vendor=gpu_vendor,
                )
                if cached is not None:
                    options.append(cached)
                    mode_option_count += 1
                    if request.ray_tracing is not False:
                        break
                    continue
                candidates = customization_candidates(
                    forced_request,
                    templates,
                    components_by_id,
                    price_by_component_id,
                    purchase_mode=purchase_mode,
                    gpu_vendor=gpu_vendor,
                )
                option = _customized_option(
                    http_request,
                    forced_request,
                    candidates,
                    components_by_id,
                    price_by_component_id,
                )
                if option is not None:
                    option = store_pending_option(
                        session,
                        request_hash,
                        cache_key,
                        request_payload,
                        cache_version,
                        option,
                    )
                    options.append(option)
                    mode_option_count += 1
            else:
                option = _base_option(forced_request, templates, session)
                if option is not None:
                    options.append(option)
                    mode_option_count += 1
            if mode_option_count and request.ray_tracing is not False:
                break
        if mode_option_count == 0:
            unavailable_modes.append(purchase_mode)

    if not options:
        raise HTTPException(
            status_code=503,
            detail="当前预算和游戏方向没有可用的结构化配置方案。",
        )
    return BuildOptionsResponse(
        direction=direction,
        options=options,
        unavailable_modes=unavailable_modes,
    )


@router.post(
    "/options/{selection_id}/select",
    response_model=BuildSelectionConfirmationResponse,
)
def select_build_option(
    selection_id: UUID,
    session: Session = Depends(get_session),
) -> BuildSelectionConfirmationResponse:
    row = mark_option_selected(
        session,
        str(selection_id),
        current_cache_version(session),
    )
    if row is None:
        raise HTTPException(status_code=404, detail="配置选择记录不存在或已失效。")
    return BuildSelectionConfirmationResponse(
        selection_id=row.id,
        selected_count=row.selected_count,
    )


def _base_option(
    request: BuildRequest,
    templates: list,
    session: Session,
) -> Optional[BuildOptionResponse]:
    for template in rank_build_templates(request, templates):
        if not template.details:
            continue
        components = get_components_by_ids(session, template.components.values())
        compatibility = evaluate_compatibility(
            BuildSelection(components=dict(template.components)),
            {component.id: component for component in components},
        )
        if not compatibility.compatible:
            continue
        try:
            return BuildOptionResponse.model_validate(
                template_response(template, compatibility).model_dump()
            )
        except ValidationError as exc:
            logger.warning("Skipping invalid build option template %s: %s", template.id, exc)
    return None


def _customized_option(
    http_request: Request,
    request: BuildRequest,
    candidates: list,
    components_by_id: dict,
    price_by_component_id: dict,
) -> Optional[BuildOptionResponse]:
    fallback = deterministic_customization(
        request,
        candidates,
        components_by_id,
        price_by_component_id,
    )
    if not candidates or not http_request.app.state.settings.ai_provider_api_key:
        return fallback

    candidates_by_id = {candidate.id: candidate for candidate in candidates}
    retry_feedback = None
    for _ in range(2):
        try:
            selection = select_build_with_deepseek(
                request,
                candidates,
                components_by_id,
                price_by_component_id,
                http_request.app.state.settings,
                retry_feedback=retry_feedback,
            )
            http_request.app.state.high_cost_usage_metrics.record_actual_ai_cost(
                http_request.url.path,
                selection.actual_cost_cents,
            )
            selected_template = candidates_by_id[selection.base_template_id]
            try:
                return customize_template(
                    request,
                    selected_template,
                    selection.patches,
                    components_by_id,
                    price_by_component_id,
                    source="ai_provider",
                    reasons=selection.reasons,
                )
            except CustomizationError:
                return customize_template(
                    request,
                    selected_template,
                    {},
                    components_by_id,
                    price_by_component_id,
                    source="ai_provider",
                    reasons=selection.reasons,
                )
        except (AIProviderError, CustomizationError, KeyError) as exc:
            retry_feedback = str(exc)[:240]

    http_request.app.state.high_cost_usage_metrics.record_external_ai_failure(
        http_request.url.path,
    )
    return fallback


def _option_gpu_vendors(
    request: BuildRequest,
    direction: str,
) -> tuple[Optional[str], ...]:
    if request.no_gpu_build:
        return (None,)
    if request.use_case == "办公":
        return (None,)
    if request.use_case == "游戏兼办公":
        return ("nvidia",)
    if request.budget < 5_000 or direction == "fps":
        return (None,)
    if request.ray_tracing is False:
        return ("nvidia", "amd")
    if request.ray_tracing is True:
        return ("nvidia",)
    return ("nvidia", "amd")


@router.post("/generate", response_model=BuildGenerationResponse)
def generate_build(
    http_request: Request,
    request: BuildRequest,
    session: Session = Depends(get_session),
) -> BuildGenerationResponse:
    template = match_build_template(request, list_build_templates(session))
    if template is None:
        fallback = rules_fallback_response(
            request,
            list_components(session),
            list_component_prices(session),
        )
        if fallback is not None:
            return fallback
        return ai_pending_response(
            ai_provider_configured=bool(http_request.app.state.settings.ai_provider_api_key)
        )

    components = get_components_by_ids(session, template.components.values())
    compatibility = evaluate_compatibility(
        BuildSelection(components=dict(template.components)),
        {component.id: component for component in components},
    )
    return template_response(template, compatibility)
