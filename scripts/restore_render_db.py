"""
Restore tables from a JSON backup into a PostgreSQL database.

Usage:
    set DATABASE_URL=postgresql+psycopg://user:pass@host:port/db
    python scripts/restore_render_db.py

Or pass the DB URL directly:
    python scripts/restore_render_db.py "postgresql+psycopg://user:pass@host/db"

This script:
  1. Reads the schema.sql from infra/backup/ and creates the tables
  2. Inserts rows from each tables/*.json file
  3. Reports row counts after import

IMPORTANT: This is additive — it will NOT drop existing tables.
           Use --drop-first flag to drop and recreate.
"""
import json
import os
import sys

from sqlalchemy import create_engine, text


def main():
    drop_first = "--drop-first" in sys.argv
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    db_url = args[0] if args else os.getenv("DATABASE_URL")
    if not db_url:
        print("ERROR: Provide DATABASE_URL as env var or first argument.")
        sys.exit(1)

    if db_url.startswith("postgres://"):
        db_url = db_url.replace("postgres://", "postgresql+psycopg://", 1)

    engine = create_engine(db_url)

    backup_dir = os.path.join(os.path.dirname(__file__), "..", "infra", "backup")
    tables_dir = os.path.join(backup_dir, "tables")
    schema_path = os.path.join(backup_dir, "schema.sql")
    meta_path = os.path.join(backup_dir, "metadata.json")

    if not os.path.exists(meta_path):
        print(f"ERROR: No backup found at {backup_dir}")
        print("Run scripts/backup_render_db.py first.")
        sys.exit(1)

    with open(meta_path, "r", encoding="utf-8") as f:
        metadata = json.load(f)

    print(f"Restoring backup from: {metadata['backup_time']}")
    print(f"Tables: {len(metadata['tables'])}")

    with engine.connect() as conn:
        # Step 1: Create schema
        if os.path.exists(schema_path):
            print("\n── Creating schema ──")
            with open(schema_path, "r", encoding="utf-8") as f:
                schema_sql = f.read()
            for statement in schema_sql.split(";"):
                stmt = statement.strip()
                if stmt and not stmt.startswith("--"):
                    try:
                        conn.execute(text(stmt))
                        conn.commit()
                    except Exception as e:
                        conn.rollback()
                        # Skip if table already exists
                        if "already exists" not in str(e):
                            print(f"  Warning: {e}")

        # Step 2: Insert rows from JSON backups
        print("\n── Restoring data ──")
        for table_name, info in sorted(metadata["tables"].items()):
            json_path = os.path.join(tables_dir, f"{table_name}.json")
            if not os.path.exists(json_path):
                print(f"  {table_name}: SKIP (no JSON file)")
                continue

            with open(json_path, "r", encoding="utf-8") as f:
                rows = json.load(f)

            if not rows:
                print(f"  {table_name}: 0 rows (empty)")
                continue

            if drop_first:
                try:
                    conn.execute(text(f'DELETE FROM "{table_name}"'))
                    conn.commit()
                except Exception:
                    conn.rollback()

            inserted = 0
            for row in rows:
                cols = list(row.keys())
                placeholders = ", ".join(f":{c}" for c in cols)
                col_names = ", ".join(f'"{c}"' for c in cols)
                try:
                    conn.execute(
                        text(f'INSERT INTO "{table_name}" ({col_names}) VALUES ({placeholders})'),
                        row,
                    )
                    conn.commit()
                    inserted += 1
                except Exception as e:
                    conn.rollback()
                    if "duplicate key" not in str(e) and "unique constraint" not in str(e).lower():
                        print(f"    Error inserting into {table_name}: {e}")

            print(f"  {table_name}: {inserted}/{len(rows)} rows restored")

    print("\n✅ Restore complete!")


if __name__ == "__main__":
    main()
