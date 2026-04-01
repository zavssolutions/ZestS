"""Add skate_type and age_group to users and skater_profiles

Revision ID: 20260329_0005
Revises: 20260325_0004
Create Date: 2026-03-29 17:15:00.000000

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = '20260329_0005'
down_revision = '20260325_0004'
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Add to users table
    op.add_column('users', sa.Column('skate_type', sa.String(length=60), nullable=True))
    op.add_column('users', sa.Column('age_group', sa.String(length=60), nullable=True))
    
    # Add to skater_profiles table (if not exists)
    # Using a slightly safer approach for skater_profiles since we saw it partially exists in some versions
    op.execute("""
        DO $$
        BEGIN
            IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='skater_profiles' AND column_name='skate_type') THEN
                ALTER TABLE skater_profiles ADD COLUMN skate_type VARCHAR(60);
            END IF;
            IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='skater_profiles' AND column_name='age_group') THEN
                ALTER TABLE skater_profiles ADD COLUMN age_group VARCHAR(60);
            END IF;
        END $$;
    """)


def downgrade() -> None:
    op.drop_column('skater_profiles', 'age_group')
    op.drop_column('skater_profiles', 'skate_type')
    op.drop_column('users', 'age_group')
    op.drop_column('users', 'skate_type')
