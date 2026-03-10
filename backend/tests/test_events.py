"""Tests for event CRUD, registration, categories, results, referrals, and share links."""

from __future__ import annotations

import uuid
from unittest.mock import patch

from app.models.enums import EventStatus, UserRole
from app.models.user import User
from app.models.event import Event, EventCategory, EventResult


# ── Events: listing ─────────────────────────────────────────────────

def test_list_upcoming_events(client, sample_event):
    resp = client.get("/api/v1/events/upcoming")
    assert resp.status_code == 200
    events = resp.json()
    assert isinstance(events, list)
    assert any(e["id"] == str(sample_event.id) for e in events)


def test_list_anonymous_events_returns_one(client, sample_event):
    resp = client.get("/api/v1/events/upcoming/anonymous")
    assert resp.status_code == 200
    events = resp.json()
    assert len(events) <= 1


# ── Events: detail ──────────────────────────────────────────────────

def test_get_event_detail(client, sample_event):
    resp = client.get(f"/api/v1/events/{sample_event.id}")
    assert resp.status_code == 200
    data = resp.json()
    assert data["event"]["id"] == str(sample_event.id)
    assert data["maps_link"] is not None  # lat/long set


def test_get_event_not_found(client):
    resp = client.get(f"/api/v1/events/{uuid.uuid4()}")
    assert resp.status_code == 404


# ── Events: categories ──────────────────────────────────────────────

def test_list_event_categories(client, sample_event, sample_category):
    resp = client.get(f"/api/v1/events/{sample_event.id}/categories")
    assert resp.status_code == 200
    cats = resp.json()
    assert len(cats) >= 1
    assert cats[0]["name"] == sample_category.name


# ── Events: share link ──────────────────────────────────────────────

def test_generate_share_link(client, sample_event, parent_user, session):
    # Mock auth dependency to return parent_user
    from app.api.deps import get_current_user
    app = client.app
    app.dependency_overrides[get_current_user] = lambda: parent_user
    resp = client.post(f"/api/v1/events/{sample_event.id}/share-link")
    assert resp.status_code == 200
    data = resp.json()
    assert "share_link" in data
    assert str(sample_event.id) in data["share_link"]
    assert str(parent_user.id) in data["share_link"]
    del app.dependency_overrides[get_current_user]


# ── Events: referrals ───────────────────────────────────────────────

def test_referral_install_adds_10_points(client, sample_event, admin_user, parent_user):
    payload = {
        "referrer_user_id": str(admin_user.id),
        "referred_user_id": str(parent_user.id),
    }
    resp = client.post(f"/api/v1/events/{sample_event.id}/referrals/install", json=payload)
    assert resp.status_code == 200
    data = resp.json()
    assert data["points"] == 10


def test_referral_view_adds_1_point(client, sample_event, admin_user, parent_user):
    payload = {
        "referrer_user_id": str(admin_user.id),
        "referred_user_id": str(parent_user.id),
    }
    resp = client.post(f"/api/v1/events/{sample_event.id}/referrals/view", json=payload)
    assert resp.status_code == 200
    data = resp.json()
    assert data["points"] >= 1
