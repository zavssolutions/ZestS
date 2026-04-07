import logging
import time
from contextlib import asynccontextmanager
from pathlib import Path

from fastapi import FastAPI, Request, status
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
import sys
from fastapi.responses import JSONResponse
from fastapi.staticfiles import StaticFiles

from sqlalchemy import text
from app.api.v1.router import api_router
from app.core.config import get_settings
from app.core.logging import configure_logging
from app.db.session import engine
from alembic.config import Config
from alembic import command
import asyncio
from reset_db import reset_database_cleanly

logger = logging.getLogger(__name__)

settings = get_settings()
configure_logging()


def run_migrations():
    try:
        print("DEBUG: Starting SQLModel Native Database Creation (Bypassing Alembic)...")
        logger.info("Initializing database schema...")
        from sqlmodel import SQLModel
        
        # We must import all models so SQLModel registers them before create_all is called
        import app.models  # Ensures registries are mapped
        
        try:
            print("DEBUG: Forcefully terminating other DB connections to prevent deadlocks...")
            with engine.begin() as conn:
                conn.execute(text("""
                    SELECT pg_terminate_backend(pg_stat_activity.pid)
                    FROM pg_stat_activity
                    WHERE pg_stat_activity.datname = current_database()
                      AND pid <> pg_backend_pid();
                """))
            print("DEBUG: Other connections terminated.")
        except Exception as e:
            print(f"DEBUG: Could not terminate other connections (likely insufficient privileges on Render): {e}")
            logger.warning(f"Could not terminate other connections: {e}")
        
        print("DEBUG: Executing SQLModel.metadata.create_all(engine)...")
        SQLModel.metadata.create_all(engine)
        print("DEBUG: SQLModel table creation completed natively without freezing.")
        
        print("DEBUG: Starting raw SQL fixes to complement SQLModel...")
        with engine.begin() as conn:
            # Fix users table
            conn.execute(text("ALTER TABLE users ADD COLUMN IF NOT EXISTS sport VARCHAR(20) DEFAULT 'skating'"))
            conn.execute(text("ALTER TABLE users ADD COLUMN IF NOT EXISTS skate_type VARCHAR(60)"))
            conn.execute(text("ALTER TABLE users ADD COLUMN IF NOT EXISTS age_group VARCHAR(60)"))
            
            # Cast legacy ENUMs to VARCHAR to match the SQLModel definition and prevent DatatypeMismatch
            
            # Drop dependent constraints first
            conn.execute(text("ALTER TABLE users DROP CONSTRAINT IF EXISTS ck_users_kid_dob_required"))
            
            conn.execute(text("ALTER TABLE users ALTER COLUMN role DROP DEFAULT"))
            conn.execute(text("ALTER TABLE users ALTER COLUMN role TYPE VARCHAR(20) USING role::text"))
            conn.execute(text("ALTER TABLE users ALTER COLUMN role SET DEFAULT 'parent'"))
            
            conn.execute(text("ALTER TABLE users ALTER COLUMN gender DROP DEFAULT"))
            conn.execute(text("ALTER TABLE users ALTER COLUMN gender TYPE VARCHAR(20) USING gender::text"))
            conn.execute(text("ALTER TABLE users ALTER COLUMN gender SET DEFAULT 'unspecified'"))
            
            # Cast event and payment ENUMs to VARCHAR
            conn.execute(text("ALTER TABLE events ALTER COLUMN status DROP DEFAULT"))
            conn.execute(text("ALTER TABLE events ALTER COLUMN status TYPE VARCHAR(20) USING status::text"))
            conn.execute(text("ALTER TABLE events ALTER COLUMN status SET DEFAULT 'draft'"))
            
            # Add missing columns to events table for data population
            conn.execute(text("ALTER TABLE events ADD COLUMN IF NOT EXISTS organizer_id INTEGER"))
            conn.execute(text("ALTER TABLE events ADD COLUMN IF NOT EXISTS organizer_user_id UUID"))
            conn.execute(text("ALTER TABLE events ADD COLUMN IF NOT EXISTS images_url JSON"))
            conn.execute(text("ALTER TABLE events ADD COLUMN IF NOT EXISTS other_urls JSON"))
            conn.execute(text("ALTER TABLE events ADD COLUMN IF NOT EXISTS city VARCHAR(100)"))
            conn.execute(text("ALTER TABLE events ADD COLUMN IF NOT EXISTS price NUMERIC(10, 2) DEFAULT 0"))
            
            # Add missing columns to event_categories table
            conn.execute(text("""
                DO $$
                BEGIN
                    IF EXISTS(SELECT 1 FROM information_schema.columns WHERE table_name='event_categories' AND column_name='gender_restriction') THEN
                        ALTER TABLE event_categories RENAME COLUMN gender_restriction TO gender;
                    END IF;
                END $$;
            """))
            conn.execute(text("ALTER TABLE event_categories ADD COLUMN IF NOT EXISTS category_type VARCHAR(60)"))
            conn.execute(text("ALTER TABLE event_categories ADD COLUMN IF NOT EXISTS images_url JSON"))
            conn.execute(text("ALTER TABLE event_categories ADD COLUMN IF NOT EXISTS other_urls JSON"))
            conn.execute(text("ALTER TABLE event_categories ADD COLUMN IF NOT EXISTS city VARCHAR(100)"))
            
            # Add missing columns to banners
            conn.execute(text("ALTER TABLE banners ADD COLUMN IF NOT EXISTS share_url VARCHAR(500)"))
            
            conn.execute(text("ALTER TABLE event_registrations ALTER COLUMN status DROP DEFAULT"))
            conn.execute(text("ALTER TABLE event_registrations ALTER COLUMN status TYPE VARCHAR(20) USING status::text"))
            conn.execute(text("ALTER TABLE event_registrations ALTER COLUMN status SET DEFAULT 'pending'"))
            
            conn.execute(text("ALTER TABLE payments ALTER COLUMN status DROP DEFAULT"))
            conn.execute(text("ALTER TABLE payments ALTER COLUMN status TYPE VARCHAR(20) USING status::text"))
            conn.execute(text("ALTER TABLE payments ALTER COLUMN status SET DEFAULT 'initiated'"))
            
            # Fix skater_profiles
            conn.execute(text("ALTER TABLE skater_profiles ADD COLUMN IF NOT EXISTS skate_type VARCHAR(60)"))
            conn.execute(text("ALTER TABLE skater_profiles ADD COLUMN IF NOT EXISTS age_group VARCHAR(60)"))
            
            # Fix organizer_profiles - ensure it's not strictly NOT NULL if we pass None
            conn.execute(text("""
                DO $$
                BEGIN
                    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='organizer_profiles' AND column_name='organizer_id') THEN
                        ALTER TABLE organizer_profiles ADD COLUMN organizer_id SERIAL;
                        ALTER TABLE organizer_profiles ADD CONSTRAINT uq_organizer_id UNIQUE (organizer_id);
                    ELSE
                        ALTER TABLE organizer_profiles ALTER COLUMN organizer_id DROP NOT NULL;
                    END IF;
                END $$;
            """))
            conn.execute(text("ALTER TABLE organizer_profiles ADD COLUMN IF NOT EXISTS city VARCHAR(100)"))
            
            # Fix events
            conn.execute(text("ALTER TABLE events ADD COLUMN IF NOT EXISTS organizer_id INTEGER"))
            conn.execute(text("ALTER TABLE events ADD COLUMN IF NOT EXISTS price NUMERIC(10, 2) DEFAULT 0"))
            conn.execute(text("ALTER TABLE events ADD COLUMN IF NOT EXISTS organizer_user_id UUID"))
            
            # Fix event_categories
            conn.execute(text("ALTER TABLE event_categories ADD COLUMN IF NOT EXISTS category_type VARCHAR(60)"))
            conn.execute(text("ALTER TABLE event_categories ADD COLUMN IF NOT EXISTS city VARCHAR(100)"))
            conn.execute(text("ALTER TABLE event_categories ADD COLUMN IF NOT EXISTS images_url JSONB"))
            conn.execute(text("ALTER TABLE event_categories ADD COLUMN IF NOT EXISTS other_urls JSONB"))
            conn.execute(text("ALTER TABLE event_categories ADD COLUMN IF NOT EXISTS price NUMERIC(10, 2) DEFAULT 0"))
            
            # Fix users - ensure columns match seeder
            conn.execute(text("ALTER TABLE users ADD COLUMN IF NOT EXISTS sport VARCHAR(20) DEFAULT 'skating'"))
            conn.execute(text("ALTER TABLE users ADD COLUMN IF NOT EXISTS age_group VARCHAR(60)"))
            conn.execute(text("ALTER TABLE users ADD COLUMN IF NOT EXISTS skate_type VARCHAR(60)"))
            
            # Fix categories - ensure gender exists
            conn.execute(text("""
                DO $$
                BEGIN
                    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='event_categories' AND column_name='gender') THEN
                        IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='event_categories' AND column_name='gender_restriction') THEN
                            ALTER TABLE event_categories RENAME COLUMN gender_restriction TO gender;
                        ELSE
                            ALTER TABLE event_categories ADD COLUMN gender VARCHAR(30);
                        END IF;
                    END IF;
                END $$;
            """))
            
        print("DEBUG: Raw SQL fixes completed gracefully.")
        logger.info("Raw SQL fixes completed successfully.")
    except Exception as e:
        import traceback
        print("!!! CRITICAL MIGRATION ERROR !!!")
        print(f"Exception Message: {e}")
        traceback.print_exc()
        logger.error(f"Error running raw SQL fixes: {e}")
        raise e  # DO NOT SWALLOW

@asynccontextmanager
async def lifespan(_: FastAPI):
    print(f"DEBUG: Lifespan starting. RESET_DATABASE={settings.reset_database}")
    logger.info(f"Lifespan starting. RESET_DATABASE={settings.reset_database}")
    
    if settings.reset_database:
        print("DEBUG: Triggering reset_database_cleanly")
        logger.warning("RESET_DATABASE is set to True. Starting database reset...")
        try:
            await asyncio.to_thread(reset_database_cleanly)
            print("DEBUG: Database reset completed successfully")
        except Exception as e:
            print(f"DEBUG: Database reset failed: {e}")
            logger.error(f"Database reset failed: {e}")
    
    # Run migrations in a background thread to avoid blocking the event loop
    if settings.run_migrations:
        print("DEBUG: Running migrations...")
        await asyncio.to_thread(run_migrations)
        print("DEBUG: Migrations finished")
    else:
        print("DEBUG: Automatic migrations are disabled (RUN_MIGRATIONS=False)")
    yield


app = FastAPI(
    title=settings.app_name,
    version="1.0.0",
    openapi_url=f"{settings.api_v1_prefix}/openapi.json",
    docs_url=f"{settings.api_v1_prefix}/docs",
    redoc_url=f"{settings.api_v1_prefix}/redoc",
    lifespan=lifespan,
)

# ── Middleware ────────────────────────────────────────────────────────────

# CORS – allow_credentials=True requires explicit origins, NOT ["*"].
# Using ["*"] with credentials is rejected by browsers.
# For mobile (Dio), credentials flag is irrelevant, so we keep it simple.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.middleware("http")
async def log_requests(request: Request, call_next):
    start = time.time()
    response = await call_next(request)
    elapsed_ms = (time.time() - start) * 1000
    msg = f"REQUEST {request.method} {request.url.path} -> {response.status_code} ({elapsed_ms:.0f}ms)"
    logger.info(msg)
    print(msg) # Fail-safe print for Render logs
    return response


# ── Exception handler ────────────────────────────────────────────────────

@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    logger.exception(f"Unhandled exception on {request.url.path}")
    return JSONResponse(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        content={"detail": "An internal error has occurred"},
    )

@app.exception_handler(RequestValidationError)
async def validation_exception_handler(request: Request, exc: RequestValidationError):
    logger.error(f"Validation error on {request.url.path}: {exc.errors()}")
    return JSONResponse(
        status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
        content={"detail": exc.errors(), "body": exc.body},
    )


# ── Health check ─────────────────────────────────────────────────────────

@app.get("/", tags=["system"])
def root() -> dict:
    return {
        "message": "ZestS MVP API is running",
        "docs": f"{settings.api_v1_prefix}/docs",
        "health": "/healthz",
        "reset_database_enabled": settings.reset_database
    }

@app.get("/healthz", tags=["system"])
def healthz() -> dict:
    return {"status": "ok"}


# ── Static files & routes ────────────────────────────────────────────────

static_dir = Path("static")
static_dir.mkdir(exist_ok=True)
(static_dir / "uploads").mkdir(exist_ok=True)

app.include_router(api_router, prefix=settings.api_v1_prefix)
app.mount("/static", StaticFiles(directory="static"), name="static")
