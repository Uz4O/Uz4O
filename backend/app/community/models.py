from datetime import datetime, timezone
from typing import List, Optional
from uuid import uuid4

from sqlalchemy import Boolean, DateTime, ForeignKey, Integer, JSON, String, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column

import app.auth.models  # noqa: F401
from app.db import Base


def _uuid() -> str:
    return str(uuid4())


class CommunityPost(Base):
    __tablename__ = "community_post"

    id: Mapped[str] = mapped_column(String, primary_key=True, default=_uuid)
    author_id: Mapped[str] = mapped_column(
        String,
        ForeignKey("account.id", ondelete="CASCADE"),
        index=True,
        nullable=False,
    )
    summary: Mapped[str] = mapped_column(String, nullable=False)
    body: Mapped[str] = mapped_column(String, nullable=False)
    tags: Mapped[List[str]] = mapped_column(JSON, default=list, nullable=False)
    parts: Mapped[List[str]] = mapped_column(JSON, default=list, nullable=False)
    image_asset: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    is_pinned: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    like_count: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    comment_count: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    save_count: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    status: Mapped[str] = mapped_column(String, default="published", index=True, nullable=False)
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


class CommunityComment(Base):
    __tablename__ = "community_comment"

    id: Mapped[str] = mapped_column(String, primary_key=True, default=_uuid)
    post_id: Mapped[str] = mapped_column(
        String,
        ForeignKey("community_post.id", ondelete="CASCADE"),
        index=True,
        nullable=False,
    )
    author_id: Mapped[str] = mapped_column(
        String,
        ForeignKey("account.id", ondelete="CASCADE"),
        index=True,
        nullable=False,
    )
    body: Mapped[str] = mapped_column(String, nullable=False)
    status: Mapped[str] = mapped_column(String, default="published", index=True, nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        nullable=False,
    )


class CommunityReaction(Base):
    __tablename__ = "community_reaction"
    __table_args__ = (
        UniqueConstraint("post_id", "account_id", "type", name="uq_community_reaction_once"),
    )

    id: Mapped[str] = mapped_column(String, primary_key=True, default=_uuid)
    post_id: Mapped[str] = mapped_column(
        String,
        ForeignKey("community_post.id", ondelete="CASCADE"),
        index=True,
        nullable=False,
    )
    account_id: Mapped[str] = mapped_column(
        String,
        ForeignKey("account.id", ondelete="CASCADE"),
        index=True,
        nullable=False,
    )
    type: Mapped[str] = mapped_column(String, nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        nullable=False,
    )
