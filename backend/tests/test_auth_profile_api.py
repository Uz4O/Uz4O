from fastapi.testclient import TestClient
from typing import Optional
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.core.config import Settings
from app.db import Base, get_session
from app.main import create_app
from app.api.auth import _generate_debug_code
from app.auth.security import verify_access_token


TEST_SECRET = "test-secret-with-at-least-32-bytes"
CUSTOM_TEST_SECRET = "custom-test-secret-with-at-least-32-bytes"


def make_client(
    *,
    auth_token_secret: str = TEST_SECRET,
    auth_sms_debug: bool = True,
    apple_login_client_id: Optional[str] = None,
) -> TestClient:
    engine = create_engine(
        "sqlite+pysqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(engine)
    session_factory = sessionmaker(bind=engine)
    app = create_app(
        Settings(
            _env_file=None,
            postgres_url=None,
            redis_url=None,
            auth_token_secret=auth_token_secret,
            auth_sms_debug=auth_sms_debug,
            apple_login_client_id=apple_login_client_id,
        )
    )

    def override_session():
        with session_factory() as session:
            yield session

    app.dependency_overrides[get_session] = override_session
    return TestClient(app)


def login(client: TestClient) -> str:
    send_response = client.post("/v1/auth/sms/send", json={"phone": "13800138000"})
    assert send_response.status_code == 200
    code = send_response.json()["debug_code"]
    login_response = client.post(
        "/v1/auth/login",
        json={"phone": "13800138000", "code": code},
    )
    assert login_response.status_code == 200
    return login_response.json()["access_token"]


def test_sms_login_returns_token_and_current_account() -> None:
    client = make_client()

    token = login(client)
    response = client.get("/v1/auth/me", headers={"Authorization": f"Bearer {token}"})

    assert response.status_code == 200
    assert response.json()["phone"] == "13800138000"


def test_sms_send_fails_closed_when_debug_is_disabled_without_provider() -> None:
    client = make_client(auth_sms_debug=False)

    response = client.post("/v1/auth/sms/send", json={"phone": "13800138000"})
    login_response = client.post(
        "/v1/auth/login",
        json={"phone": "13800138000", "code": _generate_debug_code("13800138000")},
    )

    assert response.status_code == 503
    assert response.json() == {"detail": "SMS provider is not configured"}
    assert login_response.status_code == 401


def test_sms_send_rejects_non_numeric_phone() -> None:
    client = make_client()

    response = client.post("/v1/auth/sms/send", json={"phone": "abcde"})

    assert response.status_code == 422


def test_sms_login_rejects_non_numeric_code() -> None:
    client = make_client()

    response = client.post(
        "/v1/auth/login",
        json={"phone": "13800138000", "code": "12ab"},
    )

    assert response.status_code == 422


def test_debug_sms_code_is_stable_across_processes() -> None:
    assert _generate_debug_code("13800138000") == "824854"


def test_apple_login_reports_missing_server_configuration_without_leaking_token() -> None:
    client = make_client()
    identity_token = "apple-sensitive-identity-token"

    response = client.post(
        "/v1/auth/apple/login",
        json={"identity_token": identity_token, "authorization_code": "apple-code"},
    )

    assert response.status_code == 503
    assert response.json() == {"detail": "Apple login is not configured"}
    assert identity_token not in response.text


def test_apple_login_uses_verified_identity_to_create_account(monkeypatch) -> None:
    client = make_client(
        auth_token_secret=CUSTOM_TEST_SECRET,
        apple_login_client_id="com.example.app",
    )

    def fake_verify(identity_token: str, client_id: str):
        assert identity_token == "valid.apple.identity.token"
        assert client_id == "com.example.app"
        from app.auth.apple import AppleIdentity

        return AppleIdentity(sub="apple-user-1", email="user@example.com")

    monkeypatch.setattr("app.api.auth.verify_apple_identity_token", fake_verify)

    login_response = client.post(
        "/v1/auth/apple/login",
        json={"identity_token": "valid.apple.identity.token"},
    )

    assert login_response.status_code == 200
    body = login_response.json()
    assert body["token_type"] == "bearer"
    assert body["account"]["phone"] is None
    token = body["access_token"]

    me_response = client.get("/v1/auth/me", headers={"Authorization": f"Bearer {token}"})

    assert me_response.status_code == 200
    assert me_response.json()["id"] == body["account"]["id"]
    assert verify_access_token(token, secret=CUSTOM_TEST_SECRET) == body["account"]["id"]


def test_apple_login_rejects_invalid_identity_without_leaking_token(monkeypatch) -> None:
    client = make_client(apple_login_client_id="com.example.app")
    identity_token = "invalid.apple.identity.token"

    monkeypatch.setattr("app.api.auth.verify_apple_identity_token", lambda token, client_id: None)

    response = client.post(
        "/v1/auth/apple/login",
        json={"identity_token": identity_token},
    )

    assert response.status_code == 401
    assert response.json() == {"detail": "Invalid Apple identity token"}
    assert identity_token not in response.text


def test_login_token_uses_app_configured_secret() -> None:
    client = make_client(auth_token_secret=CUSTOM_TEST_SECRET)

    send_response = client.post("/v1/auth/sms/send", json={"phone": "13800138000"})
    code = send_response.json()["debug_code"]
    login_response = client.post(
        "/v1/auth/login",
        json={"phone": "13800138000", "code": code},
    )

    assert login_response.status_code == 200
    account_id = login_response.json()["account"]["id"]
    token = login_response.json()["access_token"]
    assert verify_access_token(token, secret=CUSTOM_TEST_SECRET) == account_id
    assert verify_access_token(token, secret="wrong-secret-with-at-least-32-bytes") is None


def test_protected_profile_endpoint_rejects_missing_token() -> None:
    client = make_client()

    response = client.get("/v1/profile/onboarding")

    assert response.status_code == 401
    assert response.json() == {"detail": "Missing bearer token"}


def test_protected_endpoint_rejects_oversized_bearer_token_before_verification(monkeypatch) -> None:
    client = make_client()

    def fail_if_called(*args, **kwargs):
        raise AssertionError("oversized token should not be verified")

    monkeypatch.setattr("app.auth.dependencies.verify_access_token", fail_if_called)

    response = client.get(
        "/v1/auth/me",
        headers={"Authorization": f"Bearer {'x' * 5000}"},
    )

    assert response.status_code == 401
    assert response.json() == {"detail": "Invalid bearer token"}


def test_onboarding_profile_defaults_and_upsert() -> None:
    client = make_client()
    token = login(client)
    headers = {"Authorization": f"Bearer {token}"}

    default_response = client.get("/v1/profile/onboarding", headers=headers)
    assert default_response.status_code == 200
    assert default_response.json() == {
        "preference": "balanced",
        "home_feature_order": [],
    }

    update_response = client.put(
        "/v1/profile/onboarding",
        headers=headers,
        json={"preference": "performance", "home_feature_order": ["build", "compat"]},
    )
    assert update_response.status_code == 200
    assert update_response.json()["preference"] == "performance"

    get_response = client.get("/v1/profile/onboarding", headers=headers)
    assert get_response.json()["home_feature_order"] == ["build", "compat"]


def test_onboarding_profile_rejects_oversized_feature_order() -> None:
    client = make_client()
    token = login(client)
    headers = {"Authorization": f"Bearer {token}"}

    response = client.put(
        "/v1/profile/onboarding",
        headers=headers,
        json={
            "preference": "balanced",
            "home_feature_order": [f"feature-{index}" for index in range(80)],
        },
    )

    assert response.status_code == 422


def test_hardware_profile_defaults_and_upsert() -> None:
    client = make_client()
    token = login(client)
    headers = {"Authorization": f"Bearer {token}"}

    default_response = client.get("/v1/profile/hardware", headers=headers)
    assert default_response.status_code == 200
    assert default_response.json()["was_skipped"] is False

    update_response = client.put(
        "/v1/profile/hardware",
        headers=headers,
        json={
            "label": "我的主机",
            "cpu": "i5-14600k",
            "gpu": "rtx-5070",
            "motherboard": "b760m",
            "memory": "ram-6000-cl30",
            "storage": "sn850x",
            "power_supply": "psu-750w",
            "was_skipped": False,
        },
    )
    assert update_response.status_code == 200
    assert update_response.json()["cpu"] == "i5-14600k"

    get_response = client.get("/v1/profile/hardware", headers=headers)
    assert get_response.json()["label"] == "我的主机"


def test_hardware_profile_rejects_oversized_text_fields() -> None:
    client = make_client()
    token = login(client)
    headers = {"Authorization": f"Bearer {token}"}

    response = client.put(
        "/v1/profile/hardware",
        headers=headers,
        json={
            "label": "x" * 121,
            "cpu": "i5-14600k",
            "was_skipped": False,
        },
    )

    assert response.status_code == 422
