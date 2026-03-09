from typing import Optional

from pydantic import BaseModel, ConfigDict


class StaticPageOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    slug: str
    title: str
    content: str


class SupportIssueCreate(BaseModel):
    email: Optional[str] = None
    message: str
