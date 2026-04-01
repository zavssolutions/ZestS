import sys
import os
sys.path.append(os.getcwd())

import pytest
from uuid import uuid4
from datetime import datetime, timedelta, timezone
from fastapi.testclient import TestClient
from sqlmodel import Session, create_engine, select, SQLModel
from sqlmodel import Session, select
from app.main import app as fastapi_app
from app.db.session import engine, get_session
from app.api.deps import require_roles
import app.models  # Ensure all tables are registered
from app.models.user import User, OrganizerProfile
from app.models.enums import UserRole
from app.models.event import Event, EventCategory

@pytest.mark.skip(reason="Requires real database and manual setup")
def test_massive_event_creation():
    # We use the REAL project engine (pointed at Render or Local DB)
    client = TestClient(fastapi_app)
    
    # 1. Setup Mock User
    # In a real DB, we should check if the user exists or use an existing admin
    admin_email = "sivakumar.perumalla.lld01@gmail.com"
    
    with Session(engine) as session:
        user = session.exec(select(User).where(User.email == admin_email)).first()
        if not user:
            # Fallback to creating a test admin if not found (might fail if UID missing)
            user = User(
                email=admin_email,
                role=UserRole.ADMIN,
                is_active=True,
                firebase_uid=f"test_uid_{uuid4()}"
            )
            session.add(user)
            session.commit()
            session.refresh(user)

        # Ensure Organizer Profile exists
        org_profile = session.get(OrganizerProfile, user.id)
        if not org_profile:
            org_profile = OrganizerProfile(user_id=user.id, org_name="Test Org")
            session.add(org_profile)
            session.commit()
    
    # Override dependencies
    fastapi_app.dependency_overrides[get_session] = lambda: Session(engine)
    fastapi_app.dependency_overrides[require_roles(UserRole.ADMIN, UserRole.ORGANIZER)] = lambda: user

    # 3. Create Payload with 10 Categories
    start_at = datetime.now(timezone.utc) + timedelta(days=30)
    end_at = start_at + timedelta(hours=5)
    
    categories = []
    for i in range(1, 11):
        categories.append({
            "name": f"Category {i}",
            "price": 100.0 * i,
            "category_type": "Road",
            "skate_type": "Inline",
            "age_group": "Under 15",
            "distance": f"{i}km",
            "images_url": [f"https://example.com/img{i}.png", f"https://example.com/thumb{i}.jpg"]
        })
        
    payload = {
        "title": "Massive Test Event",
        "description": "Event with 10 categories",
        "price": 500.0,
        "location_name": "Olympic Stadium",
        "venue_city": "Test City",
        "start_at_utc": start_at.isoformat(),
        "end_at_utc": end_at.isoformat(),
        "latitude": 12.97,
        "longitude": 77.59,
        "categories": categories
    }
    
    print("\n--- Sending Massive Payload ---")
    response = client.post("/api/v1/events", json=payload)
    
    print(f"Status: {response.status_code}")
    if response.status_code != 200:
        print(f"Error Detail: {response.text}")
    
    assert response.status_code == 200
    event_id = response.json()["id"]
    print(f"Created Event ID: {event_id}")

    # 4. Verify Database Contents
    with Session(test_engine) as session:
        # Fetch Event
        db_event = session.get(Event, event_id)
        print(f"\n--- DB Event: {db_event.title} ---")
        print(f"Price: {db_event.price}")
        print(f"Organizer ID: {db_event.organizer_id}")
        
        # Fetch Categories
        db_categories = session.exec(select(EventCategory).where(EventCategory.event_id == event_id)).all()
        print(f"\n--- DB Categories (Count: {len(db_categories)}) ---")
        for cat in db_categories:
            print(f"- {cat.name}: Price={cat.price}, Images={cat.images_url}")

    # Cleanup overrides
    app.dependency_overrides.clear()

if __name__ == "__main__":
    test_massive_event_creation()
