from datetime import datetime, timezone
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlmodel import select

from app.api.deps import CurrentUser, SessionDep, require_roles
from app.models.enums import EventStatus, UserRole
from app.models.event import Event, EventRegistration, Referral
from app.schemas.event import (
    EventCreate,
    EventOut,
    EventRegistrationCreate,
    EventStatusUpdate,
    ReferralAction,
)
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
    current_user: CurrentUser = Depends(require_roles(UserRole.ADMIN, UserRole.ORGANIZER)),
    session: SessionDep,
) -> Event:
    event = Event(**payload.model_dump(), organizer_user_id=current_user.id)
    session.add(event)
    session.commit()
    session.refresh(event)
    sync_event(event)
    return event


@router.post("/{event_id}/status", response_model=EventOut)
def update_event_status(
    event_id: UUID,
    payload: EventStatusUpdate,
    current_user: CurrentUser = Depends(require_roles(UserRole.ADMIN, UserRole.ORGANIZER)),
    session: SessionDep,
) -> Event:
    event = session.get(Event, event_id)
    if event is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Event not found")

    event.status = EventStatus(payload.status)
    event.updated_at = datetime.now(timezone.utc)
    session.add(event)
    session.commit()
    session.refresh(event)

    if event.status in (EventStatus.PUBLISHED, EventStatus.CANCELED):
        broadcast_event_status_task.delay(str(event.id), event.status)

    return event


@router.post("/registrations", response_model=dict)
def register_event(payload: EventRegistrationCreate, current_user: CurrentUser, session: SessionDep) -> dict:
    if current_user.role == UserRole.KID and current_user.parent_id:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Kid profiles cannot login directly")

    registration = EventRegistration(**payload.model_dump())
    session.add(registration)
    session.commit()
    return {"status": "ok", "registration_id": str(registration.id)}


@router.post("/{event_id}/share-link", response_model=dict)
def generate_event_share_link(event_id: UUID, current_user: CurrentUser) -> dict:
    deep_link = f"https://zests.app.link/event/{event_id}?referrer={current_user.id}"
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

