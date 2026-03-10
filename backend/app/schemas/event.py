from datetime import datetime
from typing import Optional
from uuid import UUID

from pydantic import BaseModel, ConfigDict


class EventCreate(BaseModel):
    title: str
    description: Optional[str] = None
    start_at_utc: datetime
    end_at_utc: datetime
    location_name: str
    venue_city: Optional[str] = None
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    banner_image_url: Optional[str] = None


class EventUpdate(BaseModel):
    title: Optional[str] = None
    description: Optional[str] = None
    start_at_utc: Optional[datetime] = None
    end_at_utc: Optional[datetime] = None
    location_name: Optional[str] = None
    venue_city: Optional[str] = None
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    banner_image_url: Optional[str] = None
    status: Optional[str] = None


class EventOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    title: str
    description: Optional[str]
    start_at_utc: datetime
    end_at_utc: datetime
    location_name: str
    venue_city: Optional[str]
    latitude: Optional[float]
    longitude: Optional[float]
    banner_image_url: Optional[str]
    status: str


class EventStatusUpdate(BaseModel):
    status: str


class EventRegistrationCreate(BaseModel):
    event_id: UUID
    category_id: UUID
    user_id: UUID


class ReferralAction(BaseModel):
    referrer_user_id: UUID
    referred_user_id: UUID


class EventResultCreate(BaseModel):
    event_id: UUID
    category_id: UUID
    user_id: UUID
    rank: Optional[int] = None
    timing_ms: Optional[int] = None
    points_earned: int = 0


class EventResultUpdate(BaseModel):
    rank: Optional[int] = None
    timing_ms: Optional[int] = None
    points_earned: Optional[int] = None


class EventResultOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    event_id: UUID
    category_id: UUID
    user_id: UUID
    rank: Optional[int]
    timing_ms: Optional[int]
    points_earned: int
    created_at: datetime
