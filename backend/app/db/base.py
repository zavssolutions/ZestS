from sqlmodel import SQLModel
from sqlalchemy import text

# Import models so SQLModel metadata is complete before create_all/migrations.
from app import models  # noqa: F401


def _patch_schema(engine) -> None:
    """One-time schema patches for production PostgreSQL.

    Each patch checks whether it's needed before executing,
    so this is a no-op on subsequent boots.
    On SQLite (tests) all checks fail gracefully.
    """
    import logging
    logger = logging.getLogger(__name__)

    try:
        with engine.connect() as conn:

            def _col_type(table: str, column: str) -> str | None:
                """Return the data_type of a column, or None."""
                row = conn.execute(text(
                    "SELECT data_type FROM information_schema.columns "
                    "WHERE table_name = :tbl AND column_name = :col"
                ), {"tbl": table, "col": column}).fetchone()
                return row[0] if row else None

            # 1. banners.share_url — add if missing
            if _col_type("banners", "share_url") is None:
                conn.execute(text("ALTER TABLE banners ADD COLUMN share_url VARCHAR(500)"))
                conn.commit()
                logger.info("Patched: added banners.share_url")

            # 2. Convert native PG enum columns to VARCHAR (one-time)
            for col in ("role", "sport", "gender"):
                dtype = _col_type("users", col)
                if dtype and dtype.upper() == "USER-DEFINED":
                    conn.execute(text(
                        f"ALTER TABLE users ALTER COLUMN {col} TYPE VARCHAR(20) USING {col}::text"
                    ))
                    conn.commit()
                    logger.info(f"Patched: converted users.{col} from enum to varchar")

    except Exception as e:
        # SQLite or connection issues — silently skip
        import logging as _l
        _l.getLogger(__name__).debug(f"Schema patch skipped (non-PG): {e}")


def create_db_and_tables(engine) -> None:
    SQLModel.metadata.create_all(engine)
    _patch_schema(engine)
