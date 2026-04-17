#!/usr/bin/env python3
"""
Seed script for ZestS backend.
Creates dummy data for local development and testing.
"""

from __future__ import annotations
import sys
import uuid
from datetime import date, datetime, timedelta, timezone
from sqlmodel import Session, select

# Ensure the parent directory is importable
sys.path.insert(0, ".")

from app.db.session import engine
from app.db.base import create_db_and_tables
from app.models.enums import EventStatus, Gender, RegistrationStatus, Sport, UserRole
from app.models.user import User, ParentProfile, TrainerProfile, OrganizerProfile, SkaterProfile
from app.models.event import Event, EventCategory, EventRegistration, EventResult, Referral
from app.models.content import Banner, Sponsor, StaticPage, SupportIssue, SystemSetting

ABOUT_US_TEXT = "Our journey began with a question..."

def seed() -> None:
    print("Initializing database...")
    create_db_and_tables(engine)
    
    with Session(engine) as s:
        if s.exec(select(User)).first() is not None:
            print("⚠️ Database already has data. Skipping seed.")
            return

        now = datetime.now(timezone.utc)

        # 1. CORE USERS
        print("Creating Users...")
        admin = User(id=uuid.uuid4(), role=UserRole.ADMIN, first_name="Siva", last_name="Kumar", email="admin@zestsports.in", firebase_uid="admin_seed_uid", is_active=True, sport=Sport.SKATING, city="Hyderabad")
        parent = User(id=uuid.uuid4(), role=UserRole.PARENT, first_name="Ravi", last_name="Sharma", email="ravi.sharma@example.com", mobile_no="+919876543210", firebase_uid="parent_seed_uid", is_active=True, city="Bangalore")
        trainer = User(id=uuid.uuid4(), role=UserRole.TRAINER, first_name="Coach", last_name="Venkat", email="venkat.trainer@example.com", firebase_uid="trainer_seed_uid", is_active=True, city="Hyderabad")
        organizer = User(id=uuid.uuid4(), role=UserRole.ORGANIZER, first_name="Meena", last_name="Rao", email="meena.org@example.com", firebase_uid="organizer_seed_uid", is_active=True, city="Chennai")
        
        s.add_all([admin, parent, trainer, organizer])
        s.commit()
        
        # 2. KIDS (Depend on Parent)
        kid1 = User(id=uuid.uuid4(), parent_id=parent.id, role=UserRole.KID, first_name="Arjun", last_name="Sharma", dob=date(2016, 5, 12), email=parent.email)
        kid2 = User(id=uuid.uuid4(), parent_id=parent.id, role=UserRole.KID, first_name="Priya", last_name="Sharma", dob=date(2018, 8, 3), email=parent.email)
        s.add_all([kid1, kid2])
        s.commit()

        # 3. PROFILES (Depend on Users)
        print("Creating Profiles...")
        s.add(ParentProfile(user_id=parent.id, max_kids_allowed=3))
        s.add(TrainerProfile(user_id=trainer.id, school_name="City Skating Academy", experience_years=8))
        s.add(OrganizerProfile(user_id=organizer.id, org_name="South India Skating Federation", is_verified_org=True))
        s.add(SkaterProfile(user_id=kid1.id, skill_level="beginner"))
        s.add(SkaterProfile(user_id=kid2.id, skill_level="intermediate"))
        s.commit()

        # 4. EVENTS
        print("Creating Events...")
        event1 = Event(id=uuid.uuid4(), organizer_user_id=organizer.id, title="Hyderabad Open 2026", description="Championship", start_at_utc=now + timedelta(days=30), end_at_utc=now + timedelta(days=31), location_name="Stadium", venue_city="Hyderabad", status=EventStatus.PUBLISHED)
        event2 = Event(id=uuid.uuid4(), organizer_user_id=organizer.id, title="Bangalore Cup 2026", description="Speed Cup", start_at_utc=now + timedelta(days=60), end_at_utc=now + timedelta(days=61), location_name="Stadium", venue_city="Bangalore", status=EventStatus.PUBLISHED)
        s.add_all([event1, event2])
        s.commit()

        # 5. CATEGORIES
        cat1 = EventCategory(id=uuid.uuid4(), event_id=event1.id, name="Under 8 - 200m", skate_type="inline", age_group="under_8", price=300)
        cat2 = EventCategory(id=uuid.uuid4(), event_id=event1.id, name="Under 12 - 500m", skate_type="inline", age_group="under_12", price=500)
        s.add_all([cat1, cat2])
        s.commit()

        # 6. REGISTRATIONS
        s.add(EventRegistration(id=uuid.uuid4(), event_id=event1.id, category_id=cat1.id, user_id=kid1.id, status=RegistrationStatus.CONFIRMED))
        s.commit()

        # 7. CONTENT
        s.add(StaticPage(slug="about-us", title="About Us", content=ABOUT_US_TEXT))
        s.add(Banner(title="Welcome", image_url="assets/images/zests_logo.png"))
        s.add(Sponsor(name="SkateIndia", logo_url="https://via.placeholder.com/120x60"))
        s.commit()

        print("✅ Seed data created successfully on Supabase!")

if __name__ == "__main__":
    seed()
