import logging
from sqlmodel import Session
from app.db.session import engine
from app.models.event import Event
from app.services.notifications import send_event_status
from app.services.search_sync import sync_event

logger = logging.getLogger(__name__)

def broadcast_event_status_bg(event_id: str, status: str):
    """Internal background task to send notifications."""
    try:
        with Session(engine) as session:
            send_event_status(session, event_id, status)
        logger.info(f"Broadcast event status complete for {event_id}")
    except Exception as e:
        logger.error(f"Failed to broadcast event status for {event_id}: {e}")

def sync_event_search_bg(event_id: str):
    """Internal background task to sync event search index."""
    try:
        with Session(engine) as session:
            event = session.get(Event, event_id)
            if event:
                sync_event(event)
        logger.info(f"Search sync complete for {event_id}")
    except Exception as e:
        logger.error(f"Failed to sync event search for {event_id}: {e}")
