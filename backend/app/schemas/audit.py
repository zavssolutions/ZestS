from datetime import datetime
from typing import Optional
from uuid import UUID

from pydantic import BaseModel, ConfigDict


class AuditLogOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    user_id: Optional[UUID]
    level: str
    action: str
    entity_type: Optional[str]
    entity_id: Optional[UUID]
    metadata_json: Optional[str]
    ip_address: Optional[str]
    created_at: datetime
