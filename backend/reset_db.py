import logging
from sqlalchemy import create_engine, text
from app.core.config import get_settings

# Configure logging
logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s [%(name)s] %(message)s")
logger = logging.getLogger(__name__)

def reset_database_cleanly():
    """Drop all tables and custom types in the current database schema."""
    settings = get_settings()
    
    logger.info(f"Connecting to database: {settings.database_url}")
    engine = create_engine(settings.database_url, isolation_level="AUTOCOMMIT")
    
    try:
        with engine.connect() as conn:
            logger.info("Starting database reset (dropping all tables and enums)...")
            
            # 1. Drop all tables in the public schema
            logger.info("Dropping all tables...")
            conn.execute(text("""
                DO $$ 
                DECLARE 
                    r RECORD;
                BEGIN
                    FOR r IN (SELECT tablename FROM pg_tables WHERE schemaname = 'public') LOOP
                        EXECUTE 'DROP TABLE IF EXISTS ' || quote_ident(r.tablename) || ' CASCADE';
                    END LOOP;
                END $$;
            """))

            # 2. Drop all custom types (enums)
            logger.info("Dropping all custom types (enums)...")
            conn.execute(text("""
                DO $$ 
                DECLARE 
                    r RECORD;
                BEGIN
                    FOR r IN (SELECT typname FROM pg_type t JOIN pg_namespace n ON n.oid = t.typnamespace WHERE n.nspname = 'public' AND typtype = 'e') LOOP
                        EXECUTE 'DROP TYPE IF EXISTS ' || quote_ident(r.typname) || ' CASCADE';
                    END LOOP;
                END $$;
            """))

            # 3. Drop extensions (carefully, primarily pgcrypto)
            logger.info("Dropping extensions...")
            conn.execute(text("DROP EXTENSION IF EXISTS pgcrypto CASCADE;"))
            
            # 4. Clear alembic_version table if it exists (though CASCADE drop table should have handled it)
            conn.execute(text("DROP TABLE IF EXISTS alembic_version CASCADE;"))

        logger.info("Database reset completed successfully.")
    except Exception as e:
        logger.error(f"Error during database reset: {e}")
        raise e

if __name__ == "__main__":
    reset_database_cleanly()
