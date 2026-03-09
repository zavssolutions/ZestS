# Meilisearch Sync

`events` index is updated from backend service hooks.

- `sync_event(event)` is called on event create/update.
- Celery task `sync_event_search` can be expanded for bulk sync.
- Keep PostgreSQL as source of truth.
