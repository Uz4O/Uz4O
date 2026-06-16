import json
from datetime import datetime
from typing import Any, Dict, List, Optional

from fastapi import APIRouter, Depends, HTTPException, Query, Response
from pydantic import BaseModel, Field, field_validator
from sqlalchemy.orm import Session

from app.auth.dependencies import get_current_account
from app.auth.models import Account
from app.builds.models import SavedBuild
from app.builds.repository import create_saved_build, delete_saved_build, list_saved_builds
from app.db import get_session


MAX_SAVED_BUILD_PLAN_BYTES = 20_000


class SavedBuildRequest(BaseModel):
    title: str = Field(min_length=1, max_length=120)
    plan: Dict[str, Any] = Field(default_factory=dict)
    budget: Optional[int] = Field(default=None, ge=0)
    total_price: Optional[int] = Field(default=None, ge=0)
    use_case: Optional[str] = Field(default=None, max_length=64)

    @field_validator("plan")
    @classmethod
    def plan_must_fit_database_budget(cls, value: Dict[str, Any]) -> Dict[str, Any]:
        size = len(json.dumps(value, ensure_ascii=False, separators=(",", ":")).encode("utf-8"))
        if size > MAX_SAVED_BUILD_PLAN_BYTES:
            raise ValueError("Saved build plan is too large")
        return value


class SavedBuildResponse(BaseModel):
    id: str
    title: str
    plan: Dict[str, Any]
    budget: Optional[int]
    total_price: Optional[int]
    use_case: Optional[str]
    created_at: datetime
    updated_at: datetime


router = APIRouter(prefix="/v1/builds", tags=["saved-builds"])


@router.get("", response_model=List[SavedBuildResponse])
def read_saved_builds(
    limit: int = Query(default=50, ge=1, le=100),
    offset: int = Query(default=0, ge=0),
    account: Account = Depends(get_current_account),
    session: Session = Depends(get_session),
) -> List[SavedBuildResponse]:
    return [
        _saved_build_response(build)
        for build in list_saved_builds(session, account.id, limit=limit, offset=offset)
    ]


@router.post("", response_model=SavedBuildResponse)
def write_saved_build(
    request: SavedBuildRequest,
    account: Account = Depends(get_current_account),
    session: Session = Depends(get_session),
) -> SavedBuildResponse:
    saved_build = create_saved_build(
        session,
        account_id=account.id,
        title=request.title,
        plan=request.plan,
        budget=request.budget,
        total_price=request.total_price,
        use_case=request.use_case,
    )
    return _saved_build_response(saved_build)


@router.delete("/{build_id}", status_code=204)
def remove_saved_build(
    build_id: str,
    account: Account = Depends(get_current_account),
    session: Session = Depends(get_session),
) -> Response:
    if not delete_saved_build(session, account.id, build_id):
        raise HTTPException(status_code=404, detail="Saved build not found")
    return Response(status_code=204)


def _saved_build_response(saved_build: SavedBuild) -> SavedBuildResponse:
    return SavedBuildResponse(
        id=saved_build.id,
        title=saved_build.title,
        plan=saved_build.plan,
        budget=saved_build.budget,
        total_price=saved_build.total_price,
        use_case=saved_build.use_case,
        created_at=saved_build.created_at,
        updated_at=saved_build.updated_at,
    )
