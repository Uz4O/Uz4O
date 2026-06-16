from datetime import datetime, timezone
from typing import List, Optional
from uuid import uuid4

from sqlalchemy import Boolean, DateTime, ForeignKey, JSON, String
from sqlalchemy.orm import Mapped, mapped_column

import app.auth.models  # noqa: F401
from app.db import Base


def _uuid() -> str:
    return str(uuid4())


class OnboardingProfile(Base):
    __tablename__ = "onboarding_profile"

    account_id: Mapped[str] = mapped_column(
        String,
        ForeignKey("account.id", ondelete="CASCADE"),
        primary_key=True,
    )
    preference: Mapped[str] = mapped_column(String, default="balanced", nullable=False)
    home_feature_order: Mapped[List[str]] = mapped_column(JSON, default=list, nullable=False)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        onupdate=lambda: datetime.now(timezone.utc),
        nullable=False,
    )


class HardwareProfile(Base):
    __tablename__ = "hardware_profile"

    id: Mapped[str] = mapped_column(String, primary_key=True, default=_uuid)
    account_id: Mapped[str] = mapped_column(
        String,
        ForeignKey("account.id", ondelete="CASCADE"),
        index=True,
        nullable=False,
    )
    label: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    cpu: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    gpu: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    motherboard: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    memory: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    storage: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    power_supply: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    is_current_computer: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    was_skipped: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        onupdate=lambda: datetime.now(timezone.utc),
        nullable=False,
    )
