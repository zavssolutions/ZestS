import pytest
import uuid
from datetime import datetime, timedelta, timezone
from fastapi import status
from sqlmodel import Session, select
from app.models.event import Event, EventCategory, EventRegistration
from app.models.enums import UserRole
from app.api.deps import get_current_user

def test_event_date_validation(client, admin_user):
    """Test that end_at_utc must be after start_at_utc."""
    app = client.app
    app.dependency_overrides[get_current_user] = lambda: admin_user
    
    now = datetime.now(timezone.utc)
    payload = {
        "title": "Invalid Dates Event",
        "location_name": "Test Location",
        "start_at_utc": now.isoformat(),
        "end_at_utc": (now - timedelta(hours=1)).isoformat(), # Invalid: before start
        "categories": [{"name": "Cat 1"}]
    }
    response = client.post("/api/v1/events", json=payload)
    assert response.status_code == status.HTTP_400_BAD_REQUEST
    assert "must be on or after start date" in response.text
    
    del app.dependency_overrides[get_current_user]

def test_registration_published_only(client, admin_user, parent_user, session: Session):
    """Test that registration is only allowed for published events."""
    now = datetime.now(timezone.utc)
    
    # Create a draft event
    event = Event(
        title="Draft Event",
        start_at_utc=now + timedelta(days=1),
        end_at_utc=now + timedelta(days=2),
        location_name="Secret Place",
        status="draft"
    )
    session.add(event)
    session.commit()
    
    category = EventCategory(name="Draft Cat", event_id=event.id, max_slots=10)
    session.add(category)
    session.commit()
    
    app = client.app
    app.dependency_overrides[get_current_user] = lambda: parent_user
    
    payload = {"event_id": str(event.id), "category_id": str(category.id)}
    response = client.post("/api/v1/events/registrations", json=payload)
    assert response.status_code == status.HTTP_400_BAD_REQUEST
    assert "Can only register for published events" in response.json()["detail"]
    
    del app.dependency_overrides[get_current_user]

def test_registration_capacity_limit(client, parent_user, session: Session):
    """Test that registration fails if category is full."""
    now = datetime.now(timezone.utc)
    # Create a published event with 1 slot
    event = Event(
        title="Limited Event",
        start_at_utc=now + timedelta(days=1),
        end_at_utc=now + timedelta(days=2),
        location_name="Tiny Room",
        status="published"
    )
    session.add(event)
    session.commit()
    
    category = EventCategory(name="One Slot", event_id=event.id, max_slots=1)
    session.add(category)
    session.commit()
    
    app = client.app
    app.dependency_overrides[get_current_user] = lambda: parent_user
    
    # Register first user
    payload = {"event_id": str(event.id), "category_id": str(category.id)}
    response1 = client.post("/api/v1/events/registrations", json=payload)
    assert response1.status_code == 200
    
    # Try second registration (should fail)
    response2 = client.post("/api/v1/events/registrations", json=payload)
    assert response2.status_code == 400
    assert "This category is full" in response2.json()["detail"]
    
    del app.dependency_overrides[get_current_user]

def test_event_schema_alignment_fields(client, admin_user):
    """Test that new fields (city, images_url, other_urls) are handled."""
    app = client.app
    app.dependency_overrides[get_current_user] = lambda: admin_user
    
    now = datetime.now(timezone.utc)
    payload = {
        "title": "Rich Info Event",
        "location_name": "Tech City",
        "start_at_utc": (now + timedelta(days=1)).isoformat(),
        "end_at_utc": (now + timedelta(days=2)).isoformat(),
        "city": "Cyberabad",
        "images_url": ["http://img1.com", "http://img2.com"],
        "other_urls": {"website": "http://event.com"},
        "categories": [
            {
                "name": "Pro",
                "city": "Cyberabad",
                "images_url": ["http://catimg.com"]
            }
        ]
    }
    response = client.post("/api/v1/events", json=payload)
    assert response.status_code == 200
    data = response.json()
    assert data["city"] == "Cyberabad"
    assert data["images_url"] == ["http://img1.com", "http://img2.com"]
    assert data["other_urls"] == {"website": "http://event.com"}
    
    del app.dependency_overrides[get_current_user]
