#!/usr/bin/env python3
"""
Seed script for ZestS backend.

Creates dummy data for local development and testing.
Run from the backend directory:
    python -m scripts.seed_dummy_data

Requires env var DATABASE_URL to point to a running PostgreSQL instance.
"""

from __future__ import annotations

import sys
import uuid
from datetime import date, datetime, timedelta, timezone

from sqlmodel import Session, select

# Ensure the parent directory is importable
sys.path.insert(0, ".")

from app.db.session import engine  # noqa: E402
from app.db.base import create_db_and_tables  # noqa: E402
from app.models.enums import EventStatus, Gender, RegistrationStatus, Sport, UserRole  # noqa: E402
from app.models.user import User, ParentProfile, TrainerProfile, OrganizerProfile, SkaterProfile  # noqa: E402
from app.models.event import Event, EventCategory, EventRegistration, EventResult, Referral  # noqa: E402
from app.models.content import Banner, Sponsor, StaticPage, SupportIssue, SystemSetting  # noqa: E402
from app.models.notification import DeviceToken  # noqa: E402

ABOUT_US_TEXT = """Everyday, as our children spent three intense hours on the skating rink, we waited on the sidelines — watching, learning, and hoping we were making the right decisions for their future.

But behind the excitement, there was constant uncertainty. Finding reliable information about upcoming events was a challenge. Details were scattered. Deadlines were missed. Planning became stressful instead of strategic. As parents who were new to the sports ecosystem, we often felt we were navigating in the dark.

Then came a turning point: After attending a major event, we realized something deeper — success in sports isn't just about talent and hard work. It's also about awareness, timely information, and the right connections. Knowing trainers, understanding federations, and staying informed weren't optional advantages — they were necessities for anyone seriously considering a sporting career for their child.

We weren't organizers. We weren't from a sports background. We were simply parents trying to do our best. So we asked ourselves:
What if this confusion could be simplified?
What if every skater and parent had access to structured, reliable, and timely information in one place?

That question sparked a fire in us. What began as casual conversations during practice hours evolved into research, discussions, and eventually a proof of concept. We set out to build a tech-driven solution — not just to solve our problem, but to empower an entire skating community.

This is how our journey began."""


def seed() -> None:
    create_db_and_tables(engine)
    with Session(engine) as s:
        if s.exec(select(User)).first() is not None:
            print("⚠️  Database already has data. Skipping seed.")
            return

        now = datetime.now(timezone.utc)

        # ── Admin user ──────────────────────────────────────────
        admin = User(
            id=uuid.uuid4(),
            role=UserRole.ADMIN,
            first_name="Siva",
            last_name="Kumar",
            email="admin@zestsports.in",
            firebase_uid="admin_seed_uid",
            is_active=True,
            is_verified=True,
            has_completed_profile=True,
            sport=Sport.SKATING,
            gender=Gender.MALE,
            country="India",
            state="Telangana",
            city="Hyderabad",
        )
        s.add(admin)

        # ── Parent user ─────────────────────────────────────────
        parent = User(
            id=uuid.uuid4(),
            role=UserRole.PARENT,
            first_name="Ravi",
            last_name="Sharma",
            email="ravi.sharma@example.com",
            mobile_no="+919876543210",
            firebase_uid="parent_seed_uid",
            is_active=True,
            is_verified=True,
            has_completed_profile=True,
            sport=Sport.SKATING,
            gender=Gender.MALE,
            country="India",
            state="Karnataka",
            city="Bangalore",
        )
        s.add(parent)
        s.add(ParentProfile(user_id=parent.id, max_kids_allowed=3))

        # ── Kid users ───────────────────────────────────────────
        kid1 = User(
            id=uuid.uuid4(),
            parent_id=parent.id,
            role=UserRole.KID,
            first_name="Arjun",
            last_name="Sharma",
            dob=date(2016, 5, 12),
            sport=Sport.SKATING,
            gender=Gender.MALE,
            email=parent.email,
            mobile_no=parent.mobile_no,
        )
        kid2 = User(
            id=uuid.uuid4(),
            parent_id=parent.id,
            role=UserRole.KID,
            first_name="Priya",
            last_name="Sharma",
            dob=date(2018, 8, 3),
            sport=Sport.SKATING,
            gender=Gender.FEMALE,
            email=parent.email,
            mobile_no=parent.mobile_no,
        )
        s.add_all([kid1, kid2])
        for kid in [kid1, kid2]:
            s.add(SkaterProfile(user_id=kid.id, skill_level="beginner", years_skating=1))

        # ── Trainer user ────────────────────────────────────────
        trainer = User(
            id=uuid.uuid4(),
            role=UserRole.TRAINER,
            first_name="Coach",
            last_name="Venkat",
            email="venkat.trainer@example.com",
            firebase_uid="trainer_seed_uid",
            is_active=True,
            has_completed_profile=True,
            sport=Sport.SKATING,
            gender=Gender.MALE,
            city="Hyderabad",
        )
        s.add(trainer)
        s.add(TrainerProfile(
            user_id=trainer.id,
            school_name="City Skating Academy",
            club_name="Speed Wheels Club",
            specialization="inline",
            experience_years=8,
        ))

        # ── Organizer user ──────────────────────────────────────
        organizer = User(
            id=uuid.uuid4(),
            role=UserRole.ORGANIZER,
            first_name="Meena",
            last_name="Rao",
            email="meena.org@example.com",
            firebase_uid="organizer_seed_uid",
            is_active=True,
            has_completed_profile=True,
            sport=Sport.SKATING,
            gender=Gender.FEMALE,
            city="Chennai",
        )
        s.add(organizer)
        s.add(OrganizerProfile(
            user_id=organizer.id,
            org_name="South India Skating Federation",
            website_url="https://sisf.example.com",
            is_verified_org=True,
        ))

        s.commit()

        # ── Events ──────────────────────────────────────────────
        event1 = Event(
            id=uuid.uuid4(),
            organizer_user_id=organizer.id,
            title="Hyderabad Open Skating Championship 2026",
            description="Annual open championship for inline and quad skating. All age groups welcome.",
            start_at_utc=now + timedelta(days=30),
            end_at_utc=now + timedelta(days=31),
            location_name="Gachibowli Indoor Stadium",
            venue_city="Hyderabad",
            latitude=17.4399,
            longitude=78.3489,
            banner_image_url="https://images.unsplash.com/photo-1558618666-fcd25c85f82e?w=800",
            status=EventStatus.PUBLISHED,
        )
        event2 = Event(
            id=uuid.uuid4(),
            organizer_user_id=organizer.id,
            title="Bangalore Speed Skating Cup 2026",
            description="State-level speed skating competition on a professional 200m track.",
            start_at_utc=now + timedelta(days=60),
            end_at_utc=now + timedelta(days=61),
            location_name="Kanteerava Outdoor Stadium",
            venue_city="Bangalore",
            latitude=12.9716,
            longitude=77.5946,
            banner_image_url="https://images.unsplash.com/photo-1551698618-1dfe5d97d256?w=800",
            status=EventStatus.PUBLISHED,
        )
        event3 = Event(
            id=uuid.uuid4(),
            organizer_user_id=admin.id,
            title="Chennai Junior Skating Meet 2026",
            description="Exclusive meet for skaters under 14. Quarter and half-mile races.",
            start_at_utc=now + timedelta(days=90),
            end_at_utc=now + timedelta(days=90, hours=8),
            location_name="YMCA Grounds",
            venue_city="Chennai",
            latitude=13.0827,
            longitude=80.2707,
            status=EventStatus.DRAFT,
        )
        s.add_all([event1, event2, event3])
        s.commit()

        # ── Event categories ────────────────────────────────────
        cats = [
            EventCategory(id=uuid.uuid4(), event_id=event1.id, name="Under 8 - 200m", skate_type="inline",
                          age_group="under_8", distance="200m", max_slots=30, price=300),
            EventCategory(id=uuid.uuid4(), event_id=event1.id, name="Under 12 - 500m", skate_type="inline",
                          age_group="under_12", distance="500m", max_slots=40, price=500),
            EventCategory(id=uuid.uuid4(), event_id=event1.id, name="Open - 1000m", skate_type="inline",
                          age_group="open", distance="1000m", max_slots=50, price=800),
            EventCategory(id=uuid.uuid4(), event_id=event2.id, name="Under 14 - 300m Sprint", skate_type="speed",
                          age_group="under_14", distance="300m", max_slots=25, price=600),
            EventCategory(id=uuid.uuid4(), event_id=event2.id, name="Senior - 1500m", skate_type="speed",
                          age_group="senior", distance="1500m", max_slots=20, price=1000),
        ]
        s.add_all(cats)
        s.commit()

        # ── Event registrations ─────────────────────────────────
        reg1 = EventRegistration(
            id=uuid.uuid4(), event_id=event1.id, category_id=cats[0].id,
            user_id=kid1.id, status=RegistrationStatus.CONFIRMED,
        )
        reg2 = EventRegistration(
            id=uuid.uuid4(), event_id=event1.id, category_id=cats[1].id,
            user_id=kid2.id, status=RegistrationStatus.CONFIRMED,
        )
        s.add_all([reg1, reg2])
        s.commit()

        # ── Event results (for a completed event) ───────────────
        past_event = Event(
            id=uuid.uuid4(),
            organizer_user_id=organizer.id,
            title="Vizag Skating Open 2025",
            description="Last year's championship results.",
            start_at_utc=now - timedelta(days=60),
            end_at_utc=now - timedelta(days=59),
            location_name="Beach Stadium",
            venue_city="Visakhapatnam",
            status=EventStatus.COMPLETED,
        )
        s.add(past_event)
        past_cat = EventCategory(
            id=uuid.uuid4(), event_id=past_event.id, name="Under 10 - 200m",
            skate_type="inline", age_group="under_10", distance="200m", max_slots=30, price=400,
        )
        s.add(past_cat)
        s.commit()
        s.add_all([
            EventResult(id=uuid.uuid4(), event_id=past_event.id, category_id=past_cat.id,
                        user_id=kid1.id, rank=1, timing_ms=28500, points_earned=100),
            EventResult(id=uuid.uuid4(), event_id=past_event.id, category_id=past_cat.id,
                        user_id=kid2.id, rank=3, timing_ms=31200, points_earned=60),
        ])
        s.commit()

        # ── Static pages ────────────────────────────────────────
        s.add_all([
            StaticPage(slug="terms-and-conditions", title="Terms and Conditions", content=""),
            StaticPage(slug="about-us", title="About Us", content=ABOUT_US_TEXT),
            StaticPage(slug="privacy-policy", title="Privacy Policy", content=""),
            StaticPage(slug="faqs", title="FAQs", content=""),
        ])

        # ── Banners ─────────────────────────────────────────────
        s.add_all([
            Banner(title="Hyderabad Open 2026", image_url="https://images.unsplash.com/photo-1558618666-fcd25c85f82e?w=800",
                   link_url=f"/events/{event1.id}", placement="home_top", display_order=0),
            Banner(title="Speed Cup Bangalore", image_url="https://images.unsplash.com/photo-1551698618-1dfe5d97d256?w=800",
                   link_url=f"/events/{event2.id}", placement="home_top", display_order=1),
        ])

        # ── Sponsors ────────────────────────────────────────────
        s.add_all([
            Sponsor(name="SkateIndia", logo_url="https://via.placeholder.com/120x60?text=SkateIndia"),
            Sponsor(name="PowerWheels", logo_url="https://via.placeholder.com/120x60?text=PowerWheels"),
        ])

        # ── Support issue ───────────────────────────────────────
        s.add(SupportIssue(
            user_id=parent.id,
            email=parent.email,
            message="How do I register my second child?",
            status="open",
        ))

        # ── Referral ────────────────────────────────────────────
        s.add(Referral(
            event_id=event1.id,
            referrer_user_id=parent.id,
            referred_user_id=trainer.id,
            points=10,
        ))

        s.commit()
        print("✅ Seed data created successfully!")
        print(f"   Admin:     {admin.email}  (firebase_uid={admin.firebase_uid})")
        print(f"   Parent:    {parent.email}  (firebase_uid={parent.firebase_uid})")
        print(f"   Kid 1:     {kid1.first_name} {kid1.last_name}  (parent_id={parent.id})")
        print(f"   Kid 2:     {kid2.first_name} {kid2.last_name}  (parent_id={parent.id})")
        print(f"   Trainer:   {trainer.email}")
        print(f"   Organizer: {organizer.email}")
        print(f"   Events:    {event1.title}, {event2.title}, {event3.title}, {past_event.title}")


if __name__ == "__main__":
    seed()
