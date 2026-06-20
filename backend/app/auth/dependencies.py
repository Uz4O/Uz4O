from typing import Optional

from fastapi import Depends, Header, HTTPException, Request
from sqlalchemy.orm import Session

from app.auth.models import Account
from app.auth.repository import get_account
from app.auth.security import verify_access_token
from app.core.config import Settings
from app.db import get_session


MAX_BEARER_TOKEN_LENGTH = 4096


def get_app_settings(request: Request) -> Settings:
    return request.app.state.settings


def get_current_account(
    authorization: Optional[str] = Header(default=None),
    session: Session = Depends(get_session),
    settings: Settings = Depends(get_app_settings),
) -> Account:
    if not authorization:
        raise HTTPException(status_code=401, detail="Missing bearer token")
    return _account_from_authorization(authorization, session, settings)


def get_optional_current_account(
    authorization: Optional[str] = Header(default=None),
    session: Session = Depends(get_session),
    settings: Settings = Depends(get_app_settings),
) -> Optional[Account]:
    if authorization is None:
        return None
    return _account_from_authorization(authorization, session, settings)


def require_moderator(account: Account = Depends(get_current_account)) -> Account:
    if not account.is_moderator:
        raise HTTPException(status_code=403, detail="Moderator access required")
    return account


def _account_from_authorization(
    authorization: str,
    session: Session,
    settings: Settings,
) -> Account:
    if not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Invalid bearer token")

    token = authorization.removeprefix("Bearer ").strip()
    if len(token) > MAX_BEARER_TOKEN_LENGTH:
        raise HTTPException(status_code=401, detail="Invalid bearer token")
    account_id = verify_access_token(token, settings.auth_token_secret)
    if account_id is None:
        raise HTTPException(status_code=401, detail="Invalid bearer token")

    account = get_account(session, account_id)
    if account is None:
        raise HTTPException(status_code=401, detail="Invalid bearer token")
    return account
