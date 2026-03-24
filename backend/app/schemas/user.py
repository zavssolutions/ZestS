from datetime import date, datetime
from typing import Optional
from uuid import UUID

from pydantic import BaseModel, ConfigDict

from app.models.enums import Sport, UserRole


class UserProfileOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    parent_id: Optional[UUID]
    role: UserRole
    first_name: Optional[str]
    last_name: Optional[str]
    mobile_no: Optional[str]
    email: Optional[str]
    dob: Optional[date]
    favorite_sport: Optional[str]
    profile_picture_url: Optional[str]
    has_completed_profile: bool
    skate_type: Optional[str] = None
    age_group: Optional[str] = None


class UserProfileUpsert(BaseModel):
    role: Optional[UserRole] = None
    first_name: Optional[str] = None
    last_name: Optional[str] = None
    mobile_no: Optional[str] = None
    email: Optional[str] = None
    dob: Optional[date] = None
    favorite_sport: Sport = Sport.SKATING
    
    # Trainer
    school_name: Optional[str] = None
    club_name: Optional[str] = None
    specialization: Optional[str] = None
    experience_years: Optional[int] = None
    
    # Organizer
    org_name: Optional[str] = None
    website_url: Optional[str] = None
    
    # Skater
    skill_level: Optional[str] = None
    years_skating: Optional[int] = None
    preferred_tracks: Optional[str] = None
    skate_type: Optional[str] = None
    age_group: Optional[str] = None


class KidCreate(BaseModel):
    first_name: str
    last_name: Optional[str] = None
    dob: date
    gender: Optional[str] = "unspecified"
    skate_type: Optional[str] = None
    age_group: Optional[str] = None


class UserRoleUpdate(BaseModel):
    role: UserRole


class UserUpdate(BaseModel):
    role: Optional[UserRole] = None
    first_name: Optional[str] = None
    last_name: Optional[str] = None
    mobile_no: Optional[str] = None
    email: Optional[str] = None
    is_active: Optional[bool] = None
    is_verified: Optional[bool] = None


class UserAdminOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    parent_id: Optional[UUID]
    role: UserRole
    first_name: Optional[str]
    last_name: Optional[str]
    mobile_no: Optional[str]
    email: Optional[str]
    is_active: bool
    is_verified: bool
    created_at: datetime
