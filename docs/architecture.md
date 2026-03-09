# Architecture

## Services

- Flutter mobile app communicates with FastAPI over HTTPS.
- FastAPI uses PostgreSQL as source of truth.
- Redis powers cache/session and Celery broker.
- Celery handles background jobs (notifications/search sync).
- Meilisearch accelerates event search.
- Next.js admin runs under `/admin` base path.

## Core design choices

- All event times are stored as UTC in PostgreSQL (`TIMESTAMPTZ`).
- Kids are sub-profiles under parent users (`users.parent_id`).
- Auth and payments are toggleable via environment flags.
- Terms and Conditions and About pages are static rows in `static_pages`.
