import json
import random
from uuid import uuid4
from datetime import datetime, timedelta, timezone

from sqlalchemy import delete
from sqlmodel import Session, select, func

from app.models.user import User, OrganizerProfile, SkaterProfile, ParentProfile, ParentChildMapping
from app.models.event import Event, EventCategory, EventRegistration, EventResult
from app.models.content import Sponsor, Banner
from app.models.enums import UserRole

def clear_all_data(session: Session):
    """
    Carefully deletes ALL dynamically populated data in the correct foreign key order structure.
    Does NOT wipe schema data, only user-generated/event rows.
    """
    try:
        # 1. Truncate bottom tier event references
        print("DEBUG SEEDER: Clearing results and registrations...")
        session.execute(delete(EventResult))
        session.execute(delete(EventRegistration))
        
        # 2. Delete Categories, then Events themselves
        print("DEBUG SEEDER: Clearing categories and events...")
        session.execute(delete(EventCategory))
        session.execute(delete(Event))

        # 3. Delete Hierarchies
        print("DEBUG SEEDER: Clearing hierarchies...")
        session.execute(delete(ParentChildMapping))

        # 4. Delete Profiles
        print("DEBUG SEEDER: Clearing profiles...")
        session.execute(delete(SkaterProfile))
        session.execute(delete(ParentProfile))
        session.execute(delete(OrganizerProfile))

        # 5. Delete Users except admins
        print("DEBUG SEEDER: Clearing non-admin users...")
        session.execute(delete(User).where(User.role != "admin"))

        # 6. Delete Sponsors & Banners
        print("DEBUG SEEDER: Clearing sponsors and banners...")
        session.execute(delete(Banner))
        session.execute(delete(Sponsor))

        session.commit()
        return {"message": "All data cleared successfully."}
    except Exception as e:
        session.rollback()
        print(f"DEBUG SEEDER ERROR in clear: {str(e)}")
        raise e



def seed_e2e_data(session: Session, num_skaters: int = 100, num_parents: int = 10):
    """
    End-to-End massive populator. Appends to existing data instead of wiping.
    """
    try:
        now = datetime.now(timezone.utc)
        
        # Generate random constants
        genders = ["male", "female"]
        skate_types = ["Inline", "Quad", "Figure"]
        age_groups = ["U10", "10-15", "15-20", "20+"]
        distances = ["100m", "500m", "1000m"]
        
        # ==========================================
        # 1. Create Organizer
        # ==========================================
        print("DEBUG SEEDER: Creating organizer...")
        org_user = User(
            email=f"organizer_{uuid4().hex[:6]}@zests.test",
            first_name="Demo",
            last_name="Organizer",
            role="organizer",
            is_active=True,
        )
        session.add(org_user)
        session.commit()
        session.refresh(org_user)
        
        org_prof = OrganizerProfile(
            user_id=org_user.id,
            organizer_id=random.randint(100, 9999), # Manual ID to bypass sequence/not-null issues
            org_name="ZestS Official Massive Org",
            is_verified_org=True
        )
        session.add(org_prof)
        session.commit()
        session.refresh(org_prof)

        # ==========================================
        # 2. Create Event & Event Categories (Cartesian Product)
        # ==========================================
        print(f"DEBUG SEEDER: Creating event for organizer_id={org_prof.organizer_id}...")
        event = Event(
            organizer_id=org_prof.organizer_id,
            organizer_user_id=org_user.id,
            title=f"Massive E2E Seed Event {uuid4().hex[:4]}",
            start_at_utc=now + timedelta(days=10),
            end_at_utc=now + timedelta(days=12),
            location_name="ZestS Mega Arena",
            status="published",
            price=150.0
        )
        session.add(event)
        session.commit()
        session.refresh(event)

        print("DEBUG SEEDER: Creating categories...")
        categories = []
        # Make a few diverse categories so we can assign users
        for s_type in skate_types:
            for a_grp in age_groups:
                for dist in distances:
                    for gen in genders:
                        cat = EventCategory(
                            event_id=event.id,
                            name=f"{s_type} {dist} {a_grp} {gen}",
                            skate_type=s_type,
                            age_group=a_grp,
                            distance=dist,
                            gender=gen,
                            price=150.0
                        )
                        categories.append(cat)
                        session.add(cat)
        session.commit()

        # ==========================================
        # 3. Create Sponsor & Banner
        # ==========================================
        print("DEBUG SEEDER: Creating sponsor and banner...")
        sponsor = Sponsor(
            name="RedBull ZestS Simulator",
            logo_url="https://picsum.photos/100"
        )
        session.add(sponsor)
        session.commit()
        
        banner = Banner(
            title="Welcome to ZestS!",
            image_url="assets/images/zests_logo.png",
            placement="home_top",
            share_url=f"https://zests.app.link/home"
        )
        session.add(banner)

        banner2 = Banner(
            title="Register for upcoming championships!",
            image_url="assets/images/zests_logo.png",
            placement="home_top",
            share_url=f"https://zests.app.link/events"
        )
        session.add(banner2)
        session.commit()

        # ==========================================
        # 4. Create Parents & Kids
        # ==========================================
        print(f"DEBUG SEEDER: Creating {num_parents} parents...")
        kids = []
        for i in range(num_parents):
            parent = User(
                email=f"parent_{uuid4().hex[:6]}@zests.test",
                first_name=f"Parent {i}",
                role="parent",
            )
            session.add(parent)
            session.commit()
            session.refresh(parent)
            
            # Add 2 kids per parent
            for j in range(2):
                k_gen = random.choice(genders)
                k_age = random.choice(age_groups[:2]) # mostly younger
                k_skts = random.choice(skate_types)
                
                kid = User(
                    email=f"kid_{uuid4().hex[:8]}@zests.test",
                    first_name=f"Kid {i}-{j}",
                    role="kid",
                    gender=k_gen,
                    sport="skating"
                )
                session.add(kid)
                session.commit()
                session.refresh(kid)
                
                kids.append({
                    "user": kid,
                    "gender": k_gen,
                    "age_group": k_age,
                    "skate_type": k_skts
                })
                
                # Map Parent to Kid
                mapping = ParentChildMapping(parent_id=parent.id, child_id=kid.id)
                session.add(mapping)
                
                kid_profile = SkaterProfile(
                    user_id=kid.id,
                    skill_level="Intermediate",
                    skate_type=k_skts,
                    age_group=k_age
                )
                session.add(kid_profile)
        session.commit()

        # ==========================================
        # 5. Create random Skaters
        # ==========================================
        print(f"DEBUG SEEDER: Creating {num_skaters} skaters...")
        skaters = []
        for i in range(num_skaters):
            s_gen = random.choice(genders)
            s_age = random.choice(age_groups)
            s_skts = random.choice(skate_types)
            
            skater = User(
                email=f"skater_{uuid4().hex[:8]}@zests.test",
                first_name=f"Skater {i}",
                role="kid", # Let's assume all skaters are standalone "kid" roles for this logic
                gender=s_gen,
            )
            session.add(skater)
            session.commit()
            session.refresh(skater)
            
            skaters.append({
                "user": skater,
                "gender": s_gen,
                "age_group": s_age,
                "skate_type": s_skts
            })
            
            skater_prof = SkaterProfile(
                user_id=skater.id,
                skill_level="Advanced",
                skate_type=s_skts,
                age_group=s_age
            )
            session.add(skater_prof)
        session.commit()
        
        # Combine kids and skaters for universal registration step
        all_participants = kids + skaters

        # ==========================================
        # 6. Registrations
        # ==========================================
        print("DEBUG SEEDER: Creating registrations...")
        for p in all_participants:
            # Find matching categories
            matching_cats = [c for c in categories 
                             if c.gender == p["gender"] 
                             and c.age_group == p["age_group"] 
                             and c.skate_type == p["skate_type"]]
            if not matching_cats:
                continue
            
            chosen_cat = random.choice(matching_cats)
            
            reg = EventRegistration(
                event_id=event.id,
                category_id=chosen_cat.id,
                user_id=p["user"].id,
                status="confirmed"
            )
            session.add(reg)
        
        # Single commit for all registrations
        try:
            session.commit()
        except Exception as e:
            session.rollback()
            print(f"DEBUG SEEDER: Registration batch commit failed: {e}")

        # ==========================================
        # 7. Create Leaderboard Event Results
        # ==========================================
        print("DEBUG SEEDER: Generating leaderboard...")
        regs = session.execute(select(EventRegistration).where(EventRegistration.event_id == event.id)).scalars().all()
        
        # Group by category_id
        cat_to_users = {}
        for r in regs:
            if r.category_id not in cat_to_users:
                cat_to_users[r.category_id] = []
            cat_to_users[r.category_id].append(r.user_id)
            
        for cat_id, uids in cat_to_users.items():
            if len(uids) == 0:
                continue
                
            random.shuffle(uids)
            winners = uids[:3] # Up to top 3
            
            for rank, uid in enumerate(winners, start=1):
                pts = 100 if rank == 1 else (75 if rank == 2 else 50)
                res = EventResult(
                    event_id=event.id,
                    category_id=cat_id,
                    user_id=uid,
                    rank=rank,
                    timing_ms=random.randint(45000, 120000), # 45s to 2mins
                    points_earned=pts
                )
                session.add(res)
        session.commit()

        print("DEBUG SEEDER: Completed successfully!")
        return {"message": "Success! Massive dataset injected into ZestS."}
    except Exception as e:
        session.rollback()
        import traceback
        error_msg = f"SEEDER ERROR: {str(e)}\n{traceback.format_exc()}"
        print(error_msg)
        raise e

