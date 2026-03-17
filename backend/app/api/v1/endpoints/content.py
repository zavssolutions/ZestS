from datetime import datetime, timezone
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from sqlmodel import select

from app.api.deps import OptionalCurrentUser, SessionDep, require_roles
from app.models.content import Banner, StaticPage, SupportIssue
from app.schemas.content import BannerOut
from app.models.enums import UserRole
from app.models.user import User
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


# ── Static Pages ─────────────────────────────────────────────────────


@router.get("/pages", response_model=list[StaticPageOut])
def list_pages(session: SessionDep) -> list[StaticPage]:
    return session.exec(select(StaticPage).where(StaticPage.is_published == True)).all()  # noqa: E712


@router.get("/pages/{slug}", response_model=StaticPageOut)
def get_page(slug: str, session: SessionDep) -> StaticPage:
    page = session.exec(select(StaticPage).where(StaticPage.slug == slug)).first()
    if page is None:
        # Auto-seed well-known pages on first access
        if slug == "terms-and-conditions":
            return _get_or_seed_page(session, slug, "Terms and Conditions", "")
        if slug == "about-us":
            return _get_or_seed_page(session, slug, "About Us", ABOUT_US_DEFAULT)
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Page not found")
    return page


@router.get("/pages/terms-and-conditions", response_model=StaticPageOut, include_in_schema=False)
def terms_page(session: SessionDep) -> StaticPage:
    return _get_or_seed_page(session, "terms-and-conditions", "Terms and Conditions", "")


@router.get("/pages/about-us", response_model=StaticPageOut, include_in_schema=False)
def about_page(session: SessionDep) -> StaticPage:
    return _get_or_seed_page(session, "about-us", "About Us", ABOUT_US_DEFAULT)


@router.put("/admin/pages/{slug}", response_model=StaticPageOut)
def upsert_page(
    slug: str,
    payload: StaticPageOut,
    session: SessionDep,
    _: User = Depends(require_roles(UserRole.ADMIN)),
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


# ── Banners ─────────────────────────────────────────────────────────


@router.get("/banners", response_model=list[BannerOut])
def list_active_banners(session: SessionDep) -> list[Banner]:
    statement = (
        select(Banner)
        .where(Banner.is_active == True)  # noqa: E712
        .order_by(Banner.display_order, Banner.created_at.desc())
    )
    return session.exec(statement).all()


@router.get("/banners/{banner_id}", response_model=BannerOut)
def get_banner(banner_id: UUID, session: SessionDep) -> Banner:
    """Get a single banner by UUID. Used for deep link resolution when the app
    receives a ``/banner/{banner_id}`` link."""
    banner = session.get(Banner, banner_id)
    if banner is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Banner not found")
    return banner


@router.post("/banners/{banner_id}/share-link", response_model=dict)
def generate_banner_share_link(banner_id: UUID, session: SessionDep) -> dict:
    """Generate a shareable deep link for a banner.

    The returned URL follows the pattern ``https://zests.app.link/banner/{id}``.
    On mobile, app-links / universal-links intercept this and open the banner
    inside the app.  If the app is not installed, the link falls through to the
    web which should redirect to the appropriate app store."""
    banner = session.get(Banner, banner_id)
    if banner is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Banner not found")
    share_link = banner.share_url or f"https://zests.app.link/banner/{banner_id}"
    return {"banner_id": str(banner_id), "share_link": share_link}


# ── Support ─────────────────────────────────────────────────────────


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


@router.get("/support/issues/{issue_id}", response_model=dict)
def get_support_issue(issue_id: UUID, session: SessionDep) -> dict:
    issue = session.get(SupportIssue, issue_id)
    if issue is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Issue not found")
    return {
        "id": str(issue.id),
        "user_id": str(issue.user_id) if issue.user_id else None,
        "email": issue.email,
        "message": issue.message,
        "status": issue.status,
        "created_at": issue.created_at.isoformat(),
    }

