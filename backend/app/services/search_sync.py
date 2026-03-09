from meilisearch import Client

from app.core.config import get_settings
from app.models.event import Event


def _client() -> Client:
    settings = get_settings()
    return Client(settings.meilisearch_url, settings.meilisearch_master_key)


def sync_event(event: Event) -> None:
    payload = {
        "id": str(event.id),
        "title": event.title,
        "description": event.description,
        "venue_city": event.venue_city,
        "location_name": event.location_name,
        "start_at_utc": event.start_at_utc.isoformat(),
    }
    _client().index("events").add_documents([payload])
