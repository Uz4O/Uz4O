"""add community safety tables

Revision ID: 20260621_0007
Revises: 20260616_0006
Create Date: 2026-06-21
"""

from alembic import op
import sqlalchemy as sa


revision = "20260621_0007"
down_revision = "20260616_0006"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "account",
        sa.Column("is_moderator", sa.Boolean(), nullable=False, server_default=sa.false()),
    )
    op.create_table(
        "community_report",
        sa.Column("id", sa.String(), primary_key=True),
        sa.Column(
            "reporter_id",
            sa.String(),
            sa.ForeignKey("account.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("target_type", sa.String(), nullable=False),
        sa.Column("target_id", sa.String(), nullable=False),
        sa.Column("reason", sa.String(), nullable=False),
        sa.Column("details", sa.String(), nullable=False, server_default=""),
        sa.Column("status", sa.String(), nullable=False, server_default="open"),
        sa.Column("resolution_note", sa.String(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.UniqueConstraint(
            "reporter_id",
            "target_type",
            "target_id",
            name="uq_community_report_reporter_target",
        ),
        sa.CheckConstraint("target_type IN ('post', 'comment')", name="ck_report_target_type"),
    )
    op.create_index("ix_community_report_reporter_id", "community_report", ["reporter_id"])
    op.create_index("ix_community_report_target_id", "community_report", ["target_id"])
    op.create_index("ix_community_report_status", "community_report", ["status"])
    op.create_table(
        "community_block",
        sa.Column("id", sa.String(), primary_key=True),
        sa.Column(
            "blocker_id",
            sa.String(),
            sa.ForeignKey("account.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column(
            "blocked_id",
            sa.String(),
            sa.ForeignKey("account.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.UniqueConstraint("blocker_id", "blocked_id", name="uq_community_block_pair"),
        sa.CheckConstraint("blocker_id != blocked_id", name="ck_community_block_not_self"),
    )
    op.create_index("ix_community_block_blocker_id", "community_block", ["blocker_id"])
    op.create_index("ix_community_block_blocked_id", "community_block", ["blocked_id"])


def downgrade() -> None:
    op.drop_index("ix_community_block_blocked_id", table_name="community_block")
    op.drop_index("ix_community_block_blocker_id", table_name="community_block")
    op.drop_table("community_block")
    op.drop_index("ix_community_report_status", table_name="community_report")
    op.drop_index("ix_community_report_target_id", table_name="community_report")
    op.drop_index("ix_community_report_reporter_id", table_name="community_report")
    op.drop_table("community_report")
    op.drop_column("account", "is_moderator")
