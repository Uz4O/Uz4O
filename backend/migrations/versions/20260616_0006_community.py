"""create community tables

Revision ID: 20260616_0006
Revises: 20260616_0005
Create Date: 2026-06-16
"""

from alembic import op
import sqlalchemy as sa


revision = "20260616_0006"
down_revision = "20260616_0005"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "community_post",
        sa.Column("id", sa.String(), primary_key=True),
        sa.Column("author_id", sa.String(), sa.ForeignKey("account.id", ondelete="CASCADE"), nullable=False),
        sa.Column("summary", sa.String(), nullable=False),
        sa.Column("body", sa.String(), nullable=False),
        sa.Column("tags", sa.JSON(), nullable=False, server_default=sa.text("'[]'")),
        sa.Column("parts", sa.JSON(), nullable=False, server_default=sa.text("'[]'")),
        sa.Column("image_asset", sa.String(), nullable=True),
        sa.Column("is_pinned", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column("like_count", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("comment_count", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("save_count", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("status", sa.String(), nullable=False, server_default="published"),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
    )
    op.create_index("ix_community_post_author_id", "community_post", ["author_id"])
    op.create_index("ix_community_post_status", "community_post", ["status"])

    op.create_table(
        "community_comment",
        sa.Column("id", sa.String(), primary_key=True),
        sa.Column("post_id", sa.String(), sa.ForeignKey("community_post.id", ondelete="CASCADE"), nullable=False),
        sa.Column("author_id", sa.String(), sa.ForeignKey("account.id", ondelete="CASCADE"), nullable=False),
        sa.Column("body", sa.String(), nullable=False),
        sa.Column("status", sa.String(), nullable=False, server_default="published"),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
    )
    op.create_index("ix_community_comment_post_id", "community_comment", ["post_id"])
    op.create_index("ix_community_comment_author_id", "community_comment", ["author_id"])
    op.create_index("ix_community_comment_status", "community_comment", ["status"])

    op.create_table(
        "community_reaction",
        sa.Column("id", sa.String(), primary_key=True),
        sa.Column("post_id", sa.String(), sa.ForeignKey("community_post.id", ondelete="CASCADE"), nullable=False),
        sa.Column("account_id", sa.String(), sa.ForeignKey("account.id", ondelete="CASCADE"), nullable=False),
        sa.Column("type", sa.String(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.UniqueConstraint("post_id", "account_id", "type", name="uq_community_reaction_once"),
    )
    op.create_index("ix_community_reaction_post_id", "community_reaction", ["post_id"])
    op.create_index("ix_community_reaction_account_id", "community_reaction", ["account_id"])


def downgrade() -> None:
    op.drop_index("ix_community_reaction_account_id", table_name="community_reaction")
    op.drop_index("ix_community_reaction_post_id", table_name="community_reaction")
    op.drop_table("community_reaction")
    op.drop_index("ix_community_comment_status", table_name="community_comment")
    op.drop_index("ix_community_comment_author_id", table_name="community_comment")
    op.drop_index("ix_community_comment_post_id", table_name="community_comment")
    op.drop_table("community_comment")
    op.drop_index("ix_community_post_status", table_name="community_post")
    op.drop_index("ix_community_post_author_id", table_name="community_post")
    op.drop_table("community_post")
