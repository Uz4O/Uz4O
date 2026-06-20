from datetime import datetime, timezone
from typing import Optional
from uuid import uuid4

from sqlalchemy import Boolean, DateTime, String, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column

from app.db import Base


def _uuid() -> str:
    return str(uuid4())


class Account(Base):
    __tablename__ = "account"

    id: Mapped[str] = mapped_column(String, primary_key=True, default=_uuid)
    phone: Mapped[Optional[str]] = mapped_column(String, unique=True, nullable=True)
    apple_sub: Mapped[Optional[str]] = mapped_column(String, unique=True, nullable=True)
    wechat_openid: Mapped[Optional[str]] = mapped_column(String, unique=True, nullable=True)
    nickname: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    is_moderator: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        nullable=False,
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        onupdate=lambda: datetime.now(timezone.utc),
        nullable=False,
    )


class AuthSmsCode(Base):
    __tablename__ = "auth_sms_code"
    __table_args__ = (UniqueConstraint("phone", "code_hash", name="uq_auth_sms_code_phone_hash"),)

    id: Mapped[str] = mapped_column(String, primary_key=True, default=_uuid)
    phone: Mapped[str] = mapped_column(String, index=True, nullable=False)
    code_hash: Mapped[str] = mapped_column(String, nullable=False)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    consumed_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        nullable=False,
    )
