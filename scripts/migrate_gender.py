from sqlmodel import Session, select
from app.db.session import engine
from app.models.user import User
from app.models.event import EventCategory

def migrate_genders():
    with Session(engine) as session:
        # 1. Update Users
        users_to_migrate = session.exec(
            select(User).where(User.gender.in_(["other", "unspecified"]))
        ).all()
        
        print(f"Migrating {len(users_to_migrate)} users...")
        for user in users_to_migrate:
            user.gender = "male"
            session.add(user)
            
        # 2. Update Event Categories (if any exist with bad gender)
        cats_to_migrate = session.exec(
            select(EventCategory).where(EventCategory.gender.in_(["Other", "Unspecified", "other", "unspecified"]))
        ).all()
        
        print(f"Migrating {len(cats_to_migrate)} event categories...")
        for cat in cats_to_migrate:
            cat.gender = "male"
            session.add(cat)
            
        session.commit()
        print("Migration successfully committed.")

if __name__ == "__main__":
    migrate_genders()
