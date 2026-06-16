import base64
import hashlib
import hmac
import json
from datetime import datetime, timezone
from typing import Optional

import jwt


def hash_sms_code(phone: str, code: str) -> str:
    digest = hashlib.sha256(f"{phone}:{code}".encode("utf-8")).hexdigest()
    return digest


def verify_sms_code(phone: str, code: str, code_hash: str) -> bool:
    return hmac.compare_digest(hash_sms_code(phone, code), code_hash)


def sign_access_token(account_id: str, secret: str, expires_at: datetime) -> str:
    return jwt.encode(
        {"sub": account_id, "exp": int(expires_at.timestamp())},
        secret,
        algorithm="HS256",
    )


def verify_access_token(token: str, secret: str) -> Optional[str]:
    try:
        payload = jwt.decode(token, secret, algorithms=["HS256"])
        account_id = payload.get("sub")
        return account_id if isinstance(account_id, str) and account_id else None
    except jwt.PyJWTError:
        pass
    return _legacy_verify_access_token(token, secret)


# TODO(过渡期至 2026-06-30): 旧自研 token 兼容分支，过渡期后连同此函数一起删除。
def _legacy_verify_access_token(token: str, secret: str) -> Optional[str]:
    parts = token.split(".")
    if len(parts) != 2:
        return None
    payload_bytes, signature = parts
    try:
        expected_signature = _signature(payload_bytes, secret)
    except UnicodeEncodeError:
        return None
    if not hmac.compare_digest(expected_signature, signature):
        return None
    try:
        payload = json.loads(_urlsafe_decode(payload_bytes))
    except (ValueError, json.JSONDecodeError):
        return None
    expires_at = payload.get("exp")
    account_id = payload.get("sub")
    if not isinstance(expires_at, int) or not isinstance(account_id, str):
        return None
    if datetime.now(timezone.utc).timestamp() >= expires_at:
        return None
    return account_id


def _urlsafe_json(payload: dict) -> str:
    raw = json.dumps(payload, separators=(",", ":"), sort_keys=True).encode("utf-8")
    return base64.urlsafe_b64encode(raw).decode("ascii").rstrip("=")


def _urlsafe_decode(value: str) -> str:
    padding = "=" * (-len(value) % 4)
    return base64.urlsafe_b64decode(f"{value}{padding}".encode("ascii")).decode("utf-8")


def _signature(payload_bytes: str, secret: str) -> str:
    digest = hmac.new(secret.encode("utf-8"), payload_bytes.encode("ascii"), hashlib.sha256).digest()
    return base64.urlsafe_b64encode(digest).decode("ascii").rstrip("=")
