"""allow reviewed public FPS references

Revision ID: 20260715_0014
Revises: 20260715_0013
Create Date: 2026-07-15
"""

from alembic import op


revision = "20260715_0014"
down_revision = "20260715_0013"
branch_labels = None
depends_on = None


TABLE_CONSTRAINTS = (
    ("hardware_performance_profile", "ck_hardware_perf_source_kind"),
    ("game_performance_anchor", "ck_game_perf_anchor_source_kind"),
)


def upgrade() -> None:
    _replace_source_constraints(include_public_reference=True)


def downgrade() -> None:
    _replace_source_constraints(include_public_reference=False)


def _replace_source_constraints(include_public_reference: bool) -> None:
    source_kinds = "'self_measured', 'licensed', 'open_license'"
    if include_public_reference:
        source_kinds += ", 'public_reference'"
    for table_name, constraint_name in TABLE_CONSTRAINTS:
        with op.batch_alter_table(table_name) as batch_op:
            batch_op.drop_constraint(constraint_name, type_="check")
            batch_op.create_check_constraint(
                constraint_name,
                f"source_kind IN ({source_kinds})",
            )
