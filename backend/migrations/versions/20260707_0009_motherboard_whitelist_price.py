"""create motherboard_whitelist_price table

Revision ID: 20260707_0009
Revises: 20260707_0008
Create Date: 2026-07-07
"""

from alembic import op
import sqlalchemy as sa


revision = "20260707_0009"
down_revision = "20260707_0008"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "motherboard_whitelist_price",
        sa.Column("component_id", sa.String(), sa.ForeignKey("hardware_component.id", ondelete="CASCADE"), primary_key=True),
        sa.Column("name", sa.String(), nullable=False),
        sa.Column("platform", sa.String(), nullable=False),
        sa.Column("used_price", sa.Integer(), nullable=True),
        sa.Column("new_price", sa.Integer(), nullable=True),
        sa.Column("status", sa.String(), nullable=False),
        sa.Column("source", sa.String(), nullable=False),
        sa.Column("approved_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
    )


def downgrade() -> None:
    op.drop_table("motherboard_whitelist_price")
