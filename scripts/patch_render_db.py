"""
Standalone script to patch missing columns in the production (Render) PostgreSQL database.

Usage:
    set DATABASE_URL=postgresql+psycopg://user:pass@host:port/db
    python scripts/patch_render_db.py

Or pass the Render internal DB URL directly:
    python scripts/patch_render_db.py "postgresql+psycopg://user:pass@host:port/db"
"""
import sys
from sqlalchemy import create_engine, text


def main():
    db_url = None
    if len(sys.argv) > 1:
        db_url = sys.argv[1]
    else:
        import os
        db_url = os.getenv("DATABASE_URL")

    if not db_url:
        print("ERROR: Provide DATABASE_URL as env var or first argument.")
        print("  Example: python scripts/patch_render_db.py 'postgresql+psycopg://user:pass@host/db'")
        sys.exit(1)

    # Render provides postgres:// but SQLAlchemy requires postgresql://
    if db_url.startswith("postgres://"):
        db_url = db_url.replace("postgres://", "postgresql+psycopg://", 1)

    print(f"Connecting to: {db_url[:40]}...")
    engine = create_engine(db_url)

    patches = [
        "ALTER TABLE banners ADD COLUMN IF NOT EXISTS share_url VARCHAR(500)",
    ]

    with engine.connect() as conn:
        for sql in patches:
            try:
                conn.execute(text(sql))
                conn.commit()
                print(f"  OK: {sql}")
            except Exception as e:
                print(f"  FAILED: {sql} -> {e}")

    print("\nDone! The banners table should now have the share_url column.")


if __name__ == "__main__":
    main()
