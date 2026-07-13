import logging
from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException, Request
from pydantic import ValidationError
from sqlalchemy.orm import Session

from app.builds.repository import list_build_templates
from app.builds.ai_provider import select_build_with_deepseek
from app.builds.service import (
    BuildGenerationResponse,
    BuildOptionResponse,
    BuildOptionsResponse,
    BuildRequest,
    ai_provider_response,
    ai_pending_response,
    classify_game_direction,
    match_build_template,
    rank_build_templates,
    rules_fallback_after_ai_failure,
    rules_fallback_response,
    template_response,
    fallback_candidates_by_role,
)
from app.catalog.repository import get_components_by_ids, list_component_prices, list_components
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


@router.post("/options", response_model=BuildOptionsResponse)
def get_build_options(
    request: BuildRequest,
    session: Session = Depends(get_session),
) -> BuildOptionsResponse:
    direction = classify_game_direction(request.game_categories)
    templates = list_build_templates(session)
    options = []
    unavailable_modes = []

    for purchase_mode in BUILD_OPTION_MODES:
        forced_request = BuildRequest(
            budget=request.budget,
            use_case="游戏",
            preferences=[
                BUILD_DIRECTION_TOKENS[direction],
                BUILD_PURCHASE_TOKENS[purchase_mode],
            ],
        )
        for template in rank_build_templates(forced_request, templates):
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
                option = BuildOptionResponse.model_validate(
                    template_response(template, compatibility).model_dump()
                )
            except ValidationError as exc:
                logger.warning(
                    "Skipping invalid build option template %s: %s",
                    template.id,
                    exc,
                )
                continue
            options.append(option)
            break
        else:
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


@router.post("/generate", response_model=BuildGenerationResponse)
def generate_build(
    http_request: Request,
    request: BuildRequest,
    session: Session = Depends(get_session),
) -> BuildGenerationResponse:
    template = match_build_template(request, list_build_templates(session))
    if template is None:
        components = list_components(session)
        prices = list_component_prices(session)
        fallback = rules_fallback_response(
            request,
            components,
            prices,
        )
        if fallback is not None:
            if http_request.app.state.settings.ai_provider_api_key:
                ai_response = _try_ai_provider_response(
                    http_request=http_request,
                    request=request,
                    components=components,
                    prices=prices,
                )
                if ai_response is not None:
                    return ai_response
                return rules_fallback_after_ai_failure(fallback)
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


def _try_ai_provider_response(
    http_request: Request,
    request: BuildRequest,
    components: List,
    prices: List,
) -> Optional[BuildGenerationResponse]:
    price_by_component_id = {price.component_id: price for price in prices}
    components_by_id = {component.id: component for component in components}
    candidates_by_role = fallback_candidates_by_role(components, price_by_component_id)
    try:
        selection = select_build_with_deepseek(
            request,
            candidates_by_role,
            price_by_component_id,
            http_request.app.state.settings,
        )
    except Exception:
        http_request.app.state.high_cost_usage_metrics.record_external_ai_failure(
            http_request.url.path,
        )
        return None

    selected_components = {
        role: component_id
        for role, component_id in selection.components.items()
        if component_id in components_by_id
    }
    if selected_components != selection.components:
        http_request.app.state.high_cost_usage_metrics.record_external_ai_failure(
            http_request.url.path,
        )
        return None

    compatibility = evaluate_compatibility(
        BuildSelection(components=selected_components),
        components_by_id,
    )
    if not compatibility.compatible:
        http_request.app.state.high_cost_usage_metrics.record_external_ai_failure(
            http_request.url.path,
        )
        return None

    estimated_total = sum(
        price_by_component_id[component_id].reference_price
        for component_id in selected_components.values()
        if component_id in price_by_component_id
    )
    http_request.app.state.high_cost_usage_metrics.record_actual_ai_cost(
        http_request.url.path,
        selection.actual_cost_cents,
    )
    return ai_provider_response(
        request=request,
        components=selected_components,
        explanation=selection.explanation,
        estimated_total=estimated_total,
        compatibility=compatibility,
    )
