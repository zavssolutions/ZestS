from __future__ import annotations

from datetime import date, datetime, timezone
from typing import Optional
from uuid import UUID, uuid4

from sqlalchemy import Column, DateTime, ForeignKey, String, UniqueConstraint
from sqlmodel import Field, SQLModel

from app.models.enums import Gender, Sport, UserRole


class User(SQLModel, table=True):
    __tablename__ = "users"
    __table_args__ = (
        UniqueConstraint("mobile_no", name="uq_users_mobile_no"),
        UniqueConstraint("email", name="uq_users_email"),
        UniqueConstraint("firebase_uid", name="uq_users_firebase_uid"),
    )

    id: UUID = Field(default_factory=uuid4, primary_key=True)
    parent_id: Optional[UUID] = Field(default=None, foreign_key="users.id")

    role: str = Field(default="parent", sa_column=Column(String(20), nullable=False, server_default="parent"))
    sport: str = Field(default="skating", sa_column=Column(String(20), nullable=False, server_default="skating"))
    gender: str = Field(default="unspecified", sa_column=Column(String(20), nullable=False, server_default="unspecified"))

    firebase_uid: Optional[str] = Field(default=None, max_length=128)
    google_uid: Optional[str] = Field(default=None, max_length=128)

    mobile_no: Optional[str] = Field(default=None, max_length=20)
    email: Optional[str] = Field(default=None, max_length=255)

    first_name: Optional[str] = Field(default=None, max_length=50)
    last_name: Optional[str] = Field(default=None, max_length=50)
    dob: Optional[date] = Field(default=None)

    country: Optional[str] = Field(default=None, max_length=100)
    state: Optional[str] = Field(default=None, max_length=100)
    city: Optional[str] = Field(default=None, max_length=100)
    address: Optional[str] = Field(default=None)

    profile_picture_url: Optional[str] = Field(default=None, max_length=500)
    favorite_sport: Optional[str] = Field(default="skating", max_length=50)

    is_active: bool = Field(default=True)
    is_verified: bool = Field(default=False)
    has_completed_profile: bool = Field(default=False)

    created_at: datetime = Field(
        default_factory=lambda: datetime.now(timezone.utc),
        sa_column=Column(DateTime(timezone=True), nullable=False),
    )
    updated_at: datetime = Field(
        default_factory=lambda: datetime.now(timezone.utc),
        sa_column=Column(DateTime(timezone=True), nullable=False),
    )
    last_login_at: Optional[datetime] = Field(
        default=None,
        sa_column=Column(DateTime(timezone=True), nullable=True),
    )


class ParentProfile(SQLModel, table=True):
    __tablename__ = "parent_profiles"

    user_id: UUID = Field(
        sa_column=Column(ForeignKey("users.id", ondelete="CASCADE"), primary_key=True)
    )
    max_kids_allowed: int = Field(default=3)


class TrainerProfile(SQLModel, table=True):
    __tablename__ = "trainer_profiles"

    user_id: UUID = Field(
        sa_column=Column(ForeignKey("users.id", ondelete="CASCADE"), primary_key=True)
    )
    school_name: Optional[str] = Field(default=None, max_length=100)
    club_name: Optional[str] = Field(default=None, max_length=100)
    specialization: Optional[str] = Field(default=None)
    experience_years: Optional[int] = Field(default=None)


class OrganizerProfile(SQLModel, table=True):
    __tablename__ = "organizer_profiles"

    user_id: UUID = Field(
        sa_column=Column(ForeignKey("users.id", ondelete="CASCADE"), primary_key=True)
    )
    org_name: str = Field(sa_column=Column(String(120), nullable=False))
    website_url: Optional[str] = Field(default=None, max_length=255)
    is_verified_org: bool = Field(default=False)


class SkaterProfile(SQLModel, table=True):
    __tablename__ = "skater_profiles"

    user_id: UUID = Field(
        sa_column=Column(ForeignKey("users.id", ondelete="CASCADE"), primary_key=True)
    )
    skill_level: Optional[str] = Field(default=None, max_length=50)
    years_skating: Optional[int] = Field(default=None)
    preferred_tracks: Optional[str] = Field(default=None)
    school_name: Optional[str] = Field(default=None, max_length=100)
