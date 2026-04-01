from app.db.session import Session, engine
from app.models.event import Event, EventCategory
from app.models.enums import EventStatus, UserRole
from app.models.user import User
from app.api.v1.endpoints.admin import get_db_dump
from uuid import uuid4
from datetime import datetime, timedelta, timezone
import json

def test_and_dump_internal():
    with Session(engine) as session:
        # 1. Create Event
        event_id = uuid4()
        event = Event(
            id=event_id,
            title="Shell Massive Test with Dump",
            description="Verified 10 categories + Debug Dump",
            start_at_utc=datetime.now(timezone.utc) + timedelta(days=5),
            end_at_utc=datetime.now(timezone.utc) + timedelta(days=6),
            status=EventStatus.PUBLISHED,
            location_name="Internal Arena",
            venue_city="Dump City"
        )
        session.add(event)
        for i in range(1, 11):
            cat = EventCategory(
                id=uuid4(), event_id=event_id, name=f"Cat {i}", 
                price=10.0*i, skate_type="inline", age_group="Under 15"
            )
            session.add(cat)
        session.commit()
        
        # 2. Mock Admin User and Call Dump logic
        admin_user = User(id=uuid4(), email="admin@test.com", role=UserRole.ADMIN)
        dump = get_db_dump(session=session, current_user=admin_user)
        
        # 3. Print Filtered Dump
        print("\n--- DB DUMP: events ---")
        event_row = next((e for e in dump["events"]["rows"] if e["id"] == str(event_id)), None)
        print(json.dumps(event_row, indent=2))
        
        print("\n--- DB DUMP: event_categories ---")
        cat_rows = [c for c in dump["event_categories"]["rows"] if c["event_id"] == str(event_id)]
        for c in cat_rows:
            print(f"  - {c['name']}: {c['price']}")
        
        print(f"\n✅ VERIFIED: Found {len(cat_rows)} categories in dump!")

if __name__ == "__main__":
    test_and_dump_internal()
