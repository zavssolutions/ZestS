from datetime import datetime
from typing import Optional
from uuid import UUID

from pydantic import BaseModel, ConfigDict


class DeviceTokenCreate(BaseModel):
    token: str
    platform: str


class NotificationOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    user_id: UUID
    title: str
    body: str
    data_json: Optional[str]
    is_read: bool
    created_at: datetime
