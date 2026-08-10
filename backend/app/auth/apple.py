import hashlib
import hmac
from dataclasses import dataclass
from functools import lru_cache
from typing import Optional

import jwt
from jwt import PyJWKClient
from jwt.exceptions import PyJWTError


APPLE_ISSUER = "https://appleid.apple.com"
APPLE_JWKS_URL = "https://appleid.apple.com/auth/keys"


@dataclass(frozen=True)
class AppleIdentity:
    sub: str
    email: Optional[str] = None


def verify_apple_identity_token(
    identity_token: str,
    client_id: str,
    nonce: str,
) -> Optional[AppleIdentity]:
    try:
        signing_key = _apple_jwk_client().get_signing_key_from_jwt(identity_token).key
        payload = jwt.decode(
            identity_token,
            signing_key,
            algorithms=["RS256"],
            audience=client_id,
            issuer=APPLE_ISSUER,
        )
    except (PyJWTError, ValueError):
        return None

    sub = payload.get("sub")
    if not isinstance(sub, str) or not sub:
        return None
    token_nonce = payload.get("nonce")
    expected_nonce = hashlib.sha256(nonce.encode("utf-8")).hexdigest()
    if not isinstance(token_nonce, str) or not hmac.compare_digest(
        token_nonce,
        expected_nonce,
    ):
        return None
    email = payload.get("email")
    return AppleIdentity(sub=sub, email=email if isinstance(email, str) else None)


@lru_cache(maxsize=1)
def _apple_jwk_client() -> PyJWKClient:
    return PyJWKClient(APPLE_JWKS_URL)
