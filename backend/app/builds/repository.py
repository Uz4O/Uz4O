from typing import Any, Dict, Iterable, List, Optional

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.builds.models import BuildTemplate, SavedBuild
from app.builds.service import BuildTemplateInput
from app.catalog.models import ComponentPrice, HardwareComponent
from app.compat.engine import BuildSelection, evaluate_compatibility


REQUIRED_TEMPLATE_ROLES = {"cpu", "motherboard", "ram", "psu"}


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
        price.component_id
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
        if (
            template.estimated_total is not None
            and not template.budget_min <= template.estimated_total <= template.budget_max
        ):
            errors.append(f"{template.id}: estimated_total outside budget range")
        missing_roles = sorted(REQUIRED_TEMPLATE_ROLES - set(template.components))
        if missing_roles:
            errors.append(
                f"{template.id}: missing required roles: " + ", ".join(missing_roles)
            )
    if errors:
        raise ValueError("Invalid build templates; " + "; ".join(errors))


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
