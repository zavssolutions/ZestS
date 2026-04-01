import logging
import time
from contextlib import asynccontextmanager
from pathlib import Path

from fastapi import FastAPI, Request, status
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from fastapi.staticfiles import StaticFiles

from sqlalchemy import text
from app.api.v1.router import api_router
from app.core.config import get_settings
from app.core.logging import configure_logging
from app.db.session import engine
from alembic.config import Config
from alembic import command

logger = logging.getLogger(__name__)

settings = get_settings()
configure_logging()


def run_migrations():
    try:
        logger.info("Running automatic Alembic migrations...")
        import os
        base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        alembic_ini_path = os.path.join(base_dir, "alembic.ini")
        alembic_cfg = Config(alembic_ini_path)
        alembic_cfg.set_main_option("script_location", os.path.join(base_dir, "alembic"))
        
        command.upgrade(alembic_cfg, "head")
        logger.info("Alembic migrations successful.")
        with engine.begin() as conn:
            # Fix users table
            conn.execute(text("ALTER TABLE users ADD COLUMN IF NOT EXISTS skate_type VARCHAR(60)"))
            conn.execute(text("ALTER TABLE users ADD COLUMN IF NOT EXISTS age_group VARCHAR(60)"))
            
            # Fix skater_profiles
            conn.execute(text("ALTER TABLE skater_profiles ADD COLUMN IF NOT EXISTS skate_type VARCHAR(60)"))
            conn.execute(text("ALTER TABLE skater_profiles ADD COLUMN IF NOT EXISTS age_group VARCHAR(60)"))
            
            # Fix organizer_profiles
            conn.execute(text("ALTER TABLE organizer_profiles ADD COLUMN IF NOT EXISTS organizer_id SERIAL UNIQUE"))
            conn.execute(text("ALTER TABLE organizer_profiles ADD COLUMN IF NOT EXISTS city VARCHAR(100)"))
            
            # Fix events
            conn.execute(text("ALTER TABLE events ADD COLUMN IF NOT EXISTS organizer_id INTEGER"))
            conn.execute(text("ALTER TABLE events ADD COLUMN IF NOT EXISTS price NUMERIC(10, 2) DEFAULT 0"))
            
            # Fix event_categories
            conn.execute(text("ALTER TABLE event_categories ADD COLUMN IF NOT EXISTS category_type VARCHAR(60)"))
            conn.execute(text("ALTER TABLE event_categories ADD COLUMN IF NOT EXISTS city VARCHAR(100)"))
            conn.execute(text("ALTER TABLE event_categories ADD COLUMN IF NOT EXISTS images_url JSONB"))
            conn.execute(text("ALTER TABLE event_categories ADD COLUMN IF NOT EXISTS other_urls JSONB"))
            
        logger.info("Raw SQL fixes completed successfully.")
    except Exception as e:
        logger.error(f"Error running raw SQL fixes: {e}")

@asynccontextmanager
async def lifespan(_: FastAPI):
    run_migrations()
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
    logger.info(
        "REQUEST %s %s -> %s (%.0fms)",
        request.method,
        request.url.path,
        response.status_code,
        elapsed_ms,
    )
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

@app.get("/healthz", tags=["system"])
def healthz() -> dict:
    return {"status": "ok"}


# ── Static files & routes ────────────────────────────────────────────────

static_dir = Path("static")
static_dir.mkdir(exist_ok=True)
(static_dir / "uploads").mkdir(exist_ok=True)

app.include_router(api_router, prefix=settings.api_v1_prefix)
app.mount("/static", StaticFiles(directory="static"), name="static")
