import os
from sqlalchemy import create_engine, text

# Fallback to Render URL if env var not set
HARDCODED_URL = "postgresql://zests_admin:PGqLnE79TwOMu6BDalkSJwoQPm70Mlrg@dpg-d6t2phi4d50c73c1vshg-a.oregon-postgres.render.com/zestsmvp_db"
DB_URL = os.getenv("DATABASE_URL", HARDCODED_URL)

def test_conn():
    try:
        # Supabase often requires postgresql+psycopg
        url = DB_URL
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
