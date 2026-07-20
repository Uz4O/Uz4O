"""add selected build recommendation cache

Revision ID: 20260720_0015
Revises: 20260715_0014
Create Date: 2026-07-20
"""

from alembic import op
import sqlalchemy as sa


revision = "20260720_0015"
down_revision = "20260715_0014"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "build_selection_cache",
        sa.Column("id", sa.String(), nullable=False),
        sa.Column("request_hash", sa.String(length=64), nullable=False),
        sa.Column("option_key", sa.String(length=32), nullable=False),
        sa.Column("request_payload", sa.JSON(), nullable=False),
        sa.Column("response_payload", sa.JSON(), nullable=False),
        sa.Column("cache_version", sa.String(length=64), nullable=False),
        sa.Column("selected_count", sa.Integer(), server_default="0", nullable=False),
        sa.Column("last_selected_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint(
            "request_hash",
            "option_key",
            name="uq_build_selection_cache_request_option",
        ),
    )
    op.create_index(
        "ix_build_selection_cache_request_hash",
        "build_selection_cache",
        ["request_hash"],
        unique=False,
    )


def downgrade() -> None:
    op.drop_index(
        "ix_build_selection_cache_request_hash",
        table_name="build_selection_cache",
    )
    op.drop_table("build_selection_cache")
