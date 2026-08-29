import re
from dataclasses import dataclass
from itertools import product
from typing import Dict, Iterable, List, Optional

from app.builds.models import BuildTemplate
from app.builds.office_catalog import (
    OFFICE_CPU_IDS,
    OFFICE_GPU_IDS,
    OFFICE_MOTHERBOARD_IDS,
    OFFICE_ONLY_GPU_IDS,
)
from app.builds.service import (
    BuildOptionResponse,
    BuildRequest,
    BuildTemplateDetails,
    BuildTemplateExtra,
    BuildTemplatePart,
    classify_office_workload,
)
from app.catalog.models import ComponentPrice, HardwareComponent
from app.catalog.rule_specs import (
    GPU_MIN_CPU_PERFORMANCE,
    GPU_PERFORMANCE,
    is_cpu_gpu_pairing_allowed,
    minimum_psu_watt_for_specs,
    psu_supports_gpu_power_connector,
)
from app.compat.engine import BuildSelection, evaluate_compatibility


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
VALUE_STORAGE_MAX_BUDGET = 7_000
VALUE_STORAGE_IDS = {
    "512GB": "base-ssd-fanxiang-s500-pro-512gb",
    "1TB": "base-ssd-fanxiang-s790e-1tb",
}
A520_WIFI_EXCEPTION_ID = "asus-a520m-k"
A520_MAX_GPU_PERFORMANCE = GPU_PERFORMANCE["rx-7650-gre"]
LEGACY_AM4_COOLER_ID = "thermalright-ax120-se"
WEAK_HIGH_END_AM5_MOTHERBOARD_IDS = {"asus-prime-b650m-k"}
HIGH_END_AM5_CPU_IDS = {"r7-9800x3d", "r7-9850x3d"}
LEGACY_AM4_CPU_IDS = {"r5-5600", "r5-5600x"}
WIRELESS_ADAPTER_PRICE = 50
MAX_BUDGET_SHORTFALL = 200
RAY_TRACING_MIN_BUDGET = 10_000


class CustomizationError(ValueError):
    pass


@dataclass(frozen=True)
class BudgetWindow:
    quality_floor: int
    ceiling: int

    def accepts(self, total: int) -> bool:
        return self.quality_floor <= total <= self.ceiling

    def meets_quality_floor(self, total: int) -> bool:
        return total >= self.quality_floor


def build_budget_window(request: BuildRequest) -> BudgetWindow:
    ceiling = (
        request.budget + 800
        if request.budget >= 10_000
        else request.budget + (500 if request.allows_flexible_budget else 300)
    )
    return BudgetWindow(
        quality_floor=max(0, request.budget - MAX_BUDGET_SHORTFALL),
        ceiling=ceiling,
    )


def customized_budget_limit(request: BuildRequest) -> int:
    return build_budget_window(request).ceiling


def customized_budget_floor(request: BuildRequest) -> int:
    return build_budget_window(request).quality_floor


def adjacent_reviewed_budget(budget: int) -> int:
    step = 500 if budget < 10_000 else 1_000
    return (budget // step + 1) * step


def customization_candidates(
    request: BuildRequest,
    templates: Iterable[BuildTemplate],
    components_by_id: Dict[str, HardwareComponent],
    price_by_component_id: Dict[str, ComponentPrice],
    *,
    purchase_mode: str,
    gpu_vendor: Optional[str],
    failure_reasons: Optional[List[str]] = None,
    preview_totals: Optional[List[int]] = None,
) -> List[BuildTemplate]:
    candidates = []
    for template in templates:
        if template.status not in {None, "active"} or not template.details:
            continue
        try:
            details = BuildTemplateDetails.model_validate(template.details)
        except ValueError:
            if failure_reasons is not None:
                failure_reasons.append("审核基底的结构化明细无效")
            continue
        if request.use_case not in template.use_cases:
            continue
        if request.use_case == "办公":
            workload_tag = f"office-{classify_office_workload(request.office_apps)}"
            if workload_tag not in template.tags:
                continue
        if details.direction != request.direction or details.purchase_mode != purchase_mode:
            continue
        if details.target_budget > adjacent_reviewed_budget(request.budget):
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
        except CustomizationError as exc:
            if failure_reasons is not None:
                failure_reasons.append(str(exc))
            continue
        total = preview.estimated_total or 0
        candidates.append((template, total))
        if preview_totals is not None:
            preview_totals.append(total)

    if request.use_case == "办公" and candidates:
        latest_reviewed_budget = max(
            BuildTemplateDetails.model_validate(template.details).target_budget
            for template, _ in candidates
        )
        candidates = [
            (template, total)
            for template, total in candidates
            if BuildTemplateDetails.model_validate(template.details).target_budget
            == latest_reviewed_budget
        ]

    floor = customized_budget_floor(request)
    limit = customized_budget_limit(request)
    candidates.sort(
        key=lambda item: (
            not floor <= item[1] <= limit,
            -_primary_performance(item[0]),
            abs(item[1] - request.budget),
            item[0].id,
        )
    )
    return [template for template, _ in candidates]


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
    minimum_direction_performance: Optional[int] = None,
    condition_overrides: Optional[Dict[str, str]] = None,
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
    condition_overrides = condition_overrides or {}
    if set(condition_overrides) - CUSTOMIZABLE_ROLES:
        raise CustomizationError("配置包含未知配件成色")
    base_performance = (
        minimum_direction_performance
        if minimum_direction_performance is not None
        else _direction_performance(details.direction, parts)
    )

    for role, component_id in patches.items():
        if request.no_gpu_build and role == "gpu":
            raise CustomizationError("自备显卡不能被 AI 替换")
        component = components_by_id.get(component_id)
        if component is None or not component_allowed_for_request(request, component):
            raise CustomizationError("AI 返回了当前用途不可用的配件")
        parts[role] = _priced_part(
            role,
            component_id,
            condition_overrides.get(role, parts[role].condition),
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
        parts["storage"] = _required_storage_part(
            request,
            parts["storage"],
            components_by_id,
            price_by_component_id,
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
    _validate_specified_parts(request, parts)
    _validate_budget_cpu_policy(request, parts)
    _validate_gpu_vendor(request, parts["gpu"])
    _validate_gpu_cpu_floor(parts)
    _validate_cpu_gpu_pairing(request, parts)
    _validate_motherboard_policy(request, parts)
    _validate_am5_memory(parts)
    _validate_ddr4_memory(parts)
    _validate_psu(parts)
    _validate_cooler(parts)

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
    if validate_budget and total < customized_budget_floor(request):
        raise CustomizationError("修改后的配置低于预算下限")
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
    candidates = list(candidates)
    reviewed_core_baselines, feasible_core_baselines = _candidate_core_performances(
        request,
        candidates,
        components_by_id,
        price_by_component_id,
    )
    if reviewed_core_baselines:
        minimum_direction_performance = max(
            _focus_core_performance(request.direction, performance)
            for performance in reviewed_core_baselines
        )
    else:
        minimum_direction_performance = min(
            (_primary_performance(template) for template in candidates),
            default=0,
        )
        minimum_direction_performance = max(
            0,
            minimum_direction_performance - 15,
        )
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
        if (
            _direction_performance(
                request.direction,
                {part.role: part for part in option.details.parts},
            )
            < minimum_direction_performance
        ):
            continue
        if _core_is_dominated(
            _core_performance({part.role: part for part in option.details.parts}),
            feasible_core_baselines,
        ):
            continue
        valid.append(option)

    searched = _search_customization(
        request,
        candidates,
        components_by_id,
        price_by_component_id,
        minimum_direction_performance,
        feasible_core_baselines,
    )
    if searched is not None:
        valid.append(searched)
    return select_best_build_option(request, valid)


def _search_customization(
    request: BuildRequest,
    candidates: List[BuildTemplate],
    components_by_id: Dict[str, HardwareComponent],
    price_by_component_id: Dict[str, ComponentPrice],
    minimum_performance: int,
    feasible_core_baselines: List[tuple[int, int]],
) -> Optional[BuildOptionResponse]:
    if not candidates:
        return None
    base = min(
        candidates,
        key=lambda template: (
            _primary_performance(template),
            BuildTemplateDetails.model_validate(template.details).target_budget,
            template.id,
        ),
    )
    details = BuildTemplateDetails.model_validate(base.details)
    base_parts = {part.role: part for part in details.parts}
    if set(base_parts) != CUSTOMIZABLE_ROLES:
        return None

    conditions = {role: part.condition for role, part in base_parts.items()}
    role_candidates = {}
    for role in ("cpu", "motherboard", "gpu", "psu", "cooler", "case"):
        role_conditions = [conditions[role]]
        if (
            details.purchase_mode == "mixed"
            and role in {"cooler", "case"}
            and conditions[role] == "used"
        ):
            role_conditions.append("new")
        role_candidates[role] = [
            part
            for condition in role_conditions
            for part in _priced_candidates(
                request,
                role,
                condition,
                components_by_id,
                price_by_component_id,
            )
        ]
        if role == "cooler" and "new" not in role_conditions:
            role_candidates[role].extend(
                part
                for part in _priced_candidates(
                    request,
                    role,
                    "new",
                    components_by_id,
                    price_by_component_id,
                )
                if part.component_id == LEGACY_AM4_COOLER_ID
            )
    if any(not role_candidates[role] for role in role_candidates):
        return None

    if request.no_gpu_build:
        owned_gpu = find_owned_gpu(
            request.owned_gpu_model or "",
            components_by_id.values(),
        )
        gpu_candidates = [
            BuildTemplatePart(
                role="gpu",
                component_id=owned_gpu.id,
                name=owned_gpu.name,
                condition="owned",
                reference_price=0,
                price_source="用户自备",
                price_date=details.price_date,
                specs=dict(owned_gpu.specs),
            )
        ]
    else:
        gpu_candidates = role_candidates["gpu"]

    try:
        storage = (
            _required_storage_part(
                request,
                base_parts["storage"],
                components_by_id,
                price_by_component_id,
            )
            if request.storage_size
            else _priced_part(
                "storage",
                base_parts["storage"].component_id,
                conditions["storage"],
                components_by_id,
                price_by_component_id,
                allow_unrecommended=True,
            )
        )
    except CustomizationError:
        return None

    memory_capacity = (
        int(request.memory_size.removesuffix("GB"))
        if request.memory_size
        else base_parts["ram"].specs.get("capacity_gb")
    )
    ram_candidates = [
        part
        for part in _priced_candidates(
            request,
            "ram",
            conditions["ram"],
            components_by_id,
            price_by_component_id,
        )
        if part.specs.get("capacity_gb") == memory_capacity
    ]
    if not ram_candidates:
        return None

    observed_memory_types = _observed_motherboard_memory_types(candidates)
    budget_window = build_budget_window(request)
    ranked_patches = []
    for cpu, motherboard, gpu in product(
        role_candidates["cpu"],
        role_candidates["motherboard"],
        gpu_candidates,
    ):
        if cpu.specs.get("socket") != motherboard.specs.get("socket"):
            continue
        if not request.no_gpu_build:
            try:
                _validate_gpu_vendor(request, gpu)
                _validate_gpu_cpu_floor({"cpu": cpu, "gpu": gpu})
                _validate_cpu_gpu_pairing(request, {"cpu": cpu, "gpu": gpu})
            except CustomizationError:
                continue
        core_parts = {"cpu": cpu, "gpu": gpu}
        if _direction_performance(details.direction, core_parts) < minimum_performance:
            continue
        if _core_is_dominated(_core_performance(core_parts), feasible_core_baselines):
            continue

        memory_type = motherboard.specs.get("mem_type")
        if not memory_type:
            memory_type = observed_memory_types.get(motherboard.component_id)
        compatible_ram = [
            ram
            for ram in ram_candidates
            if memory_type and ram.specs.get("type") == memory_type
            and (
                motherboard.specs.get("socket") != "AM5"
                or (
                    ram.specs.get("speed_mhz") == 6000
                    and ram.specs.get("cas_latency") == 28
                )
            )
        ]
        if not compatible_ram:
            continue

        valid_psus = []
        for psu in role_candidates["psu"]:
            try:
                _validate_psu({"cpu": cpu, "gpu": gpu, "psu": psu})
            except CustomizationError:
                continue
            valid_psus.append(psu)
        if not valid_psus:
            continue
        psu = min(
            valid_psus,
            key=lambda part: (
                part.specs.get("watt", 0),
                part.reference_price,
                part.component_id,
            ),
        )
        cooler_candidates = _required_cooler_candidates(
            cpu,
            role_candidates["cooler"],
        )
        if not cooler_candidates:
            continue

        for ram, cooler, case in product(
            compatible_ram,
            cooler_candidates,
            role_candidates["case"],
        ):
            parts = {
                "cpu": cpu,
                "motherboard": motherboard,
                "gpu": gpu,
                "ram": ram,
                "storage": storage,
                "psu": psu,
                "cooler": cooler,
                "case": case,
            }
            try:
                _validate_motherboard_policy(request, parts)
            except CustomizationError:
                continue
            total = sum(part.reference_price for part in parts.values())
            total += _wireless_cost(request, motherboard)
            if not budget_window.accepts(total):
                continue
            ranked_patches.append(
                (
                    _parts_sort_key(request, parts, total),
                    {
                        role: part.component_id
                        for role, part in parts.items()
                        if not (request.no_gpu_build and role == "gpu")
                    },
                    {
                        role: part.condition
                        for role, part in parts.items()
                        if part.condition != conditions[role]
                    },
                )
            )

    patch_bases = sorted(
        candidates,
        key=lambda template: (
            BuildTemplateDetails.model_validate(template.details).target_budget
            > request.budget,
            abs(
                BuildTemplateDetails.model_validate(template.details).target_budget
                - request.budget
            ),
            -_primary_performance(template),
            template.id,
        ),
    )
    for _, patches, condition_overrides in sorted(
        ranked_patches,
        key=lambda item: item[0],
    ):
        for patch_base in patch_bases:
            try:
                return customize_template(
                    request,
                    patch_base,
                    patches,
                    components_by_id,
                    price_by_component_id,
                    source="template",
                    reasons=[
                        "已锁定内存与存储容量，并用审核白名单内配件优化预算。"
                        if minimum_performance
                        else "改用更低价位基底，以满足容量、兼容性和预算硬约束。"
                    ],
                    minimum_direction_performance=minimum_performance,
                    condition_overrides=condition_overrides,
                )
            except CustomizationError:
                continue
    return None


def _candidate_core_performances(
    request: BuildRequest,
    candidates: List[BuildTemplate],
    components_by_id: Dict[str, HardwareComponent],
    price_by_component_id: Dict[str, ComponentPrice],
) -> tuple[List[tuple[int, int]], List[tuple[int, int]]]:
    reviewed_performances = []
    feasible_performances = []
    budget_window = build_budget_window(request)
    for candidate in candidates:
        details = BuildTemplateDetails.model_validate(candidate.details)
        try:
            preview = customize_template(
                request,
                candidate,
                {},
                components_by_id,
                price_by_component_id,
                source="template",
                validate_budget=False,
            )
        except CustomizationError:
            continue
        total = preview.estimated_total or 0
        if total <= budget_window.ceiling:
            performance = _core_performance(
                {part.role: part for part in preview.details.parts}
            )
            reviewed_performances.append(performance)
            if budget_window.meets_quality_floor(total):
                feasible_performances.append(performance)
    return reviewed_performances, feasible_performances


def _priced_candidates(
    request: BuildRequest,
    role: str,
    condition: str,
    components_by_id: Dict[str, HardwareComponent],
    price_by_component_id: Dict[str, ComponentPrice],
) -> List[BuildTemplatePart]:
    candidates = []
    for component in components_by_id.values():
        price = price_by_component_id.get(component.id)
        if (
            component.category != role
            or component.status != "active"
            or not component.is_recommended
            or price is None
            or condition_price(price, condition) is None
            or not component_allowed_for_request(request, component)
        ):
            continue
        candidates.append(
            _priced_part(
                role,
                component.id,
                condition,
                components_by_id,
                price_by_component_id,
            )
        )
    return candidates


def _observed_motherboard_memory_types(
    candidates: Iterable[BuildTemplate],
) -> Dict[str, str]:
    observed: Dict[str, set[str]] = {}
    for template in candidates:
        details = BuildTemplateDetails.model_validate(template.details)
        parts = {part.role: part for part in details.parts}
        memory_type = parts["ram"].specs.get("type")
        if isinstance(memory_type, str):
            observed.setdefault(parts["motherboard"].component_id, set()).add(memory_type)
    return {
        component_id: next(iter(memory_types))
        for component_id, memory_types in observed.items()
        if len(memory_types) == 1
    }


def _wireless_cost(request: BuildRequest, motherboard: BuildTemplatePart) -> int:
    if not request.needs_wireless_network or "WIFI" in motherboard.name.upper():
        return 0
    return WIRELESS_ADAPTER_PRICE


def _option_sort_key(
    request: BuildRequest,
    option: BuildOptionResponse,
) -> tuple:
    parts = {part.role: part for part in option.details.parts}
    return (*_parts_sort_key(request, parts, option.estimated_total or 0), option.template_id)


def select_best_build_option(
    request: BuildRequest,
    options: Iterable[BuildOptionResponse],
) -> Optional[BuildOptionResponse]:
    return min(
        options,
        key=lambda option: _option_sort_key(request, option),
        default=None,
    )


def _parts_sort_key(
    request: BuildRequest,
    parts: Dict[str, BuildTemplatePart],
    total: int,
) -> tuple:
    cpu_performance = parts["cpu"].specs.get("perf_index", 0)
    gpu_performance = parts["gpu"].specs.get("perf_index", 0)
    if not isinstance(cpu_performance, int):
        cpu_performance = 0
    if not isinstance(gpu_performance, int):
        gpu_performance = 0
    if request.direction == "fps":
        performance = (cpu_performance, gpu_performance)
    elif request.direction == "aaa":
        performance = (gpu_performance, cpu_performance)
    else:
        performance = (
            min(cpu_performance, gpu_performance),
            cpu_performance + gpu_performance,
        )
    budget_window = build_budget_window(request)
    return (
        not budget_window.meets_quality_floor(total),
        -performance[0],
        -performance[1],
        -_motherboard_reliability(parts["motherboard"]),
        -_cooler_reliability(parts["cooler"]),
        abs(total - request.budget),
        total > request.budget,
        -total,
        tuple(part.component_id for part in parts.values()),
    )


def _motherboard_reliability(motherboard: BuildTemplatePart) -> int:
    chipset = str(motherboard.specs.get("chipset", "")).upper()
    if chipset.startswith("X"):
        return 3
    if chipset.startswith("B"):
        return 2
    if chipset.startswith("A"):
        return 1
    return 0


def _cooler_reliability(cooler: BuildTemplatePart) -> int:
    towers = cooler.specs.get("towers", 1)
    heatpipes = cooler.specs.get("heatpipes", 0)
    return (towers if isinstance(towers, int) else 1) * 10 + (
        heatpipes if isinstance(heatpipes, int) else 0
    )


def _required_cooler_candidates(
    cpu: BuildTemplatePart,
    candidates: List[BuildTemplatePart],
) -> List[BuildTemplatePart]:
    if cpu.component_id in LEGACY_AM4_CPU_IDS:
        return [
            cooler
            for cooler in candidates
            if cooler.component_id == LEGACY_AM4_COOLER_ID
        ]
    hot_cpu = (
        cpu.component_id in {"r7-7800x3d", "r7-9800x3d", "r7-9850x3d"}
        or isinstance(cpu.specs.get("tdp"), int)
        and cpu.specs["tdp"] >= 120
    )
    adequate = []
    for cooler in candidates:
        heatpipes = cooler.specs.get("heatpipes")
        if isinstance(heatpipes, int) and heatpipes < 6:
            continue
        towers = cooler.specs.get("towers")
        if hot_cpu and not (
            isinstance(towers, int) and towers >= 2
            or "dual-tower" in cooler.component_id
        ):
            continue
        adequate.append(cooler)
    if not adequate:
        return []
    conditions = {part.condition for part in adequate}
    return [
        min(
            (part for part in adequate if part.condition == condition),
            key=lambda part: (part.reference_price, part.component_id),
        )
        for condition in sorted(conditions)
    ]


def condition_price(price: ComponentPrice, condition: str) -> Optional[int]:
    if condition == "new":
        return price.price_range_high
    if condition == "used":
        return price.price_range_low
    return None


def component_allowed_for_request(
    request: BuildRequest,
    component: HardwareComponent,
) -> bool:
    if (
        component.category == "cpu"
        and request.specified_cpu
        and not _matches_specified_model(request.specified_cpu, component)
    ):
        return False
    if component.id == "i5-14600kf":
        return False
    if (
        component.category == "gpu"
        and request.specified_gpu
        and not _matches_specified_model(request.specified_gpu, component)
    ):
        return False
    requested_cpu = (request.cpu_preference or "").replace(" ", "").lower()
    if component.category == "cpu" and requested_cpu in {"amd", "a家", "锐龙"}:
        if not component.id.startswith("r"):
            return False
    if component.category == "cpu" and requested_cpu in {"intel", "英特尔", "i家"}:
        if not component.id.startswith(("i", "u")):
            return False
    if request.use_case != "办公":
        requested_gpu = (request.gpu_preference or "").replace(" ", "").lower()
        if (
            component.category == "gpu"
            and requested_gpu in {"nvidia", "n卡", "英伟达"}
        ):
            return component.id.startswith("rtx-")
        return not (
            component.category == "gpu"
            and component.id in OFFICE_ONLY_GPU_IDS
        )
    if component.category == "cpu":
        return component.id in OFFICE_CPU_IDS
    if component.category == "motherboard":
        return component.id in OFFICE_MOTHERBOARD_IDS
    if component.category == "gpu":
        if component.id not in OFFICE_GPU_IDS:
            return False
        if classify_office_workload(request.office_apps) == "cuda":
            return component.id.startswith("rtx-")
    return True


def _matches_specified_model(
    query: str,
    component: HardwareComponent,
) -> bool:
    query_key = _model_key(query)
    if not query_key:
        return False
    component_keys = (_model_key(component.id), _model_key(component.name))
    return any(
        query_key == key or query_key in key or key in query_key
        for key in component_keys
    )


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
        if (
            component.category != "ram"
            or component.status != "active"
            or not component.is_recommended
            or component.specs.get("capacity_gb") != capacity
        ):
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


def _required_storage_part(
    request: BuildRequest,
    current: BuildTemplatePart,
    components_by_id: Dict[str, HardwareComponent],
    price_by_component_id: Dict[str, ComponentPrice],
) -> BuildTemplatePart:
    if not request.storage_size:
        return current
    storage_ids = (
        VALUE_STORAGE_IDS
        if request.budget <= VALUE_STORAGE_MAX_BUDGET
        else STORAGE_IDS
    )
    return _priced_part(
        "storage",
        storage_ids.get(
            request.storage_size,
            STORAGE_IDS[request.storage_size],
        ),
        current.condition,
        components_by_id,
        price_by_component_id,
        allow_unrecommended=True,
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
    if (
        request.ray_tracing is True
        and request.budget >= RAY_TRACING_MIN_BUDGET
        and _gpu_vendor(gpu) != "nvidia"
    ):
        raise CustomizationError("开启光追时只能使用 NVIDIA 显卡")
    if request.use_case != "办公" and _gpu_vendor(gpu) == "intel":
        raise CustomizationError("Intel Arc 仅用于纯办公配置")
    if (
        request.use_case == "办公"
        and classify_office_workload(request.office_apps) == "cuda"
        and _gpu_vendor(gpu) != "nvidia"
    ):
        raise CustomizationError("当前办公软件需要 NVIDIA 显卡")


def _validate_specified_parts(
    request: BuildRequest,
    parts: Dict[str, BuildTemplatePart],
) -> None:
    for role, query in (
        ("cpu", request.specified_cpu),
        ("gpu", request.specified_gpu),
    ):
        if not query:
            continue
        component = HardwareComponent(
            id=parts[role].component_id,
            category=role,
            name=parts[role].name,
            brand="",
            detail_raw="",
            specs=dict(parts[role].specs),
            is_recommended=True,
            status="active",
        )
        if not _matches_specified_model(query, component):
            raise CustomizationError(f"配置未满足用户指定的 {role.upper()} 型号")


def _validate_budget_cpu_policy(
    request: BuildRequest,
    parts: Dict[str, BuildTemplatePart],
) -> None:
    if not budget_cpu_policy_allows(request, parts["cpu"]):
        raise CustomizationError("6000元及以上游戏配置不能使用 R5 5600/5600X")


def budget_cpu_policy_allows(
    request: BuildRequest,
    cpu: BuildTemplatePart,
) -> bool:
    return not (
        request.use_case != "办公"
        and request.budget >= 6_000
        and cpu.component_id in LEGACY_AM4_CPU_IDS
        and not request.specified_cpu
    )


def _validate_gpu_cpu_floor(parts: Dict[str, BuildTemplatePart]) -> None:
    required = GPU_MIN_CPU_PERFORMANCE.get(parts["gpu"].component_id)
    cpu_performance = parts["cpu"].specs.get("perf_index")
    if required is not None and (
        type(cpu_performance) is not int or cpu_performance < required
    ):
        raise CustomizationError("显卡所需的 CPU 性能下限未满足")


def _validate_cpu_gpu_pairing(
    request: BuildRequest,
    parts: Dict[str, BuildTemplatePart],
) -> None:
    if request.use_case == "办公":
        return
    if not is_cpu_gpu_pairing_allowed(
        parts["cpu"].component_id,
        parts["gpu"].component_id,
    ):
        raise CustomizationError("CPU 与显卡搭配达到高U低显或低U高显级别")


def _validate_motherboard_policy(
    request: BuildRequest,
    parts: Dict[str, BuildTemplatePart],
) -> None:
    if not motherboard_supports_cpu(parts):
        if parts["motherboard"].component_id == A520_WIFI_EXCEPTION_ID:
            raise CustomizationError("A520M-K 只能搭配 RX 7650 GRE 同级或更低性能显卡")
        raise CustomizationError("9800X3D/9850X3D 不能使用入门级 B650M-K 主板")


def motherboard_supports_cpu(
    parts: Dict[str, BuildTemplatePart],
) -> bool:
    return not (
        (
            parts["cpu"].component_id in HIGH_END_AM5_CPU_IDS
            and parts["motherboard"].component_id in WEAK_HIGH_END_AM5_MOTHERBOARD_IDS
        )
        or (
            parts["motherboard"].component_id == A520_WIFI_EXCEPTION_ID
            and parts["gpu"].specs.get("perf_index", A520_MAX_GPU_PERFORMANCE + 1)
            > A520_MAX_GPU_PERFORMANCE
        )
    )


def _validate_am5_memory(parts: Dict[str, BuildTemplatePart]) -> None:
    if parts["motherboard"].specs.get("socket") != "AM5":
        return
    ram = parts["ram"].specs
    if ram.get("speed_mhz") != 6000 or ram.get("cas_latency") != 28:
        raise CustomizationError("AM5 平台必须使用 DDR5 6000 C28 内存")


def _validate_ddr4_memory(parts: Dict[str, BuildTemplatePart]) -> None:
    if not ddr4_memory_policy_allows(parts["ram"]):
        raise CustomizationError("DDR4 内存必须使用双通道 3200 规格")


def ddr4_memory_policy_allows(ram: BuildTemplatePart) -> bool:
    specs = ram.specs
    return specs.get("type") != "DDR4" or (
        specs.get("modules") == 2 and specs.get("speed_mhz") == 3200
    )


def _validate_psu(parts: Dict[str, BuildTemplatePart]) -> None:
    cpu_tdp = parts["cpu"].specs.get("tdp")
    gpu_tdp = parts["gpu"].specs.get("tdp")
    psu_watt = parts["psu"].specs.get("watt")
    if not all(type(value) is int for value in (cpu_tdp, gpu_tdp, psu_watt)):
        raise CustomizationError("缺少电源功耗校验数据")
    required = minimum_psu_watt_for_specs(
        cpu_tdp,
        parts["gpu"].component_id,
        gpu_tdp,
    )
    if psu_watt < required:
        raise CustomizationError(f"电源至少需要 {required}W")
    if not psu_supports_gpu_power_connector(
        parts["gpu"].component_id,
        parts["psu"].specs,
    ):
        raise CustomizationError("电源缺少完整的原生600W 12V-2x6供电路径")


def _validate_cooler(parts: Dict[str, BuildTemplatePart]) -> None:
    cpu = parts["cpu"]
    cooler = parts["cooler"]
    if cpu.component_id in LEGACY_AM4_CPU_IDS:
        if (
            cooler.component_id != LEGACY_AM4_COOLER_ID
            or cooler.condition != "new"
        ):
            raise CustomizationError("R5 5600/5600X 必须使用全新利民 AX120 SE 散热器")
        return
    heatpipes = cooler.specs.get("heatpipes")
    if isinstance(heatpipes, int) and heatpipes < 6:
        raise CustomizationError("散热器至少需要六热管")
    hot_cpu = (
        cpu.component_id in {"r7-7800x3d", "r7-9800x3d", "r7-9850x3d"}
        or isinstance(cpu.specs.get("tdp"), int)
        and cpu.specs["tdp"] >= 120
    )
    towers = cooler.specs.get("towers")
    if hot_cpu and not (
        isinstance(towers, int) and towers >= 2
        or "dual-tower" in cooler.component_id
    ):
        raise CustomizationError("当前高热 CPU 必须使用双塔六热管散热器")


def _direction_performance(
    direction: str,
    parts: Dict[str, BuildTemplatePart],
) -> int:
    return _direction_performance_tuple(direction, parts)[0]


def _direction_performance_tuple(
    direction: str,
    parts: Dict[str, BuildTemplatePart],
) -> tuple[int, int]:
    cpu = parts["cpu"].specs.get("perf_index")
    gpu = parts["gpu"].specs.get("perf_index")
    if type(cpu) is not int or type(gpu) is not int:
        return (0, 0)
    if direction == "fps":
        return (cpu, gpu)
    if direction == "aaa":
        return (gpu, cpu)
    return (min(cpu, gpu), cpu + gpu)


def _core_performance(
    parts: Dict[str, BuildTemplatePart],
) -> tuple[int, int]:
    cpu = parts["cpu"].specs.get("perf_index")
    gpu = parts["gpu"].specs.get("perf_index")
    return (
        cpu if type(cpu) is int else 0,
        gpu if type(gpu) is int else 0,
    )


def _focus_core_performance(
    direction: str,
    performance: tuple[int, int],
) -> int:
    cpu, gpu = performance
    if direction == "fps":
        return cpu
    if direction == "aaa":
        return gpu
    return min(cpu, gpu)


def _core_is_dominated(
    performance: tuple[int, int],
    baselines: List[tuple[int, int]],
) -> bool:
    cpu, gpu = performance
    return any(
        baseline_cpu >= cpu
        and baseline_gpu >= gpu
        and (baseline_cpu > cpu or baseline_gpu > gpu)
        for baseline_cpu, baseline_gpu in baselines
    )


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
