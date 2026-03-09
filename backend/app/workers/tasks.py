from app.workers.celery_app import celery_app


@celery_app.task(name="broadcast_event_status")
def broadcast_event_status_task(event_id: str, status: str) -> dict:
    # Hook for FCM push notifications and in-app notifications.
    return {"event_id": event_id, "status": status}


@celery_app.task(name="sync_event_search")
def sync_event_search_task(event_id: str) -> dict:
    return {"event_id": event_id, "synced": True}
