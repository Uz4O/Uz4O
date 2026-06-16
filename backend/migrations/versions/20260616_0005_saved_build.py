"""create saved_build table

Revision ID: 20260616_0005
Revises: 20260615_0004
Create Date: 2026-06-16
"""

from alembic import op
import sqlalchemy as sa


revision = "20260616_0005"
down_revision = "20260615_0004"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "saved_build",
        sa.Column("id", sa.String(), primary_key=True),
        sa.Column(
            "account_id",
            sa.String(),
            sa.ForeignKey("account.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("title", sa.String(), nullable=False),
        sa.Column("plan", sa.JSON(), nullable=False, server_default=sa.text("'{}'")),
        sa.Column("budget", sa.Integer(), nullable=True),
        sa.Column("total_price", sa.Integer(), nullable=True),
        sa.Column("use_case", sa.String(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
    )
    op.create_index("ix_saved_build_account_id", "saved_build", ["account_id"])


def downgrade() -> None:
    op.drop_index("ix_saved_build_account_id", table_name="saved_build")
    op.drop_table("saved_build")
