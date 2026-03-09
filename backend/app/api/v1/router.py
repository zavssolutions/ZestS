from fastapi import APIRouter

from app.api.v1.endpoints import admin, auth, config, content, events, users

api_router = APIRouter()
api_router.include_router(auth.router)
api_router.include_router(config.router)
api_router.include_router(users.router)
api_router.include_router(events.router)
api_router.include_router(content.router)
api_router.include_router(admin.router)
