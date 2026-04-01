"""Add parent_child_mapping table

Revision ID: 20260401_0006
Revises: 20260329_0005
Create Date: 2026-04-01 10:00:00.000000

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = '20260401_0006'
down_revision = '20260329_0005'
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        'parent_child_mapping',
        sa.Column('id', sa.UUID(), nullable=False),
        sa.Column('parent_id', sa.UUID(), nullable=False),
        sa.Column('child_id', sa.UUID(), nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index('ix_parent_child_mapping_parent_id', 'parent_child_mapping', ['parent_id'], unique=False)
    op.create_index('ix_parent_child_mapping_child_id', 'parent_child_mapping', ['child_id'], unique=False)
    op.create_foreign_key('fk_parent_child_mapping_parent_id', 'parent_child_mapping', 'users', ['parent_id'], ['id'])
    op.create_foreign_key('fk_parent_child_mapping_child_id', 'parent_child_mapping', 'users', ['child_id'], ['id'])


def downgrade() -> None:
    op.drop_table('parent_child_mapping')
