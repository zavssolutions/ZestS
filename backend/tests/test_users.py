"""Tests for user profile CRUD, kid management, and admin user operations."""

from __future__ import annotations

import uuid

from app.api.deps import get_current_user
from app.models.enums import UserRole
from app.models.user import User


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
    session.commit()
    session.refresh(kid)
    return kid
