from datetime import datetime
from typing import Any, Dict, List, Optional

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel
from sqlalchemy.orm import Session

from app.catalog.models import ComponentPrice, HardwareComponent
from app.catalog.readiness import DataReadiness, build_data_readiness
from app.catalog.repository import (
    get_component_price,
    list_component_prices,
    list_components,
    list_compatible_motherboards,
)
from app.db import get_session


class HardwareComponentResponse(BaseModel):
    id: str
    category: str
    name: str
    brand: str
    detail_raw: str
    specs: Dict[str, Any]
    is_recommended: bool
    status: str


class ComponentPriceResponse(BaseModel):
    component_id: str
    reference_price: int
    price_range_low: Optional[int]
    price_range_high: Optional[int]
    source: str
    accepted_count: int
    rejected_count: int
    review_reasons: List[str]
    approved_at: datetime


class ComponentPriceDetailResponse(ComponentPriceResponse):
    pass


class CatalogReadinessResponse(BaseModel):
    ready: bool
    component_count: int
    price_count: int
    active_template_count: int
    recommended_counts: Dict[str, int]
    priced_recommended_counts: Dict[str, int]
    missing_recommended_categories: List[str]
    missing_priced_recommended_categories: List[str]


router = APIRouter(prefix="/v1/catalog", tags=["catalog"])


@router.get("/components", response_model=List[HardwareComponentResponse])
def components(
    category: Optional[str] = None,
    brand: Optional[str] = None,
    q: Optional[str] = None,
    limit: int = Query(default=100, ge=1, le=500),
    offset: int = Query(default=0, ge=0),
    session: Session = Depends(get_session),
) -> List[HardwareComponent]:
    return list_components(session, category=category, brand=brand, q=q, limit=limit, offset=offset)


@router.get("/motherboards", response_model=List[HardwareComponentResponse])
def motherboards(
    cpu: str,
    session: Session = Depends(get_session),
) -> List[HardwareComponent]:
    return list_compatible_motherboards(session, cpu)


@router.get("/prices", response_model=List[ComponentPriceResponse])
def prices(
    limit: int = Query(default=100, ge=1, le=500),
    offset: int = Query(default=0, ge=0),
    session: Session = Depends(get_session),
) -> List[ComponentPrice]:
    return list_component_prices(session, limit=limit, offset=offset)


@router.get("/readiness", response_model=CatalogReadinessResponse)
def readiness(
    session: Session = Depends(get_session),
) -> DataReadiness:
    return build_data_readiness(session)


@router.get("/components/{component_id}/price", response_model=ComponentPriceDetailResponse)
def component_price(
    component_id: str,
    session: Session = Depends(get_session),
) -> ComponentPrice:
    price = get_component_price(session, component_id)
    if price is None:
        raise HTTPException(status_code=404, detail="Component price not found")
    return price
