import asyncio
from sqlalchemy.ext.asyncio import create_async_engine
from app.core.config import get_settings
from sqlmodel import SQLModel

# Import all models to ensure they are registered with SQLModel.metadata
from app.models.user import User, ParentProfile, TrainerProfile, OrganizerProfile, SkaterProfile
from app.models.event import Event, EventCategory, EventRegistration, EventResult, Referral
from app.models.notification import Notification, NotificationTemplate, DeviceToken
from app.models.content import Banner, TipOfTheDay
from app.models.audit import AuditLog

async def clear_database():
    settings = get_settings()
    engine = create_async_engine(settings.database_url, echo=True)
    
    async with engine.begin() as conn:
        print("Dropping all tables...")
        await conn.run_sync(SQLModel.metadata.drop_all)
        print("Recreating all tables...")
        await conn.run_sync(SQLModel.metadata.create_all)
    
    print("Database cleared successfully.")
    await engine.dispose()

if __name__ == "__main__":
    asyncio.run(clear_database())
