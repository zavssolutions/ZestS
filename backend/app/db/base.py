from sqlmodel import SQLModel
from sqlalchemy import text, inspect

# Import models so SQLModel metadata is complete before create_all/migrations.
from app import models  # noqa: F401


def _patch_missing_columns(engine) -> None:
    """Add columns that may be missing from existing tables.
    
    SQLModel.metadata.create_all only creates new tables – it never adds 
    columns to tables that already exist. This helper bridges the gap for 
    deployments where Alembic migrations haven't run (or failed silently).
    """
    import logging
    logger = logging.getLogger(__name__)
    patches = [
        ("banners", "share_url", "VARCHAR(500)"),
    ]
    try:
        with engine.connect() as conn:
            # Check existing columns via raw SQL (more reliable than inspect)
            for table, column, col_type in patches:
                try:
                    result = conn.execute(text(
                        "SELECT column_name FROM information_schema.columns "
                        "WHERE table_name = :tbl AND column_name = :col"
                    ), {"tbl": table, "col": column})
                    if result.fetchone() is None:
                        conn.execute(text(f'ALTER TABLE "{table}" ADD COLUMN "{column}" {col_type}'))
                        conn.commit()
                        logger.info(f"Patched: added {column} to {table}")
                    else:
                        logger.info(f"Column {table}.{column} already exists")
                except Exception as col_err:
                    logger.error(f"Failed to patch {table}.{column}: {col_err}")
                    try:
                        conn.rollback()
                    except Exception:
                        pass
    except Exception as e:
        logger.error(f"_patch_missing_columns error: {e}")


def create_db_and_tables(engine) -> None:
    SQLModel.metadata.create_all(engine)
    _patch_missing_columns(engine)
