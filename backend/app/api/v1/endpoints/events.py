from datetime import datetime, timezone
from typing import Optional
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import func
from sqlalchemy.exc import IntegrityError
from sqlmodel import select

from app.api.deps import CurrentUser, OptionalCurrentUser, SessionDep, require_roles
from app.models.enums import EventStatus, UserRole
from app.models.event import Event, EventCategory, EventRegistration, Referral
from app.models.user import User, OrganizerProfile, ParentChildMapping
from app.schemas.event import (
    EventCreate,
    EventUpdate,
    EventCategoryCreate,
    EventCategoryUpdate,
    EventCategoryOut,
    EventOut,
    EventRegistrationBulkCreate,
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

    # 0. Manual date validation
    if payload.end_at_utc < payload.start_at_utc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"End date ({payload.end_at_utc}) must be on or after start date ({payload.start_at_utc})"
        )
    
    # Default to current user's organizer profile if they are an organizer
    target_organizer_id = None
    
    # helper to get organizer_id from user_id
    def get_org_id(u_id: UUID) -> Optional[int]:
        profile = session.get(OrganizerProfile, u_id)
        return profile.organizer_id if profile else None

    target_organizer_user_id = current_user.id
    if organizer_email:
        organizer_user = session.exec(select(User).where(User.email == organizer_email)).first()
        if organizer_user:
            target_organizer_id = get_org_id(organizer_user.id)
            target_organizer_user_id = organizer_user.id
    
    if target_organizer_id is None:
        # Fallback to current user if they are organizer
        target_organizer_id = get_org_id(current_user.id)
        # target_organizer_user_id remains current_user.id

    event = Event(**data, organizer_id=target_organizer_id, organizer_user_id=target_organizer_user_id)
    session.add(event)
    session.commit()
    session.refresh(event)
    
    for cat_data in categories_data:
        # Copy event price to category if event price is set
        if event.price > 0:
            cat_data["price"] = event.price
        category = EventCategory(**cat_data, event_id=event.id)
        session.add(category)
    
    if categories_data:
        session.commit()
        session.refresh(event)
        
    sync_event(event)
    return event


@router.put("/{event_id}", response_model=EventOut)
def update_event(
    event_id: UUID,
    payload: EventUpdate,
    session: SessionDep,
    current_user: User = Depends(require_roles(UserRole.ADMIN, UserRole.ORGANIZER)),
) -> Event:
    event = session.get(Event, event_id)
    if event is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Event not found")

    # If Organizer: must be owner AND status must be draft
    if current_user.role == UserRole.ORGANIZER:
        profile = session.get(OrganizerProfile, current_user.id)
        if not profile or event.organizer_id != profile.organizer_id:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="You do not own this event")
        
        if event.status != "draft":
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Published events cannot be modified by organizers")

    for key, value in payload.model_dump(exclude_unset=True).items():
        setattr(event, key, value)
    
    event.updated_at = datetime.now(timezone.utc)
    session.add(event)
    session.commit()
    session.refresh(event)
    
    # Sync search index
    try:
        sync_event(event)
    except Exception as e:
        print(f"DEBUG: Search sync failed for event {event.id}: {e}")
        
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
        mapping = session.exec(
            select(ParentChildMapping)
            .where(ParentChildMapping.parent_id == current_user.id)
            .where(ParentChildMapping.child_id == payload.user_id)
        ).first()
        if not mapping:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Invalid kid profile")

    # 1. Check Event Status
    event = session.get(Event, payload.event_id)
    if not event:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Event not found")
    if event.status != "published":
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Can only register for published events")

    # 2. Check Category Capacity
    category = session.get(EventCategory, payload.category_id)
    if not category:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Category not found")
    
    if category.max_slots > 0:
        reg_count = session.exec(
            select(func.count(EventRegistration.id))
            .where(EventRegistration.category_id == category.id)
            .where(EventRegistration.status != "cancelled")
        ).one()
        if reg_count >= category.max_slots:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="This category is full")

    registration = EventRegistration(
        event_id=payload.event_id,
        category_id=payload.category_id,
        user_id=user_id,
    )
    session.add(registration)
    try:
        session.commit()
    except IntegrityError:
        session.rollback()
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Already registered, contact administrator",
        )
    return {"message": "Registration successful", "registration_id": str(registration.id)}


@router.post("/registrations/bulk", response_model=dict)
def register_event_bulk(payload: EventRegistrationBulkCreate, current_user: CurrentUser, session: SessionDep) -> dict:
    if current_user.role == UserRole.KID and current_user.parent_id:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Kid profiles cannot login directly")

    user_id = payload.user_id or current_user.id
    if payload.user_id and current_user.role != UserRole.PARENT:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Only parents can register a kid")
    
    if payload.user_id and current_user.role == UserRole.PARENT:
        mapping = session.exec(
            select(ParentChildMapping)
            .where(ParentChildMapping.parent_id == current_user.id)
            .where(ParentChildMapping.child_id == payload.user_id)
        ).first()
        if not mapping:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Invalid kid profile")

    # 1. Check Event Status
    event = session.get(Event, payload.event_id)
    if not event:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Event not found")
    if event.status != "published":
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Can only register for published events")

    registrations = []
    for category_id in payload.category_ids:
        # 2. Check Category Capacity
        category = session.get(EventCategory, category_id)
        if not category:
            continue # skip invalid categories
        
        if category.event_id != event.id:
            continue # skip if category doesn't belong to event

        if category.max_slots > 0:
            reg_count = session.exec(
                select(func.count(EventRegistration.id))
                .where(EventRegistration.category_id == category.id)
                .where(EventRegistration.status != "cancelled")
            ).one()
            if reg_count >= category.max_slots:
                continue # skip full categories

        # Double registration check
        existing = session.exec(
            select(EventRegistration)
            .where(EventRegistration.category_id == category.id)
            .where(EventRegistration.user_id == user_id)
            .where(EventRegistration.status != "cancelled")
        ).first()
        if existing:
            continue

        registration = EventRegistration(
            event_id=payload.event_id,
            category_id=category_id,
            user_id=user_id,
        )
        session.add(registration)
        registrations.append(registration)

    duplicates_found = len(payload.category_ids) - len(registrations)
    if len(registrations) == 0 and duplicates_found > 0:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Already registered, contact administrator",
        )

    session.commit()
    return {"message": f"Successfully registered for {len(registrations)} categories", "count": len(registrations)}


@router.get("/registrations/me", response_model=list[dict])
def list_my_registrations(current_user: CurrentUser, session: SessionDep) -> list[dict]:
    user_ids: list[UUID] = [current_user.id]
    name_map: dict[UUID, str] = {current_user.id: current_user.first_name or "User"}

    if current_user.role == UserRole.PARENT:
        mappings = session.exec(select(ParentChildMapping).where(ParentChildMapping.parent_id == current_user.id)).all()
        child_ids = [m.child_id for m in mappings]
        if child_ids:
            kids = session.exec(select(User).where(User.id.in_(child_ids))).all()
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
                "category_id": str(reg.category_id),
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


@router.put("/{event_id}/categories/{category_id}", response_model=EventCategoryOut)
def update_event_category(
    event_id: UUID,
    category_id: UUID,
    payload: EventCategoryUpdate,
    session: SessionDep,
    current_user: User = Depends(require_roles(UserRole.ADMIN, UserRole.ORGANIZER)),
) -> EventCategory:
    event = session.get(Event, event_id)
    if event is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Event not found")
    
    category = session.get(EventCategory, category_id)
    if category is None or category.event_id != event.id:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Category not found in this event")

    # If Organizer: must be owner AND status must be draft
    if current_user.role == UserRole.ORGANIZER:
        profile = session.get(OrganizerProfile, current_user.id)
        if not profile or event.organizer_id != profile.organizer_id:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="You do not own this event")
        
        if event.status != "draft":
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Categories of published events cannot be modified by organizers")

    for key, value in payload.model_dump(exclude_unset=True).items():
        setattr(category, key, value)
    
    session.add(category)
    session.commit()
    session.refresh(category)
    return category


@router.delete("/{event_id}/categories/{category_id}", response_model=dict)
def delete_event_category(
    event_id: UUID,
    category_id: UUID,
    session: SessionDep,
    current_user: User = Depends(require_roles(UserRole.ADMIN, UserRole.ORGANIZER)),
) -> dict:
    event = session.get(Event, event_id)
    if event is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Event not found")

    category = session.get(EventCategory, category_id)
    if category is None or category.event_id != event.id:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Category not found in this event")

    # If Organizer: must be owner AND status must be draft
    if current_user.role == UserRole.ORGANIZER:
        profile = session.get(OrganizerProfile, current_user.id)
        if not profile or event.organizer_id != profile.organizer_id:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="You do not own this event")

        if event.status != "draft":
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Categories of published events cannot be deleted by organizers")

    session.delete(category)
    session.commit()
    return {"status": "ok"}


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
