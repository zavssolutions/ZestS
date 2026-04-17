from sqlmodel import SQLModel
from sqlalchemy import text

# Import models so SQLModel metadata is complete before create_all/migrations.
from app import models  # noqa: F401


def create_db_and_tables(engine) -> None:
    SQLModel.metadata.create_all(engine)
