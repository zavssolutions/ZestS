import psycopg2
import os
import sys

# DATABASE_URL env var or fallback
DB_URL = os.getenv("DATABASE_URL")
if not DB_URL:
    print("ERROR: DATABASE_URL environment variable is not set.")
    sys.exit(1)

# Ensure protocol is correct for psycopg2 (if using raw psycopg2 without SQLAlchemy)
if DB_URL.startswith("postgresql+psycopg://"):
    DB_URL = DB_URL.replace("postgresql+psycopg://", "postgresql://")

def fix_db():
    try:
        print(f"Connecting to database...")
        conn = psycopg2.connect(DB_URL)
        cur = conn.cursor()
        
        print("Checking/Fixing skater_profiles...")
        # Add skate_type
        cur.execute("SELECT 1 FROM information_schema.columns WHERE table_name='skater_profiles' AND column_name='skate_type'")
        if not cur.fetchone():
            print("Adding column 'skate_type' to 'skater_profiles'...")
            cur.execute("ALTER TABLE skater_profiles ADD COLUMN skate_type VARCHAR(60)")
        
        # Add age_group
        cur.execute("SELECT 1 FROM information_schema.columns WHERE table_name='skater_profiles' AND column_name='age_group'")
        if not cur.fetchone():
            print("Adding column 'age_group' to 'skater_profiles'...")
            cur.execute("ALTER TABLE skater_profiles ADD COLUMN age_group VARCHAR(60)")
        
        conn.commit()
        print("✅ DB schema fixed successfully!")
        
    except Exception as e:
        print(f"❌ Error fixing DB: {e}")
    finally:
        if 'conn' in locals():
            conn.close()

if __name__ == "__main__":
    fix_db()
