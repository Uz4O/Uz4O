"""create reviewed game FPS estimator tables

Revision ID: 20260715_0013
Revises: 20260713_0012
Create Date: 2026-07-15
"""

from alembic import op
import sqlalchemy as sa


revision = "20260715_0013"
down_revision = "20260713_0012"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "hardware_performance_profile",
        sa.Column(
            "component_id",
            sa.String(),
            sa.ForeignKey("hardware_component.id", ondelete="CASCADE"),
            primary_key=True,
        ),
        sa.Column("category", sa.String(), nullable=False),
        sa.Column("performance_score", sa.Integer(), nullable=False),
        sa.Column("is_common", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column("supports_dlss", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column("supports_fsr", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column(
            "supports_standard_frame_generation",
            sa.Boolean(),
            nullable=False,
            server_default=sa.false(),
        ),
        sa.Column("source_kind", sa.String(), nullable=False),
        sa.Column("source_reference", sa.String(), nullable=False),
        sa.Column("reviewed_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("import_batch", sa.String(), nullable=False),
        sa.CheckConstraint(
            "category IN ('cpu', 'gpu')",
            name="ck_hardware_perf_category",
        ),
        sa.CheckConstraint(
            "performance_score > 0",
            name="ck_hardware_perf_positive_score",
        ),
        sa.CheckConstraint(
            "category = 'gpu' OR (supports_dlss = false "
            "AND supports_fsr = false "
            "AND supports_standard_frame_generation = false)",
            name="ck_hardware_perf_cpu_capabilities",
        ),
        sa.CheckConstraint(
            "source_kind IN ('self_measured', 'licensed', 'open_license')",
            name="ck_hardware_perf_source_kind",
        ),
        sa.CheckConstraint(
            "length(source_reference) > 0",
            name="ck_hardware_perf_source_reference",
        ),
    )
    op.create_index(
        "ix_hardware_performance_profile_import_batch",
        "hardware_performance_profile",
        ["import_batch"],
    )
    op.create_index(
        "ix_hardware_perf_category_score",
        "hardware_performance_profile",
        ["category", "performance_score"],
    )

    op.create_table(
        "game_performance_anchor",
        sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column("game_id", sa.String(), nullable=False),
        sa.Column("axis", sa.String(), nullable=False),
        sa.Column(
            "cpu_id",
            sa.String(),
            sa.ForeignKey("hardware_component.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column(
            "gpu_id",
            sa.String(),
            sa.ForeignKey("hardware_component.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("resolution", sa.String(), nullable=False),
        sa.Column("render_mode", sa.String(), nullable=False),
        sa.Column("average_fps", sa.Integer(), nullable=False),
        sa.Column("sample_role", sa.String(), nullable=False),
        sa.Column("game_version", sa.String(), nullable=False),
        sa.Column("driver_version", sa.String(), nullable=False),
        sa.Column("source_kind", sa.String(), nullable=False),
        sa.Column("source_reference", sa.String(), nullable=False),
        sa.Column("tested_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("import_batch", sa.String(), nullable=False),
        sa.UniqueConstraint(
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
        sa.CheckConstraint(
            "axis IN ('cpu', 'gpu', 'cross')",
            name="ck_game_perf_anchor_axis",
        ),
        sa.CheckConstraint(
            "resolution IN ('1080p', '2k', '4k')",
            name="ck_game_perf_anchor_resolution",
        ),
        sa.CheckConstraint(
            "render_mode IN ('native', 'dlss_quality', 'dlss_quality_fg', "
            "'fsr_quality', 'fsr_quality_fg')",
            name="ck_game_perf_anchor_render_mode",
        ),
        sa.CheckConstraint(
            "average_fps BETWEEN 1 AND 2000",
            name="ck_game_perf_anchor_fps",
        ),
        sa.CheckConstraint(
            "sample_role IN ('fit', 'validation')",
            name="ck_game_perf_anchor_sample_role",
        ),
        sa.CheckConstraint(
            "(sample_role = 'fit' AND axis IN ('cpu', 'gpu')) "
            "OR (sample_role = 'validation' AND axis = 'cross')",
            name="ck_game_perf_anchor_role_axis",
        ),
        sa.CheckConstraint(
            "source_kind IN ('self_measured', 'licensed', 'open_license')",
            name="ck_game_perf_anchor_source_kind",
        ),
        sa.CheckConstraint(
            "length(source_reference) > 0",
            name="ck_game_perf_anchor_source_reference",
        ),
    )
    op.create_index(
        "ix_game_performance_anchor_game_id",
        "game_performance_anchor",
        ["game_id"],
    )
    op.create_index(
        "ix_game_performance_anchor_import_batch",
        "game_performance_anchor",
        ["import_batch"],
    )
    op.create_index(
        "ix_game_perf_anchor_lookup",
        "game_performance_anchor",
        ["game_id", "resolution", "render_mode", "axis", "sample_role"],
    )

    op.create_table(
        "game_performance_calibration",
        sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column("game_id", sa.String(), nullable=False),
        sa.Column("resolution", sa.String(), nullable=False),
        sa.Column("render_mode", sa.String(), nullable=False),
        sa.Column("model_version", sa.String(), nullable=False),
        sa.Column("correction_factor", sa.Float(), nullable=False),
        sa.Column("validation_mape", sa.Float(), nullable=False),
        sa.Column("validation_count", sa.Integer(), nullable=False),
        sa.Column("common_validation_mape", sa.Float(), nullable=False),
        sa.Column("common_validation_count", sa.Integer(), nullable=False),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column("calibrated_at", sa.DateTime(timezone=True), nullable=False),
        sa.UniqueConstraint(
            "game_id",
            "resolution",
            "render_mode",
            "model_version",
            name="uq_game_perf_calibration_version",
        ),
        sa.CheckConstraint(
            "resolution IN ('1080p', '2k', '4k')",
            name="ck_game_perf_calibration_resolution",
        ),
        sa.CheckConstraint(
            "render_mode IN ('native', 'dlss_quality', 'dlss_quality_fg', "
            "'fsr_quality', 'fsr_quality_fg')",
            name="ck_game_perf_calibration_render_mode",
        ),
        sa.CheckConstraint(
            "correction_factor BETWEEN 0.5 AND 1.5",
            name="ck_game_perf_calibration_factor",
        ),
        sa.CheckConstraint(
            "validation_mape BETWEEN 0 AND 100",
            name="ck_game_perf_calibration_mape",
        ),
        sa.CheckConstraint(
            "common_validation_mape BETWEEN 0 AND 100",
            name="ck_game_perf_calibration_common_mape",
        ),
        sa.CheckConstraint(
            "validation_count > 0 AND common_validation_count > 0 "
            "AND common_validation_count <= validation_count",
            name="ck_game_perf_calibration_counts",
        ),
    )
    op.create_index(
        "ix_game_perf_calibration_active",
        "game_performance_calibration",
        ["game_id", "resolution", "render_mode", "is_active"],
    )


def downgrade() -> None:
    op.drop_index(
        "ix_game_perf_calibration_active",
        table_name="game_performance_calibration",
    )
    op.drop_table("game_performance_calibration")

    op.drop_index(
        "ix_game_perf_anchor_lookup",
        table_name="game_performance_anchor",
    )
    op.drop_index(
        "ix_game_performance_anchor_import_batch",
        table_name="game_performance_anchor",
    )
    op.drop_index(
        "ix_game_performance_anchor_game_id",
        table_name="game_performance_anchor",
    )
    op.drop_table("game_performance_anchor")

    op.drop_index(
        "ix_hardware_perf_category_score",
        table_name="hardware_performance_profile",
    )
    op.drop_index(
        "ix_hardware_performance_profile_import_batch",
        table_name="hardware_performance_profile",
    )
    op.drop_table("hardware_performance_profile")
