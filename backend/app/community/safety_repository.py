from typing import List, Optional, Set

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.auth.models import Account
from app.community.models import CommunityComment, CommunityPost
from app.community.safety_models import CommunityBlock, CommunityReport


def create_report(
    session: Session,
    reporter_id: str,
    target_type: str,
    target_id: str,
    reason: str,
    details: str,
) -> CommunityReport:
    _validate_report_target(session, target_type, target_id)
    existing = session.scalar(
        select(CommunityReport).where(
            CommunityReport.reporter_id == reporter_id,
            CommunityReport.target_type == target_type,
            CommunityReport.target_id == target_id,
        )
    )
    if existing is not None:
        return existing

    report = CommunityReport(
        reporter_id=reporter_id,
        target_type=target_type,
        target_id=target_id,
        reason=reason,
        details=details,
    )
    session.add(report)
    session.commit()
    return report


def block_account(session: Session, blocker_id: str, blocked_id: str) -> CommunityBlock:
    if blocker_id == blocked_id:
        raise ValueError("cannot block self")
    if session.get(Account, blocked_id) is None:
        raise LookupError("blocked account not found")
    existing = session.scalar(
        select(CommunityBlock).where(
            CommunityBlock.blocker_id == blocker_id,
            CommunityBlock.blocked_id == blocked_id,
        )
    )
    if existing is not None:
        return existing

    block = CommunityBlock(blocker_id=blocker_id, blocked_id=blocked_id)
    session.add(block)
    session.commit()
    return block


def unblock_account(session: Session, blocker_id: str, blocked_id: str) -> bool:
    block = session.scalar(
        select(CommunityBlock).where(
            CommunityBlock.blocker_id == blocker_id,
            CommunityBlock.blocked_id == blocked_id,
        )
    )
    if block is None:
        return False
    session.delete(block)
    session.commit()
    return True


def blocked_account_ids(session: Session, blocker_id: str) -> Set[str]:
    return set(
        session.scalars(
            select(CommunityBlock.blocked_id).where(
                CommunityBlock.blocker_id == blocker_id
            )
        )
    )


def soft_delete_post(
    session: Session,
    post_id: str,
    owner_id: str,
) -> Optional[CommunityPost]:
    post = session.scalar(
        select(CommunityPost).where(
            CommunityPost.id == post_id,
            CommunityPost.author_id == owner_id,
            CommunityPost.status != "deleted",
        )
    )
    if post is None:
        return None
    post.status = "deleted"
    session.commit()
    return post


def soft_delete_comment(
    session: Session,
    comment_id: str,
    owner_id: str,
) -> Optional[CommunityComment]:
    comment = session.scalar(
        select(CommunityComment).where(
            CommunityComment.id == comment_id,
            CommunityComment.author_id == owner_id,
            CommunityComment.status != "deleted",
        )
    )
    if comment is None:
        return None
    comment.status = "deleted"
    post = session.get(CommunityPost, comment.post_id)
    if post is not None and post.comment_count > 0:
        post.comment_count -= 1
    session.commit()
    return comment


def list_open_reports(
    session: Session,
    limit: int,
    offset: int,
) -> List[CommunityReport]:
    statement = (
        select(CommunityReport)
        .where(CommunityReport.status == "open")
        .order_by(CommunityReport.created_at.asc())
        .offset(offset)
        .limit(limit)
    )
    return list(session.scalars(statement))


def resolve_report(
    session: Session,
    report_id: str,
    status: str,
    resolution_note: str,
) -> Optional[CommunityReport]:
    report = session.get(CommunityReport, report_id)
    if report is None:
        return None
    report.status = status
    report.resolution_note = resolution_note
    session.commit()
    return report


def _validate_report_target(session: Session, target_type: str, target_id: str) -> None:
    if target_type == "post":
        target = session.get(CommunityPost, target_id)
    elif target_type == "comment":
        target = session.get(CommunityComment, target_id)
    else:
        raise ValueError("unsupported report target")
    if target is None or target.status != "published":
        raise LookupError("report target not found")
