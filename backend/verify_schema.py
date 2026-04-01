
import sys
import os
from sqlalchemy import create_engine, text
from sqlalchemy.engine import url

# Add current directory to path to reach app module
sys.path.append(os.getcwd())

try:
    from app.core.config import get_settings
    settings = get_settings()
    db_url = settings.database_url
except Exception as e:
    print(f"Error loading settings: {e}")
    sys.exit(1)

print(f"Connecting to: {db_url}")
engine = create_engine(db_url)

def check_column(conn, table, column):
    query = text(
        "SELECT data_type FROM information_schema.columns "
        "WHERE table_name = :tbl AND column_name = :col"
    )
    result = conn.execute(query, {"tbl": table, "col": column}).fetchone()
    return result[0] if result else None

def verify():
    with engine.connect() as conn:
        checks = [
            ("banners", "share_url"),
            ("events", "price"),
            ("events", "organizer_id"),
            ("event_categories", "category_type"),
            ("organizer_profiles", "organizer_id"),
        ]
        
        print("\n--- Column Existence Check ---")
        for table, col in checks:
            dtype = check_column(conn, table, col)
            status = f"EXISTS ({dtype})" if dtype else "MISSING"
            print(f"{table}.{col}: {status}")

        print("\n--- Enum to Varchar Conversion Check ---")
        enums = [
            ("users", "role"),
            ("users", "sport"),
            ("users", "gender"),
            ("events", "status"),
            ("event_registrations", "status"),
        ]
        for table, col in enums:
            dtype = check_column(conn, table, col)
            print(f"{table}.{col}: {dtype}")

if __name__ == "__main__":
    try:
        verify()
    except Exception as e:
        print(f"Verification failed: {e}")
