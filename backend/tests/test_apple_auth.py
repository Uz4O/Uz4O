import hashlib

from app.auth import apple


class _FakeSigningKey:
    key = "public-key"


class _FakeJWKClient:
    def get_signing_key_from_jwt(self, identity_token: str) -> _FakeSigningKey:
        assert identity_token == "valid.apple.identity.token"
        return _FakeSigningKey()


def test_verifies_nonce_bound_to_apple_identity_token(monkeypatch) -> None:
    raw_nonce = "test-nonce-with-at-least-32-characters"
    monkeypatch.setattr(apple, "_apple_jwk_client", lambda: _FakeJWKClient())

    def fake_decode(token, key, *, algorithms, audience, issuer):
        assert token == "valid.apple.identity.token"
        assert key == "public-key"
        assert algorithms == ["RS256"]
        assert audience == "top.uzbox.app"
        assert issuer == apple.APPLE_ISSUER
        return {
            "sub": "apple-user-1",
            "email": "user@example.com",
            "nonce": hashlib.sha256(raw_nonce.encode("utf-8")).hexdigest(),
        }

    monkeypatch.setattr(apple.jwt, "decode", fake_decode)

    identity = apple.verify_apple_identity_token(
        "valid.apple.identity.token",
        "top.uzbox.app",
        raw_nonce,
    )

    assert identity == apple.AppleIdentity(
        sub="apple-user-1",
        email="user@example.com",
    )


def test_rejects_missing_or_mismatched_nonce(monkeypatch) -> None:
    monkeypatch.setattr(apple, "_apple_jwk_client", lambda: _FakeJWKClient())

    for token_nonce in (None, "wrong-nonce"):
        monkeypatch.setattr(
            apple.jwt,
            "decode",
            lambda *args, **kwargs: {
                "sub": "apple-user-1",
                "nonce": token_nonce,
            },
        )

        assert (
            apple.verify_apple_identity_token(
                "valid.apple.identity.token",
                "top.uzbox.app",
                "test-nonce-with-at-least-32-characters",
            )
            is None
        )
