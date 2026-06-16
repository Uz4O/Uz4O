"""create auth and profile tables

Revision ID: 20260615_0003
Revises: 20260613_0002
Create Date: 2026-06-15
"""

from alembic import op
import sqlalchemy as sa


revision = "20260615_0003"
down_revision = "20260613_0002"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "account",
        sa.Column("id", sa.String(), primary_key=True),
        sa.Column("phone", sa.String(), nullable=True, unique=True),
        sa.Column("apple_sub", sa.String(), nullable=True, unique=True),
        sa.Column("wechat_openid", sa.String(), nullable=True, unique=True),
        sa.Column("nickname", sa.String(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
    )
    op.create_table(
        "auth_sms_code",
        sa.Column("id", sa.String(), primary_key=True),
        sa.Column("phone", sa.String(), nullable=False),
        sa.Column("code_hash", sa.String(), nullable=False),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("consumed_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.UniqueConstraint("phone", "code_hash", name="uq_auth_sms_code_phone_hash"),
    )
    op.create_index("ix_auth_sms_code_phone", "auth_sms_code", ["phone"])
    op.create_table(
        "onboarding_profile",
        sa.Column("account_id", sa.String(), sa.ForeignKey("account.id", ondelete="CASCADE"), primary_key=True),
        sa.Column("preference", sa.String(), nullable=False, server_default="balanced"),
        sa.Column("home_feature_order", sa.JSON(), nullable=False, server_default=sa.text("'[]'")),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
    )
    op.create_table(
        "hardware_profile",
        sa.Column("id", sa.String(), primary_key=True),
        sa.Column("account_id", sa.String(), sa.ForeignKey("account.id", ondelete="CASCADE"), nullable=False),
        sa.Column("label", sa.String(), nullable=True),
        sa.Column("cpu", sa.String(), nullable=True),
        sa.Column("gpu", sa.String(), nullable=True),
        sa.Column("motherboard", sa.String(), nullable=True),
        sa.Column("memory", sa.String(), nullable=True),
        sa.Column("storage", sa.String(), nullable=True),
        sa.Column("power_supply", sa.String(), nullable=True),
        sa.Column("is_current_computer", sa.Boolean(), nullable=False, server_default=sa.text("true")),
        sa.Column("was_skipped", sa.Boolean(), nullable=False, server_default=sa.text("false")),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
    )
    op.create_index("ix_hardware_profile_account_id", "hardware_profile", ["account_id"])


def downgrade() -> None:
    op.drop_index("ix_hardware_profile_account_id", table_name="hardware_profile")
    op.drop_table("hardware_profile")
    op.drop_table("onboarding_profile")
    op.drop_index("ix_auth_sms_code_phone", table_name="auth_sms_code")
    op.drop_table("auth_sms_code")
    op.drop_table("account")
