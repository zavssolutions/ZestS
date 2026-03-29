# ZestS Backend

## Run local

```bash
python -m venv .venv
. .venv/Scripts/Activate.ps1
pip install -r requirements.txt
alembic upgrade head
uvicorn app.main:app --reload
```

## Celery worker

```bash
celery -A app.workers.celery_app.celery_app worker --loglevel=INFO
```

## Skating Schemas

- **Category (Skate Type)**: Inline, Quad, Toy inline, tenacity.
- **Preferred Tracks**: Road, Rink, Ice, Artistic.
- **Skill Level**: 1 to 10 (Enum).
- **Age Groups**: 4-6, 6-8, ..., above 15.

## Security

- Keep Firebase service account, DB URL, and GCP creds only in env vars.
- Never commit `.jks`, `.p12`, or service account JSON.
- Write endpoints are role-protected (`admin`, `organizer`) where applicable.
