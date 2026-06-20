from datetime import datetime, timedelta, timezone
from typing import Iterable, List, Optional

from sqlalchemy import and_, delete, or_, select
from sqlalchemy.orm import Session

from app.auth.models import Account, AuthSmsCode
from app.auth.security import hash_sms_code, verify_sms_code
from app.builds.models import SavedBuild
from app.community.models import CommunityComment, CommunityPost, CommunityReaction
from app.community.safety_models import CommunityBlock, CommunityReport
from app.profile.models import HardwareProfile, OnboardingProfile


def create_sms_code(
    session: Session,
    phone: str,
    code: str,
    expires_in_minutes: int = 10,
) -> AuthSmsCode:
    now = datetime.now(timezone.utc)
    code_hash = hash_sms_code(phone, code)
    existing = session.scalar(
        select(AuthSmsCode).where(
            AuthSmsCode.phone == phone,
            AuthSmsCode.code_hash == code_hash,
        )
    )
    for sms_code in session.scalars(
        select(AuthSmsCode).where(
            AuthSmsCode.phone == phone,
            AuthSmsCode.consumed_at.is_(None),
            AuthSmsCode.code_hash != code_hash,
        )
    ):
        sms_code.consumed_at = now

    if existing is not None:
        existing.expires_at = now + timedelta(minutes=expires_in_minutes)
        existing.created_at = now
        existing.consumed_at = None
        session.commit()
        return existing

    sms_code = AuthSmsCode(
        phone=phone,
        code_hash=code_hash,
        expires_at=now + timedelta(minutes=expires_in_minutes),
    )
    session.add(sms_code)
    session.commit()
    return sms_code


def login_with_sms_code(session: Session, phone: str, code: str) -> Optional[Account]:
    sms_code = _latest_valid_sms_code(session, phone)
    if sms_code is None or not verify_sms_code(phone, code, sms_code.code_hash):
        return None

    account = session.scalar(select(Account).where(Account.phone == phone))
    if account is None:
        account = Account(phone=phone)
        session.add(account)
        session.flush()

    sms_code.consumed_at = datetime.now(timezone.utc)
    session.commit()
    return account


def get_or_create_account_by_apple_sub(
    session: Session,
    apple_sub: str,
    email: Optional[str] = None,
) -> Account:
    account = session.scalar(select(Account).where(Account.apple_sub == apple_sub))
    if account is None:
        account = Account(apple_sub=apple_sub, nickname=email)
        session.add(account)
    elif account.nickname is None and email:
        account.nickname = email
    session.commit()
    return account


def get_account(session: Session, account_id: str) -> Optional[Account]:
    return session.get(Account, account_id)


def list_accounts_by_ids(session: Session, account_ids: Iterable[str]) -> List[Account]:
    ids = list({account_id for account_id in account_ids if account_id})
    if not ids:
        return []
    statement = select(Account).where(Account.id.in_(ids))
    return list(session.scalars(statement))


def delete_account(session: Session, account: Account) -> None:
    post_ids = list(
        session.scalars(
            select(CommunityPost.id).where(CommunityPost.author_id == account.id)
        )
    )
    comment_ids = list(
        session.scalars(
            select(CommunityComment.id).where(
                or_(
                    CommunityComment.author_id == account.id,
                    CommunityComment.post_id.in_(post_ids) if post_ids else False,
                )
            )
        )
    )

    report_filter = CommunityReport.reporter_id == account.id
    if post_ids:
        report_filter = or_(
            report_filter,
            and_(
                CommunityReport.target_type == "post",
                CommunityReport.target_id.in_(post_ids),
            ),
        )
    if comment_ids:
        report_filter = or_(
            report_filter,
            and_(
                CommunityReport.target_type == "comment",
                CommunityReport.target_id.in_(comment_ids),
            ),
        )
    session.execute(delete(CommunityReport).where(report_filter))
    session.execute(
        delete(CommunityBlock).where(
            or_(
                CommunityBlock.blocker_id == account.id,
                CommunityBlock.blocked_id == account.id,
            )
        )
    )

    reaction_filter = CommunityReaction.account_id == account.id
    comment_filter = CommunityComment.author_id == account.id
    if post_ids:
        reaction_filter = or_(reaction_filter, CommunityReaction.post_id.in_(post_ids))
        comment_filter = or_(comment_filter, CommunityComment.post_id.in_(post_ids))

    session.execute(delete(CommunityReaction).where(reaction_filter))
    session.execute(delete(CommunityComment).where(comment_filter))
    session.execute(delete(CommunityPost).where(CommunityPost.author_id == account.id))
    session.execute(delete(SavedBuild).where(SavedBuild.account_id == account.id))
    session.execute(delete(HardwareProfile).where(HardwareProfile.account_id == account.id))
    session.execute(delete(OnboardingProfile).where(OnboardingProfile.account_id == account.id))
    if account.phone:
        session.execute(delete(AuthSmsCode).where(AuthSmsCode.phone == account.phone))
    session.delete(account)
    session.commit()


def _latest_valid_sms_code(session: Session, phone: str) -> Optional[AuthSmsCode]:
    statement = (
        select(AuthSmsCode)
        .where(
            AuthSmsCode.phone == phone,
            AuthSmsCode.consumed_at.is_(None),
        )
        .order_by(AuthSmsCode.created_at.desc())
        .limit(1)
    )
    sms_code = session.scalar(statement)
    if sms_code is None:
        return None
    expires_at = sms_code.expires_at
    if expires_at.tzinfo is None:
        expires_at = expires_at.replace(tzinfo=timezone.utc)
    if expires_at <= datetime.now(timezone.utc):
        return None
    return sms_code
