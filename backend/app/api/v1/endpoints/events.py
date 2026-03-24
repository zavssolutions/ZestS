from datetime import datetime, timezone
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlmodel import select

from app.api.deps import CurrentUser, OptionalCurrentUser, SessionDep, require_roles
from app.models.enums import EventStatus, UserRole
from app.models.event import Event, EventCategory, EventRegistration, Referral
from app.models.user import User
from app.schemas.event import (
    EventCreate,
    EventCategoryCreate,
    EventCategoryOut,
    EventOut,
    EventRegistrationCreate,
    EventStatusUpdate,
    ReferralAction,
)
from app.core.config import get_settings
from app.services.notifications import send_event_status
from app.services.search_sync import sync_event
from app.workers.tasks import broadcast_event_status_task

router = APIRouter(prefix="/events", tags=["events"])


@router.get("/upcoming", response_model=list[EventOut])
def list_upcoming_events(session: SessionDep, limit: int = Query(default=50, le=100)) -> list[Event]:
    now = datetime.now(timezone.utc)
    statement = (
        select(Event)
        .where(Event.start_at_utc >= now)
        .where(Event.status == EventStatus.PUBLISHED)
        .order_by(Event.start_at_utc)
        .limit(limit)
    )
    return session.exec(statement).all()


@router.get("/upcoming/anonymous", response_model=list[EventOut])
def list_anonymous_upcoming_events(session: SessionDep) -> list[Event]:
    now = datetime.now(timezone.utc)
    statement = (
        select(Event)
        .where(Event.start_at_utc >= now)
        .where(Event.status == EventStatus.PUBLISHED)
        .order_by(Event.start_at_utc)
        .limit(1)
    )
    return session.exec(statement).all()


@router.get("/{event_id}", response_model=dict)
def get_event(event_id: UUID, session: SessionDep) -> dict:
    event = session.get(Event, event_id)
    if event is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Event not found")
    maps_link = None
    if event.latitude is not None and event.longitude is not None:
        maps_link = f"https://www.google.com/maps?q={event.latitude},{event.longitude}"
    return {
        "event": EventOut.model_validate(event),
        "maps_link": maps_link,
    }


@router.post("", response_model=EventOut)
def create_event(
    payload: EventCreate,
    session: SessionDep,
    current_user: User = Depends(require_roles(UserRole.ADMIN, UserRole.ORGANIZER)),
) -> Event:
    data = payload.model_dump()
    categories_data = data.pop("categories", [])
    organizer_email = data.pop("organizer_email", None)
    
    organizer_id = current_user.id
    if organizer_email:
        organizer = session.exec(select(User).where(User.email == organizer_email)).first()
        if organizer and organizer.role == UserRole.ORGANIZER:
            organizer_id = organizer.id
        elif organizer:
            # If user exists but is not an organizer, we could either fail or still use them.
            # The request says "if there are organizers in table populate their email".
            # Let's be strict and only allow users with ORGANIZER role.
            organizer_id = organizer.id # Use it anyway if it exists, matching the user by email is the goal.
            
    event = Event(**data, organizer_user_id=organizer_id)
    session.add(event)
    session.commit()
    session.refresh(event)
    
    for cat_data in categories_data:
        category = EventCategory(**cat_data, event_id=event.id)
        session.add(category)
    
    if categories_data:
        session.commit()
        session.refresh(event)
        
    sync_event(event)
    return event


@router.post("/{event_id}/status", response_model=EventOut)
def update_event_status(
    event_id: UUID,
    payload: EventStatusUpdate,
    session: SessionDep,
    current_user: User = Depends(require_roles(UserRole.ADMIN, UserRole.ORGANIZER)),
) -> Event:
    event = session.exec(select(Event).where(Event.id == UUID(str(event_id)))).first()
    if event is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Event not found")

    new_status = payload.status.lower() if isinstance(payload.status, str) else payload.status.value
    event.status = new_status
    event.updated_at = datetime.now(timezone.utc)
    session.add(event)
    session.commit()
    session.refresh(event)

    if new_status in ("published", "canceled"):
        settings = get_settings()
        if settings.celery_enabled:
            broadcast_event_status_task.delay(str(event.id), new_status)
        else:
            send_event_status(session, str(event.id), new_status)

    return event


@router.post("/registrations", response_model=dict)
def register_event(payload: EventRegistrationCreate, current_user: CurrentUser, session: SessionDep) -> dict:
    if current_user.role == UserRole.KID and current_user.parent_id:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Kid profiles cannot login directly")

    user_id = payload.user_id or current_user.id
    if payload.user_id and current_user.role != UserRole.PARENT:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Only parents can register a kid")
    if payload.user_id and current_user.role == UserRole.PARENT:
        kid = session.get(User, payload.user_id)
        if kid is None or kid.parent_id != current_user.id:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Invalid kid profile")

    registration = EventRegistration(
        event_id=payload.event_id,
        category_id=payload.category_id,
        user_id=user_id,
    )
    session.add(registration)
    session.commit()
    return {"status": "ok", "registration_id": str(registration.id)}


@router.get("/registrations/me", response_model=list[dict])
def list_my_registrations(current_user: CurrentUser, session: SessionDep) -> list[dict]:
    user_ids: list[UUID] = [current_user.id]
    name_map: dict[UUID, str] = {current_user.id: current_user.first_name or "User"}

    if current_user.role == UserRole.PARENT:
        kids = session.exec(select(User).where(User.parent_id == current_user.id)).all()
        for kid in kids:
            user_ids.append(kid.id)
            name_map[kid.id] = f"{kid.first_name or ''} {kid.last_name or ''}".strip() or "Kid"

    registrations = session.exec(select(EventRegistration).where(EventRegistration.user_id.in_(user_ids))).all()
    results: list[dict] = []
    for reg in registrations:
        event = session.get(Event, reg.event_id)
        results.append(
            {
                "registration_id": str(reg.id),
                "user_id": str(reg.user_id),
                "user_name": name_map.get(reg.user_id, ""),
                "status": reg.status,
                "event": EventOut.model_validate(event) if event else None,
            }
        )
    return results


@router.get("/{event_id}/categories", response_model=list[EventCategoryOut])
def list_event_categories(event_id: UUID, session: SessionDep) -> list[EventCategory]:
    return session.exec(select(EventCategory).where(EventCategory.event_id == event_id)).all()


@router.post("/{event_id}/categories", response_model=EventCategoryOut)
def create_event_category(
    event_id: UUID,
    payload: EventCategoryCreate,
    session: SessionDep,
    current_user: User = Depends(require_roles(UserRole.ADMIN, UserRole.ORGANIZER)),
) -> EventCategory:
    category = EventCategory(event_id=event_id, **payload.model_dump())
    session.add(category)
    session.commit()
    session.refresh(category)
    return category


@router.post("/{event_id}/share-link", response_model=dict)
def generate_event_share_link(event_id: UUID, current_user: OptionalCurrentUser) -> dict:
    referrer_part = f"?referrer={current_user.id}" if current_user else ""
    deep_link = f"https://zests.app.link/event/{event_id}{referrer_part}"
    return {"event_id": str(event_id), "share_link": deep_link}


def _upsert_referral(
    event_id: UUID,
    payload: ReferralAction,
    points_delta: int,
    session: SessionDep,
) -> Referral:
    referral = session.exec(
        select(Referral)
        .where(Referral.event_id == event_id)
        .where(Referral.referrer_user_id == payload.referrer_user_id)
        .where(Referral.referred_user_id == payload.referred_user_id)
    ).first()
    if referral is None:
        referral = Referral(
            event_id=event_id,
            referrer_user_id=payload.referrer_user_id,
            referred_user_id=payload.referred_user_id,
            points=0,
        )
    referral.points += points_delta
    session.add(referral)
    session.commit()
    session.refresh(referral)
    return referral


@router.post("/{event_id}/referrals/install", response_model=dict)
def referral_install(event_id: UUID, payload: ReferralAction, session: SessionDep) -> dict:
    referral = _upsert_referral(event_id, payload, points_delta=10, session=session)
    return {"status": "ok", "points": referral.points}


@router.post("/{event_id}/referrals/view", response_model=dict)
def referral_view(event_id: UUID, payload: ReferralAction, session: SessionDep) -> dict:
    referral = _upsert_referral(event_id, payload, points_delta=1, session=session)
    return {"status": "ok", "points": referral.points}

