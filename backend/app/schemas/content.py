from datetime import datetime
from typing import Optional
from uuid import UUID

from pydantic import BaseModel, ConfigDict


class StaticPageOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    slug: str
    title: str
    content: str


class SupportIssueCreate(BaseModel):
    email: Optional[str] = None
    message: str


class SupportIssueOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    user_id: Optional[UUID]
    email: Optional[str]
    message: str
    status: str
    created_at: datetime


class BannerCreate(BaseModel):
    title: Optional[str] = None
    image_url: str
    link_url: Optional[str] = None
    placement: str = "home_top"
    display_order: int = 0
    is_active: bool = True


class BannerUpdate(BaseModel):
    title: Optional[str] = None
    image_url: Optional[str] = None
    link_url: Optional[str] = None
    placement: Optional[str] = None
    display_order: Optional[int] = None
    is_active: Optional[bool] = None


class BannerOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    title: Optional[str]
    image_url: str
    link_url: Optional[str]
    placement: str
    display_order: int
    is_active: bool
    created_at: datetime


class SponsorCreate(BaseModel):
    name: str
    logo_url: Optional[str] = None
    website_url: Optional[str] = None
    is_active: bool = True


class SponsorUpdate(BaseModel):
    name: Optional[str] = None
    logo_url: Optional[str] = None
    website_url: Optional[str] = None
    is_active: Optional[bool] = None


class SponsorOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    name: str
    logo_url: Optional[str]
    website_url: Optional[str]
    is_active: bool
