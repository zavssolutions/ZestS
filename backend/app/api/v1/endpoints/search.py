from fastapi import APIRouter, Query

from app.api.deps import SessionDep
from app.services.search import search_events

router = APIRouter(prefix="/search", tags=["search"])


@router.get("/events", response_model=list[dict])
def search_events_endpoint(session: SessionDep, q: str = Query(min_length=1), limit: int = Query(default=20, le=50)):
    return search_events(q, session, limit=limit)
