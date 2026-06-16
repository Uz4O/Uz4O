from typing import Dict, List, Literal, Optional

from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from app.catalog.models import ComponentPrice, HardwareComponent
from app.catalog.repository import get_components_by_ids, list_component_prices, list_components


UpgradeStatus = Literal["ready", "needs_more_info", "no_plan"]

ROLE_LABELS = {
    "cpu": "CPU",
    "gpu": "显卡",
    "motherboard": "主板",
    "psu": "电源",
}


class CurrentHardwareInput(BaseModel):
    cpu: Optional[str] = Field(default=None, max_length=160)
    gpu: Optional[str] = Field(default=None, max_length=160)
    motherboard: Optional[str] = Field(default=None, max_length=160)
    psu: Optional[str] = Field(default=None, max_length=160)
    power_supply: Optional[str] = Field(default=None, max_length=160)


class UpgradePlanRequest(BaseModel):
    budget: int = Field(ge=0, le=300_000)
    current: CurrentHardwareInput
    need: str = Field(default="均衡提升", max_length=200)
    games: List[str] = Field(default_factory=list, max_length=12)


class UpgradeStep(BaseModel):
    order: int
    role: str
    from_component_id: str
    from_name: str
    to_component_id: str
    to_name: str
    estimated_price: int
    expected_gain_percent: int
    reason: str


class UpgradePlanResponse(BaseModel):
    status: UpgradeStatus
    summary: str
    budget: int
    total_estimated_price: int
    primary_bottleneck: Optional[str]
    missing_fields: List[str]
    steps: List[UpgradeStep]
    notes: List[str]


def generate_upgrade_plan(session: Session, request: UpgradePlanRequest) -> UpgradePlanResponse:
    missing_fields = _missing_core_fields(request.current)
    if missing_fields:
        return UpgradePlanResponse(
            status="needs_more_info",
            summary="当前电脑信息不完整，先补齐关键硬件后再生成升级顺序。",
            budget=request.budget,
            total_estimated_price=0,
            primary_bottleneck=None,
            missing_fields=missing_fields,
            steps=[],
            notes=["至少需要 CPU、显卡、主板和电源信息，才能避免给出不兼容的升级建议。"],
        )

    current_ids = {
        "cpu": request.current.cpu,
        "gpu": request.current.gpu,
        "motherboard": request.current.motherboard,
        "psu": request.current.psu or request.current.power_supply,
    }
    current_components = {
        component.id: component
        for component in get_components_by_ids(session, current_ids.values())
    }
    missing_from_catalog = [
        ROLE_LABELS[role]
        for role, component_id in current_ids.items()
        if component_id and component_id not in current_components
    ]
    if missing_from_catalog:
        return UpgradePlanResponse(
            status="needs_more_info",
            summary="部分当前硬件没有在硬件库里找到，先补齐或换成硬件库中的型号。",
            budget=request.budget,
            total_estimated_price=0,
            primary_bottleneck=None,
            missing_fields=missing_from_catalog,
            steps=[],
            notes=["升级建议只能基于维护中的硬件库生成，避免 AI 编出不存在的型号。"],
        )

    prices = {price.component_id: price for price in list_component_prices(session)}
    steps = _gpu_upgrade_steps(session, request, current_ids, current_components, prices)
    if not steps:
        return UpgradePlanResponse(
            status="no_plan",
            summary="当前预算内暂时没有找到比现有配置更合适、且有人工参考价的升级项。",
            budget=request.budget,
            total_estimated_price=0,
            primary_bottleneck=_primary_bottleneck(current_ids, current_components),
            missing_fields=[],
            steps=[],
            notes=["可以提高预算，或先补充更多已人工确认参考价的硬件数据。"],
        )

    total = sum(step.estimated_price for step in steps)
    return UpgradePlanResponse(
        status="ready",
        summary=f"预算内优先升级{ROLE_LABELS[steps[0].role]}，预计花费约 {total} 元。",
        budget=request.budget,
        total_estimated_price=total,
        primary_bottleneck=steps[0].role,
        missing_fields=[],
        steps=steps,
        notes=["本建议只使用硬件库和人工确认参考价；价格会随市场变化，需要下单前再核对。"],
    )


def _missing_core_fields(current: CurrentHardwareInput) -> List[str]:
    missing = []
    if not current.cpu:
        missing.append("CPU")
    if not current.gpu:
        missing.append("显卡")
    if not current.motherboard:
        missing.append("主板")
    if not (current.psu or current.power_supply):
        missing.append("电源")
    return missing


def _gpu_upgrade_steps(
    session: Session,
    request: UpgradePlanRequest,
    current_ids: Dict[str, Optional[str]],
    current_components: Dict[str, HardwareComponent],
    prices: Dict[str, ComponentPrice],
) -> List[UpgradeStep]:
    current_gpu_id = current_ids["gpu"]
    if current_gpu_id is None:
        return []
    current_gpu = current_components[current_gpu_id]
    current_perf = _int_spec(current_gpu, "perf_index")
    if current_perf <= 0:
        return []

    candidates = [
        component
        for component in list_components(session, category="gpu")
        if component.is_recommended
        and component.id != current_gpu_id
        and component.id in prices
        and _int_spec(component, "perf_index") > current_perf
        and prices[component.id].reference_price <= request.budget
    ]
    if not candidates:
        return []

    best = max(
        candidates,
        key=lambda component: (
            (_int_spec(component, "perf_index") - current_perf)
            / max(prices[component.id].reference_price, 1),
            _int_spec(component, "perf_index"),
        ),
    )
    best_price = prices[best.id].reference_price
    gain = round((_int_spec(best, "perf_index") - current_perf) / current_perf * 100)
    return [
        UpgradeStep(
            order=1,
            role="gpu",
            from_component_id=current_gpu.id,
            from_name=current_gpu.name,
            to_component_id=best.id,
            to_name=best.name,
            estimated_price=best_price,
            expected_gain_percent=gain,
            reason=f"{current_gpu.name} 是当前游戏性能短板，升级到 {best.name} 的收益最明显。",
        )
    ]


def _primary_bottleneck(
    current_ids: Dict[str, Optional[str]],
    current_components: Dict[str, HardwareComponent],
) -> Optional[str]:
    cpu = current_components.get(current_ids.get("cpu") or "")
    gpu = current_components.get(current_ids.get("gpu") or "")
    if cpu is None or gpu is None:
        return None
    cpu_perf = _int_spec(cpu, "perf_index")
    gpu_perf = _int_spec(gpu, "perf_index")
    if cpu_perf <= 0 or gpu_perf <= 0:
        return None
    return "gpu" if gpu_perf < cpu_perf * 0.9 else "cpu"


def _int_spec(component: HardwareComponent, key: str) -> int:
    value = component.specs.get(key)
    return value if isinstance(value, int) else 0
