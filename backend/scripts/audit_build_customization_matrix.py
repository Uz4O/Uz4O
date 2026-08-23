#!/usr/bin/env python3
import argparse
import json
import sys
from concurrent.futures import ProcessPoolExecutor, as_completed
from datetime import datetime, timezone
from pathlib import Path
from typing import Optional


BACKEND_ROOT = Path(__file__).resolve().parents[1]
PROJECT_ROOT = BACKEND_ROOT.parent
sys.path.insert(0, str(BACKEND_ROOT))

from app.builds.customization import (  # noqa: E402
    customization_candidates,
    customized_budget_floor,
    customized_budget_limit,
    deterministic_customization,
)
from app.builds.models import BuildTemplate  # noqa: E402
from app.builds.service import BuildRequest  # noqa: E402
from app.builds.templates import read_build_template_inputs  # noqa: E402
from app.catalog.models import ComponentPrice, HardwareComponent  # noqa: E402
from app.catalog.prices import read_approved_price_rows  # noqa: E402
from app.catalog.seed import read_catalog_components  # noqa: E402


DATA_ROOT = BACKEND_ROOT / "data"
TEMPLATE_PATHS = (
    DATA_ROOT / "low-budget-base-build-templates.json",
    DATA_ROOT / "high-budget-base-build-templates.json",
)
PRICE_PATHS = (
    DATA_ROOT / "high-budget-base-reference-prices.csv",
    DATA_ROOT / "low-budget-base-reference-prices.csv",
    DATA_ROOT / "office-base-reference-prices.csv",
)
RECOMMENDATION_PATHS = (
    DATA_ROOT / "low-budget-base-recommendation-ids.txt",
    DATA_ROOT / "high-budget-base-recommendation-ids.txt",
    DATA_ROOT / "office-base-recommendation-ids.txt",
)
COMPONENT_PATHS = (
    PROJECT_ROOT / "May" / "May" / "Models" / "HardwareCatalog.swift",
    DATA_ROOT / "base-build-support-components-2026-07-12.json",
)
PURCHASE_MODES = ("used", "new", "mixed")
DIRECTIONS = ("fps", "aaa", "balanced")
MEMORY_SIZES = ("16GB", "32GB")
STORAGE_SIZES = ("512GB", "1TB", "2TB")
STORAGE_CAPACITIES = {
    "512GB": {512},
    "1TB": {1000, 1024},
    "2TB": {2000, 2048},
}


TEMPLATES: list[BuildTemplate] = []
COMPONENTS_BY_ID: dict[str, HardwareComponent] = {}
PRICES_BY_ID: dict[str, ComponentPrice] = {}


def load_catalog() -> None:
    global TEMPLATES, COMPONENTS_BY_ID, PRICES_BY_ID
    recommendation_ids = {
        component_id
        for path in RECOMMENDATION_PATHS
        for component_id in path.read_text(encoding="utf-8").splitlines()
        if component_id
    }
    catalog_rows = {
        row.id: row
        for path in COMPONENT_PATHS
        for row in read_catalog_components(path)
    }
    COMPONENTS_BY_ID = {
        component_id: HardwareComponent(
            id=row.id,
            category=row.category,
            name=row.name,
            brand=row.brand,
            detail_raw=row.detail_raw,
            specs=dict(row.specs),
            is_recommended=component_id in recommendation_ids,
            status="active",
        )
        for component_id, row in catalog_rows.items()
    }
    approved_at = datetime.now(timezone.utc)
    price_rows = {
        row.component_id: row
        for path in PRICE_PATHS
        for row in read_approved_price_rows(path, approved_at="2026-08-22")
    }
    PRICES_BY_ID = {
        component_id: ComponentPrice(
            component_id=component_id,
            reference_price=row.reference_price,
            price_range_low=row.price_range_low,
            price_range_high=row.price_range_high,
            source=row.source,
            accepted_count=row.accepted_count,
            rejected_count=row.rejected_count,
            review_reasons=list(row.review_reasons),
            approved_at=approved_at,
        )
        for component_id, row in price_rows.items()
    }
    TEMPLATES = [
        BuildTemplate(
            id=row.id,
            title=row.title,
            budget_min=row.budget_min,
            budget_max=row.budget_max,
            use_cases=list(row.use_cases),
            tags=list(row.tags),
            components=dict(row.components),
            estimated_total=row.estimated_total,
            explanation=row.explanation,
            details=row.details.model_dump(mode="json") if row.details else {},
            status="active",
        )
        for path in TEMPLATE_PATHS
        for row in read_build_template_inputs(path)
    ]


def gpu_vendors(direction: str) -> tuple[Optional[str], ...]:
    if direction == "fps":
        return (None,)
    return ("nvidia", "amd")


def audit_chunk(task: tuple[list[int], str, str, str]) -> dict:
    budgets, direction, memory_size, storage_size = task
    failures = []
    checked = 0
    for budget in budgets:
        for purchase_mode in PURCHASE_MODES:
            option = None
            for gpu_vendor in gpu_vendors(direction):
                request = BuildRequest(
                    budget=budget,
                    use_case="游戏",
                    direction=direction,
                    memory_size=memory_size,
                    storage_size=storage_size,
                    preferences=[
                        {"fps": "FPS", "aaa": "3A", "balanced": "均衡"}[direction],
                        {"used": "二手", "new": "全新", "mixed": "混合采购"}[
                            purchase_mode
                        ],
                    ],
                    gpu_preference=(
                        {"nvidia": "NVIDIA", "amd": "AMD"}[gpu_vendor]
                        if gpu_vendor
                        else None
                    ),
                )
                candidates = customization_candidates(
                    request,
                    TEMPLATES,
                    COMPONENTS_BY_ID,
                    PRICES_BY_ID,
                    purchase_mode=purchase_mode,
                    gpu_vendor=gpu_vendor,
                )
                option = deterministic_customization(
                    request,
                    candidates,
                    COMPONENTS_BY_ID,
                    PRICES_BY_ID,
                )
                if option is not None:
                    break
            checked += 1
            failure = validate_option(
                budget,
                direction,
                memory_size,
                storage_size,
                purchase_mode,
                option,
            )
            if failure:
                failures.append(failure)
    return {"checked": checked, "failures": failures}


def validate_option(
    budget: int,
    direction: str,
    memory_size: str,
    storage_size: str,
    purchase_mode: str,
    option,
) -> Optional[dict]:
    key = {
        "budget": budget,
        "direction": direction,
        "memory_size": memory_size,
        "storage_size": storage_size,
        "purchase_mode": purchase_mode,
    }
    if option is None:
        return {**key, "reason": "no_option"}
    total = option.estimated_total or 0
    request = BuildRequest(budget=budget, use_case="游戏")
    if not customized_budget_floor(request) <= total <= customized_budget_limit(request):
        return {**key, "reason": "budget_window", "total": total}
    if option.details.purchase_mode != purchase_mode:
        return {**key, "reason": "purchase_mode_mismatch"}
    parts = {part.role: part for part in option.details.parts}
    if budget >= 6_000 and parts["cpu"].component_id in {"r5-5600", "r5-5600x"}:
        return {**key, "reason": "legacy_cpu_above_6000"}
    if parts["ram"].specs.get("capacity_gb") != int(memory_size.removesuffix("GB")):
        return {**key, "reason": "memory_capacity"}
    if parts["storage"].specs.get("capacity_gb") not in STORAGE_CAPACITIES[storage_size]:
        return {**key, "reason": "storage_capacity"}
    if parts["motherboard"].specs.get("socket") == "AM5" and (
        parts["ram"].specs.get("speed_mhz") != 6000
        or parts["ram"].specs.get("cas_latency") != 28
    ):
        return {**key, "reason": "am5_memory"}
    if parts["ram"].specs.get("type") == "DDR4" and (
        parts["ram"].specs.get("modules") != 2
        or parts["ram"].specs.get("speed_mhz") != 3200
    ):
        return {**key, "reason": "ddr4_dual_channel"}
    cpu_tdp = parts["cpu"].specs.get("tdp")
    if (
        parts["cpu"].component_id in {"r7-7800x3d", "r7-9800x3d", "r7-9850x3d"}
        or isinstance(cpu_tdp, int)
        and cpu_tdp >= 120
    ) and parts["cooler"].specs.get("towers", 0) < 2:
        return {**key, "reason": "hot_cpu_cooler"}
    return None


def chunks(values: list[int], size: int) -> list[list[int]]:
    return [values[index : index + size] for index in range(0, len(values), size)]


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--budget-min", type=int, default=4_500)
    parser.add_argument("--budget-max", type=int, default=30_000)
    parser.add_argument("--budget-step", type=int, default=100)
    parser.add_argument("--chunk-size", type=int, default=16)
    parser.add_argument("--workers", type=int, default=8)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    budgets = list(range(args.budget_min, args.budget_max + 1, args.budget_step))
    tasks = [
        (budget_chunk, direction, memory_size, storage_size)
        for direction in DIRECTIONS
        for memory_size in MEMORY_SIZES
        for storage_size in STORAGE_SIZES
        for budget_chunk in chunks(budgets, args.chunk_size)
    ]
    checked = 0
    failures = []
    with ProcessPoolExecutor(
        max_workers=args.workers,
        initializer=load_catalog,
    ) as executor:
        futures = [executor.submit(audit_chunk, task) for task in tasks]
        for index, future in enumerate(as_completed(futures), start=1):
            result = future.result()
            checked += result["checked"]
            failures.extend(result["failures"])
            if index % 12 == 0 or index == len(futures):
                print(
                    f"progress={index}/{len(futures)} checked={checked} failures={len(failures)}",
                    flush=True,
                )
    report = {
        "budget_min": args.budget_min,
        "budget_max": args.budget_max,
        "budget_step": args.budget_step,
        "checked_options": checked,
        "failed_options": len(failures),
        "failures": sorted(
            failures,
            key=lambda item: (
                item["budget"],
                item["direction"],
                item["memory_size"],
                item["storage_size"],
                item["purchase_mode"],
            ),
        ),
    }
    rendered = json.dumps(report, ensure_ascii=False, indent=2)
    if args.output:
        args.output.write_text(rendered + "\n", encoding="utf-8")
    print(
        f"checked_options={checked} failed_options={len(failures)}",
        flush=True,
    )
    if failures:
        print(json.dumps(report["failures"][:20], ensure_ascii=False, indent=2))
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
