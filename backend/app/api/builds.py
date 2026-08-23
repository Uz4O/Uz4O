import logging
from typing import Optional
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Request
from pydantic import ValidationError
from sqlalchemy.orm import Session

from app.builds.gpu_rules import gpu_brand_allowed_for_budget
from app.builds.customization import (
    CustomizationError,
    RAY_TRACING_MIN_BUDGET,
    budget_cpu_policy_allows,
    customization_candidates,
    customized_budget_floor,
    customized_budget_limit,
    deterministic_customization,
    ddr4_memory_policy_allows,
    find_owned_gpu,
    motherboard_supports_cpu,
    select_best_build_option,
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
    BuildTemplateDetails,
    BuildSelectionConfirmationResponse,
    ai_pending_response,
    classify_game_direction,
    match_build_template,
    rank_build_templates,
    recommend_used_40_series_gpu,
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
THREE_MODE_MIN_BUDGET = 4_500
NVIDIA_OPTIMIZED_GAME_THRESHOLDS = {
    "PUBG": 7_900,
    "永劫无间": 7_900,
    "三角洲": 7_500,
    "三角洲行动": 7_500,
}


@router.post("/options", response_model=BuildOptionsResponse)
def get_build_options(
    request: BuildRequest,
    session: Session = Depends(get_session),
) -> BuildOptionsResponse:
    direction = request.direction or classify_game_direction(request.game_categories)
    request = request.model_copy(update={"direction": direction})
    templates = list_build_templates(session)
    catalog_loaded = request.requires_customization
    components = list_components(session) if catalog_loaded else []
    prices = list_component_prices(session) if catalog_loaded else []
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
    unavailable_mode_reasons = {}
    for purchase_mode in BUILD_OPTION_MODES:
        mode_option_start = len(options)
        mode_option_count = 0
        mode_totals = []
        mode_failure_reasons = []
        compare_value_vendors = (
            request.ray_tracing is None
            and request.budget < RAY_TRACING_MIN_BUDGET
            and direction in {"aaa", "balanced"}
            and request.gpu_preference is None
            and request.specified_gpu is None
        )
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
                    if request.ray_tracing is not False and not compare_value_vendors:
                        break
                    continue
                candidates = customization_candidates(
                    forced_request,
                    templates,
                    components_by_id,
                    price_by_component_id,
                    purchase_mode=purchase_mode,
                    gpu_vendor=gpu_vendor,
                    failure_reasons=mode_failure_reasons,
                    preview_totals=mode_totals,
                )
                option = _customized_option(
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
                if option is None:
                    if not catalog_loaded:
                        components = list_components(session)
                        prices = list_component_prices(session)
                        components_by_id = {
                            component.id: component for component in components
                        }
                        price_by_component_id = {
                            price.component_id: price for price in prices
                        }
                        catalog_loaded = True
                    candidates = customization_candidates(
                        forced_request,
                        templates,
                        components_by_id,
                        price_by_component_id,
                        purchase_mode=purchase_mode,
                        gpu_vendor=gpu_vendor,
                        failure_reasons=mode_failure_reasons,
                        preview_totals=mode_totals,
                    )
                    option = _customized_option(
                        forced_request,
                        candidates,
                        components_by_id,
                        price_by_component_id,
                    )
                if option is not None:
                    options.append(option)
                    mode_option_count += 1
            if (
                mode_option_count
                and request.ray_tracing is not False
                and not compare_value_vendors
            ):
                break
        if compare_value_vendors and mode_option_count > 1:
            best = select_best_build_option(
                request,
                options[mode_option_start:],
            )
            options[mode_option_start:] = [best] if best is not None else []
            mode_option_count = len(options) - mode_option_start
        if mode_option_count == 0:
            unavailable_modes.append(purchase_mode)
            unavailable_mode_reasons[purchase_mode] = _customization_failure_detail(
                request,
                mode_totals,
                mode_failure_reasons,
            )

    if not options:
        raise HTTPException(
            status_code=503,
            detail=_all_modes_failure_detail(unavailable_mode_reasons),
        )
    if request.budget >= THREE_MODE_MIN_BUDGET and unavailable_modes:
        raise HTTPException(
            status_code=503,
            detail=(
                "4500元及以上配置必须同时提供全新、二手和混合采购三套方案；"
                "当前审核配置暂未覆盖全部采购方式。"
            ),
        )
    gpu_prices = list_gpu_whitelist_prices(session)
    for option in options:
        option.details.used_gpu_alternative = recommend_used_40_series_gpu(
            option.details,
            gpu_prices,
        )
    return BuildOptionsResponse(
        direction=direction,
        options=options,
        unavailable_modes=unavailable_modes,
        unavailable_mode_reasons=unavailable_mode_reasons,
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
    quality_options = []
    candidate_requests = [request]
    next_budget = _next_reviewed_budget(request.budget)
    if next_budget != request.budget:
        candidate_requests.append(request.model_copy(update={"budget": next_budget}))

    for candidate_request in candidate_requests:
        ranked_templates = rank_build_templates(candidate_request, templates)
        if request.direction == "fps" and request.gpu_preference is None:
            ranked_templates = _rank_default_fps_templates(ranked_templates)
        for template in ranked_templates:
            if not template.details:
                continue
            try:
                details = BuildTemplateDetails.model_validate(template.details)
            except ValidationError:
                continue
            if not _details_match_locked_capacity(request, details):
                continue
            details_parts = {part.role: part for part in details.parts}
            if not motherboard_supports_cpu(details_parts):
                continue
            if not budget_cpu_policy_allows(request, details_parts["cpu"]):
                continue
            if not ddr4_memory_policy_allows(details_parts["ram"]):
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
            if (
                option.estimated_total is None
                or option.estimated_total > customized_budget_limit(request)
            ):
                continue
            if option.estimated_total < customized_budget_floor(request):
                continue
            quality_options.append(option)
            break
    return select_best_build_option(request, quality_options)


def _next_reviewed_budget(budget: int) -> int:
    step = 500 if budget < 10_000 else 1_000
    return (budget // step + 1) * step


def _details_match_locked_capacity(
    request: BuildRequest,
    details: BuildTemplateDetails,
) -> bool:
    parts = {part.role: part for part in details.parts}
    if request.memory_size:
        required_memory = int(request.memory_size.removesuffix("GB"))
        if parts["ram"].specs.get("capacity_gb") != required_memory:
            return False
    if request.storage_size:
        allowed_storage_capacities = {
            "512GB": {512},
            "1TB": {1000, 1024},
            "2TB": {2000, 2048},
        }
        if (
            parts["storage"].specs.get("capacity_gb")
            not in allowed_storage_capacities[request.storage_size]
        ):
            return False
    return True


def _rank_default_fps_templates(templates: list) -> list:
    first_by_vendor = {}
    for template in templates:
        try:
            details = BuildTemplateDetails.model_validate(template.details)
        except ValidationError:
            continue
        first_by_vendor.setdefault(details.gpu_vendor, details)
    nvidia = first_by_vendor.get("nvidia")
    amd = first_by_vendor.get("amd")
    if nvidia is None or amd is None:
        return templates

    nvidia_parts = {part.role: part for part in nvidia.parts}
    amd_parts = {part.role: part for part in amd.parts}
    nvidia_cpu = nvidia_parts["cpu"].specs.get("perf_index")
    nvidia_gpu = nvidia_parts["gpu"].specs.get("perf_index")
    amd_cpu = amd_parts["cpu"].specs.get("perf_index")
    amd_gpu = amd_parts["gpu"].specs.get("perf_index")
    if not all(
        type(value) is int
        for value in (nvidia_cpu, nvidia_gpu, amd_cpu, amd_gpu)
    ):
        return templates

    prefer_amd = (
        amd_cpu > nvidia_cpu and amd_gpu >= nvidia_gpu
    ) or (
        amd_cpu >= nvidia_cpu and amd_gpu * 100 >= nvidia_gpu * 115
    )
    preferred_vendor = "amd" if prefer_amd else "nvidia"
    return [
        template
        for _, template in sorted(
            enumerate(templates),
            key=lambda item: (
                _template_gpu_vendor(item[1]) != preferred_vendor,
                item[0],
            ),
        )
    ]


def _template_gpu_vendor(template) -> Optional[str]:
    try:
        return BuildTemplateDetails.model_validate(template.details).gpu_vendor
    except ValidationError:
        return None


def _customized_option(
    request: BuildRequest,
    candidates: list,
    components_by_id: dict,
    price_by_component_id: dict,
) -> Optional[BuildOptionResponse]:
    return deterministic_customization(
        request,
        candidates,
        components_by_id,
        price_by_component_id,
    )


def _customization_failure_detail(
    request: BuildRequest,
    preview_totals: list[int],
    failure_reasons: list[str],
) -> str:
    minimum_total = min(preview_totals, default=None)
    maximum_total = max(preview_totals, default=None)
    budget_floor = customized_budget_floor(request)
    budget_limit = customized_budget_limit(request)
    if minimum_total is not None and minimum_total > budget_limit:
        suggestion = (
            "可以开启“预算可小幅浮动”、降低容量需求或提高预算。"
            if request.budget < 10_000 and not request.allows_flexible_budget
            else "可以降低容量需求或提高预算。"
        )
        return (
            "已检查当前、较低价位及相邻高一档的审核基底；"
            f"满足当前硬性需求的最低审核配置约为 {minimum_total} 元，"
            f"超过本次预算上限 {budget_limit} 元。{suggestion}"
        )
    if maximum_total is not None and maximum_total < budget_floor:
        return (
            "已检查当前、较低价位及相邻高一档的审核基底；"
            f"可行配置中最高审核总价约为 {maximum_total} 元，"
            f"低于本次预算下限 {budget_floor} 元。"
            "暂时没有可以把余额用于有效性能或可靠性升级的审核方案。"
        )
    if any("审核价格" in reason for reason in failure_reasons):
        return (
            "已检查当前、较低价位及相邻高一档的审核基底，但当前容量、平台或采购成色"
            "缺少对应的审核价格，暂时无法生成可靠方案。"
        )
    return (
        "当前预算和方向没有可用的结构化配置方案；已检查当前、较低价位及"
        "相邻高一档的审核基底，但没有同时满足硬性需求、兼容性、功耗和预算上限的方案。"
    )


def _all_modes_failure_detail(mode_reasons: dict[str, str]) -> str:
    unique_reasons = list(dict.fromkeys(mode_reasons.values()))
    if len(unique_reasons) == 1:
        return f"所有采购方式均暂不可用。{unique_reasons[0]}"
    labels = {"used": "二手", "new": "全新", "mixed": "混合采购"}
    details = "；".join(
        f"{labels.get(mode, mode)}：{reason}"
        for mode, reason in mode_reasons.items()
    )
    return f"所有采购方式均暂不可用。{details}"


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
    specified_gpu = (request.specified_gpu or "").replace(" ", "").lower()
    if specified_gpu.startswith(("rtx", "gtx")):
        return ("nvidia",)
    if specified_gpu.startswith("rx"):
        return ("amd",)
    requested_gpu = (request.gpu_preference or "").replace(" ", "").lower()
    if requested_gpu in {"nvidia", "n卡", "英伟达"}:
        return ("nvidia",)
    if requested_gpu in {"amd", "a卡"}:
        return ("amd",)
    optimized_games = set(request.game_categories) & NVIDIA_OPTIMIZED_GAME_THRESHOLDS.keys()
    if request.gpu_preference is None and any(
        request.budget >= NVIDIA_OPTIMIZED_GAME_THRESHOLDS[game]
        for game in optimized_games
    ):
        return ("nvidia",)
    if (
        request.ray_tracing is True
        and request.budget >= RAY_TRACING_MIN_BUDGET
    ):
        return ("nvidia",)
    if request.budget < 5_000 or direction == "fps":
        return (None,)
    if request.ray_tracing is False:
        return ("nvidia", "amd")
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
    response = template_response(template, compatibility)
    if response.details is not None:
        response.details.used_gpu_alternative = recommend_used_40_series_gpu(
            response.details,
            list_gpu_whitelist_prices(session),
        )
    return response
