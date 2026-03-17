import json
from datetime import datetime, timedelta, timezone
from typing import Optional
from uuid import UUID

from fastapi import APIRouter, Depends, File, HTTPException, Query, UploadFile, status
from sqlalchemy import or_
from sqlmodel import func, select

from app.api.deps import SessionDep, require_roles
from app.models.audit import AuditLog
from app.models.content import Banner, Sponsor, SupportIssue, SystemSetting
from app.models.enums import UserRole
from app.models.event import Event, EventRegistration, EventResult
from app.models.user import User
from app.schemas.audit import AuditLogOut
from app.schemas.content import (
    BannerCreate,
    BannerOut,
    BannerUpdate,
    SponsorCreate,
    SponsorOut,
    SponsorUpdate,
    SupportIssueOut,
)
from app.schemas.event import EventOut, EventResultCreate, EventResultOut, EventResultUpdate, EventUpdate
from app.schemas.user import UserAdminOut, UserUpdate
from app.services.storage import upload_bytes

router = APIRouter(prefix="/admin", tags=["admin"])


def _log_action(
    session: SessionDep,
    user_id: UUID,
    action: str,
    entity_type: str,
    entity_id: Optional[UUID] = None,
    metadata: Optional[dict] = None,
) -> None:
    log = AuditLog(
        user_id=user_id,
        action=action,
        entity_type=entity_type,
        entity_id=entity_id,
        metadata_json=json.dumps(metadata) if metadata else None,
    )
    session.add(log)
    session.commit()


@router.get("/stats")
def dashboard_stats(
    session: SessionDep,
    _: User = Depends(require_roles(UserRole.ADMIN)),
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
    session: SessionDep,
    current_user: User = Depends(require_roles(UserRole.ADMIN)),
) -> dict:
    setting = session.get(SystemSetting, "log_level")
    if setting is None:
        setting = SystemSetting(key="log_level", value=level.upper())
    else:
        setting.value = level.upper()
    session.add(setting)
    session.commit()
    _log_action(session, current_user.id, "set_log_level", "system_settings", None, {"level": level})
    return {"status": "ok", "log_level": level.upper()}


@router.get("/users", response_model=list[UserAdminOut])
def list_users(
    session: SessionDep,
    current_user: User = Depends(require_roles(UserRole.ADMIN)),
    search: Optional[str] = Query(default=None),
) -> list[User]:
    statement = select(User)
    if search:
        pattern = f"%{search}%"
        statement = statement.where(
            or_(
                User.first_name.ilike(pattern),
                User.last_name.ilike(pattern),
                User.email.ilike(pattern),
                User.mobile_no.ilike(pattern),
            )
        )
    results = session.exec(statement).all()
    _log_action(session, current_user.id, "list_users", "users", None, {"search": search})
    return results


@router.get("/users/{user_id}", response_model=UserAdminOut)
def get_user(
    user_id: UUID,
    session: SessionDep,
    current_user: User = Depends(require_roles(UserRole.ADMIN)),
) -> User:
    user = session.get(User, user_id)
    if user is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")
    _log_action(session, current_user.id, "get_user", "users", user_id)
    return user


@router.put("/users/{user_id}", response_model=UserAdminOut)
def update_user(
    user_id: UUID,
    payload: UserUpdate,
    session: SessionDep,
    current_user: User = Depends(require_roles(UserRole.ADMIN)),
) -> User:
    user = session.get(User, user_id)
    if user is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")

    for key, value in payload.model_dump(exclude_unset=True).items():
        setattr(user, key, value)

    user.updated_at = datetime.now(timezone.utc)
    session.add(user)
    session.commit()
    session.refresh(user)
    _log_action(session, current_user.id, "update_user", "users", user_id, payload.model_dump())
    return user


@router.get("/events", response_model=list[EventOut])
def list_events(
    session: SessionDep,
    current_user: User = Depends(require_roles(UserRole.ADMIN)),
) -> list[Event]:
    statement = select(Event).order_by(Event.start_at_utc.desc())
    results = session.exec(statement).all()
    _log_action(session, current_user.id, "list_events", "events")
    return results


@router.put("/events/{event_id}", response_model=EventOut)
def update_event(
    event_id: UUID,
    payload: EventUpdate,
    session: SessionDep,
    current_user: User = Depends(require_roles(UserRole.ADMIN)),
) -> Event:
    event = session.get(Event, event_id)
    if event is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Event not found")

    for key, value in payload.model_dump(exclude_unset=True).items():
        setattr(event, key, value)
    event.updated_at = datetime.now(timezone.utc)
    session.add(event)
    session.commit()
    session.refresh(event)
    _log_action(session, current_user.id, "update_event", "events", event_id, payload.model_dump())
    return event


@router.delete("/events/{event_id}", response_model=dict)
def delete_event(
    event_id: UUID,
    session: SessionDep,
    current_user: User = Depends(require_roles(UserRole.ADMIN)),
) -> dict:
    event = session.get(Event, event_id)
    if event is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Event not found")
    session.delete(event)
    session.commit()
    _log_action(session, current_user.id, "delete_event", "events", event_id)
    return {"status": "ok"}


@router.get("/banners", response_model=list[BannerOut])
def list_banners(
    session: SessionDep,
    current_user: User = Depends(require_roles(UserRole.ADMIN)),
) -> list[Banner]:
    statement = select(Banner).order_by(Banner.display_order, Banner.created_at.desc())
    results = session.exec(statement).all()
    _log_action(session, current_user.id, "list_banners", "banners")
    return results


@router.post("/banners", response_model=BannerOut)
def create_banner(
    payload: BannerCreate,
    session: SessionDep,
    current_user: User = Depends(require_roles(UserRole.ADMIN)),
) -> Banner:
    banner = Banner(**payload.model_dump())
    session.add(banner)
    session.commit()
    session.refresh(banner)
    _log_action(session, current_user.id, "create_banner", "banners", banner.id, payload.model_dump())
    return banner


@router.put("/banners/{banner_id}", response_model=BannerOut)
def update_banner(
    banner_id: UUID,
    payload: BannerUpdate,
    session: SessionDep,
    current_user: User = Depends(require_roles(UserRole.ADMIN)),
) -> Banner:
    banner = session.get(Banner, banner_id)
    if banner is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Banner not found")

    for key, value in payload.model_dump(exclude_unset=True).items():
        setattr(banner, key, value)
    session.add(banner)
    session.commit()
    session.refresh(banner)
    _log_action(session, current_user.id, "update_banner", "banners", banner_id, payload.model_dump())
    return banner


@router.delete("/banners/{banner_id}", response_model=dict)
def delete_banner(
    banner_id: UUID,
    session: SessionDep,
    current_user: User = Depends(require_roles(UserRole.ADMIN)),
) -> dict:
    banner = session.get(Banner, banner_id)
    if banner is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Banner not found")
    session.delete(banner)
    session.commit()
    _log_action(session, current_user.id, "delete_banner", "banners", banner_id)
    return {"status": "ok"}


@router.post("/banners/{banner_id}/upload-image", response_model=BannerOut)
def upload_banner_image(
    banner_id: UUID,
    session: SessionDep,
    current_user: User = Depends(require_roles(UserRole.ADMIN)),
    file: UploadFile = File(...),
) -> Banner:
    """Upload an image for an existing banner. The file is sent to GCP Storage
    and the banner's ``image_url`` is updated with the public URL."""
    banner = session.get(Banner, banner_id)
    if banner is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Banner not found")

    data = file.file.read()
    object_name = f"banners/{banner_id}/{file.filename}"
    url = upload_bytes(object_name, data, file.content_type or "image/png")
    banner.image_url = url
    if not banner.share_url:
        banner.share_url = f"https://zests.app.link/banner/{banner_id}"
    session.add(banner)
    session.commit()
    session.refresh(banner)
    _log_action(session, current_user.id, "upload_banner_image", "banners", banner_id, {"filename": file.filename})
    return banner


@router.get("/sponsors", response_model=list[SponsorOut])
def list_sponsors(
    session: SessionDep,
    current_user: User = Depends(require_roles(UserRole.ADMIN)),
) -> list[Sponsor]:
    statement = select(Sponsor).order_by(Sponsor.name)
    results = session.exec(statement).all()
    _log_action(session, current_user.id, "list_sponsors", "sponsors")
    return results


@router.post("/sponsors", response_model=SponsorOut)
def create_sponsor(
    payload: SponsorCreate,
    session: SessionDep,
    current_user: User = Depends(require_roles(UserRole.ADMIN)),
) -> Sponsor:
    sponsor = Sponsor(**payload.model_dump())
    session.add(sponsor)
    session.commit()
    session.refresh(sponsor)
    _log_action(session, current_user.id, "create_sponsor", "sponsors", sponsor.id, payload.model_dump())
    return sponsor


@router.put("/sponsors/{sponsor_id}", response_model=SponsorOut)
def update_sponsor(
    sponsor_id: UUID,
    payload: SponsorUpdate,
    session: SessionDep,
    current_user: User = Depends(require_roles(UserRole.ADMIN)),
) -> Sponsor:
    sponsor = session.get(Sponsor, sponsor_id)
    if sponsor is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Sponsor not found")

    for key, value in payload.model_dump(exclude_unset=True).items():
        setattr(sponsor, key, value)
    session.add(sponsor)
    session.commit()
    session.refresh(sponsor)
    _log_action(session, current_user.id, "update_sponsor", "sponsors", sponsor_id, payload.model_dump())
    return sponsor


@router.delete("/sponsors/{sponsor_id}", response_model=dict)
def delete_sponsor(
    sponsor_id: UUID,
    session: SessionDep,
    current_user: User = Depends(require_roles(UserRole.ADMIN)),
) -> dict:
    sponsor = session.get(Sponsor, sponsor_id)
    if sponsor is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Sponsor not found")
    session.delete(sponsor)
    session.commit()
    _log_action(session, current_user.id, "delete_sponsor", "sponsors", sponsor_id)
    return {"status": "ok"}


@router.get("/support-issues", response_model=list[SupportIssueOut])
def list_support_issues(
    session: SessionDep,
    current_user: User = Depends(require_roles(UserRole.ADMIN)),
    status_filter: Optional[str] = Query(default=None, alias="status"),
) -> list[SupportIssue]:
    statement = select(SupportIssue)
    if status_filter:
        statement = statement.where(SupportIssue.status == status_filter)
    statement = statement.order_by(SupportIssue.created_at.desc())
    results = session.exec(statement).all()
    _log_action(session, current_user.id, "list_support_issues", "support_issues", None, {"status": status_filter})
    return results


@router.get("/event-results", response_model=list[EventResultOut])
def list_event_results(
    session: SessionDep,
    current_user: User = Depends(require_roles(UserRole.ADMIN)),
    event_id: Optional[UUID] = Query(default=None),
) -> list[EventResult]:
    statement = select(EventResult)
    if event_id:
        statement = statement.where(EventResult.event_id == event_id)
    results = session.exec(statement).all()
    _log_action(session, current_user.id, "list_event_results", "event_results", None, {"event_id": event_id})
    return results


@router.post("/event-results", response_model=EventResultOut)
def create_event_result(
    payload: EventResultCreate,
    session: SessionDep,
    current_user: User = Depends(require_roles(UserRole.ADMIN)),
) -> EventResult:
    result = EventResult(**payload.model_dump())
    session.add(result)
    session.commit()
    session.refresh(result)
    _log_action(session, current_user.id, "create_event_result", "event_results", result.id, payload.model_dump())
    return result


@router.put("/event-results/{result_id}", response_model=EventResultOut)
def update_event_result(
    result_id: UUID,
    payload: EventResultUpdate,
    session: SessionDep,
    current_user: User = Depends(require_roles(UserRole.ADMIN)),
) -> EventResult:
    result = session.get(EventResult, result_id)
    if result is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Event result not found")

    for key, value in payload.model_dump(exclude_unset=True).items():
        setattr(result, key, value)
    session.add(result)
    session.commit()
    session.refresh(result)
    _log_action(session, current_user.id, "update_event_result", "event_results", result_id, payload.model_dump())
    return result


@router.delete("/event-results/{result_id}", response_model=dict)
def delete_event_result(
    result_id: UUID,
    session: SessionDep,
    current_user: User = Depends(require_roles(UserRole.ADMIN)),
) -> dict:
    result = session.get(EventResult, result_id)
    if result is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Event result not found")
    session.delete(result)
    session.commit()
    _log_action(session, current_user.id, "delete_event_result", "event_results", result_id)
    return {"status": "ok"}


@router.get("/logs", response_model=list[AuditLogOut])
def list_logs(
    session: SessionDep,
    current_user: User = Depends(require_roles(UserRole.ADMIN)),
    level: Optional[str] = Query(default=None),
    limit: int = Query(default=200, le=500),
) -> list[AuditLog]:
    statement = select(AuditLog).order_by(AuditLog.created_at.desc()).limit(limit)
    if level:
        statement = statement.where(AuditLog.level == level.upper())
    results = session.exec(statement).all()
    _log_action(session, current_user.id, "list_logs", "audit_logs", None, {"level": level, "limit": limit})
    return results
