"""create component_price table

Revision ID: 20260613_0002
Revises: 20260613_0001
Create Date: 2026-06-15
"""

from alembic import op
import sqlalchemy as sa


revision = "20260613_0002"
down_revision = "20260613_0001"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "component_price",
        sa.Column("component_id", sa.String(), sa.ForeignKey("hardware_component.id", ondelete="CASCADE"), primary_key=True),
        sa.Column("reference_price", sa.Integer(), nullable=False),
        sa.Column("price_range_low", sa.Integer(), nullable=True),
        sa.Column("price_range_high", sa.Integer(), nullable=True),
        sa.Column("source", sa.String(), nullable=False),
        sa.Column("accepted_count", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("rejected_count", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("review_reasons", sa.JSON(), nullable=False, server_default=sa.text("'[]'")),
        sa.Column("approved_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
    )


def downgrade() -> None:
    op.drop_table("component_price")
