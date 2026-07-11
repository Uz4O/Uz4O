from datetime import datetime, timezone
from typing import Any, Dict, List, Optional

from sqlalchemy import Boolean, DateTime, ForeignKey, Integer, JSON, String
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


class ComponentPrice(Base):
    __tablename__ = "component_price"

    component_id: Mapped[str] = mapped_column(
        String,
        ForeignKey("hardware_component.id", ondelete="CASCADE"),
        primary_key=True,
    )
    reference_price: Mapped[int] = mapped_column(Integer, nullable=False)
    price_range_low: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    price_range_high: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    source: Mapped[str] = mapped_column(String, nullable=False)
    accepted_count: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    rejected_count: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    review_reasons: Mapped[List[str]] = mapped_column(JSON, default=list)
    approved_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        onupdate=lambda: datetime.now(timezone.utc),
        nullable=False,
    )


class GPUWhitelistPrice(Base):
    __tablename__ = "gpu_whitelist_price"

    component_id: Mapped[str] = mapped_column(
        String,
        ForeignKey("hardware_component.id", ondelete="CASCADE"),
        primary_key=True,
    )
    name: Mapped[str] = mapped_column(String, nullable=False)
    used_price: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    new_price: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    source: Mapped[str] = mapped_column(String, nullable=False)
    approved_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        onupdate=lambda: datetime.now(timezone.utc),
        nullable=False,
    )


class MotherboardWhitelistPrice(Base):
    __tablename__ = "motherboard_whitelist_price"

    component_id: Mapped[str] = mapped_column(
        String,
        ForeignKey("hardware_component.id", ondelete="CASCADE"),
        primary_key=True,
    )
    name: Mapped[str] = mapped_column(String, nullable=False)
    platform: Mapped[str] = mapped_column(String, nullable=False)
    used_price: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    new_price: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    status: Mapped[str] = mapped_column(String, nullable=False)
    source: Mapped[str] = mapped_column(String, nullable=False)
    approved_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        onupdate=lambda: datetime.now(timezone.utc),
        nullable=False,
    )


class CPUWhitelistPrice(Base):
    __tablename__ = "cpu_whitelist_price"

    component_id: Mapped[str] = mapped_column(
        String,
        ForeignKey("hardware_component.id", ondelete="CASCADE"),
        primary_key=True,
    )
    name: Mapped[str] = mapped_column(String, nullable=False)
    used_price: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    new_tray_price: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    source: Mapped[str] = mapped_column(String, nullable=False)
    approved_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        onupdate=lambda: datetime.now(timezone.utc),
        nullable=False,
    )
