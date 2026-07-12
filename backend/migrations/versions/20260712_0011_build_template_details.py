"""Add structured details to build templates.

Revision ID: 20260712_0011
Revises: 20260707_0010
"""

from alembic import op
import sqlalchemy as sa


revision = "20260712_0011"
down_revision = "20260707_0010"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "build_template",
        sa.Column(
            "details",
            sa.JSON(),
            nullable=False,
            server_default=sa.text("'{}'"),
        ),
    )


def downgrade() -> None:
    op.drop_column("build_template", "details")
