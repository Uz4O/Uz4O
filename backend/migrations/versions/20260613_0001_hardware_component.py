"""create hardware_component table

Revision ID: 20260613_0001
Revises:
Create Date: 2026-06-13
"""

from alembic import op
import sqlalchemy as sa


revision = "20260613_0001"
down_revision = None
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "hardware_component",
        sa.Column("id", sa.String(), primary_key=True),
        sa.Column("category", sa.String(), nullable=False),
        sa.Column("name", sa.String(), nullable=False),
        sa.Column("brand", sa.String(), nullable=False),
        sa.Column("detail_raw", sa.String(), nullable=False),
        sa.Column("specs", sa.JSON(), nullable=False),
        sa.Column("is_recommended", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column("status", sa.String(), nullable=False, server_default="active"),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
    )
    op.create_index("ix_hardware_component_category", "hardware_component", ["category"])
    op.create_index("ix_hardware_component_name", "hardware_component", ["name"])
    op.create_index("ix_hardware_component_brand", "hardware_component", ["brand"])


def downgrade() -> None:
    op.drop_index("ix_hardware_component_brand", table_name="hardware_component")
    op.drop_index("ix_hardware_component_name", table_name="hardware_component")
    op.drop_index("ix_hardware_component_category", table_name="hardware_component")
    op.drop_table("hardware_component")

