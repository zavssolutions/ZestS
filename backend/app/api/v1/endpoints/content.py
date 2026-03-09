from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, status
from sqlmodel import select

from app.api.deps import CurrentUser, OptionalCurrentUser, SessionDep, require_roles
from app.models.content import StaticPage, SupportIssue
from app.models.enums import UserRole
from app.schemas.content import StaticPageOut, SupportIssueCreate

router = APIRouter(tags=["content"])

ABOUT_US_DEFAULT = """Everyday, as our children spent three intense hours on the skating rink, we waited on the sidelines - watching, learning, and hoping we were making the right decisions for their future.

But behind the excitement, there was constant uncertainty. Finding reliable information about upcoming events was a challenge. Details were scattered. Deadlines were missed. Planning became stressful instead of strategic. As parents who were new to the sports ecosystem, we often felt we were navigating in the dark.

Then came a turning point: after attending a major event, we realized something deeper - success in sports is not just about talent and hard work. It is also about awareness, timely information, and the right connections.

We were not organizers. We were not from a sports background. We were simply parents trying to do our best. So we asked ourselves:
What if this confusion could be simplified?
What if every skater and parent had access to structured, reliable, and timely information in one place?

That question sparked a fire in us. What began as casual conversations during practice hours evolved into research, discussions, and eventually a proof of concept. We set out to build a tech-driven solution - not just to solve our problem, but to empower an entire skating community.

This is how our journey began."""


def _get_or_seed_page(session: SessionDep, slug: str, title: str, content: str) -> StaticPage:
    page = session.exec(select(StaticPage).where(StaticPage.slug == slug)).first()
    if page is None:
        page = StaticPage(slug=slug, title=title, content=content)
        session.add(page)
        session.commit()
        session.refresh(page)
    return page


@router.get("/pages/terms-and-conditions", response_model=StaticPageOut)
def terms_page(session: SessionDep) -> StaticPage:
    return _get_or_seed_page(session, "terms-and-conditions", "Terms and Conditions", "")


@router.get("/pages/about-us", response_model=StaticPageOut)
def about_page(session: SessionDep) -> StaticPage:
    return _get_or_seed_page(session, "about-us", "About Us", ABOUT_US_DEFAULT)


@router.put("/admin/pages/{slug}", response_model=StaticPageOut)
def upsert_page(
    slug: str,
    payload: StaticPageOut,
    _: CurrentUser = Depends(require_roles(UserRole.ADMIN)),
    session: SessionDep,
) -> StaticPage:
    page = session.exec(select(StaticPage).where(StaticPage.slug == slug)).first()
    if page is None:
        page = StaticPage(slug=slug, title=payload.title, content=payload.content)
    else:
        page.title = payload.title
        page.content = payload.content
        page.updated_at = datetime.now(timezone.utc)

    session.add(page)
    session.commit()
    session.refresh(page)
    return page


@router.post("/support/issues", response_model=dict)
def create_support_issue(
    payload: SupportIssueCreate,
    current_user: OptionalCurrentUser,
    session: SessionDep,
) -> dict:
    issue = SupportIssue(
        user_id=current_user.id if current_user else None,
        email=payload.email,
        message=payload.message,
    )
    session.add(issue)
    session.commit()
    return {"status": "ok", "issue_id": str(issue.id)}

