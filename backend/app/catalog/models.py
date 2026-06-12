from datetime import datetime, timezone
from typing import Any, Dict

from sqlalchemy import Boolean, DateTime, JSON, String
from sqlalchemy.orm import Mapped, mapped_column

from app.db import Base


class HardwareComponent(Base):
    __tablename__ = "hardware_component"

    id: Mapped[str] = mapped_column(String, primary_key=True)
    category: Mapped[str] = mapped_column(String, index=True)
    name: Mapped[str] = mapped_column(String, index=True)
    brand: Mapped[str] = mapped_column(String, index=True)
    detail_raw: Mapped[str] = mapped_column(String)
    specs: Mapped[Dict[str, Any]] = mapped_column(JSON, default=dict)
    is_recommended: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    status: Mapped[str] = mapped_column(String, default="active", nullable=False)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        onupdate=lambda: datetime.now(timezone.utc),
        nullable=False,
    )
