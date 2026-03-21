from contextlib import asynccontextmanager

from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse

from app.api.v1.router import api_router
from app.core.config import get_settings
from app.core.logging import configure_logging
from app.db.base import create_db_and_tables
from app.db.session import engine

settings = get_settings()
configure_logging()


@asynccontextmanager
async def lifespan(_: FastAPI):
    create_db_and_tables(engine)
    yield


app = FastAPI(
    title=settings.app_name,
    version="1.0.0",
    openapi_url=f"{settings.api_v1_prefix}/openapi.json",
    docs_url=f"{settings.api_v1_prefix}/docs",
    redoc_url=f"{settings.api_v1_prefix}/redoc",
    lifespan=lifespan,
)


@app.exception_handler(Exception)
async def unhandled_exception_handler(_: Request, exc: Exception) -> JSONResponse:
    return JSONResponse(
        status_code=500,
        content={
            "detail": "Something went wrong. Please try again.",
            "error": type(exc).__name__,
        },
    )


@app.get("/healthz", tags=["system"])
def healthz() -> dict:
    return {"status": "ok"}


app.include_router(api_router, prefix=settings.api_v1_prefix)


@app.post("/apply-schema-fix", tags=["system"])
def apply_schema_fix() -> dict:
    """Temporary public endpoint to patch missing columns in production DB."""
    from sqlalchemy import text
    results = []
    patches = [
        ("banners", "share_url", "VARCHAR(500)"),
    ]
    with engine.connect() as conn:
        for table, column, col_type in patches:
            try:
                row = conn.execute(text(
                    "SELECT column_name FROM information_schema.columns "
                    "WHERE table_name = :tbl AND column_name = :col"
                ), {"tbl": table, "col": column}).fetchone()
                if row is None:
                    conn.execute(text(f'ALTER TABLE "{table}" ADD COLUMN "{column}" {col_type}'))
                    conn.commit()
                    results.append(f"ADDED {table}.{column}")
                else:
                    results.append(f"EXISTS {table}.{column}")
            except Exception as e:
                results.append(f"ERROR {table}.{column}: {e}")
    return {"status": "ok", "results": results}
