"""
Export all tables from the Render PostgreSQL database to JSON files.

Usage:
    set DATABASE_URL=postgresql+psycopg://user:pass@host:port/db
    python scripts/backup_render_db.py

Or pass the Render DB URL directly:
    python scripts/backup_render_db.py "postgresql+psycopg://user:pass@host/db"

Output:
    Creates a backup/ folder with:
    - tables/*.json        — one JSON file per table with all rows
    - schema.sql           — full CREATE TABLE DDL
    - metadata.json        — backup timestamp and table row counts
"""
import json
import os
import sys
from datetime import datetime, timezone

from sqlalchemy import create_engine, inspect, text


def main():
    db_url = sys.argv[1] if len(sys.argv) > 1 else os.getenv("DATABASE_URL")
    if not db_url:
        print("ERROR: Provide DATABASE_URL as env var or first argument.")
        sys.exit(1)

    if db_url.startswith("postgres://"):
        db_url = db_url.replace("postgres://", "postgresql+psycopg://", 1)

    engine = create_engine(db_url)
    inspector = inspect(engine)

    # Output directory
    backup_dir = os.path.join(os.path.dirname(__file__), "..", "infra", "backup")
    tables_dir = os.path.join(backup_dir, "tables")
    os.makedirs(tables_dir, exist_ok=True)

    metadata = {
        "backup_time": datetime.now(timezone.utc).isoformat(),
        "database_url_host": db_url.split("@")[-1].split("/")[0] if "@" in db_url else "unknown",
        "tables": {},
    }

    table_names = inspector.get_table_names()
    print(f"Found {len(table_names)} tables")

    with engine.connect() as conn:
        # ── Export each table to JSON ──
        for table_name in sorted(table_names):
            print(f"  Exporting {table_name}...", end="")
            try:
                result = conn.execute(text(f'SELECT * FROM "{table_name}"'))
                columns = list(result.keys())
                rows = []
                for row in result.fetchall():
                    record = {}
                    for col, val in zip(columns, row):
                        # Convert non-serialisable types
                        if isinstance(val, (datetime,)):
                            val = val.isoformat()
                        elif hasattr(val, "__str__") and not isinstance(val, (str, int, float, bool, type(None))):
                            val = str(val)
                        record[col] = val
                    rows.append(record)

                out_path = os.path.join(tables_dir, f"{table_name}.json")
                with open(out_path, "w", encoding="utf-8") as f:
                    json.dump(rows, f, indent=2, default=str, ensure_ascii=False)

                metadata["tables"][table_name] = {"row_count": len(rows), "columns": columns}
                print(f" {len(rows)} rows")
            except Exception as e:
                print(f" ERROR: {e}")

        # ── Export DDL schema ──
        print("\n  Exporting schema DDL...")
        schema_lines = []
        for table_name in sorted(table_names):
            try:
                ddl = conn.execute(text(
                    "SELECT pg_catalog.pg_get_tabledef(:schema, :tbl)"
                ), {"schema": "public", "tbl": table_name}).scalar()
                schema_lines.append(f"-- Table: {table_name}\n{ddl}\n")
            except Exception:
                # pg_get_tabledef may not exist; fall back to information_schema
                cols = inspector.get_columns(table_name)
                pk = inspector.get_pk_constraint(table_name)
                col_defs = []
                for c in cols:
                    nullable = "" if c["nullable"] else " NOT NULL"
                    default = f" DEFAULT {c['default']}" if c.get("default") else ""
                    col_defs.append(f'  "{c["name"]}" {c["type"]}{nullable}{default}')
                if pk and pk.get("constrained_columns"):
                    pk_cols = ", ".join(f'"{c}"' for c in pk["constrained_columns"])
                    col_defs.append(f"  PRIMARY KEY ({pk_cols})")
                ddl = f'CREATE TABLE IF NOT EXISTS "{table_name}" (\n' + ",\n".join(col_defs) + "\n);"
                schema_lines.append(f"-- Table: {table_name}\n{ddl}\n")

        schema_path = os.path.join(backup_dir, "schema.sql")
        with open(schema_path, "w", encoding="utf-8") as f:
            f.write("\n\n".join(schema_lines))

    # ── Save metadata ──
    meta_path = os.path.join(backup_dir, "metadata.json")
    with open(meta_path, "w", encoding="utf-8") as f:
        json.dump(metadata, f, indent=2)

    print(f"\n✅ Backup complete → {os.path.abspath(backup_dir)}")
    print(f"   {len(table_names)} tables exported")
    print(f"   Schema DDL → schema.sql")
    print(f"   Metadata   → metadata.json")


if __name__ == "__main__":
    main()
