"""Tests for user profile CRUD, kid management, and admin user operations."""

from __future__ import annotations

import uuid

from app.api.deps import get_current_user
from app.models.enums import UserRole
from sqlmodel import select
import pytest
from app.models.user import User, ParentChildMapping


# ── Profile: GET /me ─────────────────────────────────────────────────

def test_get_profile(client, parent_user):
    client.app.dependency_overrides[get_current_user] = lambda: parent_user
    resp = client.get("/api/v1/users/me")
    assert resp.status_code == 200
    data = resp.json()
    assert data["first_name"] == "Parent"
    del client.app.dependency_overrides[get_current_user]


# ── Profile: PUT /me ─────────────────────────────────────────────────

def test_update_profile(client, parent_user):
    client.app.dependency_overrides[get_current_user] = lambda: parent_user
    resp = client.put("/api/v1/users/me", json={"first_name": "Updated", "favorite_sport": "skating"})
    assert resp.status_code == 200
    data = resp.json()
    assert data["first_name"] == "Updated"
    assert data["has_completed_profile"] is True
    del client.app.dependency_overrides[get_current_user]


# ── Kids: POST /me/kids ──────────────────────────────────────────────

def test_add_kid(client, parent_user):
    client.app.dependency_overrides[get_current_user] = lambda: parent_user
    resp = client.post(
        "/api/v1/users/me/kids",
        json={"first_name": "ChildA", "last_name": "Test", "dob": "2018-05-15", "gender": "male"},
    )
    assert resp.status_code == 200
    data = resp.json()
    assert data["first_name"] == "ChildA"
    assert data["role"] == "kid"
    del client.app.dependency_overrides[get_current_user]


# ── Kids: GET /me/kids ───────────────────────────────────────────────

def test_list_kids(client, parent_user, session):
    _add_kid(session, parent_user)
    client.app.dependency_overrides[get_current_user] = lambda: parent_user
    resp = client.get("/api/v1/users/me/kids")
    assert resp.status_code == 200
    kids = resp.json()
    assert len(kids) >= 1
    del client.app.dependency_overrides[get_current_user]


# ── Admin: users management ──────────────────────────────────────────

def test_admin_list_users(client, admin_user, parent_user):
    client.app.dependency_overrides[get_current_user] = lambda: admin_user
    resp = client.get("/api/v1/admin/users")
    assert resp.status_code == 200
    users = resp.json()
    assert len(users) >= 2  # admin + parent
    del client.app.dependency_overrides[get_current_user]


def test_admin_search_users(client, admin_user, parent_user):
    client.app.dependency_overrides[get_current_user] = lambda: admin_user
    resp = client.get("/api/v1/admin/users?search=Parent")
    assert resp.status_code == 200
    users = resp.json()
    assert any(u["first_name"] == "Parent" for u in users)
    del client.app.dependency_overrides[get_current_user]


def test_admin_create_user(client, admin_user):
    client.app.dependency_overrides[get_current_user] = lambda: admin_user
    resp = client.post(
        "/api/v1/admin/users",
        json={
            "role": "trainer",
            "first_name": "NewTrainer",
            "last_name": "Test",
            "mobile_no": "+911234567890",
            "email": "trainer@test.com",
            "is_active": True,
            "is_verified": False,
        },
    )
    assert resp.status_code == 200
    data = resp.json()
    assert data["role"] == "trainer"
    del client.app.dependency_overrides[get_current_user]


def test_admin_delete_user(client, admin_user, session):
    victim = User(
        id=uuid.uuid4(),
        role=UserRole.PARENT,
        first_name="Victim",
        email="victim@test.com",
    )
    session.add(victim)
    session.commit()
    client.app.dependency_overrides[get_current_user] = lambda: admin_user
    resp = client.delete(f"/api/v1/admin/users/{victim.id}")
    assert resp.status_code == 200
    del client.app.dependency_overrides[get_current_user]


def test_admin_delete_parent_with_kids(client, admin_user, parent_user, session):
    # Setup: Add a kid and mapping
    _add_kid(session, parent_user)
    
    client.app.dependency_overrides[get_current_user] = lambda: admin_user
    resp = client.delete(f"/api/v1/admin/users/{parent_user.id}")
    assert resp.status_code == 200
    
    # Verify mapping is gone
    from app.models.user import ParentChildMapping
    session.expire_all()
    mapping = session.exec(select(ParentChildMapping).where(ParentChildMapping.parent_id == parent_user.id)).first()
    assert mapping is None
    
    del client.app.dependency_overrides[get_current_user]


def test_admin_delete_organizer_with_events(client, admin_user, session):
    # Setup: Create organizer and event
    from app.models.user import User, OrganizerProfile
    from app.models.event import Event, Payment
    from app.models.enums import UserRole
    from datetime import datetime, timezone
    
    org_user = User(
        email="org@test.com", 
        first_name="Org", 
        role=UserRole.ORGANIZER,
        is_active=True,
        favorite_sport="skatting" # typo in model default maybe?
    )
    session.add(org_user)
    session.commit()
    session.refresh(org_user)
    
    org_profile = OrganizerProfile(user_id=org_user.id, org_name="Test Org")
    session.add(org_profile)
    
    event = Event(
        title="Org Event", 
        organizer_user_id=org_user.id,
        start_at_utc=datetime.now(timezone.utc),
        end_at_utc=datetime.now(timezone.utc),
        location_name="Venue"
    )
    session.add(event)
    session.commit()
    session.refresh(event)
    
    # Add a payment to trigger RESTRICT
    payment = Payment(
        user_id=admin_user.id, 
        event_id=event.id, 
        amount=100.0, 
        status="success"
    )
    session.add(payment)
    session.commit()
    
    event_id = event.id
    
    # Execute deletion
    client.app.dependency_overrides[get_current_user] = lambda: admin_user
    resp = client.delete(f"/api/v1/admin/users/{org_user.id}")
    assert resp.status_code == 200
    
    # Verify cleanup
    session.expire_all()
    assert session.get(User, org_user.id) is None
    from sqlmodel import select
    assert session.exec(select(Event).where(Event.id == event_id)).first() is None
    assert session.exec(select(Payment).where(Payment.event_id == event_id)).first() is None
    del client.app.dependency_overrides[get_current_user]


# ── Admin: dashboard stats ───────────────────────────────────────────

def test_admin_stats(client, admin_user, sample_event):
    client.app.dependency_overrides[get_current_user] = lambda: admin_user
    resp = client.get("/api/v1/admin/stats")
    assert resp.status_code == 200
    data = resp.json()
    assert "total_users" in data
    assert "total_events" in data
    assert "active_users_today" in data
    assert "registrations_today" in data
    assert "trend" in data
    del client.app.dependency_overrides[get_current_user]


# ── Helpers ──────────────────────────────────────────────────────────

def _add_kid(session, parent: User) -> User:
    from datetime import date

    kid = User(
        id=uuid.uuid4(),
        parent_id=parent.id,
        role=UserRole.KID,
        first_name="KidX",
        last_name="Test",
        dob=date(2017, 3, 1),
    )
    session.add(kid)
    mapping = ParentChildMapping(parent_id=parent.id, child_id=kid.id)
    session.add(mapping)
    session.commit()
    session.refresh(kid)
    return kid
