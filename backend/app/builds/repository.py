from typing import Any, Dict, Iterable, List, Optional

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.builds.models import BuildTemplate, SavedBuild
from app.builds.service import BuildTemplateInput
from app.catalog.models import ComponentPrice, HardwareComponent
from app.compat.engine import BuildSelection, evaluate_compatibility


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
        "gpu": "new",
        "ram": "used",
        "storage": "new",
        "psu": "new",
        "cooler": "used",
        "case": "used",
    },
}
DETAILED_DIRECTION_TAGS = {"fps": "FPS", "aaa": "3A", "balanced": "均衡"}
DETAILED_PURCHASE_TAGS = {"new": "全新", "used": "二手", "mixed": "混合采购"}


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
    if actual_conditions != DETAILED_CONDITIONS[details.purchase_mode]:
        errors.append(f"{template.id}: conditions do not match purchase mode")

    if details.target_budget != template.budget_min:
        errors.append(f"{template.id}: target budget does not match budget_min")

    required_tags = {
        DETAILED_DIRECTION_TAGS[details.direction],
        DETAILED_PURCHASE_TAGS[details.purchase_mode],
    }
    if not required_tags.issubset(set(template.tags)):
        errors.append(f"{template.id}: tags do not match structured details")

    detailed_total = sum(part.reference_price for part in details.parts)
    if template.estimated_total != detailed_total:
        errors.append(f"{template.id}: estimated_total does not match detailed prices")
    if detailed_total > details.target_budget + 200:
        errors.append(f"{template.id}: estimated_total exceeds target budget by more than 200")


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
) -> List[SavedBuild]:
    statement = (
        select(SavedBuild)
        .where(SavedBuild.account_id == account_id)
        .order_by(SavedBuild.created_at.desc(), SavedBuild.id.desc())
    )
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
