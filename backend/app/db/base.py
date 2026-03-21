from sqlmodel import SQLModel
from sqlalchemy import text

# Import models so SQLModel metadata is complete before create_all/migrations.
from app import models  # noqa: F401


def _patch_missing_columns(engine) -> None:
    """Add columns that may be missing from existing tables.
    
    Uses PostgreSQL's ADD COLUMN IF NOT EXISTS to safely patch columns.
    On SQLite (tests), this is silently skipped.
    """
    import logging
    logger = logging.getLogger(__name__)
    patches = [
        'ALTER TABLE banners ADD COLUMN IF NOT EXISTS share_url VARCHAR(500)',
        # Convert native PG enum columns to VARCHAR to avoid name/value mismatch
        "ALTER TABLE users ALTER COLUMN role TYPE VARCHAR(20) USING role::text",
        "ALTER TABLE users ALTER COLUMN sport TYPE VARCHAR(20) USING sport::text",
        "ALTER TABLE users ALTER COLUMN gender TYPE VARCHAR(20) USING gender::text",
    ]
    try:
        with engine.connect() as conn:
            for sql in patches:
                try:
                    conn.execute(text(sql))
                    conn.commit()
                    logger.info(f"Schema patch OK: {sql}")
                except Exception as e:
                    # SQLite doesn't support IF NOT EXISTS for ADD COLUMN
                    logger.warning(f"Schema patch skipped: {e}")
                    try:
                        conn.rollback()
                    except Exception:
                        pass
    except Exception as e:
        logger.error(f"_patch_missing_columns connection error: {e}")


def create_db_and_tables(engine) -> None:
    SQLModel.metadata.create_all(engine)
    _patch_missing_columns(engine)
