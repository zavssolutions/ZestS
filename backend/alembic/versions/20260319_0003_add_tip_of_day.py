"""add tip of day

Revision ID: 20260319_0003
Revises: 20260317_0002
Create Date: 2026-03-19
"""

from alembic import op
import sqlalchemy as sa


revision = "20260319_0003"
down_revision = "20260317_0002"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "tip_of_day",
        sa.Column("serial_no", sa.Integer(), primary_key=True, autoincrement=True, nullable=False),
        sa.Column("date", sa.Date(), nullable=False, unique=True),
        sa.Column("content", sa.String(length=500), nullable=False),
        sa.Column("is_url", sa.Boolean(), nullable=False, server_default=sa.text("false")),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
    )
    op.create_index(op.f("ix_tip_of_day_date"), "tip_of_day", ["date"], unique=False)


def downgrade() -> None:
    op.drop_index(op.f("ix_tip_of_day_date"), table_name="tip_of_day")
    op.drop_table("tip_of_day")

