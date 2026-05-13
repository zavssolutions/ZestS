import sys
import os
from sqlmodel import create_engine, Session, select, SQLModel
from datetime import datetime, timezone

# Add current directory to path
sys.path.append(os.getcwd())

from app.core.config import get_settings
from app.models.user import User
from app.services.seeder import seed_e2e_data
from reset_db import reset_database_cleanly

def run():
    settings = get_settings()
    print(f"Database: {settings.database_url}")
    engine = create_engine(settings.database_url)
    
    # 1. Backup admins
    admins_data = []
    try:
        with Session(engine) as session:
            admins = session.exec(select(User).where(User.role == "admin")).all()
            for a in admins:
                admins_data.append({
                    "id": a.id,
                    "email": a.email,
                    "firebase_uid": a.firebase_uid,
                    "first_name": a.first_name,
                    "last_name": a.last_name
                })
            print(f"Found {len(admins_data)} admins to preserve.")
    except Exception as e:
        print(f"Could not backup admins: {e}")

    # 2. Wipe
    print("Starting destructive reset...")
    reset_database_cleanly()
    
    # 3. Create schema
    print("Re-creating schema...")
    import app.models # Ensures all models are registered in SQLModel.metadata
    SQLModel.metadata.create_all(engine)
    
    # 4. Restore admins
    with Session(engine) as session:
        for data in admins_data:
            admin = User(
                id=data["id"],
                email=data["email"],
                firebase_uid=data["firebase_uid"],
                role="admin",
                first_name=data["first_name"],
                last_name=data["last_name"],
                is_active=True,
                is_verified=True
            )
            session.add(admin)
        session.commit()
        print(f"Restored {len(admins_data)} admins.")

    # 5. Seed
    with Session(engine) as session:
        print("Seeding fresh E2E data...")
        seed_e2e_data(session, num_skaters=5, num_parents=2) # Minimal set for reliability
        print("Seeding complete.")

if __name__ == "__main__":
    run()
