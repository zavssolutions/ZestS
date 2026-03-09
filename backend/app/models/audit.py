from datetime import datetime, timezone
from typing import Optional
from uuid import UUID, uuid4

from sqlalchemy import Column, DateTime
from sqlmodel import Field, SQLModel


class AuditLog(SQLModel, table=True):
    __tablename__ = "audit_logs"

    id: UUID = Field(default_factory=uuid4, primary_key=True)
    user_id: Optional[UUID] = Field(default=None, foreign_key="users.id")
    level: str = Field(default="INFO", max_length=10)
    action: str = Field(max_length=100)
    entity_type: Optional[str] = Field(default=None, max_length=50)
    entity_id: Optional[UUID] = Field(default=None)
    metadata_json: Optional[str] = Field(default=None)
    ip_address: Optional[str] = Field(default=None, max_length=64)

    created_at: datetime = Field(
        default_factory=lambda: datetime.now(timezone.utc),
        sa_column=Column(DateTime(timezone=True), nullable=False),
    )
