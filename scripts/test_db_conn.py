import os
from sqlalchemy import create_engine, text

def test_conn():
    # Use DATABASE_URL from environment
    DB_URL = os.getenv("DATABASE_URL")
    
    if not DB_URL:
        print("FAILURE: DATABASE_URL environment variable is not set.")
        print("Please set it using: $env:DATABASE_URL = 'postgresql+psycopg://user:pass@host:port/db'")
        return False

    try:
        url = DB_URL
        # Normalize protocol for SQLAlchemy
        if url.startswith("postgres://"):
            url = url.replace("postgres://", "postgresql+psycopg://", 1)
        elif url.startswith("postgresql://") and "+psycopg" not in url:
             url = url.replace("postgresql://", "postgresql+psycopg://", 1)

        print(f"Testing connection to: {url.split('@')[-1]}") # Hide credentials
        engine = create_engine(url)
        with engine.connect() as conn:
            res = conn.execute(text("SELECT current_database()"))
            print(f"SUCCESS: Connected to database: {res.fetchone()[0]}")
            return True
    except Exception as e:
        print(f"FAILURE: Connection failed: {e}")
        return False

if __name__ == "__main__":
    test_conn()
