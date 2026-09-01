from typing import Any, Dict, Iterable, List, Optional

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.builds.models import BuildTemplate, SavedBuild
from app.builds.service import BuildTemplateInput
from app.catalog.models import ComponentPrice, HardwareComponent
from app.compat.engine import BuildSelection, evaluate_compatibility
from app.catalog.rule_specs import (
    GPU_MIN_CPU_PERFORMANCE,
    is_cpu_gpu_pairing_allowed,
    minimum_psu_watt_for_specs,
    psu_supports_gpu_power_connector,
)


REQUIRED_TEMPLATE_ROLES = {"cpu", "motherboard", "ram", "psu"}
HIGH_BUDGET_TEMPLATE_ROLES = {
    "cpu",
    "motherboard",
    "gpu",
    "ram",
    "storage",
    "psu",
    "cooler",
    "case",
}
DETAILED_CONDITIONS = {
    "new": {role: "new" for role in HIGH_BUDGET_TEMPLATE_ROLES},
    "used": {role: "used" for role in HIGH_BUDGET_TEMPLATE_ROLES},
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
DETAILED_DIRECTION_TAGS = {"fps": "FPS", "aaa": "3A", "balanced": "均衡"}
DETAILED_PURCHASE_TAGS = {"new": "全新", "used": "二手", "mixed": "混合采购"}
DETAILED_GPU_VENDOR_TAGS = {"nvidia": "NVIDIA", "amd": "AMD", "intel": "Intel"}
LEGACY_AM4_CPU_IDS = {"r5-5600", "r5-5600x"}
LEGACY_AM4_COOLER_ID = "thermalright-ax120-se"
COOLER_BY_CPU_ID = {
    "r5-5600": LEGACY_AM4_COOLER_ID,
    "r5-5600x": LEGACY_AM4_COOLER_ID,
    "r5-7500f": "valkyrie-cq125",
    "r5-9600x": "base-cooler-6-heatpipe",
    "r7-9700x": "base-cooler-6-heatpipe",
    "i5-12600kf": "base-cooler-6-heatpipe",
    "i5-14600kf": "base-cooler-dual-tower-6-heatpipe",
    "i5-14400f": "base-cooler-dual-tower-6-heatpipe",
    "i7-13700kf": "base-cooler-dual-tower-6-heatpipe",
    "u5-245k": "base-cooler-dual-tower-6-heatpipe",
    "u5-250-plus": "base-cooler-dual-tower-6-heatpipe",
    "u7-265k": "base-cooler-dual-tower-6-heatpipe",
    "u7-270-plus": "base-cooler-dual-tower-6-heatpipe",
    "r7-7800x3d": "base-cooler-dual-tower-6-heatpipe",
    "r7-9800x3d": "base-cooler-dual-tower-6-heatpipe",
    "r7-9850x3d": "base-cooler-dual-tower-6-heatpipe",
}
MAX_DETAILED_TEMPLATE_BUDGET_SHORTFALL = 200
MAX_DETAILED_TEMPLATE_BUDGET_OVERAGE = 300


def list_build_templates(session: Session) -> List[BuildTemplate]:
    statement = select(BuildTemplate).where(BuildTemplate.status == "active")
    return list(session.scalars(statement))


def upsert_build_templates(
    session: Session,
    templates: Iterable[BuildTemplateInput],
) -> int:
    templates = list(templates)
    _validate_build_templates(session, templates)
    count = 0
    for template in templates:
        row = session.get(BuildTemplate, template.id)
        values = {
            "title": template.title,
            "budget_min": template.budget_min,
            "budget_max": template.budget_max,
            "use_cases": template.use_cases,
            "tags": template.tags,
            "components": template.components,
            "estimated_total": template.estimated_total,
            "explanation": template.explanation,
            "status": "active",
        }
        if template.details is not None:
            values["details"] = template.details.model_dump(mode="json")
        elif row is None:
            values["details"] = {}
        if row is None:
            session.add(BuildTemplate(id=template.id, **values))
        else:
            for key, value in values.items():
                setattr(row, key, value)
        count += 1
    session.commit()
    return count


def _validate_build_templates(
    session: Session,
    templates: List[BuildTemplateInput],
) -> None:
    _validate_build_template_shapes(templates)
    component_ids = sorted(
        {
            component_id
            for template in templates
            for component_id in template.components.values()
            if component_id
        }
    )
    if not component_ids:
        return

    components = {
        component.id: component
        for component in session.scalars(
            select(HardwareComponent).where(HardwareComponent.id.in_(component_ids))
        )
    }
    prices = {
        price.component_id: price
        for price in session.scalars(
            select(ComponentPrice).where(ComponentPrice.component_id.in_(component_ids))
        )
    }

    unknown_ids = [component_id for component_id in component_ids if component_id not in components]
    not_recommended_ids = [
        component_id
        for component_id in component_ids
        if component_id in components
        and (
            not components[component_id].is_recommended
            or components[component_id].status != "active"
        )
    ]
    missing_price_ids = [
        component_id
        for component_id in component_ids
        if component_id in components and component_id not in prices
    ]
    errors = []
    if unknown_ids:
        errors.append("unknown component ids: " + ", ".join(unknown_ids))
    if not_recommended_ids:
        errors.append("not recommended component ids: " + ", ".join(not_recommended_ids))
    if missing_price_ids:
        errors.append("missing price component ids: " + ", ".join(missing_price_ids))
    if errors:
        raise ValueError("Invalid build templates; " + "; ".join(errors))

    detailed_errors = _validate_detailed_template_catalog_data(
        templates,
        components,
        prices,
    )
    if detailed_errors:
        raise ValueError("Invalid build templates; " + "; ".join(detailed_errors))

    incompatible_templates = []
    for template in templates:
        compatibility = evaluate_compatibility(
            BuildSelection(components=template.components),
            components,
        )
        if not compatibility.compatible:
            failed_codes = [
                finding.code
                for finding in compatibility.findings
                if finding.level == "error"
            ]
            incompatible_templates.append(
                f"{template.id} ({', '.join(sorted(set(failed_codes)))})"
            )
    if incompatible_templates:
        raise ValueError(
            "Invalid build templates; incompatible build template: "
            + "; ".join(incompatible_templates)
        )


def _validate_build_template_shapes(templates: List[BuildTemplateInput]) -> None:
    errors = []
    for template in templates:
        if template.budget_min > template.budget_max:
            errors.append(f"{template.id}: budget_min greater than budget_max")
        if template.details is None:
            if (
                template.estimated_total is not None
                and not template.budget_min <= template.estimated_total <= template.budget_max
            ):
                errors.append(f"{template.id}: estimated_total outside budget range")
        else:
            _validate_detailed_template(template, errors)
        missing_roles = sorted(REQUIRED_TEMPLATE_ROLES - set(template.components))
        if missing_roles:
            errors.append(
                f"{template.id}: missing required roles: " + ", ".join(missing_roles)
            )
    if errors:
        raise ValueError("Invalid build templates; " + "; ".join(errors))


def _validate_detailed_template(template: BuildTemplateInput, errors: List[str]) -> None:
    details = template.details
    if details is None:
        return

    component_roles = set(template.components)
    if component_roles != HIGH_BUDGET_TEMPLATE_ROLES:
        errors.append(f"{template.id}: detailed template must contain all eight roles")

    parts_by_role = {part.role: part for part in details.parts}
    if set(parts_by_role) != HIGH_BUDGET_TEMPLATE_ROLES or len(details.parts) != 8:
        errors.append(f"{template.id}: details must contain eight unique parts")
        return

    expected_components = {
        role: part.component_id for role, part in parts_by_role.items()
    }
    if template.components != expected_components:
        errors.append(f"{template.id}: components do not match detailed parts")

    actual_conditions = {
        role: part.condition for role, part in parts_by_role.items()
    }
    expected_conditions = dict(DETAILED_CONDITIONS[details.purchase_mode])
    expected_cooler = COOLER_BY_CPU_ID.get(parts_by_role["cpu"].component_id)
    if expected_cooler is not None:
        if parts_by_role["cooler"].component_id != expected_cooler:
            errors.append(f"{template.id}: CPU must use its assigned cooler")
    if actual_conditions != expected_conditions:
        errors.append(f"{template.id}: conditions do not match purchase mode")

    if details.target_budget != template.budget_min:
        errors.append(f"{template.id}: target budget does not match budget_min")

    required_tags = {
        DETAILED_DIRECTION_TAGS[details.direction],
        DETAILED_PURCHASE_TAGS[details.purchase_mode],
        DETAILED_GPU_VENDOR_TAGS[details.gpu_vendor],
    }
    if not required_tags.issubset(set(template.tags)):
        errors.append(f"{template.id}: tags do not match structured details")

    detailed_total = sum(part.reference_price for part in details.parts)
    if template.estimated_total != detailed_total:
        errors.append(f"{template.id}: estimated_total does not match detailed prices")
    is_office_template = "办公" in template.use_cases
    max_shortfall = 550 if is_office_template else MAX_DETAILED_TEMPLATE_BUDGET_SHORTFALL
    if detailed_total < details.target_budget - max_shortfall:
        errors.append(
            f"{template.id}: estimated_total is more than {max_shortfall} below target budget"
        )
    max_overage = (
        600
        if details.target_budget == 3_000
        else 500
        if details.target_budget < 10_000
        else
        800
    )
    if detailed_total > details.target_budget + max_overage:
        errors.append(f"{template.id}: estimated_total exceeds allowed budget overage")

    ram_latency = parts_by_role["ram"].specs.get("cas_latency")
    ram_capacity = parts_by_role["ram"].specs.get("capacity_gb")
    expected_ram_capacity = (
        16 if is_office_template else 32 if details.target_budget >= 18_000 else 16
    )
    if ram_capacity != expected_ram_capacity:
        errors.append(
            f"{template.id}: expected {expected_ram_capacity}GB base RAM capacity"
        )
    if (
        not is_office_template
        and details.target_budget >= 10_000
        and (type(ram_latency) is not int or ram_latency > 32)
    ):
        errors.append(f"{template.id}: 10000+ templates require DDR5 C32 or better")

    gpu_id = parts_by_role["gpu"].component_id
    expected_gpu_vendor = (
        "nvidia"
        if gpu_id.startswith(("gtx-", "rtx-"))
        else "intel"
        if gpu_id.startswith("arc-")
        else "amd"
    )
    if details.gpu_vendor != expected_gpu_vendor:
        errors.append(f"{template.id}: gpu_vendor does not match gpu component")
    cpu_id = parts_by_role["cpu"].component_id
    if (
        not is_office_template
        and not is_cpu_gpu_pairing_allowed(cpu_id, gpu_id)
    ):
        errors.append(
            f"{template.id}: {cpu_id} and {gpu_id} reach a high-CPU/low-GPU "
            "or low-CPU/high-GPU imbalance"
        )
    minimum_gpu_cpu_performance = GPU_MIN_CPU_PERFORMANCE.get(gpu_id)
    cpu_performance = parts_by_role["cpu"].specs.get("perf_index")
    if (
        minimum_gpu_cpu_performance is not None
        and (
            type(cpu_performance) is not int
            or cpu_performance < minimum_gpu_cpu_performance
        )
    ):
        errors.append(
            f"{template.id}: {gpu_id} does not meet its minimum CPU performance floor"
        )
    cpu_tdp = parts_by_role["cpu"].specs.get("tdp")
    gpu_tdp = parts_by_role["gpu"].specs.get("tdp")
    psu_watt = parts_by_role["psu"].specs.get("watt")
    if all(type(value) is int for value in (cpu_tdp, gpu_tdp, psu_watt)):
        required_psu = minimum_psu_watt_for_specs(cpu_tdp, gpu_id, gpu_tdp)
        if psu_watt < required_psu:
            errors.append(
                f"{template.id}: PSU requires at least {required_psu}W"
            )
    if not psu_supports_gpu_power_connector(
        gpu_id,
        parts_by_role["psu"].specs,
    ):
        errors.append(
            f"{template.id}: PSU lacks a complete native 600W 12V-2x6 power path"
        )


def _validate_detailed_template_catalog_data(
    templates: List[BuildTemplateInput],
    components: Dict[str, HardwareComponent],
    prices: Dict[str, ComponentPrice],
) -> List[str]:
    errors = []
    for template in templates:
        if template.details is None:
            continue
        for part in template.details.parts:
            component = components.get(part.component_id)
            if component and component.category != part.role:
                errors.append(
                    f"{template.id}: {part.component_id} category does not match {part.role} role"
                )
            if component and part.role in {"cpu", "gpu"}:
                for field in ("perf_index", "tdp"):
                    part_value = part.specs.get(field)
                    catalog_value = component.specs.get(field)
                    if (
                        type(part_value) is not int
                        or type(catalog_value) is not int
                        or part_value != catalog_value
                    ):
                        errors.append(
                            f"{template.id}: {part.component_id} {field} does not match "
                            f"hardware catalog ({part_value!r} != {catalog_value!r})"
                        )
            price = prices.get(part.component_id)
            if price is None:
                continue
            expected_price = (
                price.price_range_high
                if part.condition == "new"
                else price.price_range_low
            )
            if expected_price is None or part.reference_price != expected_price:
                errors.append(
                    f"{template.id}: {part.component_id} reference price does not match "
                    f"{part.condition} price"
                )
    return errors


def create_saved_build(
    session: Session,
    account_id: str,
    title: str,
    plan: Dict[str, Any],
    budget: Optional[int],
    total_price: Optional[int],
    use_case: Optional[str],
) -> SavedBuild:
    saved_build = SavedBuild(
        account_id=account_id,
        title=title,
        plan=plan,
        budget=budget,
        total_price=total_price,
        use_case=use_case,
    )
    session.add(saved_build)
    session.commit()
    return saved_build


def list_saved_builds(
    session: Session,
    account_id: str,
    limit: Optional[int] = None,
    offset: int = 0,
    use_case: Optional[str] = None,
) -> List[SavedBuild]:
    statement = (
        select(SavedBuild)
        .where(SavedBuild.account_id == account_id)
        .order_by(SavedBuild.created_at.desc(), SavedBuild.id.desc())
    )
    if use_case is not None:
        statement = statement.where(SavedBuild.use_case == use_case)
    if offset:
        statement = statement.offset(offset)
    if limit is not None:
        statement = statement.limit(limit)
    return list(session.scalars(statement))


def get_saved_build(session: Session, account_id: str, build_id: str) -> Optional[SavedBuild]:
    statement = select(SavedBuild).where(
        SavedBuild.id == build_id,
        SavedBuild.account_id == account_id,
    )
    return session.scalar(statement)


def delete_saved_build(session: Session, account_id: str, build_id: str) -> bool:
    saved_build = get_saved_build(session, account_id, build_id)
    if saved_build is None:
        return False
    session.delete(saved_build)
    session.commit()
    return True
