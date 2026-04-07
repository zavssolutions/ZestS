import asyncio
from uuid import UUID
from datetime import datetime, timezone
from sqlmodel import create_engine, Session, select
from app.models.event import Event
from app.core.config import get_settings

def check_events():
    settings = get_settings()
    engine = create_engine(settings.database_url)
    with Session(engine) as session:
        now = datetime.now(timezone.utc)
        print(f"Current UTC time: {now}")
        
        # All events
        all_events = session.exec(select(Event)).all()
        print(f"Total events in DB: {len(all_events)}")
        
        for e in all_events:
            print(f"ID: {e.id}, Title: {e.title}, Status: {e.status}, StartAt: {e.start_at_utc}, Future: {e.start_at_utc >= now}")

if __name__ == "__main__":
    check_events()
