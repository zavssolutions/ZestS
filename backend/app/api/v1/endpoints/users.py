from uuid import UUID
from fastapi import APIRouter, Depends, HTTPException, status
from sqlmodel import select, func

from app.api.deps import CurrentUser, SessionDep, require_roles
from app.core.config import get_settings
from app.models.enums import UserRole
from app.models.user import User, ParentChildMapping
from app.models.event import Referral
from app.schemas.user import KidCreate, UserProfileOut, UserProfileUpsert

router = APIRouter(prefix="/users", tags=["users"])


@router.get("/me", response_model=UserProfileOut)
def get_me(current_user: CurrentUser) -> User:
    return current_user


@router.get("/me/points", response_model=dict)
def get_my_points(current_user: CurrentUser, session: SessionDep) -> dict:
    total_points = session.exec(
        select(func.sum(Referral.points)).where(Referral.referrer_user_id == current_user.id)
    ).first()
    return {"total_points": total_points or 0}


@router.put("/me", response_model=UserProfileOut)
def update_me(payload: UserProfileUpsert, current_user: CurrentUser, session: SessionDep) -> User:
    for key, value in payload.model_dump(exclude_unset=True).items():
        if hasattr(current_user, key):
            # Ensure enum values are stored as lowercase strings
            if key in ('role', 'sport', 'gender') and isinstance(value, str):
                value = value.lower()
            setattr(current_user, key, value)

    role = (payload.role.value if payload.role else current_user.role) or "parent"
    if isinstance(role, UserRole):
        role = role.value
    role = str(role).lower()

    if role == "trainer":
        from app.models.user import TrainerProfile
        profile = session.get(TrainerProfile, current_user.id)
        if not profile: profile = TrainerProfile(user_id=current_user.id)
        if payload.school_name is not None: profile.school_name = payload.school_name
        if payload.club_name is not None: profile.club_name = payload.club_name
        if payload.specialization is not None: profile.specialization = payload.specialization
        if payload.experience_years is not None: profile.experience_years = payload.experience_years
        session.add(profile)
    elif role == "organizer":
        from app.models.user import OrganizerProfile
        profile = session.get(OrganizerProfile, current_user.id)
        if not profile:
            profile = OrganizerProfile(user_id=current_user.id, org_name=payload.org_name or current_user.first_name or "Organization")
        else:
            if payload.org_name is not None: profile.org_name = payload.org_name
        if payload.website_url is not None: profile.website_url = payload.website_url
        session.add(profile)
    elif role == "skater":
        from app.models.user import SkaterProfile
        profile = session.get(SkaterProfile, current_user.id)
        if not profile: profile = SkaterProfile(user_id=current_user.id)
        if payload.skill_level is not None: profile.skill_level = payload.skill_level
        if payload.years_skating is not None: profile.years_skating = payload.years_skating
        if payload.preferred_tracks is not None: profile.preferred_tracks = payload.preferred_tracks
        if payload.school_name is not None: profile.school_name = payload.school_name
        if payload.skate_type is not None: profile.skate_type = payload.skate_type
        if payload.age_group is not None: profile.age_group = payload.age_group
        session.add(profile)

    current_user.has_completed_profile = bool(current_user.first_name and current_user.favorite_sport)
    session.add(current_user)
    session.commit()
    session.refresh(current_user)
    return current_user


@router.post("/me/kids", response_model=UserProfileOut)
def add_kid(
    payload: KidCreate,
    session: SessionDep,
    current_user: User = Depends(require_roles(UserRole.PARENT)),
) -> User:
    settings = get_settings()
    kids_count = session.exec(select(User).where(User.parent_id == current_user.id)).all()
    if len(kids_count) >= settings.max_kids_per_parent:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Maximum kids limit reached")

    kid = User(
        parent_id=current_user.id,
        role="kid",
        first_name=payload.first_name,
        last_name=payload.last_name,
        dob=payload.dob,
        gender=payload.gender.lower(),
        skate_type=payload.skate_type,
        age_group=payload.age_group,
    )
    session.add(kid)
    session.commit()
    session.refresh(kid)

    # Add to mapping table
    mapping = ParentChildMapping(parent_id=current_user.id, child_id=kid.id)
    session.add(mapping)
    session.commit()

    return kid


@router.get("/me/kids", response_model=list[UserProfileOut])
def list_kids(
    session: SessionDep,
    current_user: User = Depends(require_roles(UserRole.PARENT)),
) -> list[User]:
    mappings = session.exec(select(ParentChildMapping).where(ParentChildMapping.parent_id == current_user.id)).all()
    child_ids = [m.child_id for m in mappings]
    if not child_ids:
        return []
    return session.exec(select(User).where(User.id.in_(child_ids))).all()


@router.get("/me/kids/{kid_id}", response_model=UserProfileOut)
def get_kid_details(
    kid_id: UUID,
    session: SessionDep,
    current_user: User = Depends(require_roles(UserRole.PARENT)),
) -> User:
    mapping = session.exec(
        select(ParentChildMapping)
        .where(ParentChildMapping.parent_id == current_user.id)
        .where(ParentChildMapping.child_id == kid_id)
    ).first()
    if not mapping:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Kid not found")
    
    kid = session.get(User, kid_id)
    if not kid:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Kid user not found")
    return kid
