"""create game_performance_estimate table

Revision ID: 20260712_0011
Revises: 20260707_0010
Create Date: 2026-07-12
"""

from alembic import op
import sqlalchemy as sa


revision = "20260712_0011"
down_revision = "20260707_0010"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "game_performance_estimate",
        sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
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
        sa.Column("game_id", sa.String(), nullable=False),
        sa.Column("resolution", sa.String(), nullable=False),
        sa.Column("quality", sa.String(), nullable=False, server_default="medium"),
        sa.Column("average_fps", sa.Integer(), nullable=False),
        sa.Column("minimum_fps", sa.Integer(), nullable=False),
        sa.Column("maximum_fps", sa.Integer(), nullable=False),
        sa.Column("bottleneck_type", sa.String(), nullable=True),
        sa.Column("bottleneck_percent", sa.Integer(), nullable=True),
        sa.Column("source_url", sa.String(), nullable=False),
        sa.Column("source_fetched_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("import_batch", sa.String(), nullable=False),
        sa.CheckConstraint(
            "resolution IN ('1080p', '2k', '4k')",
            name="ck_game_perf_resolution",
        ),
        sa.CheckConstraint("quality = 'medium'", name="ck_game_perf_quality"),
        sa.CheckConstraint(
            "0 < minimum_fps AND minimum_fps <= average_fps "
            "AND average_fps <= maximum_fps AND maximum_fps <= 2000",
            name="ck_game_perf_fps_range",
        ),
        sa.CheckConstraint(
            "bottleneck_type IN ('cpu', 'gpu', 'balanced') "
            "OR bottleneck_type IS NULL",
            name="ck_game_perf_bottleneck_type",
        ),
        sa.CheckConstraint(
            "bottleneck_percent BETWEEN 0 AND 100 "
            "OR bottleneck_percent IS NULL",
            name="ck_game_perf_bottleneck_percent",
        ),
        sa.UniqueConstraint(
            "cpu_id",
            "gpu_id",
            "game_id",
            "resolution",
            "quality",
            name="uq_game_perf_combo",
        ),
    )
    op.create_index(
        "ix_game_perf_lookup",
        "game_performance_estimate",
        ["cpu_id", "gpu_id", "game_id", "resolution", "quality"],
    )
    op.create_index(
        "ix_game_performance_estimate_cpu_id",
        "game_performance_estimate",
        ["cpu_id"],
    )
    op.create_index(
        "ix_game_performance_estimate_gpu_id",
        "game_performance_estimate",
        ["gpu_id"],
    )
    op.create_index(
        "ix_game_performance_estimate_game_id",
        "game_performance_estimate",
        ["game_id"],
    )
    op.create_index(
        "ix_game_performance_estimate_import_batch",
        "game_performance_estimate",
        ["import_batch"],
    )


def downgrade() -> None:
    op.drop_index(
        "ix_game_performance_estimate_import_batch",
        table_name="game_performance_estimate",
    )
    op.drop_index(
        "ix_game_performance_estimate_game_id",
        table_name="game_performance_estimate",
    )
    op.drop_index(
        "ix_game_performance_estimate_gpu_id",
        table_name="game_performance_estimate",
    )
    op.drop_index(
        "ix_game_performance_estimate_cpu_id",
        table_name="game_performance_estimate",
    )
    op.drop_index("ix_game_perf_lookup", table_name="game_performance_estimate")
    op.drop_table("game_performance_estimate")
