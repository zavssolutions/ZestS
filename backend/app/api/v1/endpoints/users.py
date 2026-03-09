from fastapi import APIRouter, Depends, HTTPException, status
from sqlmodel import select

from app.api.deps import CurrentUser, SessionDep, require_roles
from app.models.enums import Gender, UserRole
from app.models.user import User
from app.schemas.user import KidCreate, UserProfileOut, UserProfileUpsert

router = APIRouter(prefix="/users", tags=["users"])


@router.get("/me", response_model=UserProfileOut)
def get_me(current_user: CurrentUser) -> User:
    return current_user


@router.put("/me", response_model=UserProfileOut)
def update_me(payload: UserProfileUpsert, current_user: CurrentUser, session: SessionDep) -> User:
    for key, value in payload.model_dump(exclude_unset=True).items():
        setattr(current_user, key, value)

    current_user.has_completed_profile = bool(current_user.first_name and current_user.favorite_sport)
    session.add(current_user)
    session.commit()
    session.refresh(current_user)
    return current_user


@router.post("/me/kids", response_model=UserProfileOut)
def add_kid(
    payload: KidCreate,
    current_user: CurrentUser = Depends(require_roles(UserRole.PARENT)),
    session: SessionDep,
) -> User:
    kids_count = session.exec(select(User).where(User.parent_id == current_user.id)).all()
    if len(kids_count) >= 3:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Maximum kids limit reached")

    kid = User(
        parent_id=current_user.id,
        role=UserRole.KID,
        first_name=payload.first_name,
        last_name=payload.last_name,
        dob=payload.dob,
        gender=Gender(payload.gender.lower()),
        mobile_no=current_user.mobile_no,
        email=current_user.email,
    )
    session.add(kid)
    session.commit()
    session.refresh(kid)
    return kid


@router.get("/me/kids", response_model=list[UserProfileOut])
def list_kids(
    current_user: CurrentUser = Depends(require_roles(UserRole.PARENT)),
    session: SessionDep,
) -> list[User]:
    return session.exec(select(User).where(User.parent_id == current_user.id)).all()

