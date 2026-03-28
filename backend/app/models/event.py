from datetime import datetime, timezone
from typing import Optional
from uuid import UUID, uuid4

from sqlalchemy import Column, DateTime, ForeignKey, Numeric, String, UniqueConstraint, JSON
from sqlmodel import Field, SQLModel

from app.models.enums import EventStatus, RegistrationStatus


class Event(SQLModel, table=True):
    __tablename__ = "events"

    id: UUID = Field(default_factory=uuid4, primary_key=True)
    organizer_id: Optional[int] = Field(default=None, foreign_key="organizer_profiles.organizer_id")
    organizer_user_id: Optional[UUID] = Field(default=None, foreign_key="users.id")

    title: str = Field(max_length=200)
    description: Optional[str] = Field(default=None)

    start_at_utc: datetime = Field(sa_column=Column(DateTime(timezone=True), nullable=False))
    end_at_utc: datetime = Field(sa_column=Column(DateTime(timezone=True), nullable=False))

    location_name: str = Field(max_length=120)
    venue_city: Optional[str] = Field(default=None, max_length=100)
    latitude: Optional[float] = Field(default=None)
    longitude: Optional[float] = Field(default=None)

    banner_image_url: Optional[str] = Field(default=None, max_length=500)
    images_url: Optional[list[str]] = Field(default=None, sa_column=Column(JSON))
    other_urls: Optional[dict[str, str]] = Field(default=None, sa_column=Column(JSON))
    city: Optional[str] = Field(default=None, max_length=100)
    
    price: float = Field(default=0, sa_column=Column(Numeric(10, 2), nullable=False))
    status: str = Field(default="draft", sa_column=Column(String(20), nullable=False, server_default="draft"))

    created_at: datetime = Field(
        default_factory=lambda: datetime.now(timezone.utc),
        sa_column=Column(DateTime(timezone=True), nullable=False),
    )
    updated_at: datetime = Field(
        default_factory=lambda: datetime.now(timezone.utc),
        sa_column=Column(DateTime(timezone=True), nullable=False),
    )


class EventCategory(SQLModel, table=True):
    __tablename__ = "event_categories"
    __table_args__ = (
        UniqueConstraint("event_id", "name", name="uq_event_categories_event_name"),
    )

    id: UUID = Field(default_factory=uuid4, primary_key=True)
    event_id: UUID = Field(sa_column=Column(ForeignKey("events.id", ondelete="CASCADE"), nullable=False))

    name: str = Field(max_length=120)
    category_type: Optional[str] = Field(default=None, max_length=60)
    skate_type: Optional[str] = Field(default=None, max_length=60)
    age_group: Optional[str] = Field(default=None, max_length=60)
    track_type: Optional[str] = Field(default=None, max_length=60)
    distance: Optional[str] = Field(default=None, max_length=30)
    gender_restriction: Optional[str] = Field(default=None, max_length=30)
    max_slots: int = Field(default=0)
    price: float = Field(default=0, sa_column=Column(Numeric(10, 2), nullable=False))
    
    images_url: Optional[list[str]] = Field(default=None, sa_column=Column(JSON))
    other_urls: Optional[dict[str, str]] = Field(default=None, sa_column=Column(JSON))
    city: Optional[str] = Field(default=None, max_length=100)


class EventRegistration(SQLModel, table=True):
    __tablename__ = "event_registrations"
    __table_args__ = (
        UniqueConstraint("event_id", "category_id", "user_id", name="uq_event_registration"),
    )

    id: UUID = Field(default_factory=uuid4, primary_key=True)
    event_id: UUID = Field(sa_column=Column(ForeignKey("events.id", ondelete="CASCADE"), nullable=False))
    category_id: UUID = Field(sa_column=Column(ForeignKey("event_categories.id", ondelete="CASCADE"), nullable=False))
    user_id: UUID = Field(foreign_key="users.id")

    payment_id: Optional[UUID] = Field(default=None, foreign_key="payments.id")
    status: str = Field(default="pending", sa_column=Column(String(20), nullable=False, server_default="pending"))
    from_city: Optional[str] = Field(default=None, max_length=100)

    created_at: datetime = Field(
        default_factory=lambda: datetime.now(timezone.utc),
        sa_column=Column(DateTime(timezone=True), nullable=False),
    )


class EventResult(SQLModel, table=True):
    __tablename__ = "event_results"
    __table_args__ = (
        UniqueConstraint("event_id", "category_id", "user_id", name="uq_event_result"),
    )

    id: UUID = Field(default_factory=uuid4, primary_key=True)
    event_id: UUID = Field(sa_column=Column(ForeignKey("events.id", ondelete="CASCADE"), nullable=False))
    category_id: UUID = Field(sa_column=Column(ForeignKey("event_categories.id", ondelete="CASCADE"), nullable=False))
    user_id: UUID = Field(foreign_key="users.id")

    rank: Optional[int] = Field(default=None)
    timing_ms: Optional[int] = Field(default=None)
    points_earned: int = Field(default=0)
    created_at: datetime = Field(
        default_factory=lambda: datetime.now(timezone.utc),
        sa_column=Column(DateTime(timezone=True), nullable=False),
    )


class Payment(SQLModel, table=True):
    __tablename__ = "payments"

    id: UUID = Field(default_factory=uuid4, primary_key=True)
    user_id: UUID = Field(foreign_key="users.id")
    event_id: UUID = Field(sa_column=Column(ForeignKey("events.id", ondelete="CASCADE"), nullable=False))
    category_id: Optional[UUID] = Field(default=None, sa_column=Column(ForeignKey("event_categories.id", ondelete="CASCADE"), nullable=True))

    provider: str = Field(default="none", max_length=30)
    amount: float = Field(default=0, sa_column=Column(Numeric(10, 2), nullable=False))
    currency: str = Field(default="INR", max_length=3)
    status: str = Field(default="initiated", max_length=20)
    external_transaction_id: Optional[str] = Field(default=None, max_length=100)

    paid_at: Optional[datetime] = Field(default=None, sa_column=Column(DateTime(timezone=True)))


class Referral(SQLModel, table=True):
    __tablename__ = "referrals"
    __table_args__ = (
        UniqueConstraint("event_id", "referrer_user_id", "referred_user_id", name="uq_referral"),
    )

    id: UUID = Field(default_factory=uuid4, primary_key=True)
    event_id: UUID = Field(sa_column=Column(ForeignKey("events.id", ondelete="CASCADE"), nullable=False))
    referrer_user_id: UUID = Field(foreign_key="users.id")
    referred_user_id: UUID = Field(foreign_key="users.id")
    points: int = Field(default=0)

    created_at: datetime = Field(
        default_factory=lambda: datetime.now(timezone.utc),
        sa_column=Column(DateTime(timezone=True), nullable=False),
    )
