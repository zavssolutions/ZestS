from collections.abc import Callable
from datetime import datetime, timezone
from typing import Annotated

from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlmodel import Session, select

from app.core.config import get_settings
from app.db.session import get_session
from app.models.enums import UserRole
from app.models.user import User
from app.services.firebase_auth import verify_id_token

bearer_scheme = HTTPBearer(auto_error=False)


SessionDep = Annotated[Session, Depends(get_session)]


def get_current_user(
    session: SessionDep,
    credentials: HTTPAuthorizationCredentials | None = Depends(bearer_scheme),
) -> User:
    settings = get_settings()
    if not settings.auth_enabled:
        demo_user = session.exec(select(User).limit(1)).first()
        if demo_user is None:
            demo_user = User(first_name="Demo", role=UserRole.ADMIN, has_completed_profile=True)
            session.add(demo_user)
            session.commit()
            session.refresh(demo_user)
        return demo_user

    if credentials is None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Missing auth token")

    try:
        decoded = verify_id_token(credentials.credentials)
    except Exception as exc:  # pragma: no cover - external auth provider
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid auth token") from exc

    firebase_uid = decoded.get("uid")
    if not firebase_uid:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid auth payload")

    user = session.exec(select(User).where(User.firebase_uid == firebase_uid)).first()
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

    user.last_login_at = datetime.now(timezone.utc)
    session.add(user)
    session.commit()
    session.refresh(user)
    return user


CurrentUser = Annotated[User, Depends(get_current_user)]


def get_optional_current_user(
    session: SessionDep,
    credentials: HTTPAuthorizationCredentials | None = Depends(bearer_scheme),
) -> User | None:
    if credentials is None:
        return None
    return get_current_user(credentials=credentials, session=session)


OptionalCurrentUser = Annotated[User | None, Depends(get_optional_current_user)]


def require_roles(*allowed: UserRole) -> Callable[[CurrentUser], User]:
    def _guard(user: CurrentUser) -> User:
        if user.role not in allowed:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Insufficient permissions")
        return user

    return _guard
