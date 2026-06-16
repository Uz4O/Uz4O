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
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Missing bearer token")

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
