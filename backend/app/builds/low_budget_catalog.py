import argparse
import csv
import json
from dataclasses import dataclass
from functools import lru_cache
from pathlib import Path
from typing import Dict, Iterable, List, Literal, Optional, Sequence, Tuple

from app.builds.service import (
    BuildTemplateDetails,
    BuildTemplateInput,
    BuildTemplatePart,
)
from app.builds.gpu_rules import gpu_brand_allowed_for_budget
from app.catalog.rule_specs import (
    CPU_PERFORMANCE as RULE_CPU_PERFORMANCE,
    CPU_TDP as RULE_CPU_TDP,
    GPU_MIN_CPU_PERFORMANCE,
    GPU_PERFORMANCE as RULE_GPU_PERFORMANCE,
    GPU_TDP as RULE_GPU_TDP,
    is_cpu_gpu_pairing_allowed,
    minimum_psu_watt as rule_minimum_psu_watt,
)


Direction = Literal["fps", "aaa", "balanced"]
PurchaseMode = Literal["new", "used", "mixed"]
Condition = Literal["new", "used"]
GpuVendor = Literal["nvidia", "amd"]
SkipReason = Literal[
    "over_budget",
    "no_feasible_candidate",
    "missing_evidence",
    "generation_error",
]

PRICE_DATE = "2026-08-26"
BUDGET_TIERS = list(range(3_000, 7_001, 500))
DIRECTIONS: Tuple[Direction, ...] = ("fps", "aaa", "balanced")
PURCHASE_MODES: Tuple[PurchaseMode, ...] = ("new", "used", "mixed")
PART_ROLE_ORDER = (
    "cpu",
    "motherboard",
    "gpu",
    "ram",
    "storage",
    "psu",
    "cooler",
    "case",
)
REQUIRED_PART_ROLES = set(PART_ROLE_ORDER)

BACKEND_ROOT = Path(__file__).resolve().parents[2]
PROJECT_ROOT = BACKEND_ROOT.parent
DATA_DIR = BACKEND_ROOT / "data"
CPU_PRICE_PATH = DATA_DIR / "cpu-whitelist-prices-2026-07-07.csv"
GPU_PRICE_PATH = DATA_DIR / "gpu-whitelist-prices-2026-07-07.csv"
MOTHERBOARD_PRICE_PATH = DATA_DIR / "motherboard-whitelist-prices-2026-07-07.csv"
SUPPORT_PART_PATH = DATA_DIR / "base-build-support-components-2026-07-12.json"
REVIEW_MARKDOWN_PATH = PROJECT_ROOT / "docs" / "3000-7000-yuan-base-builds.md"

CPU_SOCKET = {
    "r5-5600": "AM4",
    "r5-5600x": "AM4",
    "r5-7500f": "AM5",
    "r5-9600x": "AM5",
    "i5-12600kf": "LGA1700",
    "i5-14600kf": "LGA1700",
    "r7-9700x": "AM5",
    "r7-7800x3d": "AM5",
    "r7-9800x3d": "AM5",
}
CPU_PERFORMANCE = {
    component_id: RULE_CPU_PERFORMANCE[component_id]
    for component_id in CPU_SOCKET
}
CPU_TDP = {
    component_id: RULE_CPU_TDP[component_id] for component_id in CPU_SOCKET
}
GPU_PERFORMANCE = RULE_GPU_PERFORMANCE
GPU_TDP = RULE_GPU_TDP

CONDITIONS_BY_MODE: Dict[PurchaseMode, Dict[str, Condition]] = {
    "new": {role: "new" for role in PART_ROLE_ORDER},
    "used": {role: "used" for role in PART_ROLE_ORDER},
    "mixed": {
        "cpu": "used",
        "motherboard": "new",
        "gpu": "used",
        "ram": "used",
        "storage": "new",
        "psu": "new",
        "cooler": "used",
        "case": "used",
    },
}

DIRECTION_LABELS = {"fps": "FPS", "aaa": "3A", "balanced": "均衡"}
PURCHASE_LABELS = {"new": "全新", "used": "二手", "mixed": "混合采购"}
GPU_VENDOR_LABELS = {"nvidia": "NVIDIA", "amd": "AMD"}
ALLOWED_B850_MOTHERBOARDS = {"msi-b850m-power", "asus-b850m-awy"}
MOTHERBOARD_MODEL_RANK = {"msi-b850m-power": 2, "asus-b850m-awy": 1}
MAX_MOTHERBOARD_BUDGET_SHARE = 0.15
MAX_3A_MOTHERBOARD_STEP_UP = 300
MAX_BUDGET_SHORTFALL = 100
MAX_BUDGET_OVERAGE = 500
MINIMUM_3000_TIER_OVERAGE = 600
PENDING_REVIEW_CONDITIONS: Dict[Tuple[str, Condition], str] = {}
MINIMUM_650W_GPU_TDP = 140
LOW_BUDGET_STORAGE_IDS = {
    "base-ssd-fanxiang-s500-pro-512gb",
    "base-ssd-fanxiang-s790e-1tb",
}
CUSTOMIZATION_SUPPORT_IDS = LOW_BUDGET_STORAGE_IDS | {
    "base-ddr4-32gb-3200",
    "i5-14600kf",
    "thermalright-ax120-se",
}
ALTERNATIVE_ONLY_CPU_IDS = {"i5-14600kf"}
AM4_VALUE_BOARD_ID = "asus-a520m-k"
AM4_PCIE4_BOARD_ID = "asus-b550m-plus"
LEGACY_AM4_COOLER_ID = "thermalright-ax120-se"


@dataclass(frozen=True)
class PricedPart:
    component_id: str
    category: str
    name: str
    brand: str
    specs: Dict[str, object]
    used_price: Optional[int]
    new_price: Optional[int]
    used_source: str
    new_source: str
    price_date: str

    def price(self, condition: Condition) -> Optional[int]:
        return self.new_price if condition == "new" else self.used_price

    def source(self, condition: Condition) -> str:
        return self.new_source if condition == "new" else self.used_source


@dataclass(frozen=True)
class Candidate:
    parts: Tuple[BuildTemplatePart, ...]
    total: int
    cpu_performance: int
    gpu_performance: int

    @property
    def parts_by_role(self) -> Dict[str, BuildTemplatePart]:
        return {part.role: part for part in self.parts}

    @property
    def tie_key(self) -> Tuple[str, ...]:
        return tuple(part.component_id for part in self.parts)


@dataclass(frozen=True)
class SelectionOutcome:
    candidate: Optional[Candidate]
    skip_reason: Optional[SkipReason]


@dataclass(frozen=True)
class SkippedCombination:
    target_budget: int
    direction: Direction
    purchase_mode: PurchaseMode
    reason: SkipReason
    gpu_vendor: Optional[GpuVendor] = None

    @property
    def key(self) -> Tuple[int, Direction, PurchaseMode, Optional[GpuVendor]]:
        return (
            self.target_budget,
            self.direction,
            self.purchase_mode,
            self.gpu_vendor,
        )

    def as_dict(self) -> Dict[str, object]:
        payload = {
            "target_budget": self.target_budget,
            "direction": self.direction,
            "purchase_mode": self.purchase_mode,
            "reason": self.reason,
        }
        if self.gpu_vendor is not None:
            payload["gpu_vendor"] = self.gpu_vendor
        return payload


@dataclass(frozen=True)
class ArtifactPaths:
    templates_json: Path
    review_markdown: Path
    reference_prices_csv: Path
    recommendation_ids: Path
    audit_json: Path


@dataclass(frozen=True)
class GenerationReport:
    templates: Tuple[BuildTemplateInput, ...]
    skipped_combinations: Tuple[SkippedCombination, ...]
    source_parts: Tuple[PricedPart, ...]


@lru_cache(maxsize=1)
def generate_low_budget_report() -> GenerationReport:
    cpus, motherboards, gpus, support_parts = _load_catalog()
    source_parts = tuple([*cpus, *motherboards, *gpus, *support_parts.values()])
    templates = []
    skipped = []
    for budget in BUDGET_TIERS:
        for direction in DIRECTIONS:
            for purchase_mode in PURCHASE_MODES:
                for gpu_vendor in _gpu_vendors_for(budget, direction, purchase_mode):
                    selection = _select_candidate(
                        budget,
                        direction,
                        purchase_mode,
                        cpus,
                        motherboards,
                        gpus,
                        support_parts,
                        gpu_vendor,
                    )
                    if selection.candidate is not None:
                        templates.append(
                            _build_template(
                                budget,
                                direction,
                                purchase_mode,
                                selection.candidate,
                            )
                        )
                    else:
                        skipped.append(
                            SkippedCombination(
                                target_budget=budget,
                                direction=direction,
                                purchase_mode=purchase_mode,
                                reason=selection.skip_reason
                                or "no_feasible_candidate",
                                gpu_vendor=gpu_vendor,
                            )
                        )
    return GenerationReport(
        templates=tuple(templates),
        skipped_combinations=tuple(skipped),
        source_parts=source_parts,
    )


def generate_low_budget_templates() -> List[BuildTemplateInput]:
    return list(generate_low_budget_report().templates)


def minimum_psu_watt(cpu_id: str, gpu_id: str) -> int:
    return rule_minimum_psu_watt(cpu_id, gpu_id)


GPU_VENDOR_SPLIT_MIN_BUDGET = {
    "new": 8_000,
    "used": 6_000,
    "mixed": 7_000,
}


def _gpu_vendors_for(
    budget: int,
    direction: Direction,
    purchase_mode: PurchaseMode,
) -> Tuple[Optional[GpuVendor], ...]:
    if (
        direction in {"aaa", "balanced"}
        and budget >= GPU_VENDOR_SPLIT_MIN_BUDGET[purchase_mode]
    ):
        return ("nvidia", "amd")
    return (None,)


def _completed_tiers(templates: Sequence[BuildTemplateInput]) -> List[int]:
    directions_by_tier: Dict[int, set] = {}
    for template in templates:
        if template.details is None:
            continue
        directions_by_tier.setdefault(template.details.target_budget, set()).add(
            template.details.direction
        )
    return sorted(
        budget
        for budget, directions in directions_by_tier.items()
        if directions == set(DIRECTIONS)
    )


def render_low_budget_markdown(
    templates: Sequence[BuildTemplateInput],
    skipped_combinations: Optional[Sequence[SkippedCombination]] = None,
) -> str:
    present_tiers = sorted(
        {
            template.details.target_budget
            for template in templates
            if template.details is not None
        }
    )
    completed_tiers = _completed_tiers(templates)
    completed_tier_directions = {
        (template.details.target_budget, template.details.direction)
        for template in templates
        if template.details is not None
    }
    skipped = _complete_skipped_combinations(templates, skipped_combinations)
    skip_counts = {
        reason: sum(item.reason == reason for item in skipped)
        for reason in (
            "over_budget",
            "no_feasible_candidate",
            "missing_evidence",
            "generation_error",
        )
    }
    lines = [
        "# 3000-7000元装机基底配置",
        "",
        f"价格日期：{PRICE_DATE}",
        "",
        "说明：每500元一个档位；3A和均衡仅在全新≥8000元、二手≥6000元、混合采购≥7000元时拆分 NVIDIA 与 AMD 方案。",
        "只保留八大件参考价合计位于目标预算至目标预算加300元的真实可行方案；未生成组合记录在审计文件中。",
        (
            f"生成状态：{len(completed_tiers)}/{len(BUDGET_TIERS)}个价位有可行配置，"
            f"覆盖{len(completed_tier_directions)}/{len(BUDGET_TIERS) * len(DIRECTIONS)}个价位方向，"
            f"共{len(templates)}套；跳过{len(skipped)}个组合（超预算{skip_counts['over_budget']}，"
            f"无可行候选{skip_counts['no_feasible_candidate']}，缺少证据{skip_counts['missing_evidence']}，"
            f"生成失败{skip_counts['generation_error']}）。"
        ),
        "二手方案中的电源、SSD和显卡购买前必须复核健康度、成色和保修。",
        "",
    ]
    for budget in present_tiers:
        lines.extend([f"## {budget}元档", ""])
        for template in templates:
            details = template.details
            if details is None or details.target_budget != budget:
                continue
            lines.extend(
                [
                    f"### {DIRECTION_LABELS[details.direction]} / {PURCHASE_LABELS[details.purchase_mode]} / {GPU_VENDOR_LABELS[details.gpu_vendor]}",
                    "",
                    "| 配件 | 型号 | 状态 | 参考价 | 价格来源 | 来源日期 |",
                    "| --- | --- | --- | ---: | --- | --- |",
                ]
            )
            for part in details.parts:
                lines.append(
                    f"| {_role_label(part.role)} | {part.name} | {_condition_label(part.condition)} | "
                    f"¥{part.reference_price} | {part.price_source} | {part.price_date} |"
                )
            lines.extend(
                [
                    "",
                    f"**总价：¥{template.estimated_total}**",
                    "",
                    f"**适用用户：** {details.suitable_user}",
                    "",
                ]
            )
    return "\n".join(lines).rstrip() + "\n"


def write_low_budget_artifacts(
    output_dir: Path,
    templates: Optional[Sequence[BuildTemplateInput]] = None,
    review_markdown_path: Optional[Path] = None,
    skipped_combinations: Optional[Sequence[SkippedCombination]] = None,
    source_parts: Optional[Sequence[PricedPart]] = None,
) -> ArtifactPaths:
    output_dir = Path(output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)
    if templates is None:
        report = generate_low_budget_report()
        generated = list(report.templates)
        skips = list(report.skipped_combinations)
        prices_snapshot = report.source_parts
    else:
        generated = list(templates)
        skips = _complete_skipped_combinations(generated, skipped_combinations)
        prices_snapshot = tuple(source_parts) if source_parts is not None else None
    paths = ArtifactPaths(
        templates_json=output_dir / "low-budget-base-build-templates.json",
        review_markdown=(
            review_markdown_path or output_dir / "low-budget-base-builds.md"
        ),
        reference_prices_csv=output_dir / "low-budget-base-reference-prices.csv",
        recommendation_ids=output_dir / "low-budget-base-recommendation-ids.txt",
        audit_json=output_dir / "low-budget-base-audit.json",
    )
    paths.review_markdown.parent.mkdir(parents=True, exist_ok=True)
    paths.templates_json.write_text(
        json.dumps(
            [template.model_dump(mode="json") for template in generated],
            ensure_ascii=False,
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )
    paths.review_markdown.write_text(
        render_low_budget_markdown(generated, skips),
        encoding="utf-8",
    )
    _write_reference_prices(
        paths.reference_prices_csv,
        generated,
        prices_snapshot,
    )
    _write_recommendation_ids(paths.recommendation_ids, generated)
    _write_audit(paths.audit_json, generated, skips)
    return paths


def _select_candidate(
    budget: int,
    direction: Direction,
    purchase_mode: PurchaseMode,
    cpus: Sequence[PricedPart],
    motherboards: Sequence[PricedPart],
    gpus: Sequence[PricedPart],
    support_parts: Dict[str, PricedPart],
    gpu_vendor: Optional[GpuVendor] = None,
) -> SelectionOutcome:
    if budget >= 5_000 and direction == "fps" and gpu_vendor is None:
        by_vendor = {
            vendor: _select_candidate(
                budget,
                direction,
                purchase_mode,
                cpus,
                motherboards,
                gpus,
                support_parts,
                vendor,
            )
            for vendor in ("nvidia", "amd")
        }
        nvidia = by_vendor["nvidia"].candidate
        amd = by_vendor["amd"].candidate
        if nvidia is None:
            return by_vendor["amd"]
        if amd is None:
            return by_vendor["nvidia"]
        if (
            amd.cpu_performance > nvidia.cpu_performance
            and amd.gpu_performance >= nvidia.gpu_performance
        ):
            return by_vendor["amd"]
        if (
            amd.cpu_performance >= nvidia.cpu_performance
            and amd.gpu_performance * 100 >= nvidia.gpu_performance * 115
        ):
            return by_vendor["amd"]
        return by_vendor["nvidia"]

    best: Optional[Candidate] = None
    best_score: Optional[Tuple[int, ...]] = None
    saw_complete_candidate = False
    conditions = CONDITIONS_BY_MODE[purchase_mode]
    available_am4_board_ids = {
        motherboard.component_id
        for motherboard in motherboards
        if motherboard.component_id in {AM4_VALUE_BOARD_ID, AM4_PCIE4_BOARD_ID}
        and _condition_is_allowed(motherboard, conditions["motherboard"])
    }
    reviewed_gpu = {
        (5_000, "fps", "new"): "rx-7650-gre",
        (5_000, "fps", "mixed"): "rx-9060-xt-8gb",
    }.get((budget, direction, purchase_mode))
    if reviewed_gpu is None:
        reviewed_gpu = {
            (5_000, "aaa", "used", "amd"): "rx-7700-xt",
            (5_000, "aaa", "mixed", "nvidia"): "rtx-3070-ti",
        }.get((budget, direction, purchase_mode, gpu_vendor))
    reviewed_motherboard = {
        (5_000, "aaa", "used", "amd"): "asus-b550m-plus",
        (5_000, "aaa", "mixed", "nvidia"): "asus-b550m-plus",
    }.get((budget, direction, purchase_mode, gpu_vendor))
    for cpu in cpus:
        if cpu.component_id in ALTERNATIVE_ONLY_CPU_IDS:
            continue
        if budget >= 6_000 and cpu.component_id in {"r5-5600", "r5-5600x"}:
            continue
        if not _condition_is_allowed(cpu, conditions["cpu"]):
            continue
        cooler_id = (
            LEGACY_AM4_COOLER_ID
            if cpu.component_id in {"r5-5600", "r5-5600x"}
            else "base-cooler-dual-tower-6-heatpipe"
            if "x3d" in cpu.component_id or cpu.component_id == "i5-12600kf"
            else "base-cooler-6-heatpipe"
        )
        cooler = support_parts[cooler_id]
        effective_conditions = (
            {**conditions, "cooler": "new"}
            if cpu.component_id in {"r5-5600", "r5-5600x"}
            else conditions
        )
        value_motherboard = (
            _cheapest_adequate_motherboard(
                cpu.component_id,
                str(cpu.specs["socket"]),
                conditions["motherboard"],
                motherboards,
            )
            if direction == "aaa"
            else None
        )
        for motherboard in motherboards:
            if not _condition_is_allowed(
                motherboard,
                conditions["motherboard"],
            ):
                continue
            if (
                reviewed_motherboard is not None
                and motherboard.component_id != reviewed_motherboard
            ):
                continue
            is_am4_policy_board = (
                cpu.specs["socket"] == "AM4"
                and motherboard.component_id
                in {AM4_VALUE_BOARD_ID, AM4_PCIE4_BOARD_ID}
            )
            if (
                motherboard.specs.get("chipset") == "B850"
                and motherboard.component_id not in ALLOWED_B850_MOTHERBOARDS
            ):
                continue
            motherboard_price = motherboard.price(conditions["motherboard"])
            if (
                direction == "aaa"
                and motherboard_price is not None
                and motherboard_price > budget * MAX_MOTHERBOARD_BUDGET_SHARE
                and (
                    value_motherboard is None
                    or motherboard.component_id != value_motherboard.component_id
                )
                and not is_am4_policy_board
            ):
                continue
            if (
                value_motherboard is not None
                and motherboard_price is not None
                and motherboard_price
                > value_motherboard.price(conditions["motherboard"])
                + MAX_3A_MOTHERBOARD_STEP_UP
                and reviewed_motherboard is None
                and not is_am4_policy_board
            ):
                continue
            if cpu.specs["socket"] != motherboard.specs["socket"]:
                continue
            if (
                motherboard.component_id == "asus-prime-b650m-k"
                and cpu.component_id in {"r7-9800x3d"}
            ):
                continue

            for gpu in gpus:
                if reviewed_gpu is not None and gpu.component_id != reviewed_gpu:
                    continue
                if gpu_vendor and gpu.brand.lower() != gpu_vendor:
                    continue
                if not gpu_brand_allowed_for_budget(gpu.name, budget):
                    continue
                if not _condition_is_allowed(gpu, conditions["gpu"]):
                    continue
                if not is_cpu_gpu_pairing_allowed(
                    cpu.component_id,
                    gpu.component_id,
                ):
                    continue
                if cpu.specs["socket"] == "AM4":
                    if (
                        GPU_PERFORMANCE[gpu.component_id]
                        > GPU_PERFORMANCE["rx-7650-gre"]
                        and AM4_PCIE4_BOARD_ID in available_am4_board_ids
                        and motherboard.component_id != AM4_PCIE4_BOARD_ID
                    ):
                        continue
                minimum_gpu_cpu_performance = GPU_MIN_CPU_PERFORMANCE.get(
                    gpu.component_id
                )
                if (
                    minimum_gpu_cpu_performance is not None
                    and CPU_PERFORMANCE[cpu.component_id]
                    < minimum_gpu_cpu_performance
                    and reviewed_gpu is None
                ):
                    continue
                if (
                    cpu.component_id == "r7-9700x"
                    and minimum_gpu_cpu_performance is None
                ):
                    continue
                if (
                    cpu.component_id == "r7-9800x3d"
                    and GPU_PERFORMANCE[gpu.component_id]
                    < GPU_PERFORMANCE["rtx-5060-ti"]
                ):
                    continue
                psu = _smallest_psu(
                    minimum_psu_watt(cpu.component_id, gpu.component_id),
                    conditions["psu"],
                    support_parts,
                )
                if psu is None:
                    continue
                storage = support_parts["base-ssd-fanxiang-s500-pro-512gb"]
                for ram in _support_candidates(
                    "ram",
                    conditions["ram"],
                    support_parts,
                    memory_type=str(motherboard.specs["mem_type"]),
                ):
                    if ram.specs.get("capacity_gb") != 16:
                        continue
                    if (
                        cpu.specs["socket"] == "AM5"
                        and ram.specs.get("cas_latency") != 28
                    ):
                        continue
                    fixed_parts = {
                        "cpu": cpu,
                        "motherboard": motherboard,
                        "gpu": gpu,
                        "ram": ram,
                        "storage": storage,
                        "psu": psu,
                        "cooler": cooler,
                        "case": support_parts["base-case-mid-tower"],
                    }
                    if any(
                        not _condition_is_allowed(part, effective_conditions[role])
                        for role, part in fixed_parts.items()
                    ):
                        continue

                    parts = []
                    for role in PART_ROLE_ORDER:
                        part = fixed_parts[role]
                        condition = effective_conditions[role]
                        price = part.price(condition)
                        assert price is not None
                        parts.append(_template_part(role, part, condition, price))

                    saw_complete_candidate = True
                    total = sum(part.reference_price for part in parts)
                    max_overage = (
                        MINIMUM_3000_TIER_OVERAGE
                        if budget == 3_000
                        else MAX_BUDGET_OVERAGE
                    )
                    minimum_total = budget - MAX_BUDGET_SHORTFALL
                    if (
                        budget == 5_000
                        and direction == "aaa"
                        and reviewed_gpu is not None
                    ):
                        minimum_total = budget - 1_000
                    if not (minimum_total <= total <= budget + max_overage):
                        continue
                    candidate = Candidate(
                        parts=tuple(parts),
                        total=total,
                        cpu_performance=CPU_PERFORMANCE[cpu.component_id],
                        gpu_performance=GPU_PERFORMANCE[gpu.component_id],
                    )
                    score = _score_candidate(
                        candidate,
                        direction,
                        budget=budget,
                        prefer_modern_gpu=conditions["gpu"] == "used",
                    )
                    if (
                        best_score is None
                        or score > best_score
                        or (
                            score == best_score
                            and best is not None
                            and candidate.tie_key < best.tie_key
                        )
                    ):
                        best = candidate
                        best_score = score
    if best is not None:
        return SelectionOutcome(candidate=best, skip_reason=None)
    return SelectionOutcome(
        candidate=None,
        skip_reason=(
            "over_budget" if saw_complete_candidate else "no_feasible_candidate"
        ),
    )


def _score_candidate(
    candidate: Candidate,
    direction: Direction,
    budget: Optional[int] = None,
    prefer_modern_gpu: bool = False,
) -> Tuple[int, ...]:
    parts = candidate.parts_by_role
    gpu_id = parts["gpu"].component_id
    old_gpu_risk = int(_has_legacy_mining_risk(gpu_id))
    modern_gpu_rank = -old_gpu_risk if prefer_modern_gpu else 0
    ram_capacity = (
        int(parts["ram"].specs.get("capacity_gb", 0)) if "ram" in parts else 0
    )
    ram_latency_score = (
        -int(parts["ram"].specs.get("cas_latency", 99))
        if "ram" in parts
        else -99
    )
    motherboard = parts.get("motherboard")
    motherboard_tier_score = (
        -{"B650": 0, "B850": 1, "X870E": 2}.get(
            str(motherboard.specs.get("chipset")),
            0,
        )
        if motherboard is not None
        else 0
    )
    motherboard_model_score = (
        MOTHERBOARD_MODEL_RANK.get(motherboard.component_id, 0)
        if motherboard is not None
        else 0
    )
    if direction == "fps":
        if budget is not None and budget <= 4_000 and parts["cpu"].component_id == "i5-12600kf":
            return (
                modern_gpu_rank,
                candidate.cpu_performance,
                candidate.gpu_performance,
                -candidate.total,
                motherboard_tier_score,
                motherboard_model_score,
                ram_capacity,
                ram_latency_score,
                -old_gpu_risk,
            )
        if budget is not None and budget <= 4_500:
            gpu_priority = {"rtx-3070-ti": 2, "rx-7650-gre": 1}.get(gpu_id, 0)
            return (
                modern_gpu_rank,
                candidate.cpu_performance,
                gpu_priority,
                candidate.gpu_performance,
                -candidate.total,
                motherboard_tier_score,
                motherboard_model_score,
                ram_capacity,
                ram_latency_score,
                -old_gpu_risk,
            )
        return (
            modern_gpu_rank,
            candidate.cpu_performance,
            candidate.gpu_performance,
            motherboard_tier_score,
            motherboard_model_score,
            ram_capacity,
            ram_latency_score,
            -old_gpu_risk,
            -candidate.total,
        )
    if direction == "aaa":
        return (
            modern_gpu_rank,
            candidate.gpu_performance,
            candidate.cpu_performance,
            motherboard_tier_score,
            motherboard_model_score,
            ram_capacity,
            ram_latency_score,
            -old_gpu_risk,
            -candidate.total,
        )
    return (
        modern_gpu_rank,
        min(candidate.cpu_performance, candidate.gpu_performance),
        candidate.cpu_performance + candidate.gpu_performance,
        -abs(candidate.cpu_performance - candidate.gpu_performance),
        motherboard_tier_score,
        motherboard_model_score,
        ram_capacity,
        ram_latency_score,
        -old_gpu_risk,
        -candidate.total,
    )


def _has_legacy_mining_risk(gpu_id: str) -> bool:
    return gpu_id.startswith(("rtx-30", "rx-6"))


def _build_template(
    budget: int,
    direction: Direction,
    purchase_mode: PurchaseMode,
    candidate: Candidate,
) -> BuildTemplateInput:
    direction_label = DIRECTION_LABELS[direction]
    purchase_label = PURCHASE_LABELS[purchase_mode]
    gpu_vendor = _candidate_gpu_vendor(candidate)
    vendor_label = GPU_VENDOR_LABELS[gpu_vendor]
    vendor_suffix = (
        "-amd"
        if budget >= 5_000 and direction != "fps" and gpu_vendor == "amd"
        else ""
    )
    return BuildTemplateInput(
        id=f"base-{budget}-{direction}-{purchase_mode}{vendor_suffix}",
        title=f"{budget}元 {direction_label} {purchase_label} {vendor_label}基底配置",
        budget_min=budget,
        budget_max=budget + 499,
        use_cases=["游戏"],
        tags=[
            direction_label,
            purchase_label,
            vendor_label,
            direction,
            purchase_mode,
            gpu_vendor,
        ],
        components={part.role: part.component_id for part in candidate.parts},
        estimated_total=candidate.total,
        explanation=(
            f"以{direction_label}游戏方向优化，按{purchase_label}规则从维护中的白名单和参考价格中选出。"
        ),
        details=_details_for_candidate(
            budget,
            direction,
            purchase_mode,
            candidate,
        ),
    )


def _details_for_candidate(
    budget: int,
    direction: Direction,
    purchase_mode: PurchaseMode,
    candidate: Candidate,
) -> BuildTemplateDetails:
    if direction == "fps":
        suitable_user = "主要玩CS2、无畏契约、PUBG等高帧率游戏的用户"
    elif direction == "aaa":
        suitable_user = "主要玩高画质3A单机、重视分辨率和画质的用户"
    else:
        suitable_user = "游戏类型比较杂，希望兼顾FPS和3A的用户"

    return BuildTemplateDetails(
        target_budget=budget,
        direction=direction,
        purchase_mode=purchase_mode,
        gpu_vendor=_candidate_gpu_vendor(candidate),
        parts=list(candidate.parts),
        suitable_user=suitable_user,
        price_date=PRICE_DATE,
    )


def _template_part(
    role: str,
    part: PricedPart,
    condition: Condition,
    price: int,
) -> BuildTemplatePart:
    return BuildTemplatePart(
        role=role,
        component_id=part.component_id,
        name=part.name,
        condition=condition,
        reference_price=price,
        price_source=part.source(condition),
        price_date=part.price_date,
        specs=part.specs,
    )


def _condition_is_allowed(part: PricedPart, condition: Condition) -> bool:
    return (
        part.price(condition) is not None
        and (part.component_id, condition) not in PENDING_REVIEW_CONDITIONS
    )


def _smallest_psu(
    required_watt: int,
    condition: Condition,
    support_parts: Dict[str, PricedPart],
) -> Optional[PricedPart]:
    psus = sorted(
        (
            part
            for part in support_parts.values()
            if part.category == "psu"
            and isinstance(part.specs.get("watt"), int)
            and _condition_is_allowed(part, condition)
        ),
        key=lambda part: int(part.specs["watt"]),
    )
    return next(
        (part for part in psus if int(part.specs["watt"]) >= required_watt),
        None,
    )


def _cheapest_adequate_motherboard(
    cpu_id: str,
    socket: str,
    condition: Condition,
    motherboards: Sequence[PricedPart],
    max_price: Optional[float] = None,
) -> Optional[PricedPart]:
    candidates = [
        part
        for part in motherboards
        if part.specs.get("socket") == socket
        and _condition_is_allowed(part, condition)
        and (max_price is None or part.price(condition) <= max_price)
        and not (
            part.component_id == "asus-prime-b650m-k"
            and cpu_id in {"r7-9800x3d", "r7-9850x3d"}
        )
    ]
    return min(
        candidates,
        key=lambda part: (part.price(condition), part.component_id),
        default=None,
    )


def _support_candidates(
    category: str,
    condition: Condition,
    support_parts: Dict[str, PricedPart],
    memory_type: Optional[str] = None,
) -> List[PricedPart]:
    return sorted(
        (
            part
            for part in support_parts.values()
            if part.category == category
            and _condition_is_allowed(part, condition)
            and (memory_type is None or part.specs.get("type") == memory_type)
        ),
        key=lambda part: (
            int(part.specs.get("capacity_gb", 0)),
            part.component_id,
        ),
    )


def _candidate_gpu_vendor(candidate: Candidate) -> GpuVendor:
    gpu = candidate.parts_by_role["gpu"]
    return "nvidia" if gpu.component_id.startswith("rtx-") else "amd"


def _load_catalog() -> Tuple[
    List[PricedPart],
    List[PricedPart],
    List[PricedPart],
    Dict[str, PricedPart],
]:
    support_parts = {
        part.component_id: part for part in _load_support_parts(SUPPORT_PART_PATH)
    }
    return (
        _load_cpu_parts(CPU_PRICE_PATH),
        _load_motherboard_parts(MOTHERBOARD_PRICE_PATH),
        _load_gpu_parts(GPU_PRICE_PATH),
        support_parts,
    )


def _load_cpu_parts(path: Path) -> List[PricedPart]:
    parts = []
    for row in _read_csv(path):
        component_id = row["target_id"]
        if component_id not in CPU_PERFORMANCE:
            continue
        parts.append(
            PricedPart(
                component_id=component_id,
                category="cpu",
                name=row["name"],
                brand="Intel" if component_id.startswith("i5-") else "AMD",
                specs={
                    "socket": CPU_SOCKET[component_id],
                    "perf_index": CPU_PERFORMANCE[component_id],
                    "tdp": CPU_TDP[component_id],
                },
                used_price=_optional_int(row.get("used_price")),
                new_price=_optional_int(row.get("new_tray_price")),
                used_source=path.name,
                new_source=path.name,
                price_date="2026-07-07",
            )
        )
    return parts


def _load_motherboard_parts(path: Path) -> List[PricedPart]:
    parts = []
    for row in _read_csv(path):
        platform = row["platform"]
        if platform not in {"AM4", "AM5", "LGA1700"}:
            continue
        parts.append(
            PricedPart(
                component_id=row["target_id"],
                category="motherboard",
                name=row["name"],
                brand=row["name"].split(" ", 1)[0],
                specs={
                    "socket": platform,
                    "mem_type": "DDR4" if platform in {"AM4", "LGA1700"} else "DDR5",
                    "chipset": _motherboard_chipset(row["target_id"]),
                },
                used_price=_optional_int(row.get("used_price")),
                new_price=_optional_int(row.get("new_price")),
                used_source=path.name,
                new_source=path.name,
                price_date="2026-07-07",
            )
        )
    return parts


def _load_gpu_parts(path: Path) -> List[PricedPart]:
    parts = []
    for row in _read_csv(path):
        component_id = row["target_id"]
        if component_id not in GPU_PERFORMANCE:
            continue
        is_nvidia = component_id.startswith("rtx-")
        parts.append(
            PricedPart(
                component_id=component_id,
                category="gpu",
                name=row["name"],
                brand="NVIDIA" if is_nvidia else "AMD",
                specs={
                    "vendor": "NVIDIA" if is_nvidia else "AMD",
                    "perf_index": GPU_PERFORMANCE[component_id],
                    "tdp": GPU_TDP[component_id],
                },
                used_price=_optional_int(row.get("used_price")),
                new_price=_optional_int(row.get("new_price")),
                used_source=path.name,
                new_source=path.name,
                price_date=PRICE_DATE,
            )
        )
    return parts


def _load_support_parts(path: Path) -> List[PricedPart]:
    payload = json.loads(path.read_text(encoding="utf-8"))
    return [
        PricedPart(
            component_id=item["id"],
            category=item["category"],
            name=item["name"],
            brand=item["brand"],
            specs=item["specs"],
            used_price=item.get("used_price"),
            new_price=item.get("new_price"),
            used_source=item.get("used_source", ""),
            new_source=item.get("new_source", ""),
            price_date=item["price_date"],
        )
        for item in payload
    ]


def _write_reference_prices(
    path: Path,
    templates: Sequence[BuildTemplateInput],
    source_parts: Optional[Sequence[PricedPart]] = None,
) -> None:
    generated_parts = [
        part
        for template in templates
        if template.details is not None
        for part in template.details.parts
    ]
    referenced_ids = {part.component_id for part in generated_parts}
    referenced_ids.update(CUSTOMIZATION_SUPPORT_IDS)
    snapshot: Dict[str, Dict[str, object]] = {}
    if source_parts is not None:
        source_by_id = {part.component_id: part for part in source_parts}
        missing_ids = sorted(referenced_ids - set(source_by_id))
        if missing_ids:
            raise ValueError(
                "Source snapshot is missing: " + ", ".join(missing_ids)
            )
        for component_id in sorted(referenced_ids):
            source = source_by_id[component_id]
            snapshot[component_id] = {
                "category": source.category,
                "name": source.name,
                "brand": source.brand,
                "used_price": source.used_price,
                "new_price": source.new_price,
            }
        for part in generated_parts:
            if (part.component_id, part.condition) in PENDING_REVIEW_CONDITIONS:
                raise ValueError(
                    f"Pending-review price used by {part.component_id}"
                )
            expected_price = source_by_id[part.component_id].price(part.condition)
            if expected_price != part.reference_price:
                raise ValueError(
                    f"Snapshot price mismatch for {part.component_id}"
                )
    else:
        for part in generated_parts:
            if (part.component_id, part.condition) in PENDING_REVIEW_CONDITIONS:
                continue
            row = snapshot.setdefault(
                part.component_id,
                {
                    "category": part.role,
                    "name": part.name,
                    "brand": _brand_for_template_part(part),
                    "used_price": None,
                    "new_price": None,
                },
            )
            price_key = f"{part.condition}_price"
            existing_price = row[price_key]
            if existing_price not in (None, part.reference_price):
                raise ValueError(
                    f"Conflicting {part.condition} prices for {part.component_id}"
                )
            row[price_key] = part.reference_price

    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.writer(handle, lineterminator="\n")
        writer.writerow(
            [
                "category",
                "target_id",
                "name",
                "brand",
                "reference_price",
                "normal_price_min",
                "normal_price_max",
                "accepted_count",
                "rejected_count",
                "review_reasons",
            ]
        )
        for component_id in sorted(snapshot):
            row = snapshot[component_id]
            used_price = row["used_price"]
            new_price = row["new_price"]
            reference_price = new_price if new_price is not None else used_price
            if reference_price is None:
                raise ValueError(f"No generated price for {component_id}")
            writer.writerow(
                [
                    row["category"],
                    component_id,
                    row["name"],
                    row["brand"],
                    reference_price,
                    used_price,
                    new_price,
                    1,
                    0,
                    "low_budget_base_catalog",
                ]
            )


def _write_recommendation_ids(
    path: Path,
    templates: Sequence[BuildTemplateInput],
) -> None:
    component_ids = sorted(
        {
            component_id
            for template in templates
            for component_id in template.components.values()
        }
        | CUSTOMIZATION_SUPPORT_IDS
    )
    path.write_text("\n".join(component_ids) + "\n", encoding="utf-8")


def _write_audit(
    path: Path,
    templates: Sequence[BuildTemplateInput],
    skipped_combinations: Sequence[SkippedCombination],
) -> None:
    completed_tiers = _completed_tiers(templates)
    completed_tier_directions = {
        (template.details.target_budget, template.details.direction)
        for template in templates
        if template.details is not None
    }
    underutilized = [
        {
            "template_id": template.id,
            "target_budget": template.details.target_budget,
            "estimated_total": template.estimated_total,
            "remaining_budget": template.details.target_budget - template.estimated_total,
            "reason": "下一档有效性能升级超过预算上限，不使用主板或机箱凑预算",
        }
        for template in templates
        if template.details is not None
        and template.estimated_total is not None
        and template.details.target_budget - template.estimated_total >= 500
    ]
    skipped_payload = [item.as_dict() for item in skipped_combinations]
    payload = {
        "price_date": PRICE_DATE,
        "attempted_combination_count": len(templates) + len(skipped_combinations),
        "completed_tiers": completed_tiers,
        "completed_tier_direction_count": len(completed_tier_directions),
        "completed_template_count": len(templates),
        "skipped_combinations": skipped_payload,
        "pending_review": [
            {
                "component_id": component_id,
                "condition": condition,
                "reason": reason,
            }
            for (component_id, condition), reason in sorted(
                PENDING_REVIEW_CONDITIONS.items()
            )
        ],
        "missing_data": [
            item.as_dict()
            for item in skipped_combinations
            if item.reason in {"no_feasible_candidate", "missing_evidence"}
        ],
        "failed_templates": [
            item.as_dict()
            for item in skipped_combinations
            if item.reason == "generation_error"
        ],
        "underutilized_templates": underutilized,
    }
    path.write_text(
        json.dumps(payload, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )


def _complete_skipped_combinations(
    templates: Sequence[BuildTemplateInput],
    skipped_combinations: Optional[Sequence[SkippedCombination]] = None,
) -> List[SkippedCombination]:
    generated_keys = {
        (
            template.details.target_budget,
            template.details.direction,
            template.details.purchase_mode,
            (
                template.details.gpu_vendor
                if len(
                    _gpu_vendors_for(
                        template.details.target_budget,
                        template.details.direction,
                        template.details.purchase_mode,
                    )
                ) > 1
                else None
            ),
        )
        for template in templates
        if template.details is not None
    }
    provided_by_key = {
        item.key: item for item in (skipped_combinations or [])
    }
    return [
        provided_by_key.get(
            (budget, direction, purchase_mode, gpu_vendor),
            SkippedCombination(
                target_budget=budget,
                direction=direction,
                purchase_mode=purchase_mode,
                reason="missing_evidence",
                gpu_vendor=gpu_vendor,
            ),
        )
        for budget in BUDGET_TIERS
        for direction in DIRECTIONS
        for purchase_mode in PURCHASE_MODES
        for gpu_vendor in _gpu_vendors_for(budget, direction, purchase_mode)
        if (budget, direction, purchase_mode, gpu_vendor) not in generated_keys
    ]


def _read_csv(path: Path) -> Iterable[Dict[str, str]]:
    with path.open(encoding="utf-8", newline="") as handle:
        yield from csv.DictReader(handle)


def _optional_int(value: Optional[str]) -> Optional[int]:
    return int(value) if value else None


def _motherboard_chipset(component_id: str) -> str:
    for chipset in ("x870e", "b850", "b650", "b760", "b550", "b450", "a520"):
        if chipset in component_id:
            return chipset.upper()
    return ""


def _brand_for_template_part(part: BuildTemplatePart) -> str:
    vendor = part.specs.get("vendor")
    if isinstance(vendor, str):
        return vendor
    if part.role == "cpu":
        return "Intel" if part.component_id.startswith("i") else "AMD"
    if part.role == "motherboard":
        return part.name.split(" ", 1)[0]
    return "通用规格"


def _role_label(role: str) -> str:
    return {
        "cpu": "CPU",
        "motherboard": "主板",
        "gpu": "显卡",
        "ram": "内存",
        "storage": "SSD",
        "psu": "电源",
        "cooler": "散热器",
        "case": "机箱",
    }[role]


def _condition_label(condition: Condition) -> str:
    return "全新" if condition == "new" else "二手"


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output-dir", type=Path, default=DATA_DIR)
    parser.add_argument("--markdown", type=Path, default=REVIEW_MARKDOWN_PATH)
    args = parser.parse_args()
    report = generate_low_budget_report()
    templates = list(report.templates)
    paths = write_low_budget_artifacts(
        args.output_dir,
        templates,
        review_markdown_path=args.markdown,
        skipped_combinations=report.skipped_combinations,
        source_parts=report.source_parts,
    )
    print(f"Generated {len(templates)} templates.")
    print(paths.templates_json)
    print(paths.review_markdown)


if __name__ == "__main__":
    main()
