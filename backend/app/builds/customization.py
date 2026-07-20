import re
from math import ceil
from typing import Dict, Iterable, List, Optional

from app.builds.models import BuildTemplate
from app.builds.service import (
    BuildOptionResponse,
    BuildRequest,
    BuildTemplateDetails,
    BuildTemplateExtra,
    BuildTemplatePart,
    classify_office_workload,
)
from app.catalog.models import ComponentPrice, HardwareComponent
from app.catalog.rule_specs import GPU_MIN_CPU_PERFORMANCE
from app.compat.engine import BuildSelection, evaluate_compatibility


MAX_BASE_CANDIDATES = 8
CUSTOMIZABLE_ROLES = {
    "cpu",
    "motherboard",
    "gpu",
    "ram",
    "storage",
    "psu",
    "cooler",
    "case",
}
STORAGE_IDS = {
    "512GB": "base-ssd-512gb-tlc",
    "1TB": "base-ssd-1tb-tlc",
    "2TB": "base-ssd-2tb-tlc",
}
A520_WIFI_EXCEPTION_ID = "asus-a520m-k"
WIRELESS_ADAPTER_PRICE = 50
OFFICE_ONLY_GPU_IDS = {
    "arc-a580-8gb",
    "arc-a770-16gb",
    "arc-b570-10gb",
    "arc-b580-12gb",
}


class CustomizationError(ValueError):
    pass


def customized_budget_limit(request: BuildRequest) -> int:
    return request.budget + (800 if request.budget >= 10_000 else 500)


def customization_candidates(
    request: BuildRequest,
    templates: Iterable[BuildTemplate],
    components_by_id: Dict[str, HardwareComponent],
    price_by_component_id: Dict[str, ComponentPrice],
    *,
    purchase_mode: str,
    gpu_vendor: Optional[str],
) -> List[BuildTemplate]:
    candidates = []
    for template in templates:
        if template.status not in {None, "active"} or not template.details:
            continue
        details = BuildTemplateDetails.model_validate(template.details)
        if request.use_case not in template.use_cases:
            continue
        if details.direction != request.direction or details.purchase_mode != purchase_mode:
            continue
        if not request.no_gpu_build and gpu_vendor and details.gpu_vendor != gpu_vendor:
            continue
        try:
            preview = customize_template(
                request,
                template,
                {},
                components_by_id,
                price_by_component_id,
                source="template",
                validate_budget=False,
            )
        except CustomizationError:
            continue
        candidates.append((template, preview.estimated_total or 0))

    limit = customized_budget_limit(request)
    candidates.sort(
        key=lambda item: (
            item[1] > limit + 2_000,
            abs(item[1] - request.budget),
            -_primary_performance(item[0]),
            item[0].id,
        )
    )
    return [template for template, _ in candidates[:MAX_BASE_CANDIDATES]]


def customize_template(
    request: BuildRequest,
    template: BuildTemplate,
    patches: Dict[str, str],
    components_by_id: Dict[str, HardwareComponent],
    price_by_component_id: Dict[str, ComponentPrice],
    *,
    source: str,
    reasons: Optional[List[str]] = None,
    validate_budget: bool = True,
) -> BuildOptionResponse:
    if not template.details:
        raise CustomizationError("基底配置缺少结构化明细")
    details = BuildTemplateDetails.model_validate(template.details).model_copy(deep=True)
    parts = {part.role: part for part in details.parts}
    if set(parts) != CUSTOMIZABLE_ROLES:
        raise CustomizationError("基底配置不是完整八件套")

    unknown_roles = set(patches) - CUSTOMIZABLE_ROLES
    if unknown_roles:
        raise CustomizationError("AI 返回了未知配件类型")
    base_performance = _direction_performance(details.direction, parts)

    for role, component_id in patches.items():
        if request.no_gpu_build and role == "gpu":
            raise CustomizationError("自备显卡不能被 AI 替换")
        parts[role] = _priced_part(
            role,
            component_id,
            parts[role].condition,
            components_by_id,
            price_by_component_id,
        )

    if request.memory_size:
        parts["ram"] = _required_ram_part(
            request.memory_size,
            parts["ram"],
            components_by_id,
            price_by_component_id,
        )
    if request.storage_size:
        parts["storage"] = _priced_part(
            "storage",
            STORAGE_IDS[request.storage_size],
            parts["storage"].condition,
            components_by_id,
            price_by_component_id,
            allow_unrecommended=True,
        )
    if request.no_gpu_build:
        gpu = find_owned_gpu(request.owned_gpu_model or "", components_by_id.values())
        parts["gpu"] = BuildTemplatePart(
            role="gpu",
            component_id=gpu.id,
            name=gpu.name,
            condition="owned",
            reference_price=0,
            price_source="用户自备",
            price_date=details.price_date,
            specs=dict(gpu.specs),
        )

    extras: List[BuildTemplateExtra] = []
    if request.needs_wireless_network:
        motherboard = parts["motherboard"]
        if motherboard.component_id == A520_WIFI_EXCEPTION_ID:
            extras.append(
                BuildTemplateExtra(
                    id="wifi-bluetooth-adapter",
                    name="无线网卡（Wi-Fi + 蓝牙）",
                    condition="new",
                    reference_price=WIRELESS_ADAPTER_PRICE,
                )
            )
        elif "WIFI" not in motherboard.name.upper():
            wifi_name = motherboard.name
            wifi_name += " WIFI"
            parts["motherboard"] = motherboard.model_copy(
                update={
                    "name": wifi_name,
                    "reference_price": motherboard.reference_price + WIRELESS_ADAPTER_PRICE,
                    "price_source": motherboard.price_source + "；Wi-Fi/蓝牙功能加价",
                }
            )

    _validate_direction_floor(request, details.direction, base_performance, parts)
    _validate_gpu_vendor(request, parts["gpu"])
    _validate_gpu_cpu_floor(parts)
    _validate_psu(parts)

    components = {role: part.component_id for role, part in parts.items()}
    compatibility = evaluate_compatibility(
        BuildSelection(components=components),
        components_by_id,
    )
    if not compatibility.compatible:
        raise CustomizationError("修改后的配置存在硬性兼容问题")

    total = sum(part.reference_price for part in parts.values()) + sum(
        extra.reference_price for extra in extras
    )
    if validate_budget and total > customized_budget_limit(request):
        raise CustomizationError("修改后的配置超过预算上限")

    details.target_budget = request.budget
    details.parts = [parts[part.role] for part in details.parts]
    details.extras = extras
    details.gpu_vendor = _gpu_vendor(parts["gpu"])
    explanation = "；".join(reason.strip() for reason in reasons or [] if reason.strip())
    if not explanation:
        explanation = template.explanation

    return BuildOptionResponse(
        status="ready",
        source=source,
        template_id=template.id,
        title=template.title,
        components=components,
        estimated_total=total,
        explanation=explanation[:500],
        details=details,
    )


def deterministic_customization(
    request: BuildRequest,
    candidates: Iterable[BuildTemplate],
    components_by_id: Dict[str, HardwareComponent],
    price_by_component_id: Dict[str, ComponentPrice],
) -> Optional[BuildOptionResponse]:
    valid = []
    for template in candidates:
        try:
            option = customize_template(
                request,
                template,
                {},
                components_by_id,
                price_by_component_id,
                source="template",
            )
        except CustomizationError:
            continue
        valid.append((template, option))
    selected = min(
        valid,
        key=lambda item: (
            -_primary_performance(item[0]),
            abs((item[1].estimated_total or 0) - request.budget),
            -(item[1].estimated_total or 0),
            item[1].template_id,
        ),
        default=None,
    )
    return selected[1] if selected else None


def condition_price(price: ComponentPrice, condition: str) -> Optional[int]:
    if condition == "new":
        return price.price_range_high
    if condition == "used":
        return price.price_range_low
    return None


def find_owned_gpu(
    model: str,
    components: Iterable[HardwareComponent],
) -> HardwareComponent:
    query = _model_key(model)
    eligible = [
        component
        for component in components
        if component.category == "gpu"
        and component.status == "active"
        and component.is_recommended
    ]
    exact = [
        component
        for component in eligible
        if query in {_model_key(component.id), _model_key(component.name)}
    ]
    if len(exact) == 1:
        return exact[0]
    partial = [component for component in eligible if query in _model_key(component.name)]
    if len(partial) == 1:
        return partial[0]
    raise CustomizationError("自备显卡型号不在当前白名单内或型号不够明确")


def _priced_part(
    role: str,
    component_id: str,
    condition: str,
    components_by_id: Dict[str, HardwareComponent],
    price_by_component_id: Dict[str, ComponentPrice],
    *,
    allow_unrecommended: bool = False,
) -> BuildTemplatePart:
    component = components_by_id.get(component_id)
    price = price_by_component_id.get(component_id)
    if (
        component is None
        or price is None
        or component.category != role
        or component.status != "active"
        or (not component.is_recommended and not allow_unrecommended)
    ):
        raise CustomizationError("AI 返回了白名单外配件")
    reference_price = condition_price(price, condition)
    if reference_price is None:
        raise CustomizationError("所选配件没有对应成色的审核价格")
    approved_at = price.approved_at.date().isoformat()
    return BuildTemplatePart(
        role=role,
        component_id=component.id,
        name=component.name,
        condition=condition,
        reference_price=reference_price,
        price_source=price.source,
        price_date=approved_at,
        specs=dict(component.specs),
    )


def _required_ram_part(
    memory_size: str,
    current: BuildTemplatePart,
    components_by_id: Dict[str, HardwareComponent],
    price_by_component_id: Dict[str, ComponentPrice],
) -> BuildTemplatePart:
    capacity = int(memory_size.removesuffix("GB"))
    current_type = current.specs.get("type")
    current_speed = current.specs.get("speed_mhz")
    current_latency = current.specs.get("cas_latency")
    candidates = []
    for component in components_by_id.values():
        if component.category != "ram" or component.specs.get("capacity_gb") != capacity:
            continue
        if current_type and component.specs.get("type") != current_type:
            continue
        price = price_by_component_id.get(component.id)
        if price is None or condition_price(price, current.condition) is None:
            continue
        candidates.append(component)
    if not candidates:
        raise CustomizationError("当前内存容量没有对应平台和成色的审核价格")
    candidates.sort(
        key=lambda component: (
            component.specs.get("speed_mhz") != current_speed,
            component.specs.get("cas_latency") != current_latency,
            condition_price(price_by_component_id[component.id], current.condition) or 0,
            component.id,
        )
    )
    return _priced_part(
        "ram",
        candidates[0].id,
        current.condition,
        components_by_id,
        price_by_component_id,
    )


def _validate_direction_floor(
    request: BuildRequest,
    direction: str,
    base_performance: int,
    parts: Dict[str, BuildTemplatePart],
) -> None:
    if request.no_gpu_build:
        return
    if _direction_performance(direction, parts) < base_performance:
        raise CustomizationError("AI 降低了当前方向的核心性能")


def _validate_gpu_vendor(request: BuildRequest, gpu: BuildTemplatePart) -> None:
    if request.no_gpu_build:
        return
    requested = (request.gpu_preference or "").replace(" ", "").lower()
    if requested in {"nvidia", "n卡", "英伟达"} and _gpu_vendor(gpu) != "nvidia":
        raise CustomizationError("AI 更改了显卡品牌方向")
    if requested in {"amd", "a卡"} and _gpu_vendor(gpu) != "amd":
        raise CustomizationError("AI 更改了显卡品牌方向")
    if request.ray_tracing is True and _gpu_vendor(gpu) != "nvidia":
        raise CustomizationError("开启光追时只能使用 NVIDIA 显卡")
    if request.use_case != "办公" and _gpu_vendor(gpu) == "intel":
        raise CustomizationError("Intel Arc 仅用于纯办公配置")
    if (
        request.use_case == "办公"
        and classify_office_workload(request.office_apps) == "cuda"
        and _gpu_vendor(gpu) != "nvidia"
    ):
        raise CustomizationError("当前办公软件需要 NVIDIA 显卡")


def _validate_gpu_cpu_floor(parts: Dict[str, BuildTemplatePart]) -> None:
    required = GPU_MIN_CPU_PERFORMANCE.get(parts["gpu"].component_id)
    cpu_performance = parts["cpu"].specs.get("perf_index")
    if required is not None and (
        type(cpu_performance) is not int or cpu_performance < required
    ):
        raise CustomizationError("显卡所需的 CPU 性能下限未满足")


def _validate_psu(parts: Dict[str, BuildTemplatePart]) -> None:
    cpu_tdp = parts["cpu"].specs.get("tdp")
    gpu_tdp = parts["gpu"].specs.get("tdp")
    psu_watt = parts["psu"].specs.get("watt")
    if not all(type(value) is int for value in (cpu_tdp, gpu_tdp, psu_watt)):
        raise CustomizationError("缺少电源功耗校验数据")
    required = ceil((cpu_tdp + gpu_tdp) * 1.5 + 100)
    if psu_watt < required:
        raise CustomizationError(f"电源至少需要 {required}W")


def _direction_performance(
    direction: str,
    parts: Dict[str, BuildTemplatePart],
) -> int:
    cpu = parts["cpu"].specs.get("perf_index")
    gpu = parts["gpu"].specs.get("perf_index")
    if type(cpu) is not int or type(gpu) is not int:
        return 0
    if direction == "fps":
        return cpu
    if direction == "aaa":
        return gpu
    return min(cpu, gpu)


def _primary_performance(template: BuildTemplate) -> int:
    details = BuildTemplateDetails.model_validate(template.details)
    return _direction_performance(
        details.direction,
        {part.role: part for part in details.parts},
    )


def _gpu_vendor(gpu: BuildTemplatePart) -> str:
    vendor = str(gpu.specs.get("vendor", "")).lower()
    if vendor == "nvidia" or gpu.component_id.startswith("rtx-"):
        return "nvidia"
    if "intel" in vendor or gpu.component_id.startswith("arc-"):
        return "intel"
    return "amd"


def _model_key(value: str) -> str:
    return re.sub(r"[^a-z0-9]+", "", value.lower())
