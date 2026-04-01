"""Add deleted_users table and drop events foreign key constraint

Revision ID: 20260401_0007
Revises: 20260401_0006
Create Date: 2026-04-01 22:30:00.000000

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = '20260401_0007'
down_revision = '20260401_0006'
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Create deleted_users table to archive soft-deleted users
    op.create_table(
        'deleted_users',
        sa.Column('id', sa.UUID(), nullable=False),
        sa.Column('original_user_id', sa.UUID(), nullable=False),
        sa.Column('role', sa.String(length=50), nullable=False),
        sa.Column('email', sa.String(length=255), nullable=True),
        sa.Column('first_name', sa.String(length=50), nullable=True),
        sa.Column('last_name', sa.String(length=50), nullable=True),
        sa.Column('deleted_at', sa.DateTime(timezone=True), nullable=False),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_deleted_users_original_user_id'), 'deleted_users', ['original_user_id'], unique=True)
    
    # Drop the strict Foreign Key constraint on organizer_user_id so we can retain their UUID locally.
    # We do a conditional check since SQLite does not support isolated ALTER TABLE DROP CONSTRAINT easily.
    bind = op.get_bind()
    if bind.dialect.name == "postgresql":
        op.execute("ALTER TABLE events DROP CONSTRAINT IF EXISTS events_organizer_user_id_fkey")


def downgrade() -> None:
    bind = op.get_bind()
    if bind.dialect.name == "postgresql":
        op.execute("ALTER TABLE events ADD CONSTRAINT events_organizer_user_id_fkey FOREIGN KEY(organizer_user_id) REFERENCES users(id) ON DELETE RESTRICT")
    
    op.drop_index(op.f('ix_deleted_users_original_user_id'), table_name='deleted_users')
    op.drop_table('deleted_users')
