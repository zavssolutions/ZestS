import json
from functools import lru_cache
from typing import Any

import firebase_admin
from firebase_admin import auth, credentials

from app.core.config import get_settings


@lru_cache
def _init_firebase() -> firebase_admin.App:
    settings = get_settings()
    if firebase_admin._apps:
        return firebase_admin.get_app()

    cred = None
    raw = settings.firebase_service_account_json.strip()
    if raw:
        if raw.startswith("{"):
            cred = credentials.Certificate(json.loads(raw))
        else:
            cred = credentials.Certificate(raw)

    if cred is None:
        return firebase_admin.initialize_app(options={"projectId": settings.firebase_project_id or None})
    return firebase_admin.initialize_app(cred)


def verify_id_token(id_token: str) -> dict[str, Any]:
    _init_firebase()
    return auth.verify_id_token(id_token)
