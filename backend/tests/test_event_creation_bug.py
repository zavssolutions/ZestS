from datetime import datetime, timedelta, timezone
import pytest
from fastapi.testclient import TestClient
from sqlalchemy.orm import Session
from app.main import app
from app.api.deps import require_roles
from app.models.user import User, OrganizerProfile
from app.models.enums import UserRole
from uuid import uuid4

def test_create_event_endpoint_crash(client, session: Session):
    # 1. Create a user
    user = User(
        id=uuid4(),
        email="org@test.com",
        first_name="Test",
        last_name="Org",
        role=UserRole.ORGANIZER
    )
    session.add(user)
    session.commit()
    
    # 2. Add OrganizerProfile
    profile = OrganizerProfile(user_id=user.id, org_name="Test Org")
    session.add(profile)
    session.commit()
    session.refresh(profile)
    
    # 3. Override dependency for auth
    app.dependency_overrides[require_roles(UserRole.ADMIN, UserRole.ORGANIZER)] = lambda: user
    
    # 4. Payload exactly as sent from mobile app
    # DateTime.now().add(const Duration(days: 30)).toUtc().toIso8601String()
    start_str = (datetime.now(timezone.utc) + timedelta(days=30)).strftime("%Y-%m-%dT%H:%M:%S.%f") + "Z"
    end_str = (datetime.now(timezone.utc) + timedelta(days=31)).strftime("%Y-%m-%dT%H:%M:%S.%f") + "Z"
    
    payload = {
        "title": "Bug Hunt",
        "description": "",
        "organizer_email": "",
        "price": 0.0,
        "location_name": "Test Venue",
        "venue_city": "",
        "banner_image_url": None,
        "latitude": 17.0,
        "longitude": 78.0,
        "start_at_utc": start_str,
        "end_at_utc": end_str,
        "categories": [
            {
                "name": "General",
                "price": 0.0,
                "category_type": "Road",
                "skate_type": "Inline",
                "distance": "500m",
                "age_group": "8-10",
            }
        ]
    }
    
    response = client.post("/api/v1/events", json=payload)
    print(f"Response status: {response.status_code}")
    print(f"Response body: {response.text}")
    assert response.status_code == 200
    
    # Clear overrides
    app.dependency_overrides = {}
