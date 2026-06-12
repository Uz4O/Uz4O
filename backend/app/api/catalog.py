from typing import Any, Dict, List, Optional

from fastapi import APIRouter, Depends
from pydantic import BaseModel
from sqlalchemy.orm import Session

from app.catalog.models import HardwareComponent
from app.catalog.repository import list_components, list_compatible_motherboards
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


router = APIRouter(prefix="/v1/catalog", tags=["catalog"])


@router.get("/components", response_model=List[HardwareComponentResponse])
def components(
    category: Optional[str] = None,
    brand: Optional[str] = None,
    q: Optional[str] = None,
    session: Session = Depends(get_session),
) -> List[HardwareComponent]:
    return list_components(session, category=category, brand=brand, q=q)


@router.get("/motherboards", response_model=List[HardwareComponentResponse])
def motherboards(
    cpu: str,
    session: Session = Depends(get_session),
) -> List[HardwareComponent]:
    return list_compatible_motherboards(session, cpu)
