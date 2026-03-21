from fastapi import APIRouter, Depends, HTTPException, status
from sqlmodel import select, func

from app.api.deps import CurrentUser, SessionDep, require_roles
from app.core.config import get_settings
from app.models.enums import Gender, UserRole
from app.models.user import User
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
            setattr(current_user, key, value)

    role = payload.role if payload.role else current_user.role
    if role == UserRole.TRAINER:
        from app.models.user import TrainerProfile
        profile = session.get(TrainerProfile, current_user.id)
        if not profile: profile = TrainerProfile(user_id=current_user.id)
        if payload.school_name is not None: profile.school_name = payload.school_name
        if payload.club_name is not None: profile.club_name = payload.club_name
        if payload.specialization is not None: profile.specialization = payload.specialization
        if payload.experience_years is not None: profile.experience_years = payload.experience_years
        session.add(profile)
    elif role == UserRole.ORGANIZER:
        from app.models.user import OrganizerProfile
        profile = session.get(OrganizerProfile, current_user.id)
        if not profile:
            profile = OrganizerProfile(user_id=current_user.id, org_name=payload.org_name or current_user.first_name or "Organization")
        else:
            if payload.org_name is not None: profile.org_name = payload.org_name
        if payload.website_url is not None: profile.website_url = payload.website_url
        session.add(profile)
    elif role == UserRole.SKATER:
        from app.models.user import SkaterProfile
        profile = session.get(SkaterProfile, current_user.id)
        if not profile: profile = SkaterProfile(user_id=current_user.id)
        if payload.skill_level is not None: profile.skill_level = payload.skill_level
        if payload.years_skating is not None: profile.years_skating = payload.years_skating
        if payload.preferred_tracks is not None: profile.preferred_tracks = payload.preferred_tracks
        if payload.school_name is not None: profile.school_name = payload.school_name
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
        role=UserRole.KID,
        first_name=payload.first_name,
        last_name=payload.last_name,
        dob=payload.dob,
        gender=Gender(payload.gender.lower()),
    )
    session.add(kid)
    session.commit()
    session.refresh(kid)
    return kid


@router.get("/me/kids", response_model=list[UserProfileOut])
def list_kids(
    session: SessionDep,
    current_user: User = Depends(require_roles(UserRole.PARENT)),
) -> list[User]:
    return session.exec(select(User).where(User.parent_id == current_user.id)).all()

