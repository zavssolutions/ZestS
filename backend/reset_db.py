import logging
import time
from sqlalchemy import create_engine, text
from app.core.config import get_settings

# Configure logging
logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s [%(name)s] %(message)s")
logger = logging.getLogger(__name__)

def reset_database_cleanly():
    """Terminate connections and drop the database."""
    settings = get_settings()
    db_name = "zests"
    # Connect to the 'postgres' database instead of 'zests' to allow dropping 'zests'
    base_url = settings.database_url.rsplit("/", 1)[0] + "/postgres"
    
    logger.info(f"Connecting to management database: {base_url}")
    engine = create_engine(base_url, isolation_level="AUTOCOMMIT")
    
    try:
        with engine.connect() as conn:
            logger.info(f"Terminating all connections to {db_name}...")
            # Use pg_terminate_backend to kill other connections
            conn.execute(text(f"""
                SELECT pg_terminate_backend(pg_stat_activity.pid)
                FROM pg_stat_activity
                WHERE pg_stat_activity.datname = '{db_name}'
                  AND pid <> pg_backend_pid();
            """))
            logger.info("Connections terminated.")
            
            # Wait a moment for connections to fully close
            time.sleep(1)
            
            logger.info(f"Dropping database {db_name}...")
            conn.execute(text(f"DROP DATABASE IF EXISTS {db_name};"))
            logger.info("Database dropped.")
            
            logger.info(f"Recreating database {db_name}...")
            conn.execute(text(f"CREATE DATABASE {db_name};"))
            logger.info("Database recreated.")

        # Now connect to the new zests DB to enable extensions
        logger.info(f"Enabling extensions in {db_name}...")
        zests_engine = create_engine(settings.database_url, isolation_level="AUTOCOMMIT")
        with zests_engine.connect() as conn:
            conn.execute(text("CREATE EXTENSION IF NOT EXISTS pgcrypto;"))
        logger.info("Extensions enabled.")

        logger.info("Database reset completed successfully.")
    except Exception as e:
        logger.error(f"Error during clean reset: {e}")

if __name__ == "__main__":
    reset_database_cleanly()
