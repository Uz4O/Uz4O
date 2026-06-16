from dataclasses import dataclass
from typing import Dict, List

from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.builds.models import BuildTemplate
from app.catalog.models import ComponentPrice, HardwareComponent


REQUIRED_RECOMMENDED_CATEGORIES = ["cpu", "gpu", "motherboard", "ram", "storage", "psu"]


@dataclass
class DataReadiness:
    ready: bool
    component_count: int
    price_count: int
    active_template_count: int
    recommended_counts: Dict[str, int]
    priced_recommended_counts: Dict[str, int]
    missing_recommended_categories: List[str]
    missing_priced_recommended_categories: List[str]


def build_data_readiness(session: Session) -> DataReadiness:
    component_count = _count(session, select(func.count()).select_from(HardwareComponent))
    price_count = _count(session, select(func.count()).select_from(ComponentPrice))
    active_template_count = _count(
        session,
        select(func.count()).select_from(BuildTemplate).where(BuildTemplate.status == "active"),
    )
    recommended_counts = {
        category: _count(
            session,
            select(func.count())
            .select_from(HardwareComponent)
            .where(
                HardwareComponent.category == category,
                HardwareComponent.status == "active",
                HardwareComponent.is_recommended.is_(True),
            ),
        )
        for category in REQUIRED_RECOMMENDED_CATEGORIES
    }
    missing_recommended_categories = [
        category
        for category in REQUIRED_RECOMMENDED_CATEGORIES
        if recommended_counts[category] == 0
    ]
    priced_recommended_counts = {
        category: _count(
            session,
            select(func.count())
            .select_from(HardwareComponent)
            .join(ComponentPrice, ComponentPrice.component_id == HardwareComponent.id)
            .where(
                HardwareComponent.category == category,
                HardwareComponent.status == "active",
                HardwareComponent.is_recommended.is_(True),
            ),
        )
        for category in REQUIRED_RECOMMENDED_CATEGORIES
    }
    missing_priced_recommended_categories = [
        category
        for category in REQUIRED_RECOMMENDED_CATEGORIES
        if priced_recommended_counts[category] == 0
    ]
    ready = (
        component_count > 0
        and price_count > 0
        and active_template_count > 0
        and not missing_recommended_categories
        and not missing_priced_recommended_categories
    )
    return DataReadiness(
        ready=ready,
        component_count=component_count,
        price_count=price_count,
        active_template_count=active_template_count,
        recommended_counts=recommended_counts,
        priced_recommended_counts=priced_recommended_counts,
        missing_recommended_categories=missing_recommended_categories,
        missing_priced_recommended_categories=missing_priced_recommended_categories,
    )


def _count(session: Session, statement) -> int:
    return int(session.scalar(statement) or 0)
