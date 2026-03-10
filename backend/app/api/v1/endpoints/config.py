from fastapi import APIRouter

from app.core.config import get_settings

router = APIRouter(prefix="/config", tags=["config"])


@router.get("/mobile", response_model=dict)
def mobile_config() -> dict:
    settings = get_settings()
    return {
        "phone_auth_enabled": settings.phone_auth_enabled,
        "google_auth_enabled": settings.google_auth_enabled,
        "payments_enabled": settings.payments_enabled,
        "auth_enabled": settings.auth_enabled,
        "max_kids_per_parent": settings.max_kids_per_parent,
        "minimum_supported_versions": {
            "android": "1.0.0",
            "ios": "1.0.0",
        },
    }
