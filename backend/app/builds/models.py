from datetime import datetime, timezone
from typing import Any, Dict, List, Optional
from uuid import uuid4

from sqlalchemy import DateTime, ForeignKey, Integer, JSON, String, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column

import app.auth.models  # noqa: F401
from app.db import Base


def _uuid() -> str:
    return str(uuid4())


class BuildTemplate(Base):
    __tablename__ = "build_template"

    id: Mapped[str] = mapped_column(String, primary_key=True)
    title: Mapped[str] = mapped_column(String, nullable=False)
    budget_min: Mapped[int] = mapped_column(Integer, nullable=False)
    budget_max: Mapped[int] = mapped_column(Integer, nullable=False)
    use_cases: Mapped[List[str]] = mapped_column(JSON, default=list, nullable=False)
    tags: Mapped[List[str]] = mapped_column(JSON, default=list, nullable=False)
    components: Mapped[Dict[str, str]] = mapped_column(JSON, default=dict, nullable=False)
    estimated_total: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    explanation: Mapped[str] = mapped_column(String, nullable=False)
    details: Mapped[Dict[str, Any]] = mapped_column(JSON, default=dict, nullable=False)
    status: Mapped[str] = mapped_column(String, default="active", nullable=False)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        onupdate=lambda: datetime.now(timezone.utc),
        nullable=False,
    )


class BuildSelectionCache(Base):
    __tablename__ = "build_selection_cache"
    __table_args__ = (
        UniqueConstraint(
            "request_hash",
            "option_key",
            name="uq_build_selection_cache_request_option",
        ),
    )

    id: Mapped[str] = mapped_column(String, primary_key=True, default=_uuid)
    request_hash: Mapped[str] = mapped_column(String(64), index=True, nullable=False)
    option_key: Mapped[str] = mapped_column(String(32), nullable=False)
    request_payload: Mapped[Dict[str, Any]] = mapped_column(JSON, nullable=False)
    response_payload: Mapped[Dict[str, Any]] = mapped_column(JSON, nullable=False)
    cache_version: Mapped[str] = mapped_column(String(64), nullable=False)
    selected_count: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    last_selected_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
    )
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


class SavedBuild(Base):
    __tablename__ = "saved_build"

    id: Mapped[str] = mapped_column(String, primary_key=True, default=_uuid)
    account_id: Mapped[str] = mapped_column(
        String,
        ForeignKey("account.id", ondelete="CASCADE"),
        index=True,
        nullable=False,
    )
    title: Mapped[str] = mapped_column(String, nullable=False)
    plan: Mapped[Dict[str, Any]] = mapped_column(JSON, default=dict, nullable=False)
    budget: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    total_price: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    use_case: Mapped[Optional[str]] = mapped_column(String, nullable=True)
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
