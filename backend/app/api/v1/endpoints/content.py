from datetime import datetime, timezone
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from sqlmodel import select

from app.api.deps import OptionalCurrentUser, SessionDep, require_roles
from app.models.content import Banner, StaticPage, SupportIssue, TipOfDay
from app.schemas.content import BannerOut
from app.models.enums import UserRole
from app.models.user import User
from app.schemas.content import StaticPageOut, SupportIssueCreate, TipOfDayOut
from app.services.mailer import notify_admins_of_support_issue, notify_admins_of_reach_out

router = APIRouter(tags=["content"])

ABOUT_US_DEFAULT = """Watching our children spend three intense hours on the rink every day, we realized that talent alone wasn't enough—success required information.

As parents new to the sports ecosystem, we were flying blind. Deadlines were missed, event details were scattered, and planning was stressful rather than strategic. We saw a gap: while the skaters had the grit, the community lacked the structure.

We asked a simple question: What if we simplified the chaos?

Though we weren't sports insiders or organizers, we were parents with a mission. What started as sideline conversations evolved into a tech-driven proof of concept designed to provide every skater with structured, timely, and reliable information.

We built this to turn uncertainty into a strategy. This is our journey."""


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





# ── Tip Of The Day ───────────────────────────────────────────────────


@router.get("/tip-of-the-day", response_model=TipOfDayOut)
def get_tip_of_the_day(session: SessionDep) -> TipOfDay:
    today = datetime.now(timezone.utc).date()
    tip = session.exec(select(TipOfDay).where(TipOfDay.date == today)).first()
    if tip is None:
        tip = session.exec(select(TipOfDay).order_by(TipOfDay.date.desc())).first()
    if tip is None:
        tip = TipOfDay(date=today, content="Stay hydrated before training.", is_url=False)
        session.add(tip)
        session.commit()
        session.refresh(tip)
    return tip


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
    session.refresh(issue)
    
    # Notify admins
    notify_admins_of_support_issue(str(issue.id), payload.email, payload.message)
    
    return {"status": "ok", "issue_id": str(issue.id)}


class ReachOutRequest(SupportIssueCreate):
    role: str

@router.post("/support/reach-out", response_model=dict)
def create_reach_out(
    payload: ReachOutRequest,
    current_user: OptionalCurrentUser,
    session: SessionDep,
) -> dict:
    # Store as a support issue with a specific tag or message prefix
    message = f"[REACH OUT - {payload.role.upper()}] {payload.message}"
    issue = SupportIssue(
        user_id=current_user.id if current_user else None,
        email=payload.email,
        message=message,
    )
    session.add(issue)
    session.commit()
    session.refresh(issue)
    
    # Notify admins specifically for reach out
    notify_admins_of_reach_out(str(current_user.id) if current_user else "Anonymous", payload.role, payload.message)
    
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

