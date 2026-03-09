from fastapi import APIRouter, Depends, HTTPException, status
from sqlmodel import select

from app.api.deps import SessionDep
from app.models.enums import UserRole
from app.models.user import User
from app.schemas.auth import AuthTokenRequest, AuthTokenResponse
from app.services.firebase_auth import verify_id_token

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/token", response_model=AuthTokenResponse)
def exchange_token(payload: AuthTokenRequest, session: SessionDep) -> AuthTokenResponse:
    try:
        decoded = verify_id_token(payload.id_token)
    except Exception as exc:  # pragma: no cover
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid auth token") from exc

    firebase_uid = decoded.get("uid")
    if not firebase_uid:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Missing uid in token")

    user = session.exec(select(User).where(User.firebase_uid == firebase_uid)).first()
    is_new = user is None

    if user is None:
        user = User(
            firebase_uid=firebase_uid,
            google_uid=decoded.get("user_id"),
            email=decoded.get("email"),
            mobile_no=decoded.get("phone_number"),
            first_name=decoded.get("name"),
            profile_picture_url=decoded.get("picture"),
            role=UserRole.PARENT,
        )
        session.add(user)
        session.commit()
        session.refresh(user)

    return AuthTokenResponse(access_token=payload.id_token, user_id=str(user.id), is_new_user=is_new)

