from datetime import datetime, timedelta, timezone
import base64
import hashlib
import hmac
import json

from app.auth.security import (
    hash_sms_code,
    sign_access_token,
    verify_access_token,
    verify_sms_code,
)


TEST_SECRET = "test-secret-with-at-least-32-bytes"


def test_sms_code_hash_does_not_store_plaintext_and_verifies() -> None:
    hashed = hash_sms_code("13800138000", "123456")

    assert hashed != "123456"
    assert verify_sms_code("13800138000", "123456", hashed) is True
    assert verify_sms_code("13800138000", "654321", hashed) is False


def test_access_token_round_trips_account_id() -> None:
    token = sign_access_token(
        account_id="account-1",
        secret=TEST_SECRET,
        expires_at=datetime.now(timezone.utc) + timedelta(minutes=10),
    )

    assert verify_access_token(token, secret=TEST_SECRET) == "account-1"
    assert len(token.split(".")) == 3


def test_expired_access_token_is_rejected() -> None:
    token = sign_access_token(
        account_id="account-1",
        secret=TEST_SECRET,
        expires_at=datetime.now(timezone.utc) - timedelta(seconds=1),
    )

    assert verify_access_token(token, secret=TEST_SECRET) is None


def test_tampered_access_token_is_rejected() -> None:
    token = sign_access_token(
        account_id="account-1",
        secret=TEST_SECRET,
        expires_at=datetime.now(timezone.utc) + timedelta(minutes=10),
    )
    header, payload, signature = token.split(".")
    tampered_signature = ("a" if signature[0] != "a" else "b") + signature[1:]
    tampered = ".".join([header, payload, tampered_signature])

    assert verify_access_token(tampered, secret=TEST_SECRET) is None


def test_legacy_access_token_is_accepted_during_transition() -> None:
    token = legacy_access_token(
        account_id="account-1",
        secret=TEST_SECRET,
        expires_at=datetime.now(timezone.utc) + timedelta(minutes=10),
    )

    assert len(token.split(".")) == 2
    assert verify_access_token(token, secret=TEST_SECRET) == "account-1"


def test_malformed_access_token_is_rejected_without_error() -> None:
    assert verify_access_token("非ascii.sig", secret=TEST_SECRET) is None


def legacy_access_token(account_id: str, secret: str, expires_at: datetime) -> str:
    payload = {"sub": account_id, "exp": int(expires_at.timestamp())}
    payload_bytes = urlsafe_json(payload)
    signature = legacy_signature(payload_bytes, secret)
    return f"{payload_bytes}.{signature}"


def urlsafe_json(payload: dict) -> str:
    raw = json.dumps(payload, separators=(",", ":"), sort_keys=True).encode("utf-8")
    return base64.urlsafe_b64encode(raw).decode("ascii").rstrip("=")


def legacy_signature(payload_bytes: str, secret: str) -> str:
    digest = hmac.new(secret.encode("utf-8"), payload_bytes.encode("ascii"), hashlib.sha256).digest()
    return base64.urlsafe_b64encode(digest).decode("ascii").rstrip("=")
