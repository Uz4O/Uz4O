from datetime import datetime
from typing import Optional

from sqlalchemy import (
    Boolean,
    CheckConstraint,
    DateTime,
    Float,
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


class HardwarePerformanceProfile(Base):
    __tablename__ = "hardware_performance_profile"

    component_id: Mapped[str] = mapped_column(
        String,
        ForeignKey("hardware_component.id", ondelete="CASCADE"),
        primary_key=True,
    )
    category: Mapped[str] = mapped_column(String)
    performance_score: Mapped[int] = mapped_column(Integer)
    is_common: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    supports_dlss: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    supports_fsr: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    supports_standard_frame_generation: Mapped[bool] = mapped_column(
        Boolean,
        default=False,
        nullable=False,
    )
    source_kind: Mapped[str] = mapped_column(String)
    source_reference: Mapped[str] = mapped_column(String)
    reviewed_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    import_batch: Mapped[str] = mapped_column(String, index=True)

    __table_args__ = (
        CheckConstraint(
            "category IN ('cpu', 'gpu')",
            name="ck_hardware_perf_category",
        ),
        CheckConstraint(
            "performance_score > 0",
            name="ck_hardware_perf_positive_score",
        ),
        CheckConstraint(
            "category = 'gpu' OR (supports_dlss = false "
            "AND supports_fsr = false "
            "AND supports_standard_frame_generation = false)",
            name="ck_hardware_perf_cpu_capabilities",
        ),
        CheckConstraint(
            "source_kind IN ('self_measured', 'licensed', 'open_license', "
            "'public_reference')",
            name="ck_hardware_perf_source_kind",
        ),
        CheckConstraint(
            "length(source_reference) > 0",
            name="ck_hardware_perf_source_reference",
        ),
        Index(
            "ix_hardware_perf_category_score",
            "category",
            "performance_score",
        ),
    )


class GamePerformanceAnchor(Base):
    __tablename__ = "game_performance_anchor"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    game_id: Mapped[str] = mapped_column(String, index=True)
    axis: Mapped[str] = mapped_column(String)
    cpu_id: Mapped[str] = mapped_column(
        String,
        ForeignKey("hardware_component.id", ondelete="CASCADE"),
    )
    gpu_id: Mapped[str] = mapped_column(
        String,
        ForeignKey("hardware_component.id", ondelete="CASCADE"),
    )
    resolution: Mapped[str] = mapped_column(String)
    render_mode: Mapped[str] = mapped_column(String)
    average_fps: Mapped[int] = mapped_column(Integer)
    sample_role: Mapped[str] = mapped_column(String)
    game_version: Mapped[str] = mapped_column(String)
    driver_version: Mapped[str] = mapped_column(String)
    source_kind: Mapped[str] = mapped_column(String)
    source_reference: Mapped[str] = mapped_column(String)
    tested_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    import_batch: Mapped[str] = mapped_column(String, index=True)

    __table_args__ = (
        UniqueConstraint(
            "game_id",
            "axis",
            "cpu_id",
            "gpu_id",
            "resolution",
            "render_mode",
            "sample_role",
            "game_version",
            "driver_version",
            name="uq_game_perf_anchor_sample",
        ),
        CheckConstraint(
            "axis IN ('cpu', 'gpu', 'cross')",
            name="ck_game_perf_anchor_axis",
        ),
        CheckConstraint(
            "resolution IN ('1080p', '2k', '4k')",
            name="ck_game_perf_anchor_resolution",
        ),
        CheckConstraint(
            "render_mode IN ('native', 'dlss_quality', 'dlss_quality_fg', "
            "'fsr_quality', 'fsr_quality_fg')",
            name="ck_game_perf_anchor_render_mode",
        ),
        CheckConstraint(
            "average_fps BETWEEN 1 AND 2000",
            name="ck_game_perf_anchor_fps",
        ),
        CheckConstraint(
            "sample_role IN ('fit', 'validation')",
            name="ck_game_perf_anchor_sample_role",
        ),
        CheckConstraint(
            "(sample_role = 'fit' AND axis IN ('cpu', 'gpu')) "
            "OR (sample_role = 'validation' AND axis = 'cross')",
            name="ck_game_perf_anchor_role_axis",
        ),
        CheckConstraint(
            "source_kind IN ('self_measured', 'licensed', 'open_license', "
            "'public_reference')",
            name="ck_game_perf_anchor_source_kind",
        ),
        CheckConstraint(
            "length(source_reference) > 0",
            name="ck_game_perf_anchor_source_reference",
        ),
        Index(
            "ix_game_perf_anchor_lookup",
            "game_id",
            "resolution",
            "render_mode",
            "axis",
            "sample_role",
        ),
    )


class GamePerformanceCalibration(Base):
    __tablename__ = "game_performance_calibration"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    game_id: Mapped[str] = mapped_column(String)
    resolution: Mapped[str] = mapped_column(String)
    render_mode: Mapped[str] = mapped_column(String)
    model_version: Mapped[str] = mapped_column(String)
    correction_factor: Mapped[float] = mapped_column(Float)
    validation_mape: Mapped[float] = mapped_column(Float)
    validation_count: Mapped[int] = mapped_column(Integer)
    common_validation_mape: Mapped[float] = mapped_column(Float)
    common_validation_count: Mapped[int] = mapped_column(Integer)
    is_active: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    calibrated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))

    __table_args__ = (
        UniqueConstraint(
            "game_id",
            "resolution",
            "render_mode",
            "model_version",
            name="uq_game_perf_calibration_version",
        ),
        CheckConstraint(
            "resolution IN ('1080p', '2k', '4k')",
            name="ck_game_perf_calibration_resolution",
        ),
        CheckConstraint(
            "render_mode IN ('native', 'dlss_quality', 'dlss_quality_fg', "
            "'fsr_quality', 'fsr_quality_fg')",
            name="ck_game_perf_calibration_render_mode",
        ),
        CheckConstraint(
            "correction_factor BETWEEN 0.5 AND 1.5",
            name="ck_game_perf_calibration_factor",
        ),
        CheckConstraint(
            "validation_mape BETWEEN 0 AND 100",
            name="ck_game_perf_calibration_mape",
        ),
        CheckConstraint(
            "common_validation_mape BETWEEN 0 AND 100",
            name="ck_game_perf_calibration_common_mape",
        ),
        CheckConstraint(
            "validation_count > 0 AND common_validation_count > 0 "
            "AND common_validation_count <= validation_count",
            name="ck_game_perf_calibration_counts",
        ),
        Index(
            "ix_game_perf_calibration_active",
            "game_id",
            "resolution",
            "render_mode",
            "is_active",
        ),
    )
