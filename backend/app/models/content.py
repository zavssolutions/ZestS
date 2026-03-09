from datetime import datetime, timezone
from typing import Optional
from uuid import UUID, uuid4

from sqlalchemy import Column, DateTime
from sqlmodel import Field, SQLModel


class StaticPage(SQLModel, table=True):
    __tablename__ = "static_pages"

    id: UUID = Field(default_factory=uuid4, primary_key=True)
    slug: str = Field(unique=True, max_length=100)
    title: str = Field(max_length=200)
    content: str = Field(default="")
    is_published: bool = Field(default=True)

    updated_at: datetime = Field(
        default_factory=lambda: datetime.now(timezone.utc),
        sa_column=Column(DateTime(timezone=True), nullable=False),
    )


class Banner(SQLModel, table=True):
    __tablename__ = "banners"

    id: UUID = Field(default_factory=uuid4, primary_key=True)
    title: Optional[str] = Field(default=None, max_length=200)
    image_url: str = Field(max_length=500)
    link_url: Optional[str] = Field(default=None, max_length=500)
    placement: str = Field(default="home_top", max_length=50)
    display_order: int = Field(default=0)
    is_active: bool = Field(default=True)

    created_at: datetime = Field(
        default_factory=lambda: datetime.now(timezone.utc),
        sa_column=Column(DateTime(timezone=True), nullable=False),
    )


class Sponsor(SQLModel, table=True):
    __tablename__ = "sponsors"

    id: UUID = Field(default_factory=uuid4, primary_key=True)
    name: str = Field(max_length=120)
    logo_url: Optional[str] = Field(default=None, max_length=500)
    website_url: Optional[str] = Field(default=None, max_length=500)
    is_active: bool = Field(default=True)


class SupportIssue(SQLModel, table=True):
    __tablename__ = "support_issues"

    id: UUID = Field(default_factory=uuid4, primary_key=True)
    user_id: Optional[UUID] = Field(default=None, foreign_key="users.id")
    email: Optional[str] = Field(default=None, max_length=255)
    message: str = Field(max_length=2000)
    status: str = Field(default="open", max_length=20)

    created_at: datetime = Field(
        default_factory=lambda: datetime.now(timezone.utc),
        sa_column=Column(DateTime(timezone=True), nullable=False),
    )


class SystemSetting(SQLModel, table=True):
    __tablename__ = "system_settings"

    key: str = Field(primary_key=True, max_length=100)
    value: str = Field(default="")
    updated_at: datetime = Field(
        default_factory=lambda: datetime.now(timezone.utc),
        sa_column=Column(DateTime(timezone=True), nullable=False),
    )
