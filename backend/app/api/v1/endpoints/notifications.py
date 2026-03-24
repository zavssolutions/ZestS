from datetime import datetime, timezone

from fastapi import APIRouter, Depends
from sqlmodel import select

from app.api.deps import CurrentUser, SessionDep, require_roles
from app.models.notification import DeviceToken, Notification
from app.models.user import User
from app.models.enums import UserRole
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


@router.post("/test", response_model=dict)
def trigger_test_notification(
    session: SessionDep,
    current_user: User = Depends(require_roles(UserRole.ADMIN)),
) -> dict:
    from app.services.notifications import _send_fcm
    tokens = session.exec(select(DeviceToken)).all()
    token_values = [token.token for token in tokens]
    
    if not token_values:
        return {"status": "ok", "devices_notified": 0, "message": "No devices registered to receive notifications"}

    title = "Test Notification"
    body = f"Sent by admin {current_user.email} at {datetime.now(timezone.utc)}"
    data = {"type": "test"}
    
    _send_fcm(token_values, title, body, data)
    
    for token in tokens:
        session.add(
            Notification(
                user_id=token.user_id,
                title=title,
                body=body,
                data_json=str(data),
            )
        )
    session.commit()
    return {"status": "ok", "devices_notified": len(token_values)}
