from collections.abc import Generator

from sqlmodel import Session, create_engine

from app.core.config import get_settings

settings = get_settings()
engine = create_engine(
    settings.database_url, 
    echo=False, 
    pool_pre_ping=True,
    pool_recycle=300,  # Recycle connections every 5 minutes to prevent stale sockets
    connect_args={
        "options": "-c lock_timeout=30000 -c statement_timeout=60000" # 30s lock timeout, 60s statement timeout
    }
)


def get_session() -> Generator[Session, None, None]:
    with Session(engine) as session:
        yield session
