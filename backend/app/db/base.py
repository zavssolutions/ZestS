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

            # 2. events.price — add if missing
            if _col_type("events", "price") is None:
                conn.execute(text("ALTER TABLE events ADD COLUMN price NUMERIC DEFAULT 0"))
                conn.commit()
                logger.info("Patched: added events.price")

            # 3. events.organizer_id — add if missing
            if _col_type("events", "organizer_id") is None:
                conn.execute(text("ALTER TABLE events ADD COLUMN organizer_id INTEGER"))
                conn.commit()
                logger.info("Patched: added events.organizer_id")

            # 4. event_categories.category_type — add if missing
            if _col_type("event_categories", "category_type") is None:
                conn.execute(text("ALTER TABLE event_categories ADD COLUMN category_type VARCHAR(50)"))
                conn.commit()
                logger.info("Patched: added event_categories.category_type")

            # 5. organizer_profiles.organizer_id & city — add if missing
            if _col_type("organizer_profiles", "organizer_id") is None:
                conn.execute(text("ALTER TABLE organizer_profiles ADD COLUMN organizer_id SERIAL"))
                conn.commit()
                logger.info("Patched: added organizer_profiles.organizer_id")
            if _col_type("organizer_profiles", "city") is None:
                conn.execute(text("ALTER TABLE organizer_profiles ADD COLUMN city VARCHAR(100)"))
                conn.commit()
                logger.info("Patched: added organizer_profiles.city")

            # 6. users.city — add if missing
            if _col_type("users", "city") is None:
                conn.execute(text("ALTER TABLE users ADD COLUMN city VARCHAR(100)"))
                conn.commit()
                logger.info("Patched: added users.city")

            # 7. Add images_url, other_urls, and city to events and event_categories
            for tbl in ["events", "event_categories"]:
                if _col_type(tbl, "images_url") is None:
                    conn.execute(text(f"ALTER TABLE {tbl} ADD COLUMN images_url JSONB"))
                    logger.info(f"Patched: added {tbl}.images_url")
                if _col_type(tbl, "other_urls") is None:
                    conn.execute(text(f"ALTER TABLE {tbl} ADD COLUMN other_urls JSONB"))
                    logger.info(f"Patched: added {tbl}.other_urls")
                if _col_type(tbl, "city") is None:
                    conn.execute(text(f"ALTER TABLE {tbl} ADD COLUMN city VARCHAR(100)"))
                    logger.info(f"Patched: added {tbl}.city")
                conn.commit()

            # 9. Convert native PG enum columns to VARCHAR (one-time)
            enum_cols = [
                ("users", "role"),
                ("users", "sport"),
                ("users", "gender"),
                ("events", "status"),
                ("event_registrations", "status"),
            ]
            for table, col in enum_cols:
                dtype = _col_type(table, col)
                if dtype and dtype.upper() == "USER-DEFINED":
                    conn.execute(text(
                        f"ALTER TABLE {table} ALTER COLUMN {col} TYPE VARCHAR(20) USING {col}::text"
                    ))
                    conn.commit()
                    logger.info(f"Patched: converted {table}.{col} from enum to varchar")

    except Exception as e:
        # SQLite or connection issues — silently skip
        import logging as _l
        _l.getLogger(__name__).debug(f"Schema patch skipped (non-PG): {e}")


def create_db_and_tables(engine) -> None:
    SQLModel.metadata.create_all(engine)
    _patch_schema(engine)
