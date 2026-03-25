
import pytest
from datetime import datetime, timezone, timedelta
from uuid import uuid4
from sqlmodel import Session, select
from app.db.session import engine
from app.db.base import create_db_and_tables
from app.models.user import User
from app.models.event import Event, EventStatus
from app.models.notification import DeviceToken
from app.services.search import search_events
from app.api.v1.endpoints.notifications import trigger_test_notification

def setup_module(module):
    # Ensure tables exist for tests (especially if using sqlite memory/file)
    create_db_and_tables(engine)

def test_search_fallback():
    with Session(engine) as session:
        # Create an organizer user
        org_id = uuid4()
        org = User(id=org_id, first_name="Org", role="organizer", email="org@test.com")
        session.add(org)
        session.commit()

        # Create a published event
        event_id = uuid4()
        now = datetime.now(timezone.utc)
        event = Event(
            id=event_id,
            organizer_user_id=org_id,
            title="Refinement Test Event",
            description="Testing the search fallback",
            venue_city="Test City",
            location_name="Test Loc",
            status=EventStatus.PUBLISHED,
            start_at_utc=now + timedelta(days=1),
            end_at_utc=now + timedelta(days=1, hours=2)
        )
        session.add(event)
        session.commit()
        
        # Test search (should fallback to SQL if MeiliSearch is not configured)
        results = search_events("Refinement Test", session)
        assert len(results) >= 1
        assert any(r["title"] == "Refinement Test Event" for r in results)
        
        # Cleanup
        session.delete(event)
        session.commit()

def test_notification_safety():
    with Session(engine) as session:
        # Just verify we can query without error
        tokens = session.exec(select(DeviceToken)).all()
        assert isinstance(tokens, list)

def test_user_count_logic():
    with Session(engine) as session:
        # Create a parent and a kid
        parent_id = uuid4()
        parent = User(id=parent_id, first_name="Parent", role="parent", email="parent@test.com")
        session.add(parent)
        session.commit()
        session.refresh(parent)
        
        kid = User(first_name="Kid", role="kid", parent_id=parent.id)
        session.add(kid)
        session.commit()
        
        # Verify both exist in User table
        all_users = session.exec(select(User)).all()
        assert any(u.first_name == "Parent" for u in all_users)
        assert any(u.role == "kid" and u.parent_id == parent.id for u in all_users)
        
        # Cleanup
        session.delete(kid)
        session.delete(parent)
        session.commit()
