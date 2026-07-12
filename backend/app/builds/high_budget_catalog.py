import argparse
import csv
import json
import math
from dataclasses import dataclass
from functools import lru_cache
from pathlib import Path
from typing import Dict, Iterable, List, Literal, Optional, Sequence, Tuple

from app.builds.service import (
    BuildTemplateDetails,
    BuildTemplateInput,
    BuildTemplatePart,
)


Direction = Literal["fps", "aaa", "balanced"]
PurchaseMode = Literal["new", "used", "mixed"]
Condition = Literal["new", "used"]

PRICE_DATE = "2026-07-12"
BUDGET_TIERS = list(range(7_500, 20_001, 500))
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

CPU_PERFORMANCE = {
    "r5-7500f": 60,
    "r5-9600x": 72,
    "r7-7800x3d": 90,
    "r7-9800x3d": 100,
    "r7-9850x3d": 103,
}
CPU_TDP = {
    "r5-7500f": 88,
    "r5-9600x": 105,
    "r7-7800x3d": 120,
    "r7-9800x3d": 120,
    "r7-9850x3d": 120,
}
GPU_PERFORMANCE = {
    "rtx-3060-ti": 50,
    "rx-6750-gre": 43,
    "rx-7700-xt": 55,
    "rx-7650-gre": 43,
    "rx-7800-xt": 65,
    "rx-9060-xt-8gb": 50,
    "rx-9060-xt-12gb": 55,
    "rx-9070-gre": 75,
    "rx-9070-xt": 85,
    "rtx-3070-ti": 55,
    "rtx-3080": 60,
    "rtx-3080-ti": 65,
    "rtx-4060": 40,
    "rtx-4060-ti": 50,
    "rtx-4070": 60,
    "rtx-4070-super": 75,
    "rx-7900-xt": 75,
    "rx-7900-xtx": 85,
    "rtx-5060": 50,
    "rtx-5060-ti": 60,
    "rtx-5070": 75,
    "rtx-5070-ti": 85,
    "rtx-5080": 95,
    "rtx-5090-d-v2": 105,
    "rtx-5090-d": 105,
    "rtx-5090": 110,
}
GPU_TDP = {
    "rtx-3060-ti": 200,
    "rx-6750-gre": 250,
    "rx-7700-xt": 245,
    "rx-7650-gre": 230,
    "rx-7800-xt": 263,
    "rx-9060-xt-8gb": 180,
    "rx-9060-xt-12gb": 200,
    "rx-9070-gre": 220,
    "rx-9070-xt": 304,
    "rtx-3070-ti": 290,
    "rtx-3080": 320,
    "rtx-3080-ti": 350,
    "rtx-4060": 115,
    "rtx-4060-ti": 160,
    "rtx-4070": 200,
    "rtx-4070-super": 220,
    "rx-7900-xt": 315,
    "rx-7900-xtx": 355,
    "rtx-5060": 145,
    "rtx-5060-ti": 180,
    "rtx-5070": 250,
    "rtx-5070-ti": 300,
    "rtx-5080": 360,
    "rtx-5090-d-v2": 575,
    "rtx-5090-d": 575,
    "rtx-5090": 575,
}

CONDITIONS_BY_MODE: Dict[PurchaseMode, Dict[str, Condition]] = {
    "new": {role: "new" for role in PART_ROLE_ORDER},
    "used": {role: "used" for role in PART_ROLE_ORDER},
    "mixed": {
        "cpu": "used",
        "motherboard": "new",
        "gpu": "new",
        "ram": "used",
        "storage": "new",
        "psu": "new",
        "cooler": "used",
        "case": "used",
    },
}

DIRECTION_LABELS = {"fps": "FPS", "aaa": "3A", "balanced": "均衡"}
PURCHASE_LABELS = {"new": "全新", "used": "二手", "mixed": "混合采购"}
DIRECTIONS: Tuple[Direction, ...] = ("fps", "aaa", "balanced")
PURCHASE_MODES: Tuple[PurchaseMode, ...] = ("new", "used", "mixed")


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

    @property
    def key(self) -> Tuple[int, Direction, PurchaseMode]:
        return (self.target_budget, self.direction, self.purchase_mode)

    def as_dict(self) -> Dict[str, object]:
        return {
            "target_budget": self.target_budget,
            "direction": self.direction,
            "purchase_mode": self.purchase_mode,
            "error": self.error,
        }


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
            for purchase_mode in PURCHASE_MODES:
                try:
                    candidate = _select_candidate(
                        budget=budget,
                        direction=direction,
                        purchase_mode=purchase_mode,
                        cpus=cpus,
                        motherboards=motherboards,
                        gpus=gpus,
                        support_parts=support_parts,
                    )
                except ValueError as exc:
                    failures.append(
                        GenerationFailure(
                            target_budget=budget,
                            direction=direction,
                            purchase_mode=purchase_mode,
                            error=str(exc),
                        )
                    )
                    continue
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
    cpu_tdp = CPU_TDP[cpu_id]
    gpu_tdp = GPU_TDP[gpu_id]
    return math.ceil((cpu_tdp + gpu_tdp) * 1.5 + 100)


def _completion_metadata(
    templates: Sequence[BuildTemplateInput],
    failures: Sequence[GenerationFailure] = (),
) -> Tuple[List[int], List[Dict[str, object]]]:
    generated_keys = {
        (
            template.details.target_budget,
            template.details.direction,
            template.details.purchase_mode,
        )
        for template in templates
        if template.details is not None
    }
    failed_keys = {failure.key for failure in failures}
    completed_tiers = [
        budget
        for budget in BUDGET_TIERS
        if all(
            (budget, direction, purchase_mode) in generated_keys
            for direction in DIRECTIONS
            for purchase_mode in PURCHASE_MODES
        )
    ]
    missing_data = [
        {
            "target_budget": budget,
            "direction": direction,
            "purchase_mode": purchase_mode,
            "reason": "not_provided",
        }
        for budget in BUDGET_TIERS
        for direction in DIRECTIONS
        for purchase_mode in PURCHASE_MODES
        if (budget, direction, purchase_mode) not in generated_keys
        and (budget, direction, purchase_mode) not in failed_keys
    ]
    return completed_tiers, missing_data


def render_high_budget_markdown(
    templates: Sequence[BuildTemplateInput],
    failures: Sequence[GenerationFailure] = (),
) -> str:
    completed_tiers, missing_data = _completion_metadata(templates, failures)
    expected_template_count = len(BUDGET_TIERS) * len(DIRECTIONS) * len(PURCHASE_MODES)
    lines = [
        "# 7500-20000元装机基底配置",
        "",
        f"价格日期：{PRICE_DATE}",
        "",
        "说明：每500元一个档位，每档包含FPS、3A、均衡三个方向及全新、二手、混合采购三种方式。",
        "二手方案中的电源、SSD和显卡仍按二手采购规则生成，购买前必须复核健康度、成色和保修。",
        (
            f"生成状态：{len(completed_tiers)}/{len(BUDGET_TIERS)}个价位完成，"
            f"{len(templates)}/{expected_template_count}套配置生成，"
            f"缺失配置{len(missing_data)}套，失败配置{len(failures)}套。"
        ),
        "",
    ]
    if any(
        part.component_id == "base-psu-850w-gold" and part.condition == "used"
        for template in templates
        if template.details is not None
        for part in template.details.parts
    ):
        lines.insert(
            -1,
            "待人工复核：二手850W电源目前来自单一样本，属于低置信度参考价；所有价格在正式展示前仍需抽样核价。",
        )
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
                    f"### {DIRECTION_LABELS[details.direction]} / {PURCHASE_LABELS[details.purchase_mode]}",
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
                    f"**优点：** {'；'.join(details.advantages)}",
                    "",
                    f"**缺点：** {'；'.join(details.disadvantages)}",
                    "",
                    f"**风险：** {'；'.join(details.risks)}",
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
) -> Candidate:
    best: Optional[Candidate] = None
    best_score: Optional[Tuple[int, ...]] = None
    conditions = CONDITIONS_BY_MODE[purchase_mode]

    for cpu in cpus:
        if cpu.component_id == "r7-9850x3d" and budget < 18_000:
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

        for gpu in gpus:
            if conditions["gpu"] == "new" and gpu.component_id.startswith("rtx-40"):
                continue
            gpu_price = gpu.price(conditions["gpu"])
            if gpu_price is None:
                continue
            required_psu = minimum_psu_watt(cpu.component_id, gpu.component_id)
            psu = _smallest_psu(required_psu, support_parts)
            if psu is None:
                continue

            for motherboard in motherboards:
                fixed_parts = {
                    "cpu": cpu,
                    "motherboard": motherboard,
                    "gpu": gpu,
                    "ram": support_parts["base-ddr5-16gb-6000-c30"],
                    "storage": support_parts["base-ssd-512gb-tlc"],
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
                if total > budget + 200:
                    continue
                candidate = Candidate(
                    parts=tuple(parts),
                    total=total,
                    cpu_performance=CPU_PERFORMANCE[cpu.component_id],
                    gpu_performance=GPU_PERFORMANCE[gpu.component_id],
                )
                score = _score_candidate(candidate, direction)
                if score is not None and (best_score is None or score > best_score):
                    best = candidate
                    best_score = score

    if best is None:
        raise ValueError(
            f"No valid base build for budget={budget}, direction={direction}, mode={purchase_mode}"
        )
    return best


def _score_candidate(
    candidate: Candidate,
    direction: Direction,
) -> Optional[Tuple[int, ...]]:
    parts = candidate.parts_by_role
    cpu_id = parts["cpu"].component_id
    gpu_id = parts["gpu"].component_id
    cpu_perf = candidate.cpu_performance
    gpu_perf = candidate.gpu_performance
    old_gpu_risk = int(gpu_id.startswith("rtx-30"))

    if direction == "fps":
        minimum_gpu = {
            "r5-7500f": 43,
            "r5-9600x": 50,
            "r7-7800x3d": 50,
            "r7-9800x3d": 55,
            "r7-9850x3d": 55,
        }[cpu_id]
        if gpu_perf < minimum_gpu:
            return None
        return (cpu_perf, gpu_perf, -old_gpu_risk, -candidate.total)

    if direction == "aaa":
        minimum_cpu = 60 if gpu_perf <= 85 else 72
        if cpu_perf < minimum_cpu:
            return None
        return (
            gpu_perf,
            cpu_perf,
            -old_gpu_risk,
            -candidate.total,
        )

    if gpu_perf < 50:
        return None
    return (
        min(cpu_perf, gpu_perf),
        cpu_perf + gpu_perf,
        -abs(cpu_perf - gpu_perf),
        -old_gpu_risk,
        -candidate.total,
    )


def _build_template(
    budget: int,
    direction: Direction,
    purchase_mode: PurchaseMode,
    candidate: Candidate,
) -> BuildTemplateInput:
    direction_label = DIRECTION_LABELS[direction]
    purchase_label = PURCHASE_LABELS[purchase_mode]
    details = _details_for_candidate(budget, direction, purchase_mode, candidate)
    return BuildTemplateInput(
        id=f"base-{budget}-{direction}-{purchase_mode}",
        title=f"{budget}元 {direction_label} {purchase_label}基底配置",
        budget_min=budget,
        budget_max=budget + (200 if budget == BUDGET_TIERS[-1] else 499),
        use_cases=["游戏"],
        tags=[direction_label, purchase_label, direction, purchase_mode],
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
    parts = candidate.parts_by_role
    cpu_name = parts["cpu"].name
    gpu_name = parts["gpu"].name
    if direction == "fps":
        advantages = [
            f"{cpu_name}优先保证高帧率和1% Low",
            f"{gpu_name}达到该CPU档位的合理搭配下限",
        ]
        disadvantages = ["显卡预算低于同价位3A方案，高画质单机性能不是第一优先级"]
        suitable_user = "主要玩CS2、无畏契约、PUBG、三角洲行动等高帧率游戏的用户"
    elif direction == "aaa":
        advantages = [
            f"预算优先投入{gpu_name}，更适合高画质3A游戏",
            f"{cpu_name}达到当前显卡档位的合理游戏搭配水平",
        ]
        disadvantages = ["CPU投入低于FPS方案，不以极限高刷新率为首要目标"]
        suitable_user = "主要玩高画质3A单机、重视分辨率和画质的用户"
    else:
        advantages = [
            f"{cpu_name}与{gpu_name}之间没有明显单边堆料",
            "同时兼顾高帧率网游与3A游戏",
        ]
        disadvantages = ["不会在单一FPS或3A指标上达到同价位专项方案的极限"]
        suitable_user = "游戏类型比较杂，希望一套配置长期兼顾FPS和3A的用户"

    remaining_budget = budget - candidate.total
    if remaining_budget >= 500:
        disadvantages.append(
            f"当前白名单的下一档有效性能升级无法在预算上限内装下，保留约¥{remaining_budget}而不靠主板或机箱凑预算"
        )

    if purchase_mode == "new":
        risks = ["全新价格为阶段性参考价，下单前仍需复核当天成交价和保修渠道"]
    elif purchase_mode == "used":
        risks = [
            "二手显卡需要排查矿卡、维修和显存稳定性风险",
            "二手电源需要核对使用年限、拆修记录、线材完整性和质保",
            "二手SSD需要检查通电时间、写入量、健康度和坏块",
            "二手主板需要检查针脚、接口、暗病和个人送保条件",
        ]
    else:
        risks = [
            "CPU、内存、散热和机箱按二手采购，需要核对成色与附件",
            "主板、显卡、电源和SSD按全新采购，避免把二手价冒充全新价",
        ]

    return BuildTemplateDetails(
        target_budget=budget,
        direction=direction,
        purchase_mode=purchase_mode,
        parts=list(candidate.parts),
        advantages=advantages,
        disadvantages=disadvantages,
        risks=risks,
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


def _smallest_psu(
    required_watt: int,
    support_parts: Dict[str, PricedPart],
) -> Optional[PricedPart]:
    psus = sorted(
        (
            part
            for part in support_parts.values()
            if part.category == "psu" and isinstance(part.specs.get("watt"), int)
        ),
        key=lambda part: int(part.specs["watt"]),
    )
    return next(
        (part for part in psus if int(part.specs["watt"]) >= required_watt),
        None,
    )


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
                price_date="2026-07-07",
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
        "completed_template_count": len(templates),
        "pending_review": (
            [
                {
                    "component_id": "base-psu-850w-gold",
                    "condition": "used",
                    "reason": "当前仅有单一公开样本，正式展示前需要重新核价",
                }
            ]
            if any(
                part.component_id == "base-psu-850w-gold"
                and part.condition == "used"
                for template in templates
                if template.details is not None
                for part in template.details.parts
            )
            else []
        ),
        "missing_data": missing_data,
        "failed_templates": [failure.as_dict() for failure in failures],
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
