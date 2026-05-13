import asyncio
from datetime import datetime, timedelta, timezone
from uuid import uuid4
from sqlmodel import Session, select
from app.db.session import engine
from app.models.event import Event, EventCategory
from app.models.enums import EventStatus

def create_verified_event():
    with Session(engine) as session:
        # 1. Check if it already exists
        existing = session.exec(select(Event).where(Event.title == "🚀 ZestS Cloud Launch Celebration")).first()
        if existing:
            print(f"Verified event already exists: {existing.id}")
            return existing

        # 2. Create the Event
        new_event = Event(
            id=uuid4(),
            title="🚀 ZestS Cloud Launch Celebration",
            description="Our first event on Google Cloud & Supabase! Everything is now high-availability and lightning fast.",
            start_at_utc=datetime.now(timezone.utc) + timedelta(days=7),
            end_at_utc=datetime.now(timezone.utc) + timedelta(days=7, hours=4),
            location_name="Google Cloud Region, Asia South 1",
            venue_city="Cloud City",
            latitude=19.0760,
            longitude=72.8777,
            status=EventStatus.PUBLISHED,
            price=0.0
        )
        session.add(new_event)
        session.flush() # Get the ID if needed

        # 3. Add Categories
        cat1 = EventCategory(
            event_id=new_event.id,
            name="Cloud Racer (Pro)",
            category_type="Race",
            skate_type="Speed",
            age_group="Senior",
            distance="1000m",
            max_slots=100,
            price=0.0
        )
        cat2 = EventCategory(
            event_id=new_event.id,
            name="GCP Explorer (Junior)",
            category_type="Fun Run",
            skate_type="Recreational-inline",
            age_group="Junior",
            distance="400m",
            max_slots=50,
            price=0.0
        )
        session.add(cat1)
        session.add(cat2)

        session.commit()
        print(f"Successfully created Verified Event: {new_event.id}")
        return new_event

if __name__ == "__main__":
    create_verified_event()
