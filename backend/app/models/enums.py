from enum import StrEnum


class UserRole(StrEnum):
    PARENT = "parent"
    KID = "kid"
    TRAINER = "trainer"
    ORGANIZER = "organizer"
    ADMIN = "admin"
    SPONSOR = "sponsor"
    SKATER = "skater"


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


class SkateType(StrEnum):
    QUAD = "quad"
    INLINE = "inline"
    SPEED = "speed"
    ARTISTIC = "artistic"


class AgeGroup(StrEnum):
    UNDER_5 = "under_5"
    CADET_5_7 = "cadet(5-7)"
    SUB_JUNIOR_7_9 = "sub-junior(7-9)"
    SUB_JUNIOR_9_11 = "sub-junior(9-11)"
    JUNIOR_11_14 = "junior(11-14)"
    JUNIOR_14_17 = "junior(14-17)"
    SENIOR_17_ABOVE = "senior(17_above)"
