"""Tests for content endpoints: static pages, banners, sponsors, support issues."""

from __future__ import annotations

import uuid

from app.api.deps import get_current_user
from app.models.content import StaticPage, Banner, Sponsor, SupportIssue


# ── Static Pages ─────────────────────────────────────────────────────

def test_list_static_pages(client, session):
    page = StaticPage(slug="terms-and-conditions", title="Terms and Conditions", content="")
    session.add(page)
    session.commit()
    resp = client.get("/api/v1/pages")
    assert resp.status_code == 200
    pages = resp.json()
    assert any(p["slug"] == "terms-and-conditions" for p in pages)


def test_get_static_page_by_slug(client, session):
    page = StaticPage(slug="about-us", title="About Us", content="Our story")
    session.add(page)
    session.commit()
    resp = client.get("/api/v1/pages/about-us")
    assert resp.status_code == 200
    data = resp.json()
    assert data["title"] == "About Us"


# ── Banners (Admin) ─────────────────────────────────────────────────

def test_admin_banner_crud(client, admin_user, session):
    client.app.dependency_overrides[get_current_user] = lambda: admin_user

    # Create
    resp = client.post(
        "/api/v1/admin/banners",
        json={"title": "Test Banner", "image_url": "https://example.com/banner.jpg", "placement": "home_top"},
    )
    assert resp.status_code == 200
    banner_id = resp.json()["id"]

    # List
    resp = client.get("/api/v1/admin/banners")
    assert resp.status_code == 200
    assert len(resp.json()) >= 1

    # Update
    resp = client.put(f"/api/v1/admin/banners/{banner_id}", json={"title": "Updated Banner"})
    assert resp.status_code == 200
    assert resp.json()["title"] == "Updated Banner"

    # Delete
    resp = client.delete(f"/api/v1/admin/banners/{banner_id}")
    assert resp.status_code == 200

    del client.app.dependency_overrides[get_current_user]


def test_get_single_banner(client, admin_user, session):
    client.app.dependency_overrides[get_current_user] = lambda: admin_user
    resp = client.post(
        "/api/v1/admin/banners",
        json={"title": "Single Banner", "image_url": "https://example.com/banner.jpg", "placement": "home_top"},
    )
    banner_id = resp.json()["id"]

    resp = client.get(f"/api/v1/banners/{banner_id}")
    assert resp.status_code == 200
    assert resp.json()["title"] == "Single Banner"
    
    # 404 test
    resp = client.get(f"/api/v1/banners/{uuid.uuid4()}")
    assert resp.status_code == 404
    
    del client.app.dependency_overrides[get_current_user]


def test_banner_share_link(client, admin_user, session):
    client.app.dependency_overrides[get_current_user] = lambda: admin_user
    resp = client.post(
        "/api/v1/admin/banners",
        json={"title": "Share Banner", "image_url": "https://example.com/banner.jpg", "placement": "home_top"},
    )
    banner_id = resp.json()["id"]

    resp = client.post(f"/api/v1/banners/{banner_id}/share-link")
    assert resp.status_code == 200
    data = resp.json()
    assert data["banner_id"] == str(banner_id)
    assert "https://zests.app.link/banner/" in data["share_link"]
    
    del client.app.dependency_overrides[get_current_user]


def test_admin_banner_upload_image(client, admin_user, session, monkeypatch):
    # Mock upload_bytes to return a dummy URL
    import app.api.v1.endpoints.admin as admin_endpoints
    monkeypatch.setattr(admin_endpoints, "upload_bytes", lambda *args, **kwargs: "https://mock-gcp/image.png")

    client.app.dependency_overrides[get_current_user] = lambda: admin_user
    resp = client.post(
        "/api/v1/admin/banners",
        json={"title": "Upload Banner", "image_url": "dummy", "placement": "home_top"},
    )
    banner_id = resp.json()["id"]

    # Test upload endpoint
    file_bytes = b"fake-image-bytes"
    resp = client.post(
        f"/api/v1/admin/banners/{banner_id}/upload-image",
        files={"file": ("test.png", file_bytes, "image/png")},
    )
    assert resp.status_code == 200
    assert resp.json()["image_url"] == "https://mock-gcp/image.png"
    assert resp.json()["share_url"].endswith(str(banner_id))
    
    del client.app.dependency_overrides[get_current_user]


# ── Sponsors (Admin) ────────────────────────────────────────────────

def test_admin_sponsor_crud(client, admin_user):
    client.app.dependency_overrides[get_current_user] = lambda: admin_user

    # Create
    resp = client.post(
        "/api/v1/admin/sponsors",
        json={"name": "Test Sponsor", "logo_url": "https://example.com/logo.png", "is_active": True},
    )
    assert resp.status_code == 200
    sponsor_id = resp.json()["id"]

    # List
    resp = client.get("/api/v1/admin/sponsors")
    assert resp.status_code == 200
    assert len(resp.json()) >= 1

    # Update
    resp = client.put(f"/api/v1/admin/sponsors/{sponsor_id}", json={"name": "Updated Sponsor"})
    assert resp.status_code == 200
    assert resp.json()["name"] == "Updated Sponsor"

    # Delete
    resp = client.delete(f"/api/v1/admin/sponsors/{sponsor_id}")
    assert resp.status_code == 200

    del client.app.dependency_overrides[get_current_user]


# ── Support Issues ──────────────────────────────────────────────────

def test_submit_support_issue(client, parent_user, session):
    client.app.dependency_overrides[get_current_user] = lambda: parent_user
    resp = client.post(
        "/api/v1/support/issues",
        json={"message": "I cannot register for an event"},
    )
    assert resp.status_code == 200
    data = resp.json()
    assert data["status"] == "ok"
    assert "issue_id" in data
    del client.app.dependency_overrides[get_current_user]


def test_admin_list_support_issues(client, admin_user, session):
    issue = SupportIssue(message="Help needed", status="open")
    session.add(issue)
    session.commit()
    client.app.dependency_overrides[get_current_user] = lambda: admin_user
    resp = client.get("/api/v1/admin/support-issues")
    assert resp.status_code == 200
    assert len(resp.json()) >= 1
    del client.app.dependency_overrides[get_current_user]
