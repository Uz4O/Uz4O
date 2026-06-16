from typing import List, Optional

from fastapi import APIRouter, Depends
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from app.auth.dependencies import get_current_account
from app.auth.models import Account
from app.db import get_session
from app.profile.models import HardwareProfile, OnboardingProfile
from app.profile.repository import (
    get_current_hardware_profile,
    get_onboarding_profile,
    upsert_current_hardware_profile,
    upsert_onboarding_profile,
)


class OnboardingProfileRequest(BaseModel):
    preference: str = Field(min_length=1, max_length=32)
    home_feature_order: List[str] = Field(default_factory=list, max_length=24)


class OnboardingProfileResponse(BaseModel):
    preference: str
    home_feature_order: List[str]


class HardwareProfileRequest(BaseModel):
    label: Optional[str] = Field(default=None, max_length=120)
    cpu: Optional[str] = Field(default=None, max_length=160)
    gpu: Optional[str] = Field(default=None, max_length=160)
    motherboard: Optional[str] = Field(default=None, max_length=160)
    memory: Optional[str] = Field(default=None, max_length=160)
    storage: Optional[str] = Field(default=None, max_length=160)
    power_supply: Optional[str] = Field(default=None, max_length=160)
    was_skipped: bool = False


class HardwareProfileResponse(BaseModel):
    label: Optional[str]
    cpu: Optional[str]
    gpu: Optional[str]
    motherboard: Optional[str]
    memory: Optional[str]
    storage: Optional[str]
    power_supply: Optional[str]
    was_skipped: bool


router = APIRouter(prefix="/v1/profile", tags=["profile"])


@router.get("/onboarding", response_model=OnboardingProfileResponse)
def read_onboarding_profile(
    account: Account = Depends(get_current_account),
    session: Session = Depends(get_session),
) -> OnboardingProfileResponse:
    profile = get_onboarding_profile(session, account.id)
    return _onboarding_response(profile)


@router.put("/onboarding", response_model=OnboardingProfileResponse)
def write_onboarding_profile(
    request: OnboardingProfileRequest,
    account: Account = Depends(get_current_account),
    session: Session = Depends(get_session),
) -> OnboardingProfileResponse:
    profile = upsert_onboarding_profile(
        session,
        account_id=account.id,
        preference=request.preference,
        home_feature_order=request.home_feature_order,
    )
    return _onboarding_response(profile)


@router.get("/hardware", response_model=HardwareProfileResponse)
def read_hardware_profile(
    account: Account = Depends(get_current_account),
    session: Session = Depends(get_session),
) -> HardwareProfileResponse:
    profile = get_current_hardware_profile(session, account.id)
    return _hardware_response(profile)


@router.put("/hardware", response_model=HardwareProfileResponse)
def write_hardware_profile(
    request: HardwareProfileRequest,
    account: Account = Depends(get_current_account),
    session: Session = Depends(get_session),
) -> HardwareProfileResponse:
    profile = upsert_current_hardware_profile(
        session,
        account_id=account.id,
        label=request.label,
        cpu=request.cpu,
        gpu=request.gpu,
        motherboard=request.motherboard,
        memory=request.memory,
        storage=request.storage,
        power_supply=request.power_supply,
        was_skipped=request.was_skipped,
    )
    return _hardware_response(profile)


def _onboarding_response(profile: OnboardingProfile) -> OnboardingProfileResponse:
    return OnboardingProfileResponse(
        preference=profile.preference,
        home_feature_order=list(profile.home_feature_order or []),
    )


def _hardware_response(profile: HardwareProfile) -> HardwareProfileResponse:
    return HardwareProfileResponse(
        label=profile.label,
        cpu=profile.cpu,
        gpu=profile.gpu,
        motherboard=profile.motherboard,
        memory=profile.memory,
        storage=profile.storage,
        power_supply=profile.power_supply,
        was_skipped=profile.was_skipped,
    )
