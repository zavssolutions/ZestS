from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends
from sqlmodel import func, select

from app.api.deps import SessionDep, require_roles
from app.models.content import SystemSetting
from app.models.enums import UserRole
from app.models.event import Event, EventRegistration
from app.models.user import User

router = APIRouter(prefix="/admin", tags=["admin"])


@router.get("/stats")
def dashboard_stats(
    _: User = Depends(require_roles(UserRole.ADMIN)),
    session: SessionDep,
) -> dict:
    today_start = datetime.now(timezone.utc).replace(hour=0, minute=0, second=0, microsecond=0)
    yesterday_start = today_start - timedelta(days=1)

    total_users = session.exec(select(func.count(User.id))).one()
    total_events = session.exec(select(func.count(Event.id))).one()

    active_users_today = session.exec(
        select(func.count(User.id)).where(User.last_login_at >= today_start)
    ).one()
    registrations_today = session.exec(
        select(func.count(EventRegistration.id)).where(EventRegistration.created_at >= today_start)
    ).one()

    users_yesterday = session.exec(
        select(func.count(User.id))
        .where(User.created_at >= yesterday_start)
        .where(User.created_at < today_start)
    ).one()

    users_today = session.exec(select(func.count(User.id)).where(User.created_at >= today_start)).one()

    return {
        "total_users": total_users,
        "active_users_today": active_users_today,
        "total_events": total_events,
        "registrations_today": registrations_today,
        "trend": {
            "users_delta": users_today - users_yesterday,
        },
    }


@router.put("/log-level/{level}")
def set_log_level(
    level: str,
    _: User = Depends(require_roles(UserRole.ADMIN)),
    session: SessionDep,
) -> dict:
    setting = session.get(SystemSetting, "log_level")
    if setting is None:
        setting = SystemSetting(key="log_level", value=level.upper())
    else:
        setting.value = level.upper()
    session.add(setting)
    session.commit()
    return {"status": "ok", "log_level": level.upper()}

