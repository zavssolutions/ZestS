import random
import uuid
from datetime import datetime, timedelta, timezone
from sqlalchemy import create_engine
from sqlmodel import Session, select
from app.core.config import get_settings
from app.models.user import User
from app.models.event import Event, EventCategory, EventRegistration, EventResult, Payment
from app.models.content import Banner, Sponsor, StaticPage, TipOfDay, SupportIssue
from app.models.enums import UserRole, EventStatus, RegistrationStatus

def populate_all():
    settings = get_settings()
    engine = create_engine(settings.database_url)
    
    with Session(engine) as session:
        # 1. Users
        print("Populating Users...")
        users = []
        roles = [UserRole.PARENT, UserRole.TRAINER, UserRole.ORGANIZER, UserRole.SPONSOR, UserRole.SKATER]
        for i in range(100):
            u = User(
                email=f"user_{i}_{uuid.uuid4().hex[:6]}@example.com",
                firebase_uid=f"fb_{uuid.uuid4().hex}",
                first_name=f"FirstName{i}",
                last_name=f"LastName{i}",
                role=random.choice(roles),
                mobile_no=f"9876543{i:03d}"
            )
            session.add(u)
            users.append(u)
        session.commit()
        for u in users: session.refresh(u)

        # 2. Events
        print("Populating Events...")
        organizers = [u for u in users if u.role == UserRole.ORGANIZER]
        if not organizers: organizers = [users[0]]
        events = []
        for i in range(100):
            e = Event(
                title=f"Skating Championship {i}",
                description=f"Description for event {i}",
                organizer_user_id=random.choice(organizers).id,
                start_at_utc=datetime.now(timezone.utc) + timedelta(days=random.randint(1, 60)),
                end_at_utc=datetime.now(timezone.utc) + timedelta(days=random.randint(61, 100)),
                location_name=f"Stadium {i}",
                venue_city=f"City {i % 10}",
                status=EventStatus.PUBLISHED
            )
            session.add(e)
            events.append(e)
        session.commit()
        for e in events: session.refresh(e)

        # 3. Event Categories
        print("Populating Event Categories...")
        categories = []
        for e in events:
            for c_idx in range(2): # 2 categories per event
                cat = EventCategory(
                    event_id=e.id,
                    name=f"Category {c_idx} - {e.title}",
                    price=random.uniform(500, 2000),
                    skate_type="inline",
                    age_group="Under 14"
                )
                session.add(cat)
                categories.append(cat)
        session.commit()
        for c in categories: session.refresh(c)

        # 4. Banners
        print("Populating Banners...")
        for i in range(5): # Limit to 5 for carousel testing
            b = Banner(
                title=f"Welcome to ZestS {i+1}",
                image_url="assets/images/zests_logo.png",
                link_url="https://zests.app",
                is_active=True,
                display_order=i
            )
            session.add(b)

        # 5. Sponsors
        print("Populating Sponsors...")
        for i in range(100):
            s = Sponsor(
                name=f"Sponsor {i}",
                logo_url=f"https://picsum.photos/seed/s{i}/200/200",
                website_url="https://sponsor.example.com"
            )
            session.add(s)

        # 6. Tips
        print("Populating Tips...")
        for i in range(100):
            t = TipOfDay(
                date=(datetime.now(timezone.utc) + timedelta(days=i-50)).date(),
                content=f"Tip {i}: Keep practicing and stay hydrated!",
                is_url=False
            )
            session.add(t)

        # 7. Support Issues
        print("Populating Support Issues...")
        for i in range(100):
            si = SupportIssue(
                user_id=random.choice(users).id,
                email=f"issue_{i}@example.com",
                message=f"I have a problem with my registration {i}",
                status="open" if i % 2 == 0 else "resolved"
            )
            session.add(si)

        # 8. Registrations, Results, Payments
        print("Populating registrations, results, payments...")
        skaters = [u for u in users if u.role == UserRole.SKATER]
        if not skaters: skaters = [users[-1]]
        
        for i in range(100):
            skater = random.choice(skaters)
            event = random.choice(events)
            # Find categories for this event
            event_cats = [c for c in categories if c.event_id == event.id]
            if not event_cats: continue
            cat = random.choice(event_cats)
            
            # Payment
            pay = Payment(
                user_id=skater.id,
                event_id=event.id,
                category_id=cat.id,
                amount=cat.price,
                status="completed"
            )
            session.add(pay)
            session.commit()
            session.refresh(pay)

            # Registration
            reg = EventRegistration(
                event_id=event.id,
                category_id=cat.id,
                user_id=skater.id,
                payment_id=pay.id,
                status="confirmed"
            )
            session.add(reg)
            
            # Result (for half of them)
            if i % 2 == 0:
                res = EventResult(
                    event_id=event.id,
                    category_id=cat.id,
                    user_id=skater.id,
                    rank=random.randint(1, 10),
                    points_earned=random.randint(10, 100)
                )
                session.add(res)
        
        session.commit()
        print("Done!")

if __name__ == "__main__":
    populate_all()
