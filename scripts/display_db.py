import os
import sys

# Automatically add the backend directory to sys.path
root_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
backend_dir = os.path.join(root_dir, "backend")
if backend_dir not in sys.path:
    sys.path.append(backend_dir)

from sqlmodel import SQLModel, create_engine
from app.core.config import get_settings
from app import models

def get_engine():
    # Attempt to fetch the URL natively from the environment or settings.
    # The default from settings is usually localhost.
    settings = get_settings()
    db_url = os.getenv("DATABASE_URL", settings.database_url)
    
    # Render provides postgres:// but SQLAlchemy requires postgresql://
    if db_url and db_url.startswith("postgres://"):
        db_url = db_url.replace("postgres://", "postgresql+psycopg://")
        
    print(f"Connecting to database via URL: {db_url}")
    return create_engine(db_url)

def main():
    engine = get_engine()
    
    with engine.connect() as conn:
        print("\n=== DISPLAYING ALL TABLES IN THE RENDER DATABASE ===")
        # We loop through all registered models in the SQLModel metadata mapper
        for table_name, table in SQLModel.metadata.tables.items():
            print(f"\n--- TABLE: {table_name.upper()} ---")
            
            try:
                result = conn.execute(table.select())
                rows = result.fetchall()
                if not rows:
                    print(" (empty)")
                for row in rows:
                    print(" ", dict(row._mapping))
            except Exception as e:
                print(f" (Error querying table {table_name}: {e})")

if __name__ == "__main__":
    main()
