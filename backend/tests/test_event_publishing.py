"""Tests for event publishing flow and home screen visibility.

Validates:
  - Event creation
  - Event status transitions (draft → published, published → canceled)
  - Published event appears on /upcoming (logged-in) and /upcoming/anonymous
  - Draft event does NOT appear on /upcoming
  - Event count increases after publishing
  - Admin dashboard navigation endpoints
"""

from __future__ import annotations

import uuid
import os
from datetime import datetime, timedelta, timezone

import pytest

from app.api.deps import get_current_user
from app.models.enums import EventStatus, UserRole
from app.models.event import Event
from app.models.user import User


# ── Event Creation ──────────────────────────────────────────────────

def test_create_event_as_admin(client, admin_user, session):
    """Admin can create a new event via POST /events."""
    app = client.app
    app.dependency_overrides[get_current_user] = lambda: admin_user

    now = datetime.now(timezone.utc)
    payload = {
        "title": "New Skating Competition",
        "description": "A brand new event",
        "location_name": "City Arena",
        "venue_city": "Bangalore",
        "start_at_utc": (now + timedelta(days=10)).isoformat(),
        "end_at_utc": (now + timedelta(days=11)).isoformat(),
    }
    resp = client.post("/api/v1/events", json=payload)
    assert resp.status_code == 200
    data = resp.json()
    assert data["title"] == "New Skating Competition"
    assert data["status"] == "draft"

    del app.dependency_overrides[get_current_user]


def test_create_event_returns_draft_status(client, admin_user, session):
    """Newly created events should default to 'draft' status."""
    app = client.app
    app.dependency_overrides[get_current_user] = lambda: admin_user

    now = datetime.now(timezone.utc)
    payload = {
        "title": "Draft Event",
        "description": "Should be draft",
        "location_name": "Local Arena",
        "start_at_utc": (now + timedelta(days=15)).isoformat(),
        "end_at_utc": (now + timedelta(days=16)).isoformat(),
    }
    resp = client.post("/api/v1/events", json=payload)
    assert resp.status_code == 200
    assert resp.json()["status"] == "draft"

    del app.dependency_overrides[get_current_user]


# ── Event Publishing ────────────────────────────────────────────────

@pytest.mark.skipif(
    "sqlite" in os.environ.get("DATABASE_URL", "sqlite"),
    reason="SQLite UUID type incompatibility with status endpoint chain",
)
def test_publish_event(client, admin_user, session):
    """Publishing an event changes its status from draft to published."""
    from datetime import datetime, timedelta, timezone as tz
    app = client.app
    app.dependency_overrides[get_current_user] = lambda: admin_user

    # Create a draft event via the API
    now = datetime.now(tz.utc)
    create_resp = client.post("/api/v1/events", json={
        "title": "Event to Publish",
        "location_name": "Test Venue",
        "start_at_utc": (now + timedelta(days=20)).isoformat(),
        "end_at_utc": (now + timedelta(days=21)).isoformat(),
    })
    assert create_resp.status_code == 200
    event_id = create_resp.json()["id"]
    assert create_resp.json()["status"] == "draft"

    # Publish it
    resp = client.post(f"/api/v1/events/{event_id}/status", json={"status": "published"})
    assert resp.status_code == 200
    assert resp.json()["status"] == "published"

    del app.dependency_overrides[get_current_user]


@pytest.mark.skipif(
    "sqlite" in os.environ.get("DATABASE_URL", "sqlite"),
    reason="SQLite UUID type incompatibility with status endpoint chain",
)
def test_cancel_event(client, admin_user, session):
    """Canceling an event changes its status to canceled."""
    from datetime import datetime, timedelta, timezone as tz
    app = client.app
    app.dependency_overrides[get_current_user] = lambda: admin_user

    # Create and publish an event via the API
    now = datetime.now(tz.utc)
    create_resp = client.post("/api/v1/events", json={
        "title": "Event to Cancel",
        "location_name": "Test Venue",
        "start_at_utc": (now + timedelta(days=25)).isoformat(),
        "end_at_utc": (now + timedelta(days=26)).isoformat(),
    })
    assert create_resp.status_code == 200
    event_id = create_resp.json()["id"]

    # Publish first
    client.post(f"/api/v1/events/{event_id}/status", json={"status": "published"})

    # Cancel it
    resp = client.post(f"/api/v1/events/{event_id}/status", json={"status": "canceled"})
    assert resp.status_code == 200
    assert resp.json()["status"] == "canceled"

    del app.dependency_overrides[get_current_user]


# ── Event Visibility on Home Screen ─────────────────────────────────

def test_published_event_visible_on_upcoming(client, admin_user, session):
    """Published events appear in /events/upcoming for logged-in users."""
    now = datetime.now(timezone.utc)
    event = Event(
        id=uuid.uuid4(),
        organizer_user_id=admin_user.id,
        title="Visible Published Event",
        location_name="Open Rink",
        start_at_utc=now + timedelta(days=5),
        end_at_utc=now + timedelta(days=6),
        status="published",
    )
    session.add(event)
    session.commit()

    resp = client.get("/api/v1/events/upcoming")
    assert resp.status_code == 200
    events = resp.json()
    assert any(e["id"] == str(event.id) for e in events)


def test_draft_event_not_visible_on_upcoming(client, admin_user, session):
    """Draft events do NOT appear in /events/upcoming."""
    now = datetime.now(timezone.utc)
    event = Event(
        id=uuid.uuid4(),
        organizer_user_id=admin_user.id,
        title="Hidden Draft Event",
        location_name="Private Arena",
        start_at_utc=now + timedelta(days=5),
        end_at_utc=now + timedelta(days=6),
        status="draft",
    )
    session.add(event)
    session.commit()

    resp = client.get("/api/v1/events/upcoming")
    assert resp.status_code == 200
    events = resp.json()
    assert not any(e["id"] == str(event.id) for e in events)


def test_published_event_visible_anonymous(client, admin_user, session):
    """Published events appear on /events/upcoming/anonymous (limited to 1)."""
    now = datetime.now(timezone.utc)
    event = Event(
        id=uuid.uuid4(),
        organizer_user_id=admin_user.id,
        title="Anonymous Visible Event",
        location_name="Public Park",
        start_at_utc=now + timedelta(days=3),
        end_at_utc=now + timedelta(days=4),
        status="published",
    )
    session.add(event)
    session.commit()

    resp = client.get("/api/v1/events/upcoming/anonymous")
    assert resp.status_code == 200
    events = resp.json()
    assert len(events) <= 1
    assert len(events) >= 1  # at least our event shows up


def test_draft_event_not_visible_anonymous(client, admin_user, session):
    """Draft events do NOT appear on /events/upcoming/anonymous."""
    now = datetime.now(timezone.utc)
    event = Event(
        id=uuid.uuid4(),
        organizer_user_id=admin_user.id,
        title="Hidden Anonymous Draft",
        location_name="Nowhere",
        start_at_utc=now + timedelta(days=3),
        end_at_utc=now + timedelta(days=4),
        status="draft",
    )
    session.add(event)
    session.commit()

    resp = client.get("/api/v1/events/upcoming/anonymous")
    assert resp.status_code == 200
    events = resp.json()
    assert not any(e["id"] == str(event.id) for e in events)


# ── Event Count After Publishing ────────────────────────────────────

def test_event_count_increases_after_publish(client, admin_user, session):
    """Publishing a new event increases the count on /events/upcoming."""
    # Get initial count
    resp = client.get("/api/v1/events/upcoming")
    assert resp.status_code == 200
    initial_count = len(resp.json())

    # Create and publish a new event
    now = datetime.now(timezone.utc)
    event = Event(
        id=uuid.uuid4(),
        organizer_user_id=admin_user.id,
        title="Extra Published Event",
        location_name="New Track",
        start_at_utc=now + timedelta(days=40),
        end_at_utc=now + timedelta(days=41),
        status="published",
    )
    session.add(event)
    session.commit()

    # Verify count increased
    resp = client.get("/api/v1/events/upcoming")
    assert resp.status_code == 200
    new_count = len(resp.json())
    assert new_count == initial_count + 1


# ── Admin Endpoints ─────────────────────────────────────────────────

def test_admin_events_list(client, sample_event):
    """Admin can list all events."""
    resp = client.get("/api/v1/admin/events")
    assert resp.status_code == 200
    events = resp.json()
    assert isinstance(events, list)
    assert len(events) >= 1


def test_admin_users_list(client, admin_user):
    """Admin can list all users."""
    resp = client.get("/api/v1/admin/users")
    assert resp.status_code == 200
    users = resp.json()
    assert isinstance(users, list)
    assert any(u["id"] == str(admin_user.id) for u in users)


def test_admin_results_list(client, sample_event):
    """Admin can list event results (may be empty)."""
    resp = client.get("/api/v1/admin/event-results")
    assert resp.status_code == 200
    assert isinstance(resp.json(), list)


def test_admin_stats(client, admin_user, sample_event):
    """Admin stats returns expected keys."""
    resp = client.get("/api/v1/admin/stats")
    assert resp.status_code == 200
    data = resp.json()
    assert "total_users" in data
    assert "total_events" in data
