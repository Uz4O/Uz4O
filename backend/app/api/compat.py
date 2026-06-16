from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.catalog.repository import get_components_by_ids
from app.compat.engine import (
    BuildSelection,
    CompatibilityResult,
    CompatibilityRulesResponse,
    compatibility_rules_response,
    evaluate_compatibility,
)
from app.db import get_session


router = APIRouter(prefix="/v1/compat", tags=["compatibility"])


@router.get("/rules", response_model=CompatibilityRulesResponse)
def compatibility_rules() -> CompatibilityRulesResponse:
    return compatibility_rules_response()


@router.post("/check", response_model=CompatibilityResult)
def check_compatibility(
    selection: BuildSelection,
    session: Session = Depends(get_session),
) -> CompatibilityResult:
    components = get_components_by_ids(session, selection.selected_ids())
    return evaluate_compatibility(selection, {component.id: component for component in components})
