from datetime import datetime
from typing import Optional

from sqlalchemy import (
    CheckConstraint,
    DateTime,
    ForeignKey,
    Index,
    Integer,
    String,
    UniqueConstraint,
)
from sqlalchemy.orm import Mapped, mapped_column

from app.db import Base


class GamePerformanceEstimate(Base):
    __tablename__ = "game_performance_estimate"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    cpu_id: Mapped[str] = mapped_column(
        String,
        ForeignKey("hardware_component.id", ondelete="CASCADE"),
        index=True,
    )
    gpu_id: Mapped[str] = mapped_column(
        String,
        ForeignKey("hardware_component.id", ondelete="CASCADE"),
        index=True,
    )
    game_id: Mapped[str] = mapped_column(String, index=True)
    resolution: Mapped[str] = mapped_column(String)
    quality: Mapped[str] = mapped_column(String, default="medium")
    average_fps: Mapped[int] = mapped_column(Integer)
    minimum_fps: Mapped[int] = mapped_column(Integer)
    maximum_fps: Mapped[int] = mapped_column(Integer)
    bottleneck_type: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    bottleneck_percent: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    source_url: Mapped[str] = mapped_column(String)
    source_fetched_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    import_batch: Mapped[str] = mapped_column(String, index=True)

    __table_args__ = (
        UniqueConstraint(
            "cpu_id",
            "gpu_id",
            "game_id",
            "resolution",
            "quality",
            name="uq_game_perf_combo",
        ),
        CheckConstraint(
            "resolution IN ('1080p', '2k', '4k')",
            name="ck_game_perf_resolution",
        ),
        CheckConstraint("quality = 'medium'", name="ck_game_perf_quality"),
        CheckConstraint(
            "0 < minimum_fps AND minimum_fps <= average_fps "
            "AND average_fps <= maximum_fps AND maximum_fps <= 2000",
            name="ck_game_perf_fps_range",
        ),
        CheckConstraint(
            "bottleneck_type IN ('cpu', 'gpu', 'balanced') "
            "OR bottleneck_type IS NULL",
            name="ck_game_perf_bottleneck_type",
        ),
        CheckConstraint(
            "bottleneck_percent BETWEEN 0 AND 100 "
            "OR bottleneck_percent IS NULL",
            name="ck_game_perf_bottleneck_percent",
        ),
        Index(
            "ix_game_perf_lookup",
            "cpu_id",
            "gpu_id",
            "game_id",
            "resolution",
            "quality",
        ),
    )
