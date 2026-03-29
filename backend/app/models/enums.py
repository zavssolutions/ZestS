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


class CategoryType(StrEnum):
    ROAD = "Road"
    RINK = "Rink"
    ICE = "Ice"
    ARTISTIC = "Artistic"


class SkateType(StrEnum):
    INLINE = "Inline"
    QUAD = "Quad"
    TOY_INLINE = "Toy inline"
    TENACITY = "tenacity"


class Distance(StrEnum):
    D200M = "200m"
    D500M = "500m"
    D1000M = "1000m"


class AgeGroup(StrEnum):
    A4_6 = "4-6"
    A6_8 = "6-8"
    A8_10 = "8-10"
    A10_12 = "10-12"
    A12_15 = "12-15"
    ABOVE_15 = "above 15"
