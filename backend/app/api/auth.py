import hashlib
from datetime import datetime, timedelta, timezone
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from app.auth.dependencies import get_app_settings, get_current_account
from app.auth.apple import verify_apple_identity_token
from app.auth.models import Account
from app.auth.repository import create_sms_code, get_or_create_account_by_apple_sub, login_with_sms_code
from app.auth.security import sign_access_token
from app.core.config import Settings
from app.core.rate_limit import auth_login_rate_limit, auth_sms_rate_limit
from app.db import get_session


class SmsSendRequest(BaseModel):
    phone: str = Field(min_length=5, max_length=32, pattern=r"^\+?[0-9]+$")


class SmsSendResponse(BaseModel):
    sent: bool
    debug_code: Optional[str] = None


class LoginRequest(BaseModel):
    phone: str = Field(min_length=5, max_length=32, pattern=r"^\+?[0-9]+$")
    code: str = Field(min_length=4, max_length=8, pattern=r"^[0-9]+$")


class AppleLoginRequest(BaseModel):
    identity_token: str = Field(min_length=16, max_length=4096)
    authorization_code: Optional[str] = Field(default=None, max_length=4096)


class AccountResponse(BaseModel):
    id: str
    phone: Optional[str]
    nickname: Optional[str]


class LoginResponse(BaseModel):
    access_token: str
    token_type: str
    account: AccountResponse


router = APIRouter(prefix="/v1/auth", tags=["auth"])


@router.post(
    "/sms/send",
    response_model=SmsSendResponse,
    dependencies=[Depends(auth_sms_rate_limit)],
)
def send_sms_code(
    request: SmsSendRequest,
    session: Session = Depends(get_session),
    settings: Settings = Depends(get_app_settings),
) -> SmsSendResponse:
    if not settings.auth_sms_debug:
        raise HTTPException(status_code=503, detail="SMS provider is not configured")

    code = _generate_debug_code(request.phone)
    create_sms_code(session, phone=request.phone, code=code)
    return SmsSendResponse(sent=True, debug_code=code if settings.auth_sms_debug else None)


@router.post(
    "/login",
    response_model=LoginResponse,
    dependencies=[Depends(auth_login_rate_limit)],
)
def login(
    request: LoginRequest,
    session: Session = Depends(get_session),
    settings: Settings = Depends(get_app_settings),
) -> LoginResponse:
    account = login_with_sms_code(session, phone=request.phone, code=request.code)
    if account is None:
        raise HTTPException(status_code=401, detail="Invalid verification code")
    token = sign_access_token(
        account_id=account.id,
        secret=settings.auth_token_secret,
        expires_at=datetime.now(timezone.utc) + timedelta(days=7),
    )
    return LoginResponse(access_token=token, token_type="bearer", account=_account_response(account))


@router.post(
    "/apple/login",
    response_model=LoginResponse,
    dependencies=[Depends(auth_login_rate_limit)],
)
def apple_login(
    request: AppleLoginRequest,
    session: Session = Depends(get_session),
    settings: Settings = Depends(get_app_settings),
) -> LoginResponse:
    if not settings.apple_login_client_id:
        raise HTTPException(status_code=503, detail="Apple login is not configured")

    identity = verify_apple_identity_token(
        request.identity_token,
        settings.apple_login_client_id,
    )
    if identity is None:
        raise HTTPException(status_code=401, detail="Invalid Apple identity token")

    account = get_or_create_account_by_apple_sub(
        session,
        apple_sub=identity.sub,
        email=identity.email,
    )
    token = sign_access_token(
        account_id=account.id,
        secret=settings.auth_token_secret,
        expires_at=datetime.now(timezone.utc) + timedelta(days=7),
    )
    return LoginResponse(access_token=token, token_type="bearer", account=_account_response(account))


@router.get("/me", response_model=AccountResponse)
def me(account: Account = Depends(get_current_account)) -> AccountResponse:
    return _account_response(account)


def _account_response(account: Account) -> AccountResponse:
    return AccountResponse(id=account.id, phone=account.phone, nickname=account.nickname)


def _generate_debug_code(phone: str) -> str:
    # Deterministic in debug mode so local app testing does not depend on a SMS provider.
    digest_prefix = hashlib.sha256(phone.encode("utf-8")).hexdigest()[:12]
    return f"{int(digest_prefix, 16) % 1000000:06d}"
