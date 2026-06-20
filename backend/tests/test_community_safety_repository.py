import pytest
from sqlalchemy import create_engine, func, select
from sqlalchemy.orm import Session, sessionmaker
from sqlalchemy.pool import StaticPool

from app.auth.models import Account
from app.auth.repository import delete_account
from app.community.models import CommunityComment, CommunityPost
from app.community.repository import list_comments, list_feed_posts
from app.community.safety_models import CommunityBlock, CommunityReport
from app.community.safety_repository import (
    block_account,
    blocked_account_ids,
    create_report,
    soft_delete_comment,
    soft_delete_post,
    unblock_account,
)
from app.db import Base


def make_session() -> Session:
    engine = create_engine(
        "sqlite+pysqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(engine)
    return sessionmaker(bind=engine)()


def account(session: Session, phone: str) -> Account:
    value = Account(phone=phone)
    session.add(value)
    session.commit()
    return value


def post(session: Session, author_id: str, summary: str = "测试装机方案") -> CommunityPost:
    value = CommunityPost(
        author_id=author_id,
        summary=summary,
        body="用于社区安全仓储测试的正文",
        tags=[],
        parts=[],
        status="published",
    )
    session.add(value)
    session.commit()
    return value


def test_reports_are_idempotent_for_each_reporter_and_target() -> None:
    session = make_session()
    author = account(session, "13800138000")
    reporter = account(session, "13900139000")
    target = post(session, author.id)

    first = create_report(
        session,
        reporter_id=reporter.id,
        target_type="post",
        target_id=target.id,
        reason="spam",
        details="重复广告",
    )
    second = create_report(
        session,
        reporter_id=reporter.id,
        target_type="post",
        target_id=target.id,
        reason="other",
        details="不应覆盖首次举报",
    )

    assert second.id == first.id
    assert second.reason == "spam"
    assert session.scalar(select(func.count()).select_from(CommunityReport)) == 1


def test_blocking_is_idempotent_rejects_self_and_filters_feed() -> None:
    session = make_session()
    viewer = account(session, "13800138000")
    hidden_author = account(session, "13900139000")
    visible_author = account(session, "13700137000")
    hidden_post = post(session, hidden_author.id, "不应出现的帖子")
    visible_post = post(session, visible_author.id, "仍然可见的帖子")

    with pytest.raises(ValueError, match="cannot block self"):
        block_account(session, viewer.id, viewer.id)

    first = block_account(session, viewer.id, hidden_author.id)
    second = block_account(session, viewer.id, hidden_author.id)
    assert first.id == second.id
    assert blocked_account_ids(session, viewer.id) == {hidden_author.id}

    feed = list_feed_posts(
        session,
        excluded_author_ids=blocked_account_ids(session, viewer.id),
    )
    assert [item.id for item in feed] == [visible_post.id]
    assert hidden_post.id not in [item.id for item in feed]

    assert unblock_account(session, viewer.id, hidden_author.id) is True
    assert unblock_account(session, viewer.id, hidden_author.id) is False


def test_only_owner_can_soft_delete_posts_and_comments() -> None:
    session = make_session()
    owner = account(session, "13800138000")
    other = account(session, "13900139000")
    target = post(session, owner.id)
    comment = CommunityComment(
        post_id=target.id,
        author_id=owner.id,
        body="由作者删除的评论",
        status="published",
    )
    session.add(comment)
    target.comment_count = 1
    session.commit()

    assert soft_delete_post(session, target.id, other.id) is None
    assert soft_delete_comment(session, comment.id, other.id) is None
    assert soft_delete_comment(session, comment.id, owner.id).status == "deleted"
    assert list_comments(session, target.id) == []
    assert target.comment_count == 0
    assert soft_delete_post(session, target.id, owner.id).status == "deleted"
    assert list_feed_posts(session) == []


def test_account_erasure_removes_reports_and_blocks_in_both_directions() -> None:
    session = make_session()
    owner = account(session, "13800138000")
    reporter = account(session, "13900139000")
    unrelated_author = account(session, "13700137000")
    target = post(session, owner.id)
    unrelated_target = post(session, unrelated_author.id)
    create_report(session, reporter.id, "post", target.id, "spam", "")
    unrelated_report = create_report(
        session, reporter.id, "post", unrelated_target.id, "spam", ""
    )
    block_account(session, reporter.id, owner.id)
    block_account(session, owner.id, reporter.id)

    delete_account(session, owner)

    assert session.scalars(select(CommunityReport)).all() == [unrelated_report]
    assert session.scalar(select(func.count()).select_from(CommunityBlock)) == 0
