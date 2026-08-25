from dataclasses import dataclass
from typing import Dict, List, Literal, Optional, Sequence

from pydantic import BaseModel, Field
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.catalog.models import (
    CPUWhitelistPrice,
    GPUWhitelistPrice,
    HardwareComponent,
    MotherboardWhitelistPrice,
)
from app.catalog.repository import get_components_by_ids, list_component_prices, list_components
from app.catalog.rule_specs import (
    CPU_GPU_PAIRING_TIER,
    GPU_MIN_CPU_PERFORMANCE,
    GPU_PAIRING_TIER,
    GPU_PAIRING_CPU_TIER_BOUNDS,
    minimum_psu_watt_for_specs,
    psu_supports_gpu_power_connector,
)
from app.builds.repository import list_build_templates
from app.builds.service import BuildTemplateDetails, BuildTemplatePart
from app.compat.engine import BuildSelection, evaluate_compatibility
from app.perf.generated_estimator import hardware_performance_score
from app.perf.profiles import APPROVED_GAME_PROFILES, GameLoadType
from app.perf.service import estimate_generated_game_fps


UpgradeStatus = Literal["ready", "already_sufficient", "needs_more_info", "no_plan"]
Resolution = Literal["1080p", "2k", "4k"]

ROLE_LABELS = {
    "cpu": "CPU",
    "gpu": "显卡",
    "motherboard": "主板",
    "ram": "内存",
    "psu": "电源",
    "cooler": "散热器",
}
EXCLUDED_GAMING_GPU_IDS = {"rtx-4070-ti"}


class CurrentHardwareInput(BaseModel):
    cpu: Optional[str] = Field(default=None, max_length=160)
    gpu: Optional[str] = Field(default=None, max_length=160)
    motherboard: Optional[str] = Field(default=None, max_length=160)
    ram: Optional[str] = Field(default=None, max_length=160)
    storage: Optional[str] = Field(default=None, max_length=160)
    psu: Optional[str] = Field(default=None, max_length=160)
    power_supply: Optional[str] = Field(default=None, max_length=160)


class UpgradePlanRequest(BaseModel):
    budget: int = Field(ge=0, le=300_000)
    current: CurrentHardwareInput
    need: str = Field(default="均衡提升", max_length=200)
    games: List[str] = Field(default_factory=list, max_length=15)
    resolution: Resolution = "2k"
    target_fps: Optional[int] = Field(default=None, ge=30, le=500)


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
    bundle_id: str
    bundle_title: str
    required_together: bool


class UpgradeGameResult(BaseModel):
    game: str
    before_fps: int
    after_fps: int
    target_fps: int
    met: bool


class UpgradePlanResponse(BaseModel):
    status: UpgradeStatus
    summary: str
    budget: int
    total_estimated_price: int
    primary_bottleneck: Optional[str]
    missing_fields: List[str]
    steps: List[UpgradeStep]
    notes: List[str]
    resolution: Resolution
    target_fps: Optional[int]
    target_met: Optional[bool]
    game_results: List[UpgradeGameResult]
    direction: Optional[Literal["fps", "aaa", "balanced"]]
    anchor_template_id: Optional[str]
    price_date: Optional[str]


@dataclass(frozen=True)
class CandidatePlan:
    components: Dict[str, HardwareComponent]
    prices: Dict[str, int]
    game_results: List[UpgradeGameResult]
    score: float
    anchor_template_id: Optional[str] = None
    price_date: Optional[str] = None
    direction: Optional[str] = None

    @property
    def total(self) -> int:
        return sum(self.prices.values())


def generate_upgrade_plan(session: Session, request: UpgradePlanRequest) -> UpgradePlanResponse:
    missing_fields = _missing_core_fields(request.current)
    if request.target_fps is not None and not request.games:
        missing_fields.append("游戏")
    unsupported_games = [
        game
        for game in request.games
        if request.target_fps is not None and game not in APPROVED_GAME_PROFILES
    ]
    if unsupported_games:
        missing_fields.append("可识别的游戏")
    if missing_fields:
        return _empty_response(
            request,
            status="needs_more_info",
            summary="当前电脑或升级目标信息不完整，补齐后再生成升级顺序。",
            missing_fields=missing_fields,
            notes=["至少需要 CPU、显卡、主板和电源；游戏目标还需要选择游戏。"],
        )

    current_ids = {
        "cpu": request.current.cpu,
        "gpu": request.current.gpu,
        "motherboard": request.current.motherboard,
        "ram": request.current.ram,
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
        return _empty_response(
            request,
            status="needs_more_info",
            summary="部分当前硬件没有在硬件库里找到，先换成硬件库中的型号。",
            missing_fields=missing_from_catalog,
            notes=["只基于维护中的硬件库生成建议，避免编造型号。"],
        )

    current_by_role = {
        role: current_components[component_id]
        for role, component_id in current_ids.items()
        if component_id and component_id in current_components
    }
    direction = _direction_for_games(request.games) if request.games else None
    current_results = _game_results(
        request,
        current_by_role["cpu"],
        current_by_role["gpu"],
    )
    if (
        request.target_fps is not None
        and len(current_results) == len(request.games)
        and all(result.met for result in current_results)
    ):
        return UpgradePlanResponse(
            status="already_sufficient",
            summary=(
                f"当前配置已经能达到 {request.resolution} 下 {request.target_fps} 帧的目标，"
                "不建议为了这次目标额外更换配件。"
            ),
            budget=request.budget,
            total_estimated_price=0,
            primary_bottleneck=None,
            missing_fields=[],
            steps=[],
            notes=[
                "当前方案按已维护的游戏性能数据判断。",
                "如果之后提高分辨率、画质或目标帧率，可以重新生成升级建议。",
            ],
            resolution=request.resolution,
            target_fps=request.target_fps,
            target_met=True,
            game_results=current_results,
            direction=direction,
            anchor_template_id=None,
            price_date=None,
        )

    prices = _new_price_map(session)
    candidates = (
        _reviewed_anchor_plans(
            session,
            request,
            current_by_role,
            current_results,
            direction or "balanced",
        )
        if request.target_fps is not None
        else _candidate_plans(session, request, current_by_role, prices)
    )
    if not candidates:
        return _empty_response(
            request,
            status="no_plan",
            summary="当前预算内没有找到来自人工审核基底、性能更高且兼容的新件方案。",
            primary_bottleneck=_primary_bottleneck(current_by_role),
            notes=["可以提高预算，或调整分辨率与目标帧率后重试。"],
            direction=direction,
        )

    best = min(candidates, key=lambda candidate: _candidate_sort_key(candidate, request))
    steps = _steps_for_candidate(current_by_role, best)
    target_met = (
        len(best.game_results) == len(request.games)
        and all(result.met for result in best.game_results)
        if request.target_fps is not None
        else None
    )
    if target_met is False:
        summary = f"预算内无法完全达到 {request.target_fps} 帧，已给出最接近的兼容方案。"
    else:
        summary = f"预算内建议按顺序升级 {len(steps)} 个配件，新件预估合计约 {best.total} 元。"
    notes = [
        "预算按新配件总价计算，不扣除旧件残值。",
        "帧率为维护数据与性能模型估算，实际会受画质、版本、散热和内存影响。",
        "未列出的配件默认继续保留。",
    ]
    if any(step.role == "gpu" for step in steps):
        notes.append("购买显卡前请核对显卡长度与机箱显卡限位，当前输入不含机箱内部尺寸。")

    return UpgradePlanResponse(
        status="ready",
        summary=summary,
        budget=request.budget,
        total_estimated_price=best.total,
        primary_bottleneck=steps[0].role if steps else _primary_bottleneck(current_by_role),
        missing_fields=[],
        steps=steps,
        notes=notes,
        resolution=request.resolution,
        target_fps=request.target_fps,
        target_met=target_met,
        game_results=best.game_results,
        direction=best.direction or direction,
        anchor_template_id=best.anchor_template_id,
        price_date=best.price_date,
    )


def _reviewed_anchor_plans(
    session: Session,
    request: UpgradePlanRequest,
    current: Dict[str, HardwareComponent],
    current_results: Sequence[UpgradeGameResult],
    direction: Literal["fps", "aaa", "balanced"],
) -> List[CandidatePlan]:
    anchors = []
    anchor_component_ids = set()
    for template in list_build_templates(session):
        if not template.details or "游戏" not in template.use_cases:
            continue
        try:
            details = BuildTemplateDetails.model_validate(template.details)
        except ValueError:
            continue
        if details.purchase_mode != "new" or details.direction != direction:
            continue
        parts = {part.role: part for part in details.parts}
        if not {"cpu", "motherboard", "gpu", "ram", "psu", "cooler"}.issubset(parts):
            continue
        anchors.append((template.id, details, parts))
        anchor_component_ids.update(part.component_id for part in details.parts)

    anchor_components = {
        component.id: component
        for component in get_components_by_ids(session, anchor_component_ids)
    }
    current_cpu = current["cpu"]
    current_gpu = current["gpu"]
    current_cpu_score = _performance_score(current_cpu)
    current_gpu_score = _performance_score(current_gpu)
    plans: List[CandidatePlan] = []

    for template_id, details, parts in anchors:
        anchor_cpu = anchor_components.get(parts["cpu"].component_id)
        anchor_gpu = anchor_components.get(parts["gpu"].component_id)
        if anchor_cpu is None or anchor_gpu is None:
            continue
        anchor_cpu_score = _performance_score(anchor_cpu)
        anchor_gpu_score = _performance_score(anchor_gpu)
        if anchor_cpu_score <= 0 or anchor_gpu_score <= 0:
            continue

        cpu_changed = anchor_cpu_score > current_cpu_score
        gpu_changed = anchor_gpu_score > current_gpu_score
        if not cpu_changed and not gpu_changed:
            continue

        planned = dict(current)
        changed_prices: Dict[str, int] = {}

        def attach_anchor_part(role: str) -> bool:
            part = parts[role]
            component = anchor_components.get(part.component_id)
            if component is None or part.condition != "new":
                return False
            planned[role] = component
            before = current.get(role)
            if before is None or before.id != component.id:
                changed_prices[role] = part.reference_price
            return True

        if cpu_changed:
            if not all(
                attach_anchor_part(role)
                for role in ("cpu", "motherboard", "ram", "cooler")
            ):
                continue
        else:
            planned["cpu"] = current_cpu

        if gpu_changed:
            if not attach_anchor_part("gpu"):
                continue
        else:
            planned["gpu"] = current_gpu

        if not _psu_meets_plan(planned):
            if not attach_anchor_part("psu") or not _psu_meets_plan(planned):
                continue

        total = sum(changed_prices.values())
        if total <= 0 or total > request.budget:
            continue
        if _has_hard_compatibility_error(planned, allow_unknown_ram=not cpu_changed):
            continue

        game_results = _game_results(
            request,
            planned["cpu"],
            planned["gpu"],
            current_results,
        )
        if not _improves_target(current_results, game_results):
            continue
        score = _improvement_score(
            current_cpu_score,
            current_gpu_score,
            _performance_score(planned["cpu"]),
            _performance_score(planned["gpu"]),
        )
        plans.append(
            CandidatePlan(
                components=planned,
                prices=changed_prices,
                game_results=game_results,
                score=score,
                anchor_template_id=template_id,
                price_date=details.price_date,
                direction=details.direction,
            )
        )
    return plans


def _direction_for_games(
    games: Sequence[str],
) -> Literal["fps", "aaa", "balanced"]:
    load_types = {
        APPROVED_GAME_PROFILES[game].load_type
        for game in games
        if game in APPROVED_GAME_PROFILES
    }
    if load_types == {GameLoadType.CPU}:
        return "fps"
    if load_types == {GameLoadType.GPU}:
        return "aaa"
    return "balanced"


def _psu_meets_plan(planned: Dict[str, HardwareComponent]) -> bool:
    cpu = planned.get("cpu")
    gpu = planned.get("gpu")
    psu = planned.get("psu")
    if cpu is None or gpu is None or psu is None:
        return False
    required_watt = minimum_psu_watt_for_specs(
        _int_spec(cpu, "tdp"),
        gpu.id,
        _int_spec(gpu, "tdp"),
    )
    return (
        _int_spec(psu, "watt") >= required_watt
        and psu_supports_gpu_power_connector(gpu.id, psu.specs)
    )


def _has_hard_compatibility_error(
    planned: Dict[str, HardwareComponent],
    *,
    allow_unknown_ram: bool,
) -> bool:
    result = evaluate_compatibility(
        BuildSelection(
            components={role: component.id for role, component in planned.items()}
        ),
        {component.id: component for component in planned.values()},
    )
    allowed_errors = {"missing_ram"} if allow_unknown_ram else set()
    return any(
        finding.level == "error" and finding.code not in allowed_errors
        for finding in result.findings
    )


def _candidate_plans(
    session: Session,
    request: UpgradePlanRequest,
    current: Dict[str, HardwareComponent],
    prices: Dict[str, int],
) -> List[CandidatePlan]:
    current_cpu = current["cpu"]
    current_gpu = current["gpu"]
    current_cpu_score = _performance_score(current_cpu)
    current_gpu_score = _performance_score(current_gpu)
    if current_cpu_score <= 0 or current_gpu_score <= 0:
        return []

    cpu_candidates = [current_cpu] + [
        component
        for component in list_components(session, category="cpu")
        if component.status == "active"
        and component.is_recommended
        and component.id != current_cpu.id
        and component.id in prices
        and _performance_score(component) > current_cpu_score
    ]
    gpu_candidates = [current_gpu] + [
        component
        for component in list_components(session, category="gpu")
        if component.status == "active"
        and component.is_recommended
        and component.id != current_gpu.id
        and component.id in prices
        and component.id not in EXCLUDED_GAMING_GPU_IDS
        and not component.id.startswith("arc-")
        and _performance_score(component) > current_gpu_score
    ]

    current_results = _game_results(request, current_cpu, current_gpu)
    plans: List[CandidatePlan] = []
    all_components = list_components(session)
    by_category: Dict[str, List[HardwareComponent]] = {}
    for component in all_components:
        by_category.setdefault(component.category, []).append(component)

    for cpu in cpu_candidates:
        for gpu in gpu_candidates:
            if cpu.id == current_cpu.id and gpu.id == current_gpu.id:
                continue
            if not _pairing_allowed(cpu, gpu):
                continue
            planned = dict(current)
            planned["cpu"] = cpu
            planned["gpu"] = gpu
            changed_prices: Dict[str, int] = {}
            if cpu.id != current_cpu.id:
                changed_prices["cpu"] = prices[cpu.id]
            if gpu.id != current_gpu.id:
                changed_prices["gpu"] = prices[gpu.id]

            if not _attach_platform_dependencies(planned, changed_prices, prices, by_category):
                continue
            if not _attach_psu_dependency(planned, changed_prices, prices, by_category):
                continue
            total = sum(changed_prices.values())
            if total <= 0 or total > request.budget:
                continue

            game_results = _game_results(request, cpu, gpu, current_results)
            if request.target_fps is not None and not _improves_target(
                current_results,
                game_results,
            ):
                continue
            score = _improvement_score(
                current_cpu_score,
                current_gpu_score,
                _performance_score(cpu),
                _performance_score(gpu),
            )
            plans.append(CandidatePlan(planned, changed_prices, game_results, score))
    return plans


def _attach_platform_dependencies(
    planned: Dict[str, HardwareComponent],
    changed_prices: Dict[str, int],
    prices: Dict[str, int],
    by_category: Dict[str, List[HardwareComponent]],
) -> bool:
    cpu = planned["cpu"]
    board = planned["motherboard"]
    existing_mem_type = _str_spec(board, "mem_type")
    cpu_socket = _str_spec(cpu, "socket")
    board_socket = _str_spec(board, "socket")
    if cpu_socket and board_socket and cpu_socket != board_socket:
        board = _cheapest_component(
            by_category.get("motherboard", []),
            prices,
            lambda component: _str_spec(component, "socket") == cpu_socket,
        )
        if board is None:
            return False
        planned["motherboard"] = board
        changed_prices["motherboard"] = prices[board.id]

    old_ram = planned.get("ram")
    new_mem_type = _str_spec(planned["motherboard"], "mem_type")
    if "motherboard" in changed_prices and not new_mem_type:
        return False
    old_mem_type = _str_spec(old_ram, "type") if old_ram else ""
    if not old_mem_type:
        old_mem_type = existing_mem_type
    if new_mem_type and old_mem_type and new_mem_type != old_mem_type:
        ram = _cheapest_component(
            by_category.get("ram", []),
            prices,
            lambda component: _str_spec(component, "type") == new_mem_type
            and _int_spec(component, "capacity_gb") >= 16,
        )
        if ram is None:
            return False
        planned["ram"] = ram
        changed_prices["ram"] = prices[ram.id]
    return True


def _attach_psu_dependency(
    planned: Dict[str, HardwareComponent],
    changed_prices: Dict[str, int],
    prices: Dict[str, int],
    by_category: Dict[str, List[HardwareComponent]],
) -> bool:
    cpu = planned["cpu"]
    gpu = planned["gpu"]
    required_watt = minimum_psu_watt_for_specs(
        _int_spec(cpu, "tdp"),
        gpu.id,
        _int_spec(gpu, "tdp"),
    )
    psu = planned["psu"]
    if _int_spec(psu, "watt") >= required_watt and psu_supports_gpu_power_connector(gpu.id, psu.specs):
        return True
    replacement = _cheapest_component(
        by_category.get("psu", []),
        prices,
        lambda component: _int_spec(component, "watt") >= required_watt
        and psu_supports_gpu_power_connector(gpu.id, component.specs),
    )
    if replacement is None:
        return False
    planned["psu"] = replacement
    changed_prices["psu"] = prices[replacement.id]
    return True


def _game_results(
    request: UpgradePlanRequest,
    cpu: HardwareComponent,
    gpu: HardwareComponent,
    before: Optional[Sequence[UpgradeGameResult]] = None,
) -> List[UpgradeGameResult]:
    if request.target_fps is None:
        return []
    before_by_game = {result.game: result.before_fps for result in before or []}
    results: List[UpgradeGameResult] = []
    for game in request.games:
        after_fps = estimate_generated_game_fps(game, request.resolution, cpu, gpu)
        if after_fps is None:
            continue
        before_fps = before_by_game.get(game, after_fps)
        results.append(
            UpgradeGameResult(
                game=game,
                before_fps=before_fps,
                after_fps=after_fps,
                target_fps=request.target_fps,
                met=after_fps >= request.target_fps,
            )
        )
    return results


def _candidate_sort_key(candidate: CandidatePlan, request: UpgradePlanRequest) -> tuple:
    if request.target_fps is None:
        return (-candidate.score, candidate.total, len(candidate.prices))
    ratios = [result.after_fps / result.target_fps for result in candidate.game_results]
    worst_ratio = min(ratios, default=0.0)
    all_met = bool(candidate.game_results) and all(result.met for result in candidate.game_results)
    if all_met:
        return (0, candidate.total, len(candidate.prices), -worst_ratio)
    return (1, -worst_ratio, candidate.total, len(candidate.prices))


def _improves_target(
    current_results: Sequence[UpgradeGameResult],
    candidate_results: Sequence[UpgradeGameResult],
) -> bool:
    if not current_results or len(candidate_results) != len(current_results):
        return False
    current_worst = min(result.after_fps / result.target_fps for result in current_results)
    candidate_worst = min(result.after_fps / result.target_fps for result in candidate_results)
    return candidate_worst > current_worst


def _steps_for_candidate(
    current: Dict[str, HardwareComponent],
    candidate: CandidatePlan,
) -> List[UpgradeStep]:
    role_order = ["cpu", "motherboard", "ram", "cooler", "gpu", "psu"]
    changed_roles = [role for role in role_order if role in candidate.prices]
    bundle_ids = {
        role: _bundle_id(role, changed_roles)
        for role in changed_roles
    }
    bundle_counts = {
        bundle_id: list(bundle_ids.values()).count(bundle_id)
        for bundle_id in set(bundle_ids.values())
    }
    steps: List[UpgradeStep] = []
    for index, role in enumerate(changed_roles, start=1):
        before = current.get(role)
        after = candidate.components[role]
        before_score = _performance_score(before) if before else 0
        after_score = _performance_score(after)
        gain = (
            max(0, round((after_score - before_score) / before_score * 100))
            if before_score > 0 and after_score > 0
            else 0
        )
        reason = _step_reason(role, before, after, candidate)
        steps.append(
            UpgradeStep(
                order=index,
                role=role,
                from_component_id=before.id if before else "",
                from_name=before.name if before else "未知型号",
                to_component_id=after.id,
                to_name=after.name,
                estimated_price=candidate.prices[role],
                expected_gain_percent=gain,
                reason=reason,
                bundle_id=bundle_ids[role],
                bundle_title=_bundle_title(bundle_ids[role]),
                required_together=bundle_counts[bundle_ids[role]] > 1,
            )
        )
    return steps


def _bundle_id(role: str, changed_roles: Sequence[str]) -> str:
    if role in {"cpu", "motherboard", "ram", "cooler"}:
        return "platform"
    if role == "psu" and "gpu" not in changed_roles:
        return "platform"
    return "graphics"


def _bundle_title(bundle_id: str) -> str:
    return "平台升级套装" if bundle_id == "platform" else "显卡与供电套装"


def _step_reason(
    role: str,
    before: Optional[HardwareComponent],
    after: HardwareComponent,
    candidate: CandidatePlan,
) -> str:
    if role == "motherboard":
        return f"新 CPU 的插槽与现有主板不同，需要同步更换为 {after.name}。"
    if role == "ram":
        return f"新主板内存代际发生变化，需要同步更换为 {after.name}。"
    if role == "cooler":
        return f"新 CPU 需要经过审核的散热能力，建议同步使用 {after.name}。"
    if role == "psu":
        return f"新 CPU/显卡的供电需求超出现有电源能力，需要 {after.name}。"
    if candidate.game_results:
        hardest = min(candidate.game_results, key=lambda result: result.after_fps / result.target_fps)
        return f"升级为 {after.name}，优先改善 {hardest.game} 在目标分辨率下的帧率。"
    label = ROLE_LABELS[role]
    return f"{label} 是当前配置的主要短板之一，升级为 {after.name} 的收益更明显。"


def _new_price_map(session: Session) -> Dict[str, int]:
    prices = {row.component_id: row.reference_price for row in list_component_prices(session)}
    for row in session.scalars(select(CPUWhitelistPrice)):
        if row.new_tray_price is not None:
            prices[row.component_id] = row.new_tray_price
        elif row.component_id in prices:
            prices.pop(row.component_id)
    for row in session.scalars(select(GPUWhitelistPrice)):
        if row.new_price is not None:
            prices[row.component_id] = row.new_price
        elif row.component_id in prices:
            prices.pop(row.component_id)
    for row in session.scalars(select(MotherboardWhitelistPrice)):
        if row.status == "active" and row.new_price is not None:
            prices[row.component_id] = row.new_price
        elif row.component_id in prices:
            prices.pop(row.component_id)
    return prices


def _pairing_allowed(cpu: HardwareComponent, gpu: HardwareComponent) -> bool:
    cpu_score = _performance_score(cpu)
    minimum = GPU_MIN_CPU_PERFORMANCE.get(gpu.id)
    if minimum is not None and cpu_score < minimum:
        return False
    if cpu.id in CPU_GPU_PAIRING_TIER and gpu.id in GPU_PAIRING_TIER:
        minimum_cpu_tier, _ = GPU_PAIRING_CPU_TIER_BOUNDS[GPU_PAIRING_TIER[gpu.id]]
        return CPU_GPU_PAIRING_TIER[cpu.id] >= minimum_cpu_tier
    return cpu_score >= max(20, round(_performance_score(gpu) * 0.45))


def _cheapest_component(
    components: Sequence[HardwareComponent],
    prices: Dict[str, int],
    predicate,
) -> Optional[HardwareComponent]:
    candidates = [
        component
        for component in components
        if component.status == "active"
        and component.is_recommended
        and component.id in prices
        and predicate(component)
    ]
    return min(candidates, key=lambda component: (prices[component.id], component.id), default=None)


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


def _primary_bottleneck(current: Dict[str, HardwareComponent]) -> Optional[str]:
    cpu = current.get("cpu")
    gpu = current.get("gpu")
    if cpu is None or gpu is None:
        return None
    cpu_perf = _performance_score(cpu)
    gpu_perf = _performance_score(gpu)
    if cpu_perf <= 0 or gpu_perf <= 0:
        return None
    return "gpu" if gpu_perf < cpu_perf * 0.9 else "cpu"


def _improvement_score(
    current_cpu: int,
    current_gpu: int,
    candidate_cpu: int,
    candidate_gpu: int,
) -> float:
    cpu_ratio = candidate_cpu / current_cpu
    gpu_ratio = candidate_gpu / current_gpu
    return min(cpu_ratio, gpu_ratio) * 2 + cpu_ratio + gpu_ratio


def _performance_score(component: Optional[HardwareComponent]) -> int:
    if component is None:
        return 0
    return hardware_performance_score(
        component.id,
        component.category,
        component.name,
        component.specs,
    ) or 0


def _int_spec(component: HardwareComponent, key: str) -> int:
    value = component.specs.get(key)
    return value if type(value) is int else 0


def _str_spec(component: Optional[HardwareComponent], key: str) -> str:
    if component is None:
        return ""
    value = component.specs.get(key)
    return value if isinstance(value, str) else ""


def _empty_response(
    request: UpgradePlanRequest,
    *,
    status: UpgradeStatus,
    summary: str,
    missing_fields: Optional[List[str]] = None,
    primary_bottleneck: Optional[str] = None,
    notes: Optional[List[str]] = None,
    direction: Optional[Literal["fps", "aaa", "balanced"]] = None,
) -> UpgradePlanResponse:
    return UpgradePlanResponse(
        status=status,
        summary=summary,
        budget=request.budget,
        total_estimated_price=0,
        primary_bottleneck=primary_bottleneck,
        missing_fields=missing_fields or [],
        steps=[],
        notes=notes or [],
        resolution=request.resolution,
        target_fps=request.target_fps,
        target_met=None,
        game_results=[],
        direction=direction,
        anchor_template_id=None,
        price_date=None,
    )
