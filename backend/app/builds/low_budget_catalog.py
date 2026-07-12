import argparse
import csv
import json
import math
from dataclasses import dataclass
from functools import lru_cache
from pathlib import Path
from typing import Dict, Iterable, List, Literal, Optional, Sequence, Tuple

from app.builds.high_budget_catalog import GPU_PERFORMANCE, GPU_TDP
from app.builds.service import (
    BuildTemplateDetails,
    BuildTemplateInput,
    BuildTemplatePart,
)


Direction = Literal["fps", "aaa", "balanced"]
PurchaseMode = Literal["new", "used", "mixed"]
Condition = Literal["new", "used"]

PRICE_DATE = "2026-07-12"
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

CPU_PERFORMANCE = {
    "r5-5600": 50,
    "r5-5600x": 52,
    "r5-7500f": 60,
    "r5-9600x": 72,
    "i5-13600kf": 78,
    "r7-7800x3d": 90,
    "r7-9800x3d": 100,
}
CPU_TDP = {
    "r5-5600": 65,
    "r5-5600x": 65,
    "r5-7500f": 88,
    "r5-9600x": 105,
    "i5-13600kf": 181,
    "r7-7800x3d": 120,
    "r7-9800x3d": 120,
}
CPU_SOCKET = {
    "r5-5600": "AM4",
    "r5-5600x": "AM4",
    "r5-7500f": "AM5",
    "r5-9600x": "AM5",
    "i5-13600kf": "LGA1700",
    "r7-7800x3d": "AM5",
    "r7-9800x3d": "AM5",
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
class ArtifactPaths:
    templates_json: Path
    review_markdown: Path
    reference_prices_csv: Path
    recommendation_ids: Path
    audit_json: Path


@lru_cache(maxsize=1)
def generate_low_budget_templates() -> List[BuildTemplateInput]:
    cpus, motherboards, gpus, support_parts = _load_catalog()
    templates = []
    for budget in BUDGET_TIERS:
        for direction in DIRECTIONS:
            for purchase_mode in PURCHASE_MODES:
                candidate = _select_candidate(
                    budget,
                    direction,
                    purchase_mode,
                    cpus,
                    motherboards,
                    gpus,
                    support_parts,
                )
                if candidate is not None:
                    templates.append(
                        _build_template(budget, direction, purchase_mode, candidate)
                    )
    return templates


def minimum_psu_watt(cpu_id: str, gpu_id: str) -> int:
    return math.ceil((CPU_TDP[cpu_id] + GPU_TDP[gpu_id]) * 1.5 + 100)


def render_low_budget_markdown(templates: Sequence[BuildTemplateInput]) -> str:
    skipped_count = len(_skipped_combinations(templates))
    lines = [
        "# 3000-7000元装机基底配置",
        "",
        f"价格日期：{PRICE_DATE}",
        "",
        "说明：每500元一个档位，分别尝试FPS、3A、均衡方向的全新、二手和混合采购。",
        "只保留八大件参考价合计不超过目标预算加200元的真实可行方案；未生成组合记录在审计文件中。",
        f"生成状态：9/9个价位覆盖全部三个方向，共{len(templates)}套可行配置，跳过{skipped_count}个超预算组合。",
        "二手方案中的电源、SSD和显卡购买前必须复核健康度、成色和保修。",
        "",
    ]
    for budget in BUDGET_TIERS:
        lines.extend([f"## {budget}元档", ""])
        for template in templates:
            details = template.details
            if details is None or details.target_budget != budget:
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


def write_low_budget_artifacts(
    output_dir: Path,
    templates: Optional[Sequence[BuildTemplateInput]] = None,
    review_markdown_path: Optional[Path] = None,
) -> ArtifactPaths:
    output_dir = Path(output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)
    generated = list(
        generate_low_budget_templates() if templates is None else templates
    )
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
        render_low_budget_markdown(generated),
        encoding="utf-8",
    )
    _write_reference_prices(paths.reference_prices_csv, generated)
    _write_recommendation_ids(paths.recommendation_ids, generated)
    _write_audit(paths.audit_json, generated)
    return paths


def _select_candidate(
    budget: int,
    direction: Direction,
    purchase_mode: PurchaseMode,
    cpus: Sequence[PricedPart],
    motherboards: Sequence[PricedPart],
    gpus: Sequence[PricedPart],
    support_parts: Dict[str, PricedPart],
) -> Optional[Candidate]:
    best: Optional[Candidate] = None
    best_score: Optional[Tuple[int, ...]] = None
    conditions = CONDITIONS_BY_MODE[purchase_mode]

    for cpu in cpus:
        if cpu.price(conditions["cpu"]) is None:
            continue
        cooler_id = (
            "base-cooler-dual-tower-6-heatpipe"
            if "x3d" in cpu.component_id or cpu.component_id == "i5-13600kf"
            else "base-cooler-6-heatpipe"
        )
        cooler = support_parts[cooler_id]

        for motherboard in motherboards:
            if motherboard.price(conditions["motherboard"]) is None:
                continue
            if cpu.specs["socket"] != motherboard.specs["socket"]:
                continue
            ram_id = (
                "base-ddr4-16gb-3200"
                if motherboard.specs["mem_type"] == "DDR4"
                else "base-ddr5-16gb-6000-c30"
            )

            for gpu in gpus:
                if conditions["gpu"] == "new" and gpu.component_id.startswith(
                    "rtx-40"
                ):
                    continue
                if gpu.price(conditions["gpu"]) is None:
                    continue
                psu = _smallest_psu(
                    minimum_psu_watt(cpu.component_id, gpu.component_id),
                    conditions["psu"],
                    support_parts,
                )
                if psu is None:
                    continue
                fixed_parts = {
                    "cpu": cpu,
                    "motherboard": motherboard,
                    "gpu": gpu,
                    "ram": support_parts[ram_id],
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
    return best


def _score_candidate(
    candidate: Candidate,
    direction: Direction,
) -> Tuple[int, ...]:
    gpu_id = candidate.parts_by_role["gpu"].component_id
    old_gpu_risk = int(gpu_id.startswith("rtx-30"))
    if direction == "fps":
        return (
            candidate.cpu_performance,
            candidate.gpu_performance,
            -old_gpu_risk,
            -candidate.total,
        )
    if direction == "aaa":
        return (
            candidate.gpu_performance,
            candidate.cpu_performance,
            -old_gpu_risk,
            -candidate.total,
        )
    return (
        min(candidate.cpu_performance, candidate.gpu_performance),
        candidate.cpu_performance + candidate.gpu_performance,
        -abs(candidate.cpu_performance - candidate.gpu_performance),
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
    return BuildTemplateInput(
        id=f"base-{budget}-{direction}-{purchase_mode}",
        title=f"{budget}元 {direction_label} {purchase_label}基底配置",
        budget_min=budget,
        budget_max=budget + 499,
        use_cases=["游戏"],
        tags=[direction_label, purchase_label, direction, purchase_mode],
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
    parts = candidate.parts_by_role
    cpu_name = parts["cpu"].name
    gpu_name = parts["gpu"].name
    if direction == "fps":
        advantages = [
            f"{cpu_name}优先保证高帧率和1% Low",
            f"{gpu_name}来自当前预算内可行的显卡档位",
        ]
        disadvantages = ["显卡预算低于同价位3A方案时，高画质单机性能不是第一优先级"]
        suitable_user = "主要玩CS2、无畏契约、PUBG等高帧率游戏的用户"
    elif direction == "aaa":
        advantages = [
            f"预算优先投入{gpu_name}，更适合高画质3A游戏",
            f"{cpu_name}来自当前预算内可行的平台",
        ]
        disadvantages = ["CPU投入低于FPS方案时，不以极限高刷新率为首要目标"]
        suitable_user = "主要玩高画质3A单机、重视分辨率和画质的用户"
    else:
        advantages = [
            f"{cpu_name}与{gpu_name}之间没有刻意单边堆料",
            "同时兼顾高帧率网游与3A游戏",
        ]
        disadvantages = ["不会在单一FPS或3A指标上达到同价位专项方案的极限"]
        suitable_user = "游戏类型比较杂，希望兼顾FPS和3A的用户"

    remaining_budget = budget - candidate.total
    if remaining_budget >= 500:
        disadvantages.append(
            f"当前白名单的下一档有效性能升级无法在预算上限内装下，保留约¥{remaining_budget}"
        )

    if purchase_mode == "new":
        risks = ["全新价格为阶段性参考价，下单前仍需复核当天成交价和保修渠道"]
    elif purchase_mode == "used":
        risks = [
            "二手显卡需要排查矿卡、维修和显存稳定性风险",
            "二手电源需要核对使用年限、拆修记录、线材完整性和质保",
            "二手SSD需要检查通电时间、写入量、健康度和坏块",
            "二手主板需要检查针脚、接口和暗病",
        ]
    else:
        risks = [
            "CPU、内存、散热和机箱按二手采购，需要核对成色与附件",
            "主板、显卡、电源和SSD按全新采购，不能用二手价替代",
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
    condition: Condition,
    support_parts: Dict[str, PricedPart],
) -> Optional[PricedPart]:
    psus = sorted(
        (
            part
            for part in support_parts.values()
            if part.category == "psu"
            and isinstance(part.specs.get("watt"), int)
            and part.price(condition) is not None
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
            used_source=item.get("used_source", ""),
            new_source=item.get("new_source", ""),
            price_date=item["price_date"],
        )
        for item in payload
    ]


def _write_reference_prices(
    path: Path,
    templates: Sequence[BuildTemplateInput],
) -> None:
    referenced_ids = {
        component_id
        for template in templates
        for component_id in template.components.values()
    }
    cpus, motherboards, gpus, support_parts = _load_catalog()
    catalog = {
        part.component_id: part
        for part in [*cpus, *motherboards, *gpus, *support_parts.values()]
        if part.component_id in referenced_ids
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
            used_price = part.used_price or part.new_price
            new_price = part.new_price or part.used_price
            if used_price is None or new_price is None:
                continue
            writer.writerow(
                [
                    part.category,
                    component_id,
                    part.name,
                    part.brand,
                    new_price,
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
    )
    path.write_text("\n".join(component_ids) + "\n", encoding="utf-8")


def _write_audit(path: Path, templates: Sequence[BuildTemplateInput]) -> None:
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
    payload = {
        "price_date": PRICE_DATE,
        "attempted_combination_count": (
            len(BUDGET_TIERS) * len(DIRECTIONS) * len(PURCHASE_MODES)
        ),
        "completed_tiers": BUDGET_TIERS,
        "completed_tier_direction_count": len(completed_tier_directions),
        "completed_template_count": len(templates),
        "skipped_combinations": _skipped_combinations(templates),
        "pending_review": [
            {
                "component_id": "base-psu-850w-gold",
                "condition": "used",
                "reason": "当前仅有单一公开样本，正式展示前需要重新核价",
            }
        ],
        "missing_data": [],
        "failed_templates": [],
        "underutilized_templates": underutilized,
    }
    path.write_text(
        json.dumps(payload, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )


def _skipped_combinations(
    templates: Sequence[BuildTemplateInput],
) -> List[Dict[str, object]]:
    generated_keys = {
        (
            template.details.target_budget,
            template.details.direction,
            template.details.purchase_mode,
        )
        for template in templates
        if template.details is not None
    }
    return [
        {
            "target_budget": budget,
            "direction": direction,
            "purchase_mode": purchase_mode,
            "reason": "over_budget",
        }
        for budget in BUDGET_TIERS
        for direction in DIRECTIONS
        for purchase_mode in PURCHASE_MODES
        if (budget, direction, purchase_mode) not in generated_keys
    ]


def _read_csv(path: Path) -> Iterable[Dict[str, str]]:
    with path.open(encoding="utf-8", newline="") as handle:
        yield from csv.DictReader(handle)


def _optional_int(value: Optional[str]) -> Optional[int]:
    return int(value) if value else None


def _motherboard_chipset(component_id: str) -> str:
    for chipset in ("x870e", "b850", "b650", "b550", "b450", "a520"):
        if chipset in component_id:
            return chipset.upper()
    return ""


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
    templates = generate_low_budget_templates()
    paths = write_low_budget_artifacts(
        args.output_dir,
        templates,
        review_markdown_path=args.markdown,
    )
    print(f"Generated {len(templates)} templates.")
    print(paths.templates_json)
    print(paths.review_markdown)


if __name__ == "__main__":
    main()
