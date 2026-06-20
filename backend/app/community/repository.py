from typing import List, Optional, Set

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.community.models import CommunityComment, CommunityPost, CommunityReaction


def list_feed_posts(
    session: Session,
    topic: Optional[str] = None,
    limit: Optional[int] = None,
    offset: int = 0,
    excluded_author_ids: Optional[Set[str]] = None,
) -> List[CommunityPost]:
    statement = (
        select(CommunityPost)
        .where(CommunityPost.status == "published")
        .order_by(CommunityPost.is_pinned.desc(), CommunityPost.created_at.desc())
    )
    if excluded_author_ids:
        statement = statement.where(CommunityPost.author_id.not_in(excluded_author_ids))
    posts = list(session.scalars(statement))
    if topic and topic not in {"推荐", "最新", "关注"}:
        posts = [post for post in posts if topic in (post.tags or [])]
    if offset:
        posts = posts[offset:]
    if limit is not None:
        posts = posts[:limit]
    return posts


def get_post(session: Session, post_id: str) -> Optional[CommunityPost]:
    return session.get(CommunityPost, post_id)


def create_post(
    session: Session,
    author_id: str,
    summary: str,
    body: str,
    tags: List[str],
    parts: List[str],
    image_asset: Optional[str],
    status: str,
) -> CommunityPost:
    post = CommunityPost(
        author_id=author_id,
        summary=summary,
        body=body,
        tags=tags,
        parts=parts,
        image_asset=image_asset,
        status=status,
    )
    session.add(post)
    session.commit()
    return post


def list_comments(
    session: Session,
    post_id: str,
    limit: Optional[int] = None,
    offset: int = 0,
) -> List[CommunityComment]:
    statement = (
        select(CommunityComment)
        .where(
            CommunityComment.post_id == post_id,
            CommunityComment.status == "published",
        )
        .order_by(CommunityComment.created_at.asc())
    )
    if offset:
        statement = statement.offset(offset)
    if limit is not None:
        statement = statement.limit(limit)
    return list(session.scalars(statement))


def create_comment(
    session: Session,
    post: CommunityPost,
    author_id: str,
    body: str,
    status: str,
) -> CommunityComment:
    comment = CommunityComment(
        post_id=post.id,
        author_id=author_id,
        body=body,
        status=status,
    )
    session.add(comment)
    if status == "published":
        post.comment_count += 1
    session.commit()
    return comment


def set_reaction(
    session: Session,
    post: CommunityPost,
    account_id: str,
    reaction_type: str,
    active: bool,
) -> CommunityPost:
    statement = select(CommunityReaction).where(
        CommunityReaction.post_id == post.id,
        CommunityReaction.account_id == account_id,
        CommunityReaction.type == reaction_type,
    )
    reaction = session.scalar(statement)
    if active and reaction is None:
        session.add(CommunityReaction(post_id=post.id, account_id=account_id, type=reaction_type))
        _increment_reaction_count(post, reaction_type, 1)
    if not active and reaction is not None:
        session.delete(reaction)
        _increment_reaction_count(post, reaction_type, -1)
    session.commit()
    return post


def _increment_reaction_count(post: CommunityPost, reaction_type: str, delta: int) -> None:
    if reaction_type == "like":
        post.like_count = max(post.like_count + delta, 0)
    if reaction_type == "save":
        post.save_count = max(post.save_count + delta, 0)
