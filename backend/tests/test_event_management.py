"""Comprehensive tests for ZestS Event Management Improvements.
Covers:
- Event creation with new fields (price, organizer_email)
- Category ENUM validation
- Cascading deletes
- Event cancellation flow
- Local storage image upload fallback
"""

import pytest
import uuid
from datetime import datetime, timedelta, timezone
from unittest.mock import patch, MagicMock
from pathlib import Path

from app.models.enums import EventStatus, UserRole
from app.models.event import Event, EventCategory, EventRegistration, EventResult
from app.models.user import User, OrganizerProfile
from app.api.deps import get_current_user
from sqlmodel import select

# ── 1. Event Creation & Organizer Association ───────────────────────────

def test_create_event_with_organizer_email(client, session, admin_user):
    # Setup: Create an organizer profile first
    org_user = User(
        id=uuid.uuid4(),
        email="org@zests.com",
        role=UserRole.ORGANIZER,
        first_name="Test",
        last_name="Organizer"
    )
    session.add(org_user)
    session.commit()
    
    org_profile = OrganizerProfile(user_id=org_user.id, org_name="ZestS Org")
    session.add(org_profile)
    session.commit()
    session.refresh(org_profile)
    
    app = client.app
    app.dependency_overrides[get_current_user] = lambda: admin_user
    
    now = datetime.now(timezone.utc)
    payload = {
        "title": "Organizer Linked Event",
        "description": "Event with an organizer email",
        "location_name": "Stadium",
        "venue_city": "Mumbai",
        "start_at_utc": (now + timedelta(days=5)).isoformat(),
        "end_at_utc": (now + timedelta(days=6)).isoformat(),
        "organizer_email": "org@zests.com",
        "price": 999.50
    }
    
    resp = client.post("/api/v1/events", json=payload)
    assert resp.status_code == 200
    data = resp.json()
    assert data["organizer_id"] == org_profile.organizer_id
    assert data["price"] == 999.50
    
    del app.dependency_overrides[get_current_user]

# ── 2. Category ENUM Validation ─────────────────────────────────────────

def test_create_event_with_categories_enums(client, session, admin_user):
    app = client.app
    app.dependency_overrides[get_current_user] = lambda: admin_user
    
    now = datetime.now(timezone.utc)
    payload = {
        "title": "Enum Test Event",
        "location_name": "Rink",
        "start_at_utc": (now + timedelta(days=5)).isoformat(),
        "end_at_utc": (now + timedelta(days=6)).isoformat(),
        "categories": [
            {
                "name": "Artistic Quad 200m",
                "category_type": "Artistic",
                "skate_type": "Quad",
                "distance": "200m",
                "age_group": "8-10",
                "track_type": "oval",
                "price": 500.0
            }
        ]
    }
    
    resp = client.post("/api/v1/events", json=payload)
    assert resp.status_code == 200
    
    # Verify categories were created
    event_id = uuid.UUID(resp.json()["id"])
    categories = session.exec(select(EventCategory).where(EventCategory.event_id == event_id)).all()
    assert len(categories) == 1
    assert categories[0].category_type == "Artistic"
    assert categories[0].skate_type == "Quad"
    assert categories[0].distance == "200m"
    assert categories[0].age_group == "8-10"
    
    del app.dependency_overrides[get_current_user]

# ── 3. Cascading Deletes Verification ───────────────────────────────────

def test_event_cascade_delete(client, session, admin_user, sample_event, sample_category):
    # Setup: Add a registration and a result
    reg = EventRegistration(
        event_id=sample_event.id,
        category_id=sample_category.id,
        user_id=admin_user.id,
        status="confirmed"
    )
    session.add(reg)
    session.commit()
    
    res = EventResult(
        event_id=sample_event.id,
        category_id=sample_category.id,
        user_id=admin_user.id,
        rank=1,
        timing="00:45.00"
    )
    session.add(res)
    session.commit()
    
    app = client.app
    app.dependency_overrides[get_current_user] = lambda: admin_user
    
    # Store IDs before delete to avoid ObjectDeletedError
    reg_id = reg.id
    res_id = res.id
    cat_id = sample_category.id
    
    # Delete the event
    resp = client.delete(f"/api/v1/admin/events/{sample_event.id}")
    assert resp.status_code == 200
    
    # Verify everything is gone
    assert session.get(Event, sample_event.id) is None
    assert session.exec(select(EventCategory).where(EventCategory.event_id == sample_event.id)).first() is None
    assert session.get(EventRegistration, reg_id) is None
    assert session.get(EventResult, res_id) is None
    
    del app.dependency_overrides[get_current_user]

# ── 4. Event Cancellation Flow ──────────────────────────────────────────

def test_event_cancellation_status(client, session, admin_user, sample_event):
    app = client.app
    app.dependency_overrides[get_current_user] = lambda: admin_user
    
    # Cancel the event
    resp = client.post(f"/api/v1/events/{sample_event.id}/status", json={"status": "canceled"})
    assert resp.status_code == 200
    assert resp.json()["status"] == "canceled"
    
    # Verify it updated in DB
    updated_event = session.exec(select(Event).where(Event.id == uuid.UUID(str(sample_event.id)))).first()
    assert updated_event.status == EventStatus.CANCELED
    
    del app.dependency_overrides[get_current_user]

# ── 5. Image Upload Fallback ────────────────────────────────────────────

@patch("app.services.storage.get_storage_client")
def test_storage_local_fallback(mock_client, client, admin_user):
    # Force GCP failure
    mock_client.side_effect = Exception("GCP Unavailable")
    
    from app.services.storage import upload_bytes
    
    test_data = b"fake-image-data"
    result_url = upload_bytes("test/image.png", test_data, "image/png")
    
    assert result_url.startswith("/static/uploads/")
    file_name = result_url.split("/")[-1]
    assert Path(f"static/uploads/{file_name}").exists()
    
    # Cleanup
    Path(f"static/uploads/{file_name}").unlink()
