from dataclasses import dataclass
from typing import Iterable, List, Optional

from sqlalchemy import or_, select
from sqlalchemy.orm import Session

from app.catalog.models import ComponentPrice, CPUWhitelistPrice, GPUWhitelistPrice, HardwareComponent, MotherboardWhitelistPrice
from app.catalog.prices import ApprovedPriceRow, CPUWhitelistPriceRow, GPUWhitelistPriceRow, MotherboardWhitelistPriceRow
from app.catalog.seed import CatalogComponent


@dataclass
class RecommendationUpdateResult:
    updated_count: int
    missing_ids: List[str]


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
            "status": "active",
        }
        if row is None:
            session.add(HardwareComponent(id=component.id, is_recommended=False, **values))
        else:
            for key, value in values.items():
                setattr(row, key, value)
        count += 1
    session.commit()
    return count


def update_recommended_components(
    session: Session,
    component_ids: Iterable[str],
    replace: bool = False,
) -> RecommendationUpdateResult:
    ids = _unique_ids(component_ids)
    if replace:
        for component in session.scalars(select(HardwareComponent).where(HardwareComponent.is_recommended.is_(True))):
            component.is_recommended = False

    updated_count = 0
    missing_ids: List[str] = []
    for component_id in ids:
        component = session.get(HardwareComponent, component_id)
        if component is None:
            missing_ids.append(component_id)
            continue
        if component.status == "active":
            component.is_recommended = True
            updated_count += 1
    session.commit()
    return RecommendationUpdateResult(updated_count=updated_count, missing_ids=missing_ids)


def seed_component_prices(
    session: Session,
    prices: Iterable[ApprovedPriceRow],
) -> int:
    count = 0
    for price in prices:
        row = session.get(ComponentPrice, price.component_id)
        values = {
            "reference_price": price.reference_price,
            "price_range_low": price.price_range_low,
            "price_range_high": price.price_range_high,
            "source": price.source,
            "accepted_count": price.accepted_count,
            "rejected_count": price.rejected_count,
            "review_reasons": price.review_reasons,
            "approved_at": price.approved_at,
        }
        if row is not None:
            for key in ("price_range_low", "price_range_high"):
                if values[key] is None:
                    values[key] = getattr(row, key)
        if row is None:
            session.add(ComponentPrice(component_id=price.component_id, **values))
        else:
            for key, value in values.items():
                setattr(row, key, value)
        count += 1
    session.commit()
    return count


def seed_gpu_whitelist_prices(
    session: Session,
    prices: Iterable[GPUWhitelistPriceRow],
) -> int:
    count = 0
    for price in prices:
        row = session.get(GPUWhitelistPrice, price.component_id)
        values = {
            "name": price.name,
            "used_price": price.used_price,
            "new_price": price.new_price,
            "source": price.source,
            "approved_at": price.approved_at,
        }
        if row is None:
            session.add(GPUWhitelistPrice(component_id=price.component_id, **values))
        else:
            for key, value in values.items():
                setattr(row, key, value)
        count += 1
    session.commit()
    return count


def seed_motherboard_whitelist_prices(
    session: Session,
    prices: Iterable[MotherboardWhitelistPriceRow],
) -> int:
    count = 0
    for price in prices:
        row = session.get(MotherboardWhitelistPrice, price.component_id)
        values = {
            "name": price.name,
            "platform": price.platform,
            "used_price": price.used_price,
            "new_price": price.new_price,
            "status": price.status,
            "source": price.source,
            "approved_at": price.approved_at,
        }
        if row is None:
            session.add(MotherboardWhitelistPrice(component_id=price.component_id, **values))
        else:
            for key, value in values.items():
                setattr(row, key, value)
        count += 1
    session.commit()
    return count


def seed_cpu_whitelist_prices(
    session: Session,
    prices: Iterable[CPUWhitelistPriceRow],
) -> int:
    count = 0
    for price in prices:
        row = session.get(CPUWhitelistPrice, price.component_id)
        values = {
            "name": price.name,
            "used_price": price.used_price,
            "new_tray_price": price.new_tray_price,
            "source": price.source,
            "approved_at": price.approved_at,
        }
        if row is None:
            session.add(CPUWhitelistPrice(component_id=price.component_id, **values))
        else:
            for key, value in values.items():
                setattr(row, key, value)
        count += 1
    session.commit()
    return count


def list_component_prices(
    session: Session,
    limit: Optional[int] = None,
    offset: int = 0,
) -> List[ComponentPrice]:
    statement = select(ComponentPrice).order_by(ComponentPrice.reference_price.desc(), ComponentPrice.component_id)
    if offset:
        statement = statement.offset(offset)
    if limit is not None:
        statement = statement.limit(limit)
    return list(session.scalars(statement))


def get_component_price(session: Session, component_id: str) -> Optional[ComponentPrice]:
    return session.get(ComponentPrice, component_id)


def get_components_by_ids(session: Session, component_ids: Iterable[str]) -> List[HardwareComponent]:
    ids = [component_id for component_id in component_ids if component_id]
    if not ids:
        return []
    statement = select(HardwareComponent).where(HardwareComponent.id.in_(ids))
    return list(session.scalars(statement))


def list_components(
    session: Session,
    category: Optional[str] = None,
    brand: Optional[str] = None,
    q: Optional[str] = None,
    limit: Optional[int] = None,
    offset: int = 0,
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
    if offset:
        statement = statement.offset(offset)
    if limit is not None:
        statement = statement.limit(limit)
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


def _unique_ids(component_ids: Iterable[str]) -> List[str]:
    seen = set()
    ids: List[str] = []
    for component_id in component_ids:
        normalized = component_id.strip()
        if not normalized or normalized in seen:
            continue
        seen.add(normalized)
        ids.append(normalized)
    return ids
