"""create build_template table

Revision ID: 20260615_0004
Revises: 20260615_0003
Create Date: 2026-06-15
"""

from alembic import op
import sqlalchemy as sa


revision = "20260615_0004"
down_revision = "20260615_0003"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "build_template",
        sa.Column("id", sa.String(), primary_key=True),
        sa.Column("title", sa.String(), nullable=False),
        sa.Column("budget_min", sa.Integer(), nullable=False),
        sa.Column("budget_max", sa.Integer(), nullable=False),
        sa.Column("use_cases", sa.JSON(), nullable=False, server_default=sa.text("'[]'")),
        sa.Column("tags", sa.JSON(), nullable=False, server_default=sa.text("'[]'")),
        sa.Column("components", sa.JSON(), nullable=False, server_default=sa.text("'{}'")),
        sa.Column("estimated_total", sa.Integer(), nullable=True),
        sa.Column("explanation", sa.String(), nullable=False),
        sa.Column("status", sa.String(), nullable=False, server_default="active"),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
    )


def downgrade() -> None:
    op.drop_table("build_template")
