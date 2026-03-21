from __future__ import annotations

import uuid
from app.api.deps import get_current_user
from app.models.content import SupportIssue, StaticPage

def test_admin_update_support_issue(client, admin_user, session):
    issue = SupportIssue(
        id=uuid.uuid4(),
        message="Help me",
        status="open",
        email="test@test.com"
    )
    session.add(issue)
    session.commit()
    
    client.app.dependency_overrides[get_current_user] = lambda: admin_user
    resp = client.put(f"/api/v1/admin/support-issues/{issue.id}", json={"status": "resolved"})
    assert resp.status_code == 200, resp.text
    assert resp.json()["status"] == "resolved"
    del client.app.dependency_overrides[get_current_user]

def test_admin_update_static_page(client, admin_user, session):
    client.app.dependency_overrides[get_current_user] = lambda: admin_user
    
    # Create new
    resp = client.put("/api/v1/admin/pages/about-us", json={"content": "New content"})
    assert resp.status_code == 200, resp.text
    assert resp.json()["slug"] == "about-us"
    
    # Update existing
    resp2 = client.put("/api/v1/admin/pages/about-us", json={"content": "Updated content"})
    assert resp2.status_code == 200, resp2.text
    del client.app.dependency_overrides[get_current_user]
