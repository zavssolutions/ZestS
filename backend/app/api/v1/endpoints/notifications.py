from datetime import datetime, timezone

from fastapi import APIRouter, Depends
from sqlmodel import select

from app.api.deps import CurrentUser, SessionDep
from app.models.notification import DeviceToken, Notification
from app.schemas.notification import DeviceTokenCreate, NotificationOut

router = APIRouter(prefix="/notifications", tags=["notifications"])


@router.post("/device-token", response_model=dict)
def register_device_token(
    payload: DeviceTokenCreate,
    current_user: CurrentUser,
    session: SessionDep,
) -> dict:
    token = session.exec(select(DeviceToken).where(DeviceToken.token == payload.token)).first()
    if token is None:
        token = DeviceToken(
            user_id=current_user.id,
            token=payload.token,
            platform=payload.platform,
        )
    else:
        token.user_id = current_user.id
        token.platform = payload.platform
        token.created_at = datetime.now(timezone.utc)
    session.add(token)
    session.commit()
    return {"status": "ok"}


@router.get("", response_model=list[NotificationOut])
def list_notifications(current_user: CurrentUser, session: SessionDep) -> list[Notification]:
    statement = select(Notification).where(Notification.user_id == current_user.id).order_by(Notification.created_at.desc())
    return session.exec(statement).all()
