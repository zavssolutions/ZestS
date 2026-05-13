import sys
import os
from sqlmodel import create_engine, Session, select
from datetime import datetime, timedelta, timezone
from uuid import uuid4

# Add current directory to path
sys.path.append(os.getcwd())

from app.core.config import get_settings
from app.models.user import User
from app.models.event import Event, EventCategory, EventRegistration, EventResult
from app.models.enums import EventStatus, RegistrationStatus

def test_flow():
    settings = get_settings()
    engine = create_engine(settings.database_url)
    
    with Session(engine) as session:
        # 1. Setup Admin & Skater
        admin = session.exec(select(User).where(User.role == "admin")).first()
        skater = session.exec(select(User).where(User.role == "kid")).first()
        
        if not admin or not skater:
            print("Missing admin or skater. Seeding might have failed.")
            return

        print(f"Testing with Admin: {admin.email} and Skater: {skater.email}")

        # 2. Admin Creates Event
        print("[Admin] Creating event...")
        event = Event(
            title="E2E Test Championship",
            description="Testing the full flow",
            venue_city="Bangalore",
            start_at_utc=datetime.now(timezone.utc) + timedelta(days=7),
            end_at_utc=datetime.now(timezone.utc) + timedelta(days=8),
            organizer_id=None, # System event
            status=EventStatus.DRAFT,
            location_name="ZestS Arena"
        )
        session.add(event)
        session.commit()
        session.refresh(event)
        print(f"Event created with ID: {event.id}")

        cat = EventCategory(
            event_id=event.id,
            name="Speed 500m U12",
            price=1.0,
            category_type="speed"
        )
        session.add(cat)
        session.commit()
        session.refresh(cat)
        print(f"Category added: {cat.name}")

        # 3. Admin Publishes Event
        print("[Admin] Publishing event...")
        event.status = EventStatus.PUBLISHED
        session.add(event)
        session.commit()
        print("Event published.")

        # 4. Skater Registers for Event
        print("[Skater] Registering for event...")
        reg = EventRegistration(
            event_id=event.id,
            user_id=skater.id,
            category_id=cat.id,
            status=RegistrationStatus.CONFIRMED
        )
        session.add(reg)
        session.commit()
        print(f"Registration confirmed: {reg.id}")

        # 5. Admin Publishes Result
        print("[Admin] Publishing result...")
        res = EventResult(
            event_id=event.id,
            category_id=cat.id,
            user_id=skater.id,
            rank=1,
            timing_ms=45120,
            points_earned=100
        )
        session.add(res)
        session.commit()
        print("Result published.")

        # 6. Skater Views Result
        print("[Skater] Verifying result visibility...")
        verify_res = session.exec(select(EventResult).where(
            EventResult.event_id == event.id,
            EventResult.user_id == skater.id
        )).first()
        
        if verify_res:
            print(f"SUCCESS: Skater result found! Rank: {verify_res.rank}")
            print(f"Timing MS: {verify_res.timing_ms}")
        else:
            print("FAILURE: Result not found for skater.")

if __name__ == "__main__":
    test_flow()
