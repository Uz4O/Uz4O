from datetime import datetime, timedelta, timezone
from typing import Iterable, List, Optional

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.auth.models import Account, AuthSmsCode
from app.auth.security import hash_sms_code, verify_sms_code


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
