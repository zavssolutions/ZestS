from enum import StrEnum


class UserRole(StrEnum):
    PARENT = "parent"
    KID = "kid"
    TRAINER = "trainer"
    ORGANIZER = "organizer"
    ADMIN = "admin"


class Gender(StrEnum):
    MALE = "male"
    FEMALE = "female"
    OTHER = "other"
    UNSPECIFIED = "unspecified"


class Sport(StrEnum):
    SKATING = "skating"


class EventStatus(StrEnum):
    DRAFT = "draft"
    PUBLISHED = "published"
    CANCELED = "canceled"
    COMPLETED = "completed"


class RegistrationStatus(StrEnum):
    PENDING = "pending"
    CONFIRMED = "confirmed"
    CANCELED = "canceled"


class PaymentStatus(StrEnum):
    INITIATED = "initiated"
    SUCCESS = "success"
    FAILED = "failed"
    REFUNDED = "refunded"
