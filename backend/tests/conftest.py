"""Shared test fixtures for the ZestS backend test suite."""

from __future__ import annotations

import os
import uuid
from typing import Generator

import pytest
from fastapi.testclient import TestClient
from sqlmodel import Session, SQLModel, create_engine
from sqlmodel.pool import StaticPool

# Force test config before importing the app
os.environ.setdefault("DATABASE_URL", "sqlite:///:memory:")
os.environ.setdefault("AUTH_ENABLED", "false")
os.environ.setdefault("FIREBASE_PROJECT_ID", "test-project")
os.environ.setdefault("APP_ENV", "test")

from app.main import app  # noqa: E402
from app.db.session import get_session  # noqa: E402
from app.models.enums import EventStatus, UserRole  # noqa: E402
from app.models.user import User  # noqa: E402
from app.models.event import Event, EventCategory  # noqa: E402
from app.models.content import StaticPage, Banner, Sponsor, SupportIssue  # noqa: E402


@pytest.fixture(name="engine")
def engine_fixture():
    engine = create_engine("sqlite://", connect_args={"check_same_thread": False}, poolclass=StaticPool)
    SQLModel.metadata.create_all(engine)
    yield engine
    engine.dispose()


@pytest.fixture(name="session")
def session_fixture(engine) -> Generator[Session, None, None]:
    with Session(engine) as session:
        yield session


@pytest.fixture(name="client")
def client_fixture(session: Session) -> Generator[TestClient, None, None]:
    def override_session():
        yield session

    app.dependency_overrides[get_session] = override_session
    with TestClient(app) as c:
        yield c
    app.dependency_overrides.clear()


@pytest.fixture(name="admin_user")
def admin_user_fixture(session: Session) -> User:
    user = User(
        id=uuid.uuid4(),
        role=UserRole.ADMIN,
        first_name="Admin",
        last_name="Test",
        email="admin@test.com",
        firebase_uid="admin_firebase_uid",
        is_active=True,
        is_verified=True,
        has_completed_profile=True,
    )
    session.add(user)
    session.commit()
    session.refresh(user)
    return user


@pytest.fixture(name="parent_user")
def parent_user_fixture(session: Session) -> User:
    user = User(
        id=uuid.uuid4(),
        role=UserRole.PARENT,
        first_name="Parent",
        last_name="Test",
        email="parent@test.com",
        firebase_uid="parent_firebase_uid",
        is_active=True,
        is_verified=True,
        has_completed_profile=True,
    )
    session.add(user)
    session.commit()
    session.refresh(user)
    return user


@pytest.fixture(name="sample_event")
def sample_event_fixture(session: Session, admin_user: User) -> Event:
    from datetime import datetime, timezone, timedelta

    event = Event(
        id=uuid.uuid4(),
        organizer_user_id=admin_user.id,
        title="Test Skating Championship 2026",
        description="Annual skating competition for all age groups",
        start_at_utc=datetime.now(timezone.utc) + timedelta(days=30),
        end_at_utc=datetime.now(timezone.utc) + timedelta(days=31),
        location_name="City Sports Arena",
        venue_city="Hyderabad",
        latitude=17.385044,
        longitude=78.486671,
        status=EventStatus.PUBLISHED,
    )
    session.add(event)
    session.commit()
    session.refresh(event)
    return event


@pytest.fixture(name="sample_category")
def sample_category_fixture(session: Session, sample_event: Event) -> EventCategory:
    cat = EventCategory(
        id=uuid.uuid4(),
        event_id=sample_event.id,
        name="Under 12 - 500m Sprint",
        skate_type="inline",
        age_group="under_12",
        track_type="oval",
        distance="500m",
        max_slots=50,
        price=500.00,
    )
    session.add(cat)
    session.commit()
    session.refresh(cat)
    return cat
