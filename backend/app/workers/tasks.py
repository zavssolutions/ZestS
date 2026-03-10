from sqlmodel import Session

from app.db.session import engine
from app.models.event import Event
from app.services.notifications import send_event_status
from app.services.search_sync import sync_event
from app.workers.celery_app import celery_app


@celery_app.task(name="broadcast_event_status")
def broadcast_event_status_task(event_id: str, status: str) -> dict:
    with Session(engine) as session:
        send_event_status(session, event_id, status)
    return {"event_id": event_id, "status": status}


@celery_app.task(name="sync_event_search")
def sync_event_search_task(event_id: str) -> dict:
    with Session(engine) as session:
        event = session.get(Event, event_id)
        if event:
            sync_event(event)
    return {"event_id": event_id, "synced": True}
