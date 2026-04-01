import psycopg2

# Production DB URL
DB_URL = "postgresql://zests_admin:PGqLnE79TwOMu6BDalkSJwoQPm70Mlrg@dpg-d6t2phi4d50c73c1vshg-a.oregon-postgres.render.com/zestsmvp_db"

def fix_db():
    try:
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
