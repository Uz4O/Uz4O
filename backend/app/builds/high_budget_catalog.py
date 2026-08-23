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
    psu_supports_gpu_power_connector,
)


Direction = Literal["fps", "aaa", "balanced"]
PurchaseMode = Literal["new", "used", "mixed"]
Condition = Literal["new", "used"]
GpuVendor = Literal["nvidia", "amd"]

PRICE_DATE = "2026-08-23"
BUDGET_TIERS = [
    *range(7_500, 10_001, 500),
    *range(11_000, 30_001, 1_000),
]
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

DATA_DIR = Path(__file__).resolve().parents[2] / "data"
CPU_PRICE_PATH = DATA_DIR / "cpu-whitelist-prices-2026-07-07.csv"
GPU_PRICE_PATH = DATA_DIR / "gpu-whitelist-prices-2026-07-07.csv"
MOTHERBOARD_PRICE_PATH = DATA_DIR / "motherboard-whitelist-prices-2026-07-07.csv"
SUPPORT_PART_PATH = DATA_DIR / "base-build-support-components-2026-07-12.json"

_CPU_IDS = (
    "r5-7500f",
    "r5-9600x",
    "r7-9700x",
    "r7-7800x3d",
    "r7-9800x3d",
    "r7-9850x3d",
)
CPU_PERFORMANCE = {
    component_id: RULE_CPU_PERFORMANCE[component_id] for component_id in _CPU_IDS
}
CPU_TDP = {component_id: RULE_CPU_TDP[component_id] for component_id in _CPU_IDS}
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
DIRECTIONS: Tuple[Direction, ...] = ("fps", "aaa", "balanced")
PURCHASE_MODES: Tuple[PurchaseMode, ...] = ("new", "used", "mixed")
ALLOWED_B850_MOTHERBOARDS = {"msi-b850m-power", "asus-b850m-awy"}
MOTHERBOARD_MODEL_RANK = {"msi-b850m-power": 2, "asus-b850m-awy": 1}
MAX_MOTHERBOARD_BUDGET_SHARE = 0.15
MAX_FPS_MOTHERBOARD_BUDGET_SHARE = 0.16
MAX_3A_MOTHERBOARD_STEP_UP = 10_000
MAX_BUDGET_SHORTFALL = 200
AAA_CPU_PRIORITY_MAX_BUDGET_SHORTFALL = 200
FPS_COVERAGE_MAX_BUDGET_SHORTFALL = 200
FPS_COVERAGE_MAX_MOTHERBOARD_BUDGET_SHARE = 0.23
EXTREME_COVERAGE_MIN_BUDGET = 18_000
EXTREME_COVERAGE_MAX_MOTHERBOARD_BUDGET_SHARE = 0.32
EXTREME_COVERAGE_MAX_MOTHERBOARD_STEP_UP = 6_000
AAA_EXTREME_MAX_MOTHERBOARD_BUDGET_SHARE = 0.65
AAA_EXTREME_MAX_MOTHERBOARD_STEP_UP = 10_000
MAX_10000_PLUS_BUDGET_OVERAGE = 800
MINIMUM_650W_GPU_TDP = 140


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


@dataclass(frozen=True)
class ArtifactPaths:
    templates_json: Path
    review_markdown: Path
    reference_prices_csv: Path
    recommendation_ids: Path
    audit_json: Path


@dataclass(frozen=True)
class GenerationFailure:
    target_budget: int
    direction: Direction
    purchase_mode: PurchaseMode
    error: str
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
            "error": self.error,
        }
        if self.gpu_vendor is not None:
            payload["gpu_vendor"] = self.gpu_vendor
        return payload


@dataclass(frozen=True)
class GenerationReport:
    templates: Tuple[BuildTemplateInput, ...]
    source_parts: Tuple[PricedPart, ...]
    failures: Tuple[GenerationFailure, ...]


@lru_cache(maxsize=1)
def generate_high_budget_report() -> GenerationReport:
    cpus, motherboards, gpus, support_parts = _load_catalog()
    source_parts = tuple([*cpus, *motherboards, *gpus, *support_parts.values()])
    templates = []
    failures = []
    for budget in BUDGET_TIERS:
        for direction in DIRECTIONS:
            new_performance_floor: Dict[Optional[GpuVendor], int] = {}
            for purchase_mode in PURCHASE_MODES:
                for gpu_vendor in _gpu_vendors_for(budget, direction, purchase_mode):
                    selection_args = {
                        "budget": budget,
                        "direction": direction,
                        "purchase_mode": purchase_mode,
                        "cpus": cpus,
                        "motherboards": motherboards,
                        "gpus": gpus,
                        "support_parts": support_parts,
                        "gpu_vendor": gpu_vendor,
                        "minimum_focus_performance": (
                            new_performance_floor.get(gpu_vendor)
                            if budget >= 10_000 and purchase_mode != "new"
                            else None
                        ),
                    }
                    attempts = [{}]
                    if (
                        budget == 28_000
                        and direction == "balanced"
                        and purchase_mode == "used"
                        and gpu_vendor == "nvidia"
                    ):
                        attempts.insert(
                            0,
                            {
                                "allow_early_9850x3d": True,
                                "max_budget_shortfall": FPS_COVERAGE_MAX_BUDGET_SHORTFALL,
                                "max_motherboard_budget_share": EXTREME_COVERAGE_MAX_MOTHERBOARD_BUDGET_SHARE,
                                "prefer_budget_fit": True,
                            },
                        )
                    if budget >= 13_000 and direction == "aaa":
                        attempts.insert(
                            0,
                            {
                                "max_budget_shortfall": AAA_CPU_PRIORITY_MAX_BUDGET_SHORTFALL,
                                "max_motherboard_budget_share": AAA_EXTREME_MAX_MOTHERBOARD_BUDGET_SHARE,
                                "max_aaa_motherboard_step_up": AAA_EXTREME_MAX_MOTHERBOARD_STEP_UP,
                                "prefer_budget_fit": True,
                            },
                        )
                    if (
                        budget == 8_000
                        and direction == "aaa"
                        and purchase_mode == "used"
                        and gpu_vendor == "nvidia"
                    ):
                        attempts.append(
                            {
                                "max_budget_shortfall": 150,
                                "prefer_budget_fit": True,
                            }
                        )
                    if (
                        budget == 11_000
                        and direction == "aaa"
                        and purchase_mode in {"used", "mixed"}
                        and gpu_vendor == "nvidia"
                    ):
                        attempts.append(
                            {
                                "max_aaa_motherboard_step_up": 700,
                                "prefer_budget_fit": True,
                            }
                        )
                    if direction == "fps":
                        if budget >= 11_000:
                            attempts.append({"allow_early_9850x3d": True})
                        attempts.append(
                            {
                                "allow_early_9850x3d": budget >= 11_000,
                                "max_budget_shortfall": FPS_COVERAGE_MAX_BUDGET_SHORTFALL,
                                "max_motherboard_budget_share": (
                                    EXTREME_COVERAGE_MAX_MOTHERBOARD_BUDGET_SHARE
                                    if budget >= EXTREME_COVERAGE_MIN_BUDGET
                                    else FPS_COVERAGE_MAX_MOTHERBOARD_BUDGET_SHARE
                                ),
                                "prefer_budget_fit": True,
                            }
                        )
                    if (
                        budget >= 15_000
                        and direction != "fps"
                        and gpu_vendor == "nvidia"
                    ):
                        attempts.append(
                            {
                                "max_budget_shortfall": FPS_COVERAGE_MAX_BUDGET_SHORTFALL,
                                "max_motherboard_budget_share": (
                                    AAA_EXTREME_MAX_MOTHERBOARD_BUDGET_SHARE
                                    if budget >= EXTREME_COVERAGE_MIN_BUDGET
                                    and direction == "aaa"
                                    else EXTREME_COVERAGE_MAX_MOTHERBOARD_BUDGET_SHARE
                                    if budget >= EXTREME_COVERAGE_MIN_BUDGET
                                    else FPS_COVERAGE_MAX_MOTHERBOARD_BUDGET_SHARE
                                ),
                                "max_aaa_motherboard_step_up": (
                                    AAA_EXTREME_MAX_MOTHERBOARD_STEP_UP
                                    if budget >= EXTREME_COVERAGE_MIN_BUDGET
                                    and direction == "aaa"
                                    else EXTREME_COVERAGE_MAX_MOTHERBOARD_STEP_UP
                                    if budget >= EXTREME_COVERAGE_MIN_BUDGET
                                    else 3_500
                                ),
                                "prefer_budget_fit": True,
                            }
                        )
                        attempts.append(
                            {
                                "allow_early_9850x3d": True,
                                "max_budget_shortfall": FPS_COVERAGE_MAX_BUDGET_SHORTFALL,
                                "max_motherboard_budget_share": (
                                    AAA_EXTREME_MAX_MOTHERBOARD_BUDGET_SHARE
                                    if budget >= EXTREME_COVERAGE_MIN_BUDGET
                                    and direction == "aaa"
                                    else EXTREME_COVERAGE_MAX_MOTHERBOARD_BUDGET_SHARE
                                    if budget >= EXTREME_COVERAGE_MIN_BUDGET
                                    else FPS_COVERAGE_MAX_MOTHERBOARD_BUDGET_SHARE
                                ),
                                "max_aaa_motherboard_step_up": (
                                    AAA_EXTREME_MAX_MOTHERBOARD_STEP_UP
                                    if budget >= EXTREME_COVERAGE_MIN_BUDGET
                                    and direction == "aaa"
                                    else EXTREME_COVERAGE_MAX_MOTHERBOARD_STEP_UP
                                    if budget >= EXTREME_COVERAGE_MIN_BUDGET
                                    else 3_500
                                ),
                                "prefer_budget_fit": True,
                            }
                        )
                    candidate = None
                    last_error = None
                    for attempt in attempts:
                        storage_candidates = []
                        for storage_id in (
                            "base-ssd-512gb-tlc",
                            "base-ssd-1tb-tlc",
                            "base-ssd-2tb-tlc",
                        ):
                            try:
                                storage_candidates.append(
                                    _select_candidate(
                                        **selection_args,
                                        **attempt,
                                        storage_id=storage_id,
                                    )
                                )
                            except ValueError as exc:
                                last_error = exc
                        if storage_candidates:
                            candidate = max(
                                storage_candidates,
                                key=lambda item: _score_candidate(
                                    item,
                                    direction,
                                    prefer_modern_gpu=(
                                        CONDITIONS_BY_MODE[purchase_mode]["gpu"]
                                        == "used"
                                    ),
                                    prefer_new_9800_motherboard=budget >= 10_000,
                                ),
                            )
                            break
                    if candidate is None:
                        failures.append(
                            GenerationFailure(
                                target_budget=budget,
                                direction=direction,
                                purchase_mode=purchase_mode,
                                gpu_vendor=gpu_vendor,
                                error=str(last_error),
                            )
                        )
                        continue
                    if purchase_mode == "new":
                        new_performance_floor[gpu_vendor] = _focus_performance(
                            candidate,
                            direction,
                        )
                    templates.append(
                        _build_template(budget, direction, purchase_mode, candidate)
                    )
    return GenerationReport(
        templates=tuple(templates),
        source_parts=source_parts,
        failures=tuple(failures),
    )


def generate_high_budget_templates() -> List[BuildTemplateInput]:
    return list(generate_high_budget_report().templates)


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
    if direction == "fps" and budget >= 10_000:
        return ("nvidia", "amd")
    if (
        direction != "fps"
        and budget >= GPU_VENDOR_SPLIT_MIN_BUDGET[purchase_mode]
    ):
        return ("nvidia", "amd")
    return (None,)


def _completion_metadata(
    templates: Sequence[BuildTemplateInput],
    failures: Sequence[GenerationFailure] = (),
) -> Tuple[List[int], List[Dict[str, object]]]:
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
    failures_by_key = {failure.key: failure for failure in failures}
    completed_tiers = [
        budget
        for budget in BUDGET_TIERS
        if all(
            (budget, direction, purchase_mode, gpu_vendor) in generated_keys
            for direction in DIRECTIONS
            for purchase_mode in PURCHASE_MODES
            for gpu_vendor in _gpu_vendors_for(budget, direction, purchase_mode)
        )
    ]
    missing_data = []
    for budget in BUDGET_TIERS:
        for direction in DIRECTIONS:
            for purchase_mode in PURCHASE_MODES:
                for gpu_vendor in _gpu_vendors_for(budget, direction, purchase_mode):
                    key = (budget, direction, purchase_mode, gpu_vendor)
                    if key in generated_keys:
                        continue
                    failure = failures_by_key.get(key)
                    if failure is not None and not _is_unavailable_failure(failure):
                        continue
                    payload = _missing_combination_payload(
                        budget,
                        direction,
                        purchase_mode,
                        gpu_vendor,
                    )
                    if failure is not None:
                        payload["reason"] = "no_feasible_candidate"
                    missing_data.append(payload)
    return completed_tiers, missing_data


def _public_completed_tiers(
    templates: Sequence[BuildTemplateInput],
) -> List[int]:
    mode_keys = {
        (
            template.details.target_budget,
            template.details.direction,
            template.details.purchase_mode,
        )
        for template in templates
        if template.details is not None
    }
    nvidia_keys = {
        (
            template.details.target_budget,
            template.details.direction,
            template.details.purchase_mode,
        )
        for template in templates
        if template.details is not None
        and template.details.gpu_vendor == "nvidia"
    }
    return [
        budget
        for budget in BUDGET_TIERS
        if all(
            (budget, direction, purchase_mode) in mode_keys
            and (
                budget < 10_000
                or (budget, direction, purchase_mode) in nvidia_keys
            )
            for direction in DIRECTIONS
            for purchase_mode in PURCHASE_MODES
        )
    ]


def _missing_combination_payload(
    budget: int,
    direction: Direction,
    purchase_mode: PurchaseMode,
    gpu_vendor: Optional[GpuVendor],
) -> Dict[str, object]:
    payload: Dict[str, object] = {
        "target_budget": budget,
        "direction": direction,
        "purchase_mode": purchase_mode,
        "reason": "not_provided",
    }
    if gpu_vendor is not None:
        payload["gpu_vendor"] = gpu_vendor
    return payload


def _is_unavailable_failure(failure: GenerationFailure) -> bool:
    return failure.error.startswith("No valid base build")


def render_high_budget_markdown(
    templates: Sequence[BuildTemplateInput],
    failures: Sequence[GenerationFailure] = (),
) -> str:
    completed_tiers, missing_data = _completion_metadata(templates, failures)
    public_completed_tiers = _public_completed_tiers(templates)
    expected_template_count = sum(
        len(_gpu_vendors_for(budget, direction, purchase_mode))
        for budget in BUDGET_TIERS
        for direction in DIRECTIONS
        for purchase_mode in PURCHASE_MODES
    )
    generation_failure_count = sum(
        not _is_unavailable_failure(failure) for failure in failures
    )
    lines = [
        "# 7500-30000元装机基底配置",
        "",
        f"价格日期：{PRICE_DATE}",
        "",
        "说明：10000元以下每500元一个档位，10000元以上每1000元一个档位；3A和均衡仅在达到对应预算门槛后拆分 NVIDIA 与 AMD 方案。",
        "二手方案中的电源、SSD和显卡仍按二手采购规则生成，购买前必须复核健康度、成色和保修。",
        (
            f"生成状态：公共三采购模式覆盖{len(public_completed_tiers)}/{len(BUDGET_TIERS)}个价位；"
            f"全部厂商变体{len(completed_tiers)}/{len(BUDGET_TIERS)}个价位完成，"
            f"{len(templates)}/{expected_template_count}套配置生成，"
            f"不可用配置{len(missing_data)}套，失败配置{generation_failure_count}套。"
        ),
        "",
    ]
    present_tiers = sorted(
        {
            template.details.target_budget
            for template in templates
            if template.details is not None
        }
    )
    for budget in present_tiers:
        lines.extend([f"## {budget}元档", ""])
        tier_templates = [
            template
            for template in templates
            if template.details and template.details.target_budget == budget
        ]
        for template in tier_templates:
            details = template.details
            if details is None:
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


def write_high_budget_artifacts(
    output_dir: Path,
    templates: Optional[Sequence[BuildTemplateInput]] = None,
    review_markdown_path: Optional[Path] = None,
    report: Optional[GenerationReport] = None,
) -> ArtifactPaths:
    output_dir = Path(output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)
    if report is not None and templates is not None:
        raise ValueError("Pass either report or templates, not both")
    if report is None:
        if templates is None:
            report = generate_high_budget_report()
        else:
            generated = tuple(templates)
            report = GenerationReport(
                templates=generated,
                source_parts=_source_parts_from_templates(generated),
                failures=(),
            )
    templates = list(report.templates)
    paths = ArtifactPaths(
        templates_json=output_dir / "high-budget-base-build-templates.json",
        review_markdown=review_markdown_path or output_dir / "high-budget-base-builds.md",
        reference_prices_csv=output_dir / "high-budget-base-reference-prices.csv",
        recommendation_ids=output_dir / "high-budget-base-recommendation-ids.txt",
        audit_json=output_dir / "high-budget-base-audit.json",
    )
    paths.review_markdown.parent.mkdir(parents=True, exist_ok=True)
    paths.templates_json.write_text(
        json.dumps(
            [template.model_dump(mode="json") for template in templates],
            ensure_ascii=False,
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )
    paths.review_markdown.write_text(
        render_high_budget_markdown(templates, report.failures),
        encoding="utf-8",
    )
    _write_reference_prices(
        paths.reference_prices_csv,
        templates,
        report.source_parts,
    )
    _write_recommendation_ids(paths.recommendation_ids, templates)
    _write_audit(paths.audit_json, templates, report.failures)
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
    minimum_focus_performance: Optional[int] = None,
    allow_early_9850x3d: bool = False,
    max_budget_shortfall: int = MAX_BUDGET_SHORTFALL,
    max_motherboard_budget_share: Optional[float] = None,
    max_aaa_motherboard_step_up: int = MAX_3A_MOTHERBOARD_STEP_UP,
    prefer_budget_fit: bool = False,
    storage_id: str = "base-ssd-512gb-tlc",
) -> Candidate:
    if direction == "fps" and gpu_vendor is None:
        candidates = {}
        for vendor in ("nvidia", "amd"):
            try:
                candidates[vendor] = _select_candidate(
                    budget=budget,
                    direction=direction,
                    purchase_mode=purchase_mode,
                    cpus=cpus,
                    motherboards=motherboards,
                    gpus=gpus,
                    support_parts=support_parts,
                    gpu_vendor=vendor,
                    minimum_focus_performance=minimum_focus_performance,
                    allow_early_9850x3d=allow_early_9850x3d,
                    max_budget_shortfall=max_budget_shortfall,
                    max_motherboard_budget_share=max_motherboard_budget_share,
                    max_aaa_motherboard_step_up=max_aaa_motherboard_step_up,
                    prefer_budget_fit=prefer_budget_fit,
                    storage_id=storage_id,
                )
            except ValueError:
                pass
        if not candidates:
            raise ValueError(
                f"No valid base build for budget={budget}, direction={direction}, mode={purchase_mode}"
            )
        nvidia = candidates.get("nvidia")
        amd = candidates.get("amd")
        if nvidia is None:
            return amd
        if amd is None:
            return nvidia
        if (
            amd.cpu_performance > nvidia.cpu_performance
            and amd.gpu_performance >= nvidia.gpu_performance
        ):
            return amd
        if (
            amd.cpu_performance >= nvidia.cpu_performance
            and amd.gpu_performance * 100 >= nvidia.gpu_performance * 115
        ):
            return amd
        return nvidia

    best: Optional[Candidate] = None
    best_score: Optional[Tuple[int, ...]] = None
    conditions = CONDITIONS_BY_MODE[purchase_mode]
    required_8000_used_aaa = (
        budget == 8_000
        and direction == "aaa"
        and purchase_mode == "used"
        and gpu_vendor == "nvidia"
    )
    motherboard_budget_share = max_motherboard_budget_share or (
        MAX_FPS_MOTHERBOARD_BUDGET_SHARE
        if direction == "fps"
        else MAX_MOTHERBOARD_BUDGET_SHARE
    )
    max_motherboard_price = budget * motherboard_budget_share

    for cpu in cpus:
        if required_8000_used_aaa and cpu.component_id != "r7-7800x3d":
            continue
        if direction == "aaa" and cpu.component_id == "r7-9850x3d":
            continue
        if (
            budget >= 9_500
            and direction == "fps"
            and CPU_PERFORMANCE[cpu.component_id]
            < CPU_PERFORMANCE["r7-7800x3d"]
        ):
            continue
        if (
            cpu.component_id == "r7-9850x3d"
            and budget < 18_000
            and not allow_early_9850x3d
        ):
            continue
        cpu_price = cpu.price(conditions["cpu"])
        if cpu_price is None:
            continue
        cooler_id = (
            "base-cooler-dual-tower-6-heatpipe"
            if "x3d" in cpu.component_id
            else "base-cooler-6-heatpipe"
        )
        cooler = support_parts[cooler_id]
        value_motherboard = (
            _cheapest_adequate_motherboard(
                cpu.component_id,
                conditions["motherboard"],
                motherboards,
                max_price=(budget * MAX_MOTHERBOARD_BUDGET_SHARE),
            )
            if direction == "aaa"
            else None
        )
        for gpu in gpus:
            if not gpu_brand_allowed_for_budget(gpu.name, budget):
                continue
            if required_8000_used_aaa and gpu.component_id != "rtx-4070-super":
                continue
            if gpu_vendor and gpu.brand.lower() != gpu_vendor:
                continue
            gpu_price = gpu.price(conditions["gpu"])
            if gpu_price is None:
                continue
            if not is_cpu_gpu_pairing_allowed(
                cpu.component_id,
                gpu.component_id,
            ):
                continue
            minimum_gpu_cpu_performance = GPU_MIN_CPU_PERFORMANCE.get(
                gpu.component_id
            )
            if (
                minimum_gpu_cpu_performance is not None
                and CPU_PERFORMANCE[cpu.component_id]
                < minimum_gpu_cpu_performance
            ):
                continue
            if (
                cpu.component_id == "r7-9700x"
                and minimum_gpu_cpu_performance is None
            ):
                continue
            if (
                cpu.component_id in {"r7-9800x3d", "r7-9850x3d"}
                and GPU_PERFORMANCE[gpu.component_id]
                < GPU_PERFORMANCE["rtx-5060-ti"]
            ):
                continue
            if (
                budget >= 9_500
                and direction == "aaa"
                and cpu.component_id in {"r7-9800x3d", "r7-9850x3d"}
                and GPU_PERFORMANCE[gpu.component_id]
                < GPU_PERFORMANCE["rtx-5070-ti"]
            ):
                continue
            required_psu = minimum_psu_watt(cpu.component_id, gpu.component_id)
            psu = _smallest_psu(
                required_psu,
                conditions["psu"],
                support_parts,
                gpu.component_id,
            )
            if psu is None:
                continue
            storage = support_parts[storage_id]

            for motherboard in motherboards:
                motherboard_price = motherboard.price(conditions["motherboard"])
                if (
                    motherboard_price is None
                    or motherboard_price > max_motherboard_price
                ):
                    continue
                if (
                    motherboard.specs.get("chipset") == "B850"
                    and motherboard.component_id not in ALLOWED_B850_MOTHERBOARDS
                ):
                    continue
                if (
                    budget == 8_000
                    and direction == "fps"
                    and purchase_mode == "used"
                    and motherboard.specs.get("chipset") != "B850"
                ):
                    continue
                if (
                    budget == 10_000
                    and direction == "fps"
                    and purchase_mode == "new"
                    and motherboard.component_id != "msi-b850m-power"
                ):
                    continue
                if (
                    budget == 11_000
                    and direction == "fps"
                    and purchase_mode == "new"
                    and motherboard.component_id != "msi-b850m-power"
                ):
                    continue
                if (
                    budget == 10_000
                    and direction == "aaa"
                    and purchase_mode == "mixed"
                    and gpu_vendor == "nvidia"
                    and motherboard.component_id != "asus-b650m-tuf"
                ):
                    continue
                if (
                    value_motherboard is not None
                    and motherboard_price
                    > value_motherboard.price(conditions["motherboard"])
                    + max_aaa_motherboard_step_up
                ):
                    continue
                if (
                    motherboard.component_id == "asus-prime-b650m-k"
                    and cpu.component_id in {"r7-9800x3d", "r7-9850x3d"}
                ):
                    continue
                for ram in _support_candidates(
                    "ram",
                    conditions["ram"],
                    support_parts,
                    memory_type="DDR5",
                ):
                    required_ram_capacity = (
                        32 if budget >= EXTREME_COVERAGE_MIN_BUDGET else 16
                    )
                    if ram.specs.get("capacity_gb") != required_ram_capacity:
                        continue
                    if ram.specs.get("cas_latency") != 28:
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
                    parts = []
                    for role in PART_ROLE_ORDER:
                        part = fixed_parts[role]
                        condition = conditions[role]
                        price = part.price(condition)
                        if price is None:
                            break
                        parts.append(_template_part(role, part, condition, price))
                    if len(parts) != len(PART_ROLE_ORDER):
                        continue

                    total = sum(part.reference_price for part in parts)
                    max_overage = (
                        MAX_10000_PLUS_BUDGET_OVERAGE
                        if budget >= 10_000
                        else 500
                    )
                    if not budget - max_budget_shortfall <= total <= budget + max_overage:
                        continue
                    candidate = Candidate(
                        parts=tuple(parts),
                        total=total,
                        cpu_performance=CPU_PERFORMANCE[cpu.component_id],
                        gpu_performance=GPU_PERFORMANCE[gpu.component_id],
                    )
                    if (
                        minimum_focus_performance is not None
                        and _focus_performance(candidate, direction)
                        < minimum_focus_performance
                    ):
                        continue
                    score = _score_candidate(
                        candidate,
                        direction,
                        prefer_modern_gpu=conditions["gpu"] == "used",
                        prefer_new_9800_motherboard=budget >= 10_000,
                    )
                    if score is not None and prefer_budget_fit:
                        score_prefix_length = 4 if direction == "aaa" else 3
                        score = (
                            *score[:score_prefix_length],
                            -abs(total - budget),
                            *score[score_prefix_length:],
                        )
                    if score is not None and (
                        best_score is None or score > best_score
                    ):
                        best = candidate
                        best_score = score

    if best is None:
        raise ValueError(
            f"No valid base build for budget={budget}, direction={direction}, mode={purchase_mode}"
        )
    return best


def _focus_performance(candidate: Candidate, direction: Direction) -> int:
    if direction == "fps":
        return candidate.cpu_performance
    if direction == "aaa":
        return candidate.gpu_performance
    return min(candidate.cpu_performance, candidate.gpu_performance)


def _score_candidate(
    candidate: Candidate,
    direction: Direction,
    prefer_modern_gpu: bool = False,
    prefer_new_9800_motherboard: bool = False,
) -> Optional[Tuple[int, ...]]:
    parts = candidate.parts_by_role
    cpu_id = parts["cpu"].component_id
    gpu_id = parts["gpu"].component_id
    cpu_perf = candidate.cpu_performance
    gpu_perf = candidate.gpu_performance
    old_gpu_risk = int(_has_legacy_mining_risk(gpu_id))
    modern_gpu_rank = -old_gpu_risk if prefer_modern_gpu else 0
    ram_capacity = int(parts["ram"].specs.get("capacity_gb", 0))
    ram_latency_score = -int(parts["ram"].specs.get("cas_latency", 99))
    motherboard = parts["motherboard"]
    motherboard_price_score = motherboard.reference_price
    motherboard_tier = {"B650": 0, "B850": 1, "X870E": 2}.get(
        str(motherboard.specs.get("chipset")),
        0,
    )
    motherboard_tier_score = (
        motherboard_tier
        if prefer_new_9800_motherboard
        and cpu_id == "r7-9800x3d"
        and parts["cpu"].condition == "new"
        else -motherboard_tier
    )
    motherboard_model_score = MOTHERBOARD_MODEL_RANK.get(
        motherboard.component_id,
        0,
    )
    if direction == "fps":
        minimum_gpu = {
            "r5-7500f": 43,
            "r5-9600x": 50,
            "r7-9700x": 50,
            "r7-7800x3d": 50,
            "r7-9800x3d": 60,
            "r7-9850x3d": 60,
        }[cpu_id]
        if gpu_perf < minimum_gpu:
            return None
        return (
            modern_gpu_rank,
            cpu_perf,
            gpu_perf,
            motherboard_tier_score,
            motherboard_model_score,
            ram_capacity,
            ram_latency_score,
            -old_gpu_risk,
            -candidate.total,
        )

    if direction == "aaa":
        minimum_cpu = 60 if gpu_perf <= 85 else 72
        if cpu_perf < minimum_cpu:
            return None
        return (
            modern_gpu_rank,
            gpu_perf,
            cpu_perf,
            motherboard_price_score,
            motherboard_tier_score,
            motherboard_model_score,
            ram_capacity,
            ram_latency_score,
            -old_gpu_risk,
            -candidate.total,
        )

    if gpu_perf < 50:
        return None
    performance_gap = abs(cpu_perf - gpu_perf)
    balanced_fit = min(cpu_perf, gpu_perf) * 3 - performance_gap
    return (
        modern_gpu_rank,
        balanced_fit,
        min(cpu_perf, gpu_perf),
        cpu_perf + gpu_perf,
        -performance_gap,
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
        if gpu_vendor == "amd" and (direction != "fps" or budget >= 10_000)
        else ""
    )
    details = _details_for_candidate(budget, direction, purchase_mode, candidate)
    return BuildTemplateInput(
        id=f"base-{budget}-{direction}-{purchase_mode}{vendor_suffix}",
        title=f"{budget}元 {direction_label} {purchase_label} {vendor_label}基底配置",
        budget_min=budget,
        budget_max=_budget_max_for_tier(budget),
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
        details=details,
    )


def _details_for_candidate(
    budget: int,
    direction: Direction,
    purchase_mode: PurchaseMode,
    candidate: Candidate,
) -> BuildTemplateDetails:
    if direction == "fps":
        suitable_user = "主要玩CS2、无畏契约、PUBG、三角洲行动等高帧率游戏的用户"
    elif direction == "aaa":
        suitable_user = "主要玩高画质3A单机、重视分辨率和画质的用户"
    else:
        suitable_user = "游戏类型比较杂，希望一套配置长期兼顾FPS和3A的用户"

    return BuildTemplateDetails(
        target_budget=budget,
        direction=direction,
        purchase_mode=purchase_mode,
        gpu_vendor=_candidate_gpu_vendor(candidate),
        parts=list(candidate.parts),
        suitable_user=suitable_user,
        price_date=PRICE_DATE,
    )


def _budget_max_for_tier(budget: int) -> int:
    next_budget = next((tier for tier in BUDGET_TIERS if tier > budget), None)
    return next_budget - 1 if next_budget is not None else budget + 200


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


def _smallest_psu(
    required_watt: int,
    condition: Condition,
    support_parts: Dict[str, PricedPart],
    gpu_id: Optional[str] = None,
) -> Optional[PricedPart]:
    psus = sorted(
        (
            part
            for part in support_parts.values()
            if part.category == "psu"
            and isinstance(part.specs.get("watt"), int)
            and part.price(condition) is not None
            and (
                gpu_id is None
                or psu_supports_gpu_power_connector(gpu_id, part.specs)
            )
        ),
        key=lambda part: int(part.specs["watt"]),
    )
    return next(
        (part for part in psus if int(part.specs["watt"]) >= required_watt),
        None,
    )


def _cheapest_adequate_motherboard(
    cpu_id: str,
    condition: Condition,
    motherboards: Sequence[PricedPart],
    max_price: Optional[float] = None,
) -> Optional[PricedPart]:
    candidates = [
        part
        for part in motherboards
        if part.price(condition) is not None
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
            and part.price(condition) is not None
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
    cpus = _load_cpu_parts(CPU_PRICE_PATH)
    motherboards = _load_motherboard_parts(MOTHERBOARD_PRICE_PATH)
    gpus = _load_gpu_parts(GPU_PRICE_PATH)
    support_parts = {
        part.component_id: part for part in _load_support_parts(SUPPORT_PART_PATH)
    }
    return cpus, motherboards, gpus, support_parts


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
                brand="AMD",
                specs={
                    "socket": "AM5",
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
        if row["platform"] != "AM5":
            continue
        parts.append(
            PricedPart(
                component_id=row["target_id"],
                category="motherboard",
                name=row["name"],
                brand=row["name"].split(" ", 1)[0],
                specs={
                    "socket": "AM5",
                    "mem_type": "DDR5",
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
        parts.append(
            PricedPart(
                component_id=component_id,
                category="gpu",
                name=row["name"],
                brand="NVIDIA" if component_id.startswith("rtx-") else "AMD",
                specs={
                    "vendor": "NVIDIA" if component_id.startswith("rtx-") else "AMD",
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
            used_source=item["used_source"],
            new_source=item["new_source"],
            price_date=item["price_date"],
        )
        for item in payload
    ]


def _source_parts_from_templates(
    templates: Sequence[BuildTemplateInput],
) -> Tuple[PricedPart, ...]:
    snapshots: Dict[str, Dict[str, object]] = {}
    for template in templates:
        if template.details is None:
            continue
        for part in template.details.parts:
            snapshot = snapshots.setdefault(
                part.component_id,
                {
                    "category": part.role,
                    "name": part.name,
                    "brand": _brand_for_template_part(part),
                    "specs": part.specs,
                    "used_price": None,
                    "new_price": None,
                    "used_source": "",
                    "new_source": "",
                    "price_date": part.price_date,
                },
            )
            price_key = f"{part.condition}_price"
            existing_price = snapshot[price_key]
            if existing_price not in (None, part.reference_price):
                raise ValueError(
                    f"Conflicting {part.condition} prices for {part.component_id}"
                )
            snapshot[price_key] = part.reference_price
            snapshot[f"{part.condition}_source"] = part.price_source

    return tuple(
        PricedPart(component_id=component_id, **snapshots[component_id])
        for component_id in sorted(snapshots)
    )


def _write_reference_prices(
    path: Path,
    templates: Sequence[BuildTemplateInput],
    source_parts: Sequence[PricedPart],
) -> None:
    referenced_ids = {
        component_id
        for template in templates
        for component_id in template.components.values()
    }
    source_by_id = {part.component_id: part for part in source_parts}
    missing_ids = sorted(referenced_ids - set(source_by_id))
    if missing_ids:
        raise ValueError("Source snapshot is missing: " + ", ".join(missing_ids))
    for template in templates:
        if template.details is None:
            continue
        for part in template.details.parts:
            source = source_by_id[part.component_id]
            if source.price(part.condition) != part.reference_price:
                raise ValueError(f"Snapshot price mismatch for {part.component_id}")
    catalog = {
        component_id: source_by_id[component_id]
        for component_id in referenced_ids
    }

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
        for component_id in sorted(catalog):
            part = catalog[component_id]
            reference_price = (
                part.new_price if part.new_price is not None else part.used_price
            )
            if reference_price is None:
                continue
            writer.writerow(
                [
                    part.category,
                    component_id,
                    part.name,
                    part.brand,
                    reference_price,
                    part.used_price,
                    part.new_price,
                    1,
                    0,
                    "high_budget_base_catalog",
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
    )
    path.write_text("\n".join(component_ids) + "\n", encoding="utf-8")


def _write_audit(
    path: Path,
    templates: Sequence[BuildTemplateInput],
    failures: Sequence[GenerationFailure] = (),
) -> None:
    completed_tiers, missing_data = _completion_metadata(templates, failures)
    underutilized = [
        {
            "template_id": template.id,
            "target_budget": template.details.target_budget,
            "estimated_total": template.estimated_total,
            "remaining_budget": template.details.target_budget - template.estimated_total,
            "reason": "下一档有效性能升级超过预算上限，不使用主板或机箱凑预算",
        }
        for template in templates
        if template.details
        and template.estimated_total is not None
        and template.details.target_budget - template.estimated_total >= 500
    ]
    payload = {
        "price_date": PRICE_DATE,
        "completed_tiers": completed_tiers,
        "public_completed_tiers": _public_completed_tiers(templates),
        "completed_template_count": len(templates),
        "pending_review": [],
        "missing_data": missing_data,
        "failed_templates": [
            failure.as_dict()
            for failure in failures
            if not _is_unavailable_failure(failure)
        ],
        "underutilized_templates": underutilized,
    }
    path.write_text(
        json.dumps(payload, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )


def _read_csv(path: Path) -> Iterable[Dict[str, str]]:
    with path.open(encoding="utf-8", newline="") as handle:
        yield from csv.DictReader(handle)


def _optional_int(value: Optional[str]) -> Optional[int]:
    return int(value) if value else None


def _motherboard_chipset(component_id: str) -> str:
    if "x870e" in component_id:
        return "X870E"
    if "b850" in component_id:
        return "B850"
    return "B650"


def _brand_for_template_part(part: BuildTemplatePart) -> str:
    vendor = part.specs.get("vendor")
    if isinstance(vendor, str) and vendor:
        return vendor
    if part.role == "cpu" and part.component_id.startswith(("r5-", "r7-", "r9-")):
        return "AMD"
    if part.component_id.startswith("base-"):
        return "通用规格"
    return part.name.split(" ", 1)[0]


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
    parser.add_argument("--markdown", type=Path)
    args = parser.parse_args()
    report = generate_high_budget_report()
    paths = write_high_budget_artifacts(
        args.output_dir,
        review_markdown_path=args.markdown,
        report=report,
    )
    print(f"Generated {len(report.templates)} templates.")
    print(paths.templates_json)
    print(paths.review_markdown)


if __name__ == "__main__":
    main()
