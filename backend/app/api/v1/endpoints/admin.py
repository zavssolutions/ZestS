import json
import logging
from datetime import datetime, timedelta, timezone

logger = logging.getLogger(__name__)
from typing import Optional
from uuid import UUID

from fastapi import APIRouter, Depends, File, HTTPException, Query, UploadFile, status
from sqlalchemy import or_, text, delete, update
from sqlmodel import func, select
from pydantic import BaseModel

from app.api.deps import SessionDep, require_roles
from app.models.audit import AuditLog
from app.models.content import Banner, Sponsor, SupportIssue, SystemSetting, StaticPage
from app.models.enums import UserRole
from app.models.notification import Notification, DeviceToken
from app.models.event import Event, EventCategory, EventRegistration, EventResult, Payment, Referral
from app.services.search_sync import sync_event
from app.models.user import User, OrganizerProfile, ParentChildMapping, ParentProfile, TrainerProfile, SkaterProfile, DeletedUser
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
from app.schemas.event import (
    EventOut,
    EventUpdate,
    EventResultCreate,
    EventResultOut,
    EventResultUpdate,
    EventCategoryOut,
    EventCategoryUpdate,
    EventRegistrationOut,
    EventRegistrationUpdate,
)
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


@router.post("/run-migrations", response_model=dict)
def run_migrations(
    session: SessionDep,
    current_user: User = Depends(require_roles(UserRole.ADMIN)),
) -> dict:
    """Manually apply missing schema changes to the database."""
    from sqlalchemy import text
    results = []
    patches = [
        ("banners", "share_url", "VARCHAR(500)"),
    ]
    for table, column, col_type in patches:
        try:
            row = session.exec(text(
                "SELECT column_name FROM information_schema.columns "
                "WHERE table_name = :tbl AND column_name = :col"
            ), params={"tbl": table, "col": column}).first()
            if row is None:
                session.exec(text(f'ALTER TABLE "{table}" ADD COLUMN "{column}" {col_type}'), params={})
                session.commit()
                results.append(f"Added {table}.{column}")
            else:
                results.append(f"{table}.{column} already exists")
        except Exception as e:
            results.append(f"Error patching {table}.{column}: {e}")
    _log_action(session, current_user.id, "run_migrations", "system", None, {"results": results})
    return {"status": "ok", "results": results}


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


@router.get("/debug/db-dump")
def get_db_dump(
    session: SessionDep,
    current_user: User = Depends(require_roles(UserRole.ADMIN)),
) -> dict:
    """Diagnostic endpoint to dump first 50 rows of all tables."""
    from sqlmodel import SQLModel
    dump = {}
    for table_name, table in SQLModel.metadata.tables.items():
        try:
            # We use raw SQL to avoid needing to import every model class here
            result = session.exec(text(f'SELECT * FROM "{table_name}" LIMIT 50')).fetchall()
            # Convert rows to dicts
            rows = [dict(row._mapping) for row in result]
            # Convert UUIDs and datetimes to strings for JSON
            for row in rows:
                for k, v in row.items():
                    if isinstance(v, (UUID, datetime)):
                        row[k] = str(v)
            dump[table_name] = {
                "count": len(rows),
                "rows": rows
            }
        except Exception as e:
            dump[table_name] = {"error": str(e)}
    
    _log_action(session, current_user.id, "debug_db_dump", "system", None)
    return dump


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


@router.post("/users", response_model=UserAdminOut)
def create_user(
    payload: UserUpdate,
    session: SessionDep,
    current_user: User = Depends(require_roles(UserRole.ADMIN)),
) -> User:
    # Quick creation for admin
    user = User(**payload.model_dump(exclude_unset=True))
    session.add(user)
    session.commit()
    session.refresh(user)
    _log_action(session, current_user.id, "create_user", "users", user.id, payload.model_dump())
    return user

@router.delete("/users/{user_id}", response_model=dict)
def delete_user(
    user_id: UUID,
    session: SessionDep,
    current_user: User = Depends(require_roles(UserRole.ADMIN)),
) -> dict:
    from sqlalchemy import text
    user = session.get(User, user_id)
    if user is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")

    try:
        # 1. Archive User to deleted_users table
        archived_user = DeletedUser(
            original_user_id=user.id,
            role=user.role,
            email=user.email,
            first_name=user.first_name,
            last_name=user.last_name
        )
        session.add(archived_user)

        # Programmatic cleanup for models we have imported
        # 2. Nullify references (non-restrictive)
        session.exec(update(AuditLog).where(AuditLog.user_id == user_id).values(user_id=None))
        session.exec(update(SupportIssue).where(SupportIssue.user_id == user_id).values(user_id=None))
        session.exec(update(User).where(User.parent_id == user_id).values(parent_id=None))
        
        # Note: We no longer delete the organized events. The PostgreSQL constraints 
        # have been updated via migration to allow "ghost" organizer IDs pointing to the deleted_users archive.
        
        # 3. Delete user's own activity and identifiers
        session.exec(delete(DeviceToken).where(DeviceToken.user_id == user_id))
        session.exec(delete(Notification).where(Notification.user_id == user_id))
        session.exec(delete(EventRegistration).where(EventRegistration.user_id == user_id))
        session.exec(delete(EventResult).where(EventResult.user_id == user_id))
        session.exec(delete(Payment).where(Payment.user_id == user_id))
        session.exec(delete(Referral).where(or_(Referral.referrer_user_id == user_id, Referral.referred_user_id == user_id)))
        session.exec(delete(ParentChildMapping).where(or_(ParentChildMapping.parent_id == user_id, ParentChildMapping.child_id == user_id)))
        
        # 4. Delete profiles
        session.exec(delete(ParentProfile).where(ParentProfile.user_id == user_id))
        session.exec(delete(TrainerProfile).where(TrainerProfile.user_id == user_id))
        session.exec(delete(OrganizerProfile).where(OrganizerProfile.user_id == user_id))
        session.exec(delete(SkaterProfile).where(SkaterProfile.user_id == user_id))

        # Final raw SQL cleanup for any edge cases
        uid = str(user_id)
        session.exec(text("UPDATE events SET organizer_id = NULL WHERE organizer_id = (SELECT organizer_id FROM organizer_profiles WHERE user_id = :uid)"), params={"uid": uid})
        
        # Finally delete the user
        session.exec(delete(User).where(User.id == user_id))
        session.commit()
    except Exception as e:
        session.rollback()
        import traceback
        detail = traceback.format_exc()
        logger.error(f"Deletion failed for user {user_id}: {e}\n{detail}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Cannot delete user: {e}"
        )

    _log_action(session, current_user.id, "delete_user", "users", user_id)
    return {"status": "ok"}

@router.get("/events", response_model=list[EventOut])
def list_events(
    session: SessionDep,
    current_user: User = Depends(require_roles(UserRole.ADMIN, UserRole.ORGANIZER)),
) -> list[Event]:
    statement = select(Event)
    if current_user.role == UserRole.ORGANIZER:
        # Get organizer_id for the current user
        profile = session.get(OrganizerProfile, current_user.id)
        if profile:
            statement = statement.where(Event.organizer_id == profile.organizer_id)
        else:
            # If no profile, they see nothing
            return []
    statement = statement.order_by(Event.start_at_utc.desc())
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
    
    # Sync with Meilisearch
    try:
        sync_event(event)
    except Exception as e:
        logger.error(f"Search sync failed for event {event_id}: {e}")
        
    _log_action(session, current_user.id, "update_event", "events", event_id, payload.model_dump())
    return event


@router.delete("/events/{event_id}", response_model=dict)
def delete_event(
    event_id: UUID,
    session: SessionDep,
    current_user: User = Depends(require_roles(UserRole.ADMIN)),
) -> dict:
    from sqlmodel import delete
    from app.models.event import EventCategory, EventRegistration, EventResult, Payment, Referral
    
    event = session.get(Event, event_id)
    if event is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Event not found")
    
    try:
        # Explicitly delete related records using SQLModel delete constructs
        session.exec(delete(EventResult).where(EventResult.event_id == event_id))
        session.exec(delete(EventRegistration).where(EventRegistration.event_id == event_id))
        session.exec(delete(EventCategory).where(EventCategory.event_id == event_id))
        session.exec(delete(Payment).where(Payment.event_id == event_id))
        session.exec(delete(Referral).where(Referral.event_id == event_id))
        
        session.delete(event)
        session.commit()
    except Exception as e:
        session.rollback()
        import traceback
        detail = traceback.format_exc()
        raise HTTPException(status_code=500, detail=f"Failed to delete event: {e}\n{detail}")
        
    _log_action(session, current_user.id, "delete_event", "events", event_id)
    return {"status": "ok"}


@router.get("/event-categories/{category_id}", response_model=EventCategoryOut)
def get_event_category(
    category_id: UUID,
    session: SessionDep,
    current_user: User = Depends(require_roles(UserRole.ADMIN)),
) -> EventCategory:
    category = session.get(EventCategory, category_id)
    if category is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Category not found")
    return category


@router.put("/event-categories/{category_id}", response_model=EventCategoryOut)
def update_event_category(
    category_id: UUID,
    payload: EventCategoryUpdate,
    session: SessionDep,
    current_user: User = Depends(require_roles(UserRole.ADMIN)),
) -> EventCategory:
    category = session.get(EventCategory, category_id)
    if category is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Category not found")

    for key, value in payload.model_dump(exclude_unset=True).items():
        setattr(category, key, value)

    session.add(category)
    session.commit()
    session.refresh(category)
    _log_action(session, current_user.id, "update_category", "event_categories", category_id, payload.model_dump())
    return category


@router.delete("/event-categories/{category_id}", response_model=dict)
def delete_event_category(
    category_id: UUID,
    session: SessionDep,
    current_user: User = Depends(require_roles(UserRole.ADMIN)),
) -> dict:
    category = session.get(EventCategory, category_id)
    if category is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Category not found")

    session.delete(category)
    session.commit()
    _log_action(session, current_user.id, "delete_category", "event_categories", category_id)
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


class SupportIssueUpdate(BaseModel):
    status: str

@router.put("/support-issues/{issue_id}", response_model=SupportIssueOut)
def update_support_issue(
    issue_id: UUID,
    payload: SupportIssueUpdate,
    session: SessionDep,
    current_user: User = Depends(require_roles(UserRole.ADMIN)),
) -> SupportIssue:
    issue = session.get(SupportIssue, issue_id)
    if issue is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Issue not found")
    issue.status = payload.status
    session.add(issue)
    session.commit()
    session.refresh(issue)
    _log_action(session, current_user.id, "update_support_issue", "support_issues", issue_id, payload.model_dump())
    return issue

@router.get("/event-results", response_model=list[EventResultOut])
def list_event_results(
    session: SessionDep,
    current_user: User = Depends(require_roles(UserRole.ADMIN, UserRole.ORGANIZER)),
    event_id: Optional[UUID] = Query(default=None),
) -> list[EventResult]:
    statement = select(EventResult)
    if current_user.role == UserRole.ORGANIZER:
        # Filter results by events owned by the organizer
        profile = session.get(OrganizerProfile, current_user.id)
        if profile:
            organizer_events = select(Event.id).where(Event.organizer_id == profile.organizer_id)
            statement = statement.where(EventResult.event_id.in_(organizer_events))
        else:
            return []
        
    if event_id:
        # If event_id is provided, further filter by it (but only if it's one of their events, handled by the in_ check above if organizer)
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


@router.get("/registrations", response_model=list[EventRegistrationOut])
def list_registrations(
    session: SessionDep,
    current_user: User = Depends(require_roles(UserRole.ADMIN)),
    event_id: Optional[UUID] = Query(default=None),
    user_id: Optional[UUID] = Query(default=None),
    limit: int = Query(default=100, le=500),
) -> list[EventRegistration]:
    statement = select(EventRegistration).limit(limit)
    if event_id:
        statement = statement.where(EventRegistration.event_id == event_id)
    if user_id:
        statement = statement.where(EventRegistration.user_id == user_id)

    results = session.exec(statement).all()
    _log_action(session, current_user.id, "list_registrations", "event_registrations")
    return results


@router.put("/registrations/{registration_id}", response_model=EventRegistrationOut)
def update_registration(
    registration_id: UUID,
    payload: EventRegistrationUpdate,
    session: SessionDep,
    current_user: User = Depends(require_roles(UserRole.ADMIN)),
) -> EventRegistration:
    registration = session.get(EventRegistration, registration_id)
    if registration is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Registration not found")

    for key, value in payload.model_dump(exclude_unset=True).items():
        setattr(registration, key, value)

    session.add(registration)
    session.commit()
    session.refresh(registration)
    _log_action(session, current_user.id, "update_registration", "event_registrations", registration_id, payload.model_dump())
    return registration


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
class PageUpdate(BaseModel):
    content: str

@router.put("/pages/{slug}", response_model=dict)
def update_page(
    slug: str,
    payload: PageUpdate,
    session: SessionDep,
    current_user: User = Depends(require_roles(UserRole.ADMIN)),
) -> dict:
    statement = select(StaticPage).where(StaticPage.slug == slug)
    page = session.exec(statement).first()
    if not page:
        page = StaticPage(slug=slug, title=slug.replace("-", " ").title(), content=payload.content)
    else:
        page.content = payload.content
        page.updated_at = datetime.now(timezone.utc)
    session.add(page)
    session.commit()
    _log_action(session, current_user.id, "update_page", "static_pages", None, {"slug": slug})
    return {"status": "ok", "slug": slug}


@router.post("/debug/seed", response_model=dict)
def populate_e2e_data(
    session: SessionDep,
    current_user: User = Depends(require_roles(UserRole.ADMIN)),
    num_skaters: int = Query(default=100),
    num_parents: int = Query(default=10)
) -> dict:
    from app.services.seeder import seed_e2e_data
    try:
        result = seed_e2e_data(session, num_skaters=num_skaters, num_parents=num_parents)
        _log_action(session, current_user.id, "debug_seed_data", "system", None, {"num_skaters": num_skaters})
        return result
    except Exception as e:
        import traceback
        error_detail = f"Seeder failed: {str(e)}\n{traceback.format_exc()}"
        logger.error(error_detail)
        raise HTTPException(
            status_code=500,
            detail=f"Seed operation failed. Check server logs for full traceback. Error: {str(e)}"
        )


@router.post("/debug/clear", response_model=dict)
def clear_all_test_data(
    session: SessionDep,
    current_user: User = Depends(require_roles(UserRole.ADMIN)),
) -> dict:
    from app.services.seeder import clear_all_data
    result = clear_all_data(session)
    _log_action(session, current_user.id, "debug_clear_data", "system", None)
    return result

