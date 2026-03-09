"""Initial ZestS schema

Revision ID: 20260309_0001
Revises:
Create Date: 2026-03-09 22:55:00
"""

from alembic import op


# revision identifiers, used by Alembic.
revision = "20260309_0001"
down_revision = None
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute(
        """
        CREATE EXTENSION IF NOT EXISTS pgcrypto;

        DO $$
        BEGIN
            IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'user_role') THEN
                CREATE TYPE user_role AS ENUM ('parent', 'kid', 'trainer', 'organizer', 'admin');
            END IF;
            IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'gender_type') THEN
                CREATE TYPE gender_type AS ENUM ('male', 'female', 'other', 'unspecified');
            END IF;
            IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'event_status') THEN
                CREATE TYPE event_status AS ENUM ('draft', 'published', 'canceled', 'completed');
            END IF;
            IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'registration_status') THEN
                CREATE TYPE registration_status AS ENUM ('pending', 'confirmed', 'canceled');
            END IF;
            IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'payment_status') THEN
                CREATE TYPE payment_status AS ENUM ('initiated', 'success', 'failed', 'refunded');
            END IF;
        END $$;

        CREATE TABLE IF NOT EXISTS users (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            parent_id UUID REFERENCES users(id) ON DELETE SET NULL,
            role user_role NOT NULL DEFAULT 'parent',
            firebase_uid VARCHAR(128),
            google_uid VARCHAR(128),
            mobile_no VARCHAR(20),
            email VARCHAR(255),
            first_name VARCHAR(50),
            last_name VARCHAR(50),
            dob DATE,
            gender gender_type NOT NULL DEFAULT 'unspecified',
            country VARCHAR(100),
            state VARCHAR(100),
            city VARCHAR(100),
            address TEXT,
            favorite_sport VARCHAR(50) NOT NULL DEFAULT 'skating',
            profile_picture_url VARCHAR(500),
            is_active BOOLEAN NOT NULL DEFAULT TRUE,
            is_verified BOOLEAN NOT NULL DEFAULT FALSE,
            has_completed_profile BOOLEAN NOT NULL DEFAULT FALSE,
            created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
            updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
            last_login_at TIMESTAMPTZ,
            CONSTRAINT ck_users_kid_dob_required CHECK (role <> 'kid' OR dob IS NOT NULL)
        );

        CREATE UNIQUE INDEX IF NOT EXISTS uq_users_mobile_no ON users(mobile_no) WHERE mobile_no IS NOT NULL;
        CREATE UNIQUE INDEX IF NOT EXISTS uq_users_email ON users(email) WHERE email IS NOT NULL;
        CREATE UNIQUE INDEX IF NOT EXISTS uq_users_firebase_uid ON users(firebase_uid) WHERE firebase_uid IS NOT NULL;

        CREATE TABLE IF NOT EXISTS parent_profiles (
            user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
            max_kids_allowed INTEGER NOT NULL DEFAULT 3
        );

        CREATE TABLE IF NOT EXISTS trainer_profiles (
            user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
            school_name VARCHAR(100),
            club_name VARCHAR(100),
            specialization TEXT,
            experience_years INTEGER
        );

        CREATE TABLE IF NOT EXISTS organizer_profiles (
            user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
            org_name VARCHAR(120) NOT NULL,
            website_url VARCHAR(255),
            is_verified_org BOOLEAN NOT NULL DEFAULT FALSE
        );

        CREATE TABLE IF NOT EXISTS skater_profiles (
            user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
            skill_level VARCHAR(50),
            years_skating INTEGER,
            preferred_tracks TEXT,
            school_name VARCHAR(100)
        );

        CREATE TABLE IF NOT EXISTS static_pages (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            slug VARCHAR(100) NOT NULL UNIQUE,
            title VARCHAR(200) NOT NULL,
            content TEXT NOT NULL DEFAULT '',
            is_published BOOLEAN NOT NULL DEFAULT TRUE,
            updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
        );

        CREATE TABLE IF NOT EXISTS banners (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            title VARCHAR(200),
            image_url VARCHAR(500) NOT NULL,
            link_url VARCHAR(500),
            placement VARCHAR(50) NOT NULL DEFAULT 'home_top',
            display_order INTEGER NOT NULL DEFAULT 0,
            is_active BOOLEAN NOT NULL DEFAULT TRUE,
            created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
        );

        CREATE TABLE IF NOT EXISTS sponsors (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            name VARCHAR(120) NOT NULL,
            logo_url VARCHAR(500),
            website_url VARCHAR(500),
            is_active BOOLEAN NOT NULL DEFAULT TRUE
        );

        CREATE TABLE IF NOT EXISTS system_settings (
            key VARCHAR(100) PRIMARY KEY,
            value TEXT NOT NULL DEFAULT '',
            updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
        );

        CREATE TABLE IF NOT EXISTS support_issues (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            user_id UUID REFERENCES users(id) ON DELETE SET NULL,
            email VARCHAR(255),
            message VARCHAR(2000) NOT NULL,
            status VARCHAR(20) NOT NULL DEFAULT 'open',
            created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
        );

        CREATE TABLE IF NOT EXISTS events (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            organizer_user_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
            title VARCHAR(200) NOT NULL,
            description TEXT,
            start_at_utc TIMESTAMPTZ NOT NULL,
            end_at_utc TIMESTAMPTZ NOT NULL,
            location_name VARCHAR(120) NOT NULL,
            venue_city VARCHAR(100),
            latitude DOUBLE PRECISION,
            longitude DOUBLE PRECISION,
            banner_image_url VARCHAR(500),
            status event_status NOT NULL DEFAULT 'draft',
            created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
            updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
            CONSTRAINT ck_events_time_valid CHECK (end_at_utc > start_at_utc)
        );

        CREATE INDEX IF NOT EXISTS ix_events_start_at_utc ON events(start_at_utc);
        CREATE INDEX IF NOT EXISTS ix_events_status ON events(status);

        CREATE TABLE IF NOT EXISTS event_categories (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            event_id UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
            name VARCHAR(120) NOT NULL,
            skate_type VARCHAR(60),
            age_group VARCHAR(60),
            track_type VARCHAR(60),
            distance VARCHAR(30),
            gender_restriction VARCHAR(30),
            max_slots INTEGER NOT NULL DEFAULT 0,
            price NUMERIC(10, 2) NOT NULL DEFAULT 0,
            CONSTRAINT uq_event_categories_event_name UNIQUE (event_id, name)
        );

        CREATE TABLE IF NOT EXISTS payments (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            user_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
            event_id UUID NOT NULL REFERENCES events(id) ON DELETE RESTRICT,
            category_id UUID REFERENCES event_categories(id) ON DELETE SET NULL,
            provider VARCHAR(30) NOT NULL DEFAULT 'none',
            amount NUMERIC(10, 2) NOT NULL DEFAULT 0,
            currency VARCHAR(3) NOT NULL DEFAULT 'INR',
            status payment_status NOT NULL DEFAULT 'initiated',
            external_transaction_id VARCHAR(100),
            paid_at TIMESTAMPTZ
        );

        CREATE TABLE IF NOT EXISTS event_registrations (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            event_id UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
            category_id UUID NOT NULL REFERENCES event_categories(id) ON DELETE RESTRICT,
            user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            payment_id UUID REFERENCES payments(id) ON DELETE SET NULL,
            status registration_status NOT NULL DEFAULT 'pending',
            from_city VARCHAR(100),
            created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
            CONSTRAINT uq_event_registration UNIQUE (event_id, category_id, user_id)
        );

        CREATE TABLE IF NOT EXISTS event_results (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            event_id UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
            category_id UUID NOT NULL REFERENCES event_categories(id) ON DELETE RESTRICT,
            user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            rank INTEGER,
            timing_ms INTEGER,
            points_earned INTEGER NOT NULL DEFAULT 0,
            created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
            CONSTRAINT uq_event_result UNIQUE (event_id, category_id, user_id)
        );

        CREATE TABLE IF NOT EXISTS referrals (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            event_id UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
            referrer_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            referred_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            points INTEGER NOT NULL DEFAULT 0,
            created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
            CONSTRAINT uq_referral UNIQUE (event_id, referrer_user_id, referred_user_id)
        );

        CREATE TABLE IF NOT EXISTS notification_preferences (
            user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
            push_enabled BOOLEAN NOT NULL DEFAULT TRUE,
            email_enabled BOOLEAN NOT NULL DEFAULT TRUE,
            sms_enabled BOOLEAN NOT NULL DEFAULT FALSE,
            event_reminders BOOLEAN NOT NULL DEFAULT TRUE,
            marketing BOOLEAN NOT NULL DEFAULT FALSE
        );

        CREATE TABLE IF NOT EXISTS device_tokens (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            token VARCHAR(500) NOT NULL,
            platform VARCHAR(20) NOT NULL,
            created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
        );

        CREATE UNIQUE INDEX IF NOT EXISTS uq_device_tokens_token ON device_tokens(token);

        CREATE TABLE IF NOT EXISTS notifications (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            title VARCHAR(200) NOT NULL,
            body VARCHAR(2000) NOT NULL,
            data_json TEXT,
            is_read BOOLEAN NOT NULL DEFAULT FALSE,
            created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
        );

        CREATE TABLE IF NOT EXISTS audit_logs (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            user_id UUID REFERENCES users(id) ON DELETE SET NULL,
            level VARCHAR(10) NOT NULL DEFAULT 'INFO',
            action VARCHAR(100) NOT NULL,
            entity_type VARCHAR(50),
            entity_id UUID,
            metadata_json TEXT,
            ip_address VARCHAR(64),
            created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
        );

        CREATE INDEX IF NOT EXISTS ix_audit_logs_created_at ON audit_logs(created_at);

        INSERT INTO static_pages (slug, title, content)
        VALUES ('terms-and-conditions', 'Terms and Conditions', '')
        ON CONFLICT (slug) DO NOTHING;

        INSERT INTO static_pages (slug, title, content)
        VALUES (
            'about-us',
            'About Us',
            'Everyday, as our children spent three intense hours on the skating rink, we waited on the sidelines - watching, learning, and hoping we were making the right decisions for their future.'
        )
        ON CONFLICT (slug) DO NOTHING;
        """
    )


def downgrade() -> None:
    op.execute(
        """
        DROP TABLE IF EXISTS audit_logs;
        DROP TABLE IF EXISTS notifications;
        DROP TABLE IF EXISTS device_tokens;
        DROP TABLE IF EXISTS notification_preferences;
        DROP TABLE IF EXISTS referrals;
        DROP TABLE IF EXISTS event_results;
        DROP TABLE IF EXISTS event_registrations;
        DROP TABLE IF EXISTS payments;
        DROP TABLE IF EXISTS event_categories;
        DROP TABLE IF EXISTS events;
        DROP TABLE IF EXISTS support_issues;
        DROP TABLE IF EXISTS system_settings;
        DROP TABLE IF EXISTS sponsors;
        DROP TABLE IF EXISTS banners;
        DROP TABLE IF EXISTS static_pages;
        DROP TABLE IF EXISTS skater_profiles;
        DROP TABLE IF EXISTS organizer_profiles;
        DROP TABLE IF EXISTS trainer_profiles;
        DROP TABLE IF EXISTS parent_profiles;
        DROP TABLE IF EXISTS users;

        DROP TYPE IF EXISTS payment_status;
        DROP TYPE IF EXISTS registration_status;
        DROP TYPE IF EXISTS event_status;
        DROP TYPE IF EXISTS gender_type;
        DROP TYPE IF EXISTS user_role;
        """
    )
