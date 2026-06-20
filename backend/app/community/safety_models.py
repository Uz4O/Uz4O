from datetime import datetime, timezone
from typing import Optional
from uuid import uuid4

from sqlalchemy import CheckConstraint, DateTime, ForeignKey, String, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column

import app.auth.models  # noqa: F401
from app.db import Base


def _uuid() -> str:
    return str(uuid4())


class CommunityReport(Base):
    __tablename__ = "community_report"
    __table_args__ = (
        UniqueConstraint(
            "reporter_id",
            "target_type",
            "target_id",
            name="uq_community_report_reporter_target",
        ),
        CheckConstraint("target_type IN ('post', 'comment')", name="ck_report_target_type"),
    )

    id: Mapped[str] = mapped_column(String, primary_key=True, default=_uuid)
    reporter_id: Mapped[str] = mapped_column(
        String,
        ForeignKey("account.id", ondelete="CASCADE"),
        index=True,
        nullable=False,
    )
    target_type: Mapped[str] = mapped_column(String, nullable=False)
    target_id: Mapped[str] = mapped_column(String, index=True, nullable=False)
    reason: Mapped[str] = mapped_column(String, nullable=False)
    details: Mapped[str] = mapped_column(String, default="", nullable=False)
    status: Mapped[str] = mapped_column(String, default="open", index=True, nullable=False)
    resolution_note: Mapped[Optional[str]] = mapped_column(String, nullable=True)
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


class CommunityBlock(Base):
    __tablename__ = "community_block"
    __table_args__ = (
        UniqueConstraint("blocker_id", "blocked_id", name="uq_community_block_pair"),
        CheckConstraint("blocker_id != blocked_id", name="ck_community_block_not_self"),
    )

    id: Mapped[str] = mapped_column(String, primary_key=True, default=_uuid)
    blocker_id: Mapped[str] = mapped_column(
        String,
        ForeignKey("account.id", ondelete="CASCADE"),
        index=True,
        nullable=False,
    )
    blocked_id: Mapped[str] = mapped_column(
        String,
        ForeignKey("account.id", ondelete="CASCADE"),
        index=True,
        nullable=False,
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        nullable=False,
    )
