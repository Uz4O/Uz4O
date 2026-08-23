import argparse
import csv
import json
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, List, Literal, Optional, Sequence, Tuple

from app.builds.service import (
    BuildTemplateDetails,
    BuildTemplateInput,
    BuildTemplatePart,
)
from app.builds.gpu_rules import gpu_brand_allowed_for_budget
from app.catalog.rule_specs import minimum_psu_watt_for_specs
from app.builds.templates import read_build_template_inputs
from app.catalog.seed import extract_catalog_components, read_catalog_components


Profile = Literal["general", "media", "cuda"]
PurchaseMode = Literal["new", "used", "mixed"]
Condition = Literal["new", "used"]

PRICE_DATE = "2026-08-22"
BUDGET_TIERS = tuple(range(6_000, 30_001, 1_000))
LOW_BUDGET_TIERS = (3_000, 4_000, 5_000)
PART_ROLES = (
    "cpu",
    "motherboard",
    "gpu",
    "ram",
    "storage",
    "psu",
    "cooler",
    "case",
)

BACKEND_ROOT = Path(__file__).resolve().parents[2]
PROJECT_ROOT = BACKEND_ROOT.parent
DATA_DIR = BACKEND_ROOT / "data"
SWIFT_CATALOG_PATH = PROJECT_ROOT / "May" / "May" / "Models" / "HardwareCatalog.swift"
LOW_TEMPLATE_PATH = DATA_DIR / "low-budget-base-build-templates.json"
CPU_PRICE_PATH = DATA_DIR / "cpu-whitelist-prices-2026-07-07.csv"
GPU_PRICE_PATH = DATA_DIR / "gpu-whitelist-prices-2026-07-07.csv"
MOTHERBOARD_PRICE_PATH = DATA_DIR / "motherboard-whitelist-prices-2026-07-07.csv"
BASE_SUPPORT_PATH = DATA_DIR / "base-build-support-components-2026-07-12.json"
OFFICE_SUPPORT_PATH = DATA_DIR / "office-build-support-components-2026-07-20.json"

OFFICE_CPU_IDS = (
    "u5-245k",
    "u5-250-plus",
    "u7-265k",
    "u7-270-plus",
)
OFFICE_MOTHERBOARD_IDS = (
    "asus-b860m-k",
    "msi-pro-b860m-a",
    "msi-b860m-mortar",
)
OFFICE_ONLY_GPU_IDS = (
    "arc-a580-8gb",
    "arc-a770-16gb",
    "arc-b570-10gb",
    "arc-b580-12gb",
)
OFFICE_NVIDIA_GPU_IDS = (
    "rtx-4060",
    "rtx-4060-ti",
    "rtx-4070",
    "rtx-4070-super",
    "rtx-5060",
    "rtx-5060-ti",
    "rtx-5070",
    "rtx-5070-ti",
    "rtx-5080",
)
OFFICE_GPU_IDS = (*OFFICE_ONLY_GPU_IDS, *OFFICE_NVIDIA_GPU_IDS)
OFFICE_RAM_IDS = (
    "office-ddr5-16gb-7200-c36",
    "base-ddr5-16gb-6000-c30",
)
VALUE_STORAGE_IDS = (
    "base-ssd-fanxiang-s500-pro-512gb",
    "base-ssd-fanxiang-s790e-1tb",
)

CPU_SCORE = {
    "u5-245k": 70,
    "u5-250-plus": 80,
    "u7-265k": 90,
    "u7-270-plus": 100,
}
BOARD_IDS_BY_CPU = {
    "u5-245k": OFFICE_MOTHERBOARD_IDS,
    "u5-250-plus": ("msi-pro-b860m-a", "msi-b860m-mortar"),
    "u7-265k": ("msi-pro-b860m-a", "msi-b860m-mortar"),
    "u7-270-plus": ("msi-b860m-mortar",),
}
BOARD_SCORE = {
    "asus-b860m-k": 1,
    "msi-pro-b860m-a": 2,
    "msi-b860m-mortar": 3,
}
MEDIA_GPU_SCORE = {
    "arc-a580-8gb": 40,
    "arc-b570-10gb": 60,
    "arc-a770-16gb": 65,
    "arc-b580-12gb": 70,
}
PROFILE_LABELS = {
    "general": "日常与平面办公",
    "media": "视频剪辑",
    "cuda": "3D与CUDA",
}
PROFILE_APPS = {
    "general": ("Office", "WPS", "Photoshop", "AutoCAD"),
    "media": ("Premiere", "DaVinci Resolve", "剪映"),
    "cuda": ("Blender", "After Effects", "MATLAB", "本地 AI"),
}
PURCHASE_LABELS = {"new": "全新", "used": "二手", "mixed": "混合采购"}
GPU_VENDOR_LABELS = {"nvidia": "NVIDIA", "amd": "AMD", "intel": "Intel"}
MINIMUM_650W_GPU_TDP = 140
CONDITIONS_BY_MODE: Dict[PurchaseMode, Dict[str, Condition]] = {
    "new": {role: "new" for role in PART_ROLES},
    "used": {role: "used" for role in PART_ROLES},
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
    score: Tuple[int, ...]

    @property
    def signature(self) -> Tuple[str, ...]:
        return tuple(part.component_id for part in self.parts)


@dataclass(frozen=True)
class ArtifactPaths:
    templates_json: Path
    reference_prices_csv: Path
    recommendation_ids: Path
    audit_json: Path
    review_markdown: Path


def generate_office_templates() -> List[BuildTemplateInput]:
    catalog = _load_catalog()
    templates = [
        template
        for budget in LOW_BUDGET_TIERS
        if (template := _clone_low_budget_template(budget)) is not None
    ]
    last_by_profile_mode: Dict[Tuple[Profile, PurchaseMode], BuildTemplateInput] = {}

    for budget in BUDGET_TIERS:
        for profile in ("general", "media", "cuda"):
            for purchase_mode in ("new", "used", "mixed"):
                candidate = _select_candidate(
                    budget,
                    profile,
                    purchase_mode,
                    catalog,
                )
                if candidate is None:
                    continue
                key = (profile, purchase_mode)
                previous = last_by_profile_mode.get(key)
                if previous is not None and _template_signature(previous) == candidate.signature:
                    previous.budget_max = budget + 999
                    continue
                if previous is not None:
                    previous.budget_max = budget - 1
                template = _build_template(
                    budget,
                    profile,
                    purchase_mode,
                    candidate,
                )
                templates.append(template)
                last_by_profile_mode[key] = template

    for template in last_by_profile_mode.values():
        template.budget_max = 30_000
    return templates


def write_office_artifacts(
    output_dir: Path,
    review_markdown_path: Optional[Path] = None,
) -> ArtifactPaths:
    output_dir = Path(output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)
    templates = generate_office_templates()
    paths = ArtifactPaths(
        templates_json=output_dir / "office-base-build-templates.json",
        reference_prices_csv=output_dir / "office-base-reference-prices.csv",
        recommendation_ids=output_dir / "office-base-recommendation-ids.txt",
        audit_json=output_dir / "office-base-audit.json",
        review_markdown=review_markdown_path or output_dir / "office-base-builds.md",
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
    _write_reference_prices(paths.reference_prices_csv, templates, _load_catalog())
    _write_recommendations(paths.recommendation_ids, templates)
    _write_audit(paths.audit_json, templates)
    paths.review_markdown.write_text(
        _render_markdown(templates),
        encoding="utf-8",
    )
    return paths


def _select_candidate(
    budget: int,
    profile: Profile,
    purchase_mode: PurchaseMode,
    catalog: Dict[str, PricedPart],
) -> Optional[Candidate]:
    conditions = CONDITIONS_BY_MODE[purchase_mode]
    ram_id = (
        "office-ddr5-16gb-7200-c36"
        if conditions["ram"] == "new"
        else "base-ddr5-16gb-6000-c30"
    )
    fixed_ids = {
        "ram": ram_id,
        "storage": "base-ssd-512gb-tlc",
        "cooler": "base-cooler-dual-tower-6-heatpipe",
        "case": "base-case-mid-tower",
    }
    gpu_ids = OFFICE_NVIDIA_GPU_IDS if profile == "cuda" else OFFICE_GPU_IDS
    candidates = []
    max_total = budget + (500 if budget < 10_000 else 800)

    for cpu_id in OFFICE_CPU_IDS:
        for motherboard_id in BOARD_IDS_BY_CPU[cpu_id]:
            for gpu_id in gpu_ids:
                cpu = catalog[cpu_id]
                motherboard = catalog[motherboard_id]
                gpu = catalog[gpu_id]
                if not gpu_brand_allowed_for_budget(gpu.name, budget):
                    continue
                psu = _smallest_psu(cpu, gpu, conditions["psu"], catalog)
                if psu is None:
                    continue
                selected = {
                    "cpu": cpu,
                    "motherboard": motherboard,
                    "gpu": gpu,
                    "psu": psu,
                    **{role: catalog[part_id] for role, part_id in fixed_ids.items()},
                }
                parts = []
                for role in PART_ROLES:
                    part = selected[role]
                    condition = conditions[role]
                    price = part.price(condition)
                    if price is None:
                        break
                    parts.append(_template_part(role, part, condition, price))
                if len(parts) != len(PART_ROLES):
                    continue
                total = sum(part.reference_price for part in parts)
                if total > max_total:
                    continue
                candidates.append(
                    Candidate(
                        parts=tuple(parts),
                        total=total,
                        score=_candidate_score(
                            profile,
                            cpu_id,
                            motherboard_id,
                            gpu,
                            total,
                        ),
                    )
                )
    return max(candidates, key=lambda candidate: candidate.score, default=None)


def _candidate_score(
    profile: Profile,
    cpu_id: str,
    motherboard_id: str,
    gpu: PricedPart,
    total: int,
) -> Tuple[int, ...]:
    cpu_score = CPU_SCORE[cpu_id]
    gpu_score = int(gpu.specs["perf_index"])
    if profile == "general":
        workload_score = cpu_score * 6 + gpu_score
    elif profile == "media":
        workload_score = cpu_score * 2 + MEDIA_GPU_SCORE.get(gpu.component_id, gpu_score) * 3
    else:
        workload_score = cpu_score * 2 + gpu_score * 6
    return (
        workload_score,
        cpu_score,
        gpu_score,
        -BOARD_SCORE[motherboard_id],
        total,
    )


def _smallest_psu(
    cpu: PricedPart,
    gpu: PricedPart,
    condition: Condition,
    catalog: Dict[str, PricedPart],
) -> Optional[PricedPart]:
    required = minimum_psu_watt_for_specs(
        int(cpu.specs["tdp"]),
        gpu.component_id,
        int(gpu.specs["tdp"]),
    )
    psus = sorted(
        (
            part
            for part in catalog.values()
            if part.category == "psu"
            and part.price(condition) is not None
            and int(part.specs.get("watt", 0)) >= required
        ),
        key=lambda part: int(part.specs["watt"]),
    )
    return psus[0] if psus else None


def _build_template(
    budget: int,
    profile: Profile,
    purchase_mode: PurchaseMode,
    candidate: Candidate,
) -> BuildTemplateInput:
    gpu = next(part for part in candidate.parts if part.role == "gpu")
    gpu_vendor = _gpu_vendor(gpu.component_id)
    purchase_label = PURCHASE_LABELS[purchase_mode]
    profile_label = PROFILE_LABELS[profile]
    return BuildTemplateInput(
        id=f"office-{budget}-{profile}-{purchase_mode}",
        title=f"{budget}元 {profile_label} {purchase_label}配置",
        budget_min=budget,
        budget_max=budget + 999,
        use_cases=["办公"],
        tags=[
            "均衡",
            purchase_label,
            GPU_VENDOR_LABELS[gpu_vendor],
            f"office-{profile}",
            *PROFILE_APPS[profile],
        ],
        components={part.role: part.component_id for part in candidate.parts},
        estimated_total=candidate.total,
        explanation=f"按{profile_label}负载选择 CPU 和显卡，固定16GB内存与512GB TLC固态。",
        details=BuildTemplateDetails(
            target_budget=budget,
            direction="balanced",
            purchase_mode=purchase_mode,
            gpu_vendor=gpu_vendor,
            parts=list(candidate.parts),
            suitable_user=f"主要使用{profile_label}软件的个人用户",
            price_date=PRICE_DATE,
        ),
    )


def _clone_low_budget_template(budget: int) -> Optional[BuildTemplateInput]:
    candidates = [
        template
        for template in read_build_template_inputs(LOW_TEMPLATE_PATH)
        if template.details and template.details.target_budget == budget
    ]
    if not candidates:
        return None
    source = max(candidates, key=_existing_overall_score).model_copy(deep=True)
    details = source.details
    assert details is not None
    details.direction = "balanced"
    details.suitable_user = "5000元以下优先复用现有综合性能最强方案的办公用户"
    purchase_label = PURCHASE_LABELS[details.purchase_mode]
    vendor_label = GPU_VENDOR_LABELS[details.gpu_vendor]
    source.id = f"office-{budget}-strongest-{details.purchase_mode}"
    source.title = f"{budget}元 综合性能优先办公配置"
    source.budget_min = budget
    source.budget_max = budget + 999
    source.use_cases = ["办公"]
    source.tags = [
        "均衡",
        purchase_label,
        vendor_label,
        "office-general",
        "office-media",
        "office-cuda",
        *sorted({app for apps in PROFILE_APPS.values() for app in apps}),
    ]
    source.explanation = "5000元以下直接复用同档位现有综合性能最强的审核配置。"
    return source


def _existing_overall_score(template: BuildTemplateInput) -> Tuple[int, int, int]:
    assert template.details is not None
    parts = {part.role: part for part in template.details.parts}
    cpu = int(parts["cpu"].specs.get("perf_index", 0))
    gpu = int(parts["gpu"].specs.get("perf_index", 0))
    return cpu + gpu, min(cpu, gpu), template.estimated_total or 0


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


def _template_signature(template: BuildTemplateInput) -> Tuple[str, ...]:
    assert template.details is not None
    return tuple(part.component_id for part in template.details.parts)


def _gpu_vendor(component_id: str) -> Literal["nvidia", "amd", "intel"]:
    if component_id.startswith("rtx-"):
        return "nvidia"
    if component_id.startswith("arc-"):
        return "intel"
    return "amd"


def _load_catalog() -> Dict[str, PricedPart]:
    component_map = {
        component.id: component
        for component in extract_catalog_components(SWIFT_CATALOG_PATH)
    }
    for path in (BASE_SUPPORT_PATH, OFFICE_SUPPORT_PATH):
        component_map.update(
            {component.id: component for component in read_catalog_components(path)}
        )

    parts: Dict[str, PricedPart] = {}
    for path, category, new_column in (
        (CPU_PRICE_PATH, "cpu", "new_tray_price"),
        (GPU_PRICE_PATH, "gpu", "new_price"),
        (MOTHERBOARD_PRICE_PATH, "motherboard", "new_price"),
    ):
        for row in _read_csv(path):
            component = component_map[row["target_id"]]
            parts[component.id] = PricedPart(
                component_id=component.id,
                category=category,
                name=(row["name"]),
                brand=component.brand,
                specs=dict(component.specs),
                used_price=_optional_int(row.get("used_price")),
                new_price=_optional_int(row.get(new_column)),
                used_source=path.name,
                new_source=path.name,
                price_date=PRICE_DATE if category == "gpu" else "2026-07-20",
            )
    for path in (BASE_SUPPORT_PATH, OFFICE_SUPPORT_PATH):
        for item in json.loads(path.read_text(encoding="utf-8")):
            parts[item["id"]] = PricedPart(
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
    return parts


def _write_reference_prices(
    path: Path,
    templates: Sequence[BuildTemplateInput],
    catalog: Dict[str, PricedPart],
) -> None:
    referenced_ids = {
        part.component_id
        for template in templates
        if template.details
        for part in template.details.parts
    }
    referenced_ids.update(OFFICE_CPU_IDS)
    referenced_ids.update(OFFICE_MOTHERBOARD_IDS)
    referenced_ids.update(OFFICE_GPU_IDS)
    referenced_ids.update(OFFICE_RAM_IDS)
    referenced_ids.update(VALUE_STORAGE_IDS)
    referenced_ids.update({"base-ssd-1tb-tlc", "base-ssd-2tb-tlc"})
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.writer(handle, lineterminator="\n")
        writer.writerow(
            [
                "target_id",
                "category",
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
        for component_id in sorted(referenced_ids):
            part = catalog[component_id]
            writer.writerow(
                [
                    part.component_id,
                    part.category,
                    part.name,
                    part.brand,
                    part.new_price or part.used_price,
                    part.used_price or "",
                    part.new_price or "",
                    1,
                    0,
                    "用户提供的办公硬件白名单与参考价格",
                ]
            )


def _write_recommendations(
    path: Path,
    templates: Sequence[BuildTemplateInput],
) -> None:
    component_ids = {
        part.component_id
        for template in templates
        if template.details
        for part in template.details.parts
    }
    component_ids.update(OFFICE_CPU_IDS)
    component_ids.update(OFFICE_MOTHERBOARD_IDS)
    component_ids.update(OFFICE_GPU_IDS)
    component_ids.update(OFFICE_RAM_IDS)
    component_ids.update(VALUE_STORAGE_IDS)
    path.write_text("\n".join(sorted(component_ids)) + "\n", encoding="utf-8")


def _write_audit(path: Path, templates: Sequence[BuildTemplateInput]) -> None:
    payload = {
        "price_date": PRICE_DATE,
        "template_count": len(templates),
        "low_budget_reused_tiers": list(LOW_BUDGET_TIERS),
        "coverage": {
            f"{profile}:{mode}": [
                [template.budget_min, template.budget_max]
                for template in templates
                if f"office-{profile}" in template.tags
                and template.details
                and template.details.purchase_mode == mode
            ]
            for profile in ("general", "media", "cuda")
            for mode in ("new", "used", "mixed")
        },
    }
    path.write_text(
        json.dumps(payload, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )


def _render_markdown(templates: Sequence[BuildTemplateInput]) -> str:
    lines = [
        "# 办公基底配置",
        "",
        "固定规则：16GB 内存、512GB TLC 固态；5000元以下复用现有综合性能最强方案。",
        "",
    ]
    for template in templates:
        details = template.details
        assert details is not None
        lines.extend(
            [
                f"## {template.title}",
                "",
                f"覆盖预算：¥{template.budget_min}–¥{template.budget_max}；总价：¥{template.estimated_total}",
                "",
                "| 配件 | 型号 | 状态 | 价格 |",
                "| --- | --- | --- | ---: |",
            ]
        )
        for part in details.parts:
            lines.append(
                f"| {part.role} | {part.name} | {part.condition} | ¥{part.reference_price} |"
            )
        lines.append("")
    return "\n".join(lines).rstrip() + "\n"


def _read_csv(path: Path) -> List[Dict[str, str]]:
    with path.open(encoding="utf-8", newline="") as handle:
        return list(csv.DictReader(handle))


def _optional_int(value: Optional[str]) -> Optional[int]:
    return int(value) if value else None


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output-dir", type=Path, default=DATA_DIR)
    parser.add_argument(
        "--review-markdown",
        type=Path,
        default=PROJECT_ROOT / "docs" / "office-base-builds.md",
    )
    args = parser.parse_args()
    paths = write_office_artifacts(args.output_dir, args.review_markdown)
    print(f"Generated {len(generate_office_templates())} office base templates.")
    print(paths.templates_json)


if __name__ == "__main__":
    main()
