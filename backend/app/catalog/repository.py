from typing import Iterable, List, Optional

from sqlalchemy import or_, select
from sqlalchemy.orm import Session

from app.catalog.models import HardwareComponent
from app.catalog.seed import CatalogComponent


def seed_hardware_components(
    session: Session,
    components: Iterable[CatalogComponent],
) -> int:
    count = 0
    for component in components:
        row = session.get(HardwareComponent, component.id)
        values = {
            "category": component.category,
            "name": component.name,
            "brand": component.brand,
            "detail_raw": component.detail_raw,
            "specs": component.specs,
            "is_recommended": False,
            "status": "active",
        }
        if row is None:
            session.add(HardwareComponent(id=component.id, **values))
        else:
            for key, value in values.items():
                setattr(row, key, value)
        count += 1
    session.commit()
    return count


def list_components(
    session: Session,
    category: Optional[str] = None,
    brand: Optional[str] = None,
    q: Optional[str] = None,
) -> List[HardwareComponent]:
    statement = select(HardwareComponent).order_by(
        HardwareComponent.category,
        HardwareComponent.brand,
        HardwareComponent.name,
    )
    if category:
        statement = statement.where(HardwareComponent.category == category)
    if brand:
        statement = statement.where(HardwareComponent.brand == brand)
    if q:
        pattern = f"%{q}%"
        statement = statement.where(
            or_(
                HardwareComponent.name.ilike(pattern),
                HardwareComponent.brand.ilike(pattern),
                HardwareComponent.detail_raw.ilike(pattern),
            )
        )
    return list(session.scalars(statement))


def list_compatible_motherboards(session: Session, cpu: str) -> List[HardwareComponent]:
    cpu_statement = select(HardwareComponent).where(
        HardwareComponent.category == "cpu",
        or_(HardwareComponent.id == cpu, HardwareComponent.name == cpu),
    )
    cpu_component = session.scalar(cpu_statement)
    if not cpu_component:
        return list_components(session, category="motherboard")

    socket = cpu_component.specs.get("socket")
    if not socket:
        return list_components(session, category="motherboard")

    statement = (
        select(HardwareComponent)
        .where(HardwareComponent.category == "motherboard")
        .order_by(HardwareComponent.brand, HardwareComponent.name)
    )
    return [
        motherboard
        for motherboard in session.scalars(statement)
        if motherboard.specs.get("socket") == socket
    ]
