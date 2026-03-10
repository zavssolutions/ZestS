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
    if not query:
        return []
    try:
        result = _client().index("events").search(query, {"limit": limit})
        hits = result.get("hits", [])
        return hits
    except Exception:
        pattern = f"%{query}%"
        statement = (
            select(Event)
            .where(Event.status == EventStatus.PUBLISHED)
            .where(
                (Event.title.ilike(pattern))
                | (Event.description.ilike(pattern))
                | (Event.location_name.ilike(pattern))
                | (Event.venue_city.ilike(pattern))
            )
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
            }
            for event in events
        ]
