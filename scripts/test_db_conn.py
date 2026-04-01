from sqlalchemy import create_engine, text

# Reconstructed from screenshots and IDs
DB_URL = "postgresql://zests_admin:PGqLnE79TwOMu6BDalkSJwoQPm70Mlrg@dpg-d6t2phi4d50c73c1vshg-a.oregon-postgres.render.com/zestsmvp_db"

def test_conn():
    try:
        engine = create_engine(DB_URL)
        with engine.connect() as conn:
            res = conn.execute(text("SELECT current_database()"))
            print(f"✅ connected to: {res.fetchone()[0]}")
            return True
    except Exception as e:
        print(f"❌ Connection failed: {e}")
        return False

if __name__ == "__main__":
    test_conn()
