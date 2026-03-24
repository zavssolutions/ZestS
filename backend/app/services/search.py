from typing import Any

from meilisearch import Client
from sqlmodel import Session, select

from app.core.config import get_settings
from app.models.event import Event
from app.models.enums import EventStatus


def _client() -> Client:
    settings = get_settings()
    return Client(settings.meilisearch_url, settings.meilisearch_master_key)


def search_events(query: str, session: Session, limit: int = 20) -> list[dict[str, Any]]:
    if not query or not query.strip():
        return []
    
    query = query.strip()
    try:
        # Try MeiliSearch first
        result = _client().index("events").search(query, {"limit": limit})
        hits = result.get("hits", [])
        if hits:
            return hits
    except Exception as e:
        import logging
        logging.getLogger(__name__).warning(f"MeiliSearch failed, falling back to SQL: {e}")

    # Fallback to SQL Search
    pattern = f"%{query}%"
    statement = (
        select(Event)
        .where(
            (Event.title.ilike(pattern))
            | (Event.description.ilike(pattern))
            | (Event.location_name.ilike(pattern))
            | (Event.venue_city.ilike(pattern))
        )
        .order_by(Event.start_at_utc.desc())
        .limit(limit)
    )
    events = session.exec(statement).all()
    return [
        {
            "id": str(event.id),
            "title": event.title,
            "description": event.description,
            "venue_city": event.venue_city,
            "location_name": event.location_name,
            "start_at_utc": event.start_at_utc.isoformat(),
            "end_at_utc": event.end_at_utc.isoformat(),
            "banner_image_url": event.banner_image_url,
            "latitude": event.latitude,
            "longitude": event.longitude,
            "status": event.status,
        }
        for event in events
    ]
