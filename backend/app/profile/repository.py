from typing import List, Optional

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.profile.models import HardwareProfile, OnboardingProfile


def get_onboarding_profile(session: Session, account_id: str) -> OnboardingProfile:
    profile = session.get(OnboardingProfile, account_id)
    if profile is not None:
        return profile
    return OnboardingProfile(account_id=account_id, preference="balanced", home_feature_order=[])


def upsert_onboarding_profile(
    session: Session,
    account_id: str,
    preference: str,
    home_feature_order: List[str],
) -> OnboardingProfile:
    profile = session.get(OnboardingProfile, account_id)
    if profile is None:
        profile = OnboardingProfile(account_id=account_id)
        session.add(profile)
    profile.preference = preference
    profile.home_feature_order = home_feature_order
    session.commit()
    return profile


def get_current_hardware_profile(session: Session, account_id: str) -> HardwareProfile:
    profile = session.scalar(
        select(HardwareProfile).where(
            HardwareProfile.account_id == account_id,
            HardwareProfile.is_current_computer.is_(True),
        )
    )
    if profile is not None:
        return profile
    return HardwareProfile(account_id=account_id, is_current_computer=True, was_skipped=False)


def upsert_current_hardware_profile(
    session: Session,
    account_id: str,
    label: Optional[str],
    cpu: Optional[str],
    gpu: Optional[str],
    motherboard: Optional[str],
    memory: Optional[str],
    storage: Optional[str],
    power_supply: Optional[str],
    was_skipped: bool,
) -> HardwareProfile:
    profile = session.scalar(
        select(HardwareProfile).where(
            HardwareProfile.account_id == account_id,
            HardwareProfile.is_current_computer.is_(True),
        )
    )
    if profile is None:
        profile = HardwareProfile(account_id=account_id, is_current_computer=True)
        session.add(profile)
    profile.label = label
    profile.cpu = cpu
    profile.gpu = gpu
    profile.motherboard = motherboard
    profile.memory = memory
    profile.storage = storage
    profile.power_supply = power_supply
    profile.was_skipped = was_skipped
    session.commit()
    return profile
