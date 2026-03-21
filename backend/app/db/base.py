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
    patches = [
        ("banners", "share_url", "VARCHAR(500)"),
    ]
    with engine.connect() as conn:
        inspector = inspect(engine)
        for table, column, col_type in patches:
            if table not in inspector.get_table_names():
                continue
            existing = [c["name"] for c in inspector.get_columns(table)]
            if column not in existing:
                conn.execute(text(f"ALTER TABLE {table} ADD COLUMN {column} {col_type}"))
                conn.commit()


def create_db_and_tables(engine) -> None:
    SQLModel.metadata.create_all(engine)
    _patch_missing_columns(engine)
