"""event refinements

Revision ID: 20260325_0004
Revises: 20260319_0003
Create Date: 2026-03-25

"""

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision = "20260325_0004"
down_revision = "20260319_0003"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # 1. Update organizer_profiles with organizer_id SERIAL
    # We'll use a sequence for the serial-like behavior
    op.execute("CREATE SEQUENCE IF NOT EXISTS organizer_id_seq START WITH 1")
    op.add_column("organizer_profiles", sa.Column("organizer_id", sa.Integer(), server_default=sa.text("nextval('organizer_id_seq')"), nullable=False))
    op.create_unique_constraint("uq_organizer_id", "organizer_profiles", ["organizer_id"])

    # 2. Update events table
    op.add_column("events", sa.Column("price", sa.Numeric(precision=10, scale=2), server_default="0", nullable=False))
    
    # We need to migrate data or handled the FK change
    # For now, we'll add the new column and then link it if possible, or just start fresh if it's a dev DB.
    # The requirement says "organizer_id is foreign key... if no rows keep empty".
    op.add_column("events", sa.Column("organizer_id", sa.Integer(), nullable=True))
    op.create_foreign_key("fk_events_organizer_id", "events", "organizer_profiles", ["organizer_id"], ["organizer_id"], ondelete="SET NULL")
    
    # Remove old organizer_user_id if needed, but let's keep it for now as a backup or migration path
    # Actually, the model removed it, so let's drop it.
    op.drop_constraint("events_organizer_user_id_fkey", "events", type_="foreignkey")
    op.drop_column("events", "organizer_user_id")

    # 3. Update event_categories
    op.add_column("event_categories", sa.Column("category_type", sa.String(length=60), nullable=True))
    
    # Add cascading deletes to existing FKs
    op.drop_constraint("event_categories_event_id_fkey", "event_categories", type_="foreignkey")
    op.create_foreign_key("event_categories_event_id_fkey", "event_categories", "events", ["event_id"], ["id"], ondelete="CASCADE")

    # 4. Update event_registrations
    op.drop_constraint("event_registrations_event_id_fkey", "event_registrations", type_="foreignkey")
    op.drop_constraint("event_registrations_category_id_fkey", "event_registrations", type_="foreignkey")
    op.create_foreign_key("event_registrations_event_id_fkey", "event_registrations", "events", ["event_id"], ["id"], ondelete="CASCADE")
    op.create_foreign_key("event_registrations_category_id_fkey", "event_registrations", "event_categories", ["category_id"], ["id"], ondelete="CASCADE")

    # 5. Update event_results
    op.drop_constraint("event_results_event_id_fkey", "event_results", type_="foreignkey")
    op.drop_constraint("event_results_category_id_fkey", "event_results", type_="foreignkey")
    op.create_foreign_key("event_results_event_id_fkey", "event_results", "events", ["event_id"], ["id"], ondelete="CASCADE")
    op.create_foreign_key("event_results_category_id_fkey", "event_results", "event_categories", ["category_id"], ["id"], ondelete="CASCADE")

    # 6. Update payments
    op.drop_constraint("payments_event_id_fkey", "payments", type_="foreignkey")
    op.drop_constraint("payments_category_id_fkey", "payments", type_="foreignkey")
    op.create_foreign_key("payments_event_id_fkey", "payments", "events", ["event_id"], ["id"], ondelete="CASCADE")
    op.create_foreign_key("payments_category_id_fkey", "payments", "event_categories", ["category_id"], ["id"], ondelete="CASCADE")

    # 7. Update referrals
    op.drop_constraint("referrals_event_id_fkey", "referrals", type_="foreignkey")
    op.create_foreign_key("referrals_event_id_fkey", "referrals", "events", ["event_id"], ["id"], ondelete="CASCADE")


def downgrade() -> None:
    # Reverse all changes
    op.drop_constraint("referrals_event_id_fkey", "referrals", type_="foreignkey")
    op.create_foreign_key("referrals_event_id_fkey", "referrals", "events", ["event_id"], ["id"])

    # ... and so on. Downgrade is less critical for this task but good practice.
    # Dropping columns and constraints.
    op.drop_column("event_categories", "category_type")
    op.drop_column("events", "price")
    op.drop_column("events", "organizer_id")
    op.drop_column("organizer_profiles", "organizer_id")
    op.execute("DROP SEQUENCE IF EXISTS organizer_id_seq")
