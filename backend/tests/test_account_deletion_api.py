from fastapi.testclient import TestClient
from sqlalchemy import create_engine, func, select
from sqlalchemy.orm import Session, sessionmaker
from sqlalchemy.pool import StaticPool

from app.auth.models import Account, AuthSmsCode
from app.builds.models import SavedBuild
from app.community.models import CommunityComment, CommunityPost, CommunityReaction
from app.core.config import Settings
from app.db import Base, get_session
from app.main import create_app
from app.profile.models import HardwareProfile, OnboardingProfile


TEST_SECRET = "test-secret-with-at-least-32-bytes"


def make_client() -> tuple[TestClient, sessionmaker]:
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
            auth_token_secret=TEST_SECRET,
            auth_sms_debug=True,
        )
    )

    def override_session():
        with session_factory() as session:
            yield session

    app.dependency_overrides[get_session] = override_session
    return TestClient(app), session_factory


def login(client: TestClient, phone: str) -> tuple[str, str]:
    send_response = client.post("/v1/auth/sms/send", json={"phone": phone})
    code = send_response.json()["debug_code"]
    login_response = client.post("/v1/auth/login", json={"phone": phone, "code": code})
    body = login_response.json()
    return body["access_token"], body["account"]["id"]


def test_delete_current_account_erases_owned_data_and_invalidates_token() -> None:
    client, session_factory = make_client()
    token, account_id = login(client, "13800138000")
    other_token, other_account_id = login(client, "13900139000")
    headers = {"Authorization": f"Bearer {token}"}

    client.put(
        "/v1/profile/onboarding",
        headers=headers,
        json={"preference": "performance", "home_feature_order": ["build"]},
    )
    client.put(
        "/v1/profile/hardware",
        headers=headers,
        json={"label": "待删除主机", "cpu": "cpu-1", "was_skipped": False},
    )
    client.post(
        "/v1/builds",
        headers=headers,
        json={"title": "待删除方案", "plan": {}, "budget": 5000},
    )
    post_response = client.post(
        "/v1/community/posts",
        headers=headers,
        json={"summary": "待删除的装机方案", "body": "这是一条等待随账号删除的社区正文"},
    )
    post_id = post_response.json()["id"]
    client.post(
        f"/v1/community/posts/{post_id}/comments",
        headers={"Authorization": f"Bearer {other_token}"},
        json={"body": "其他用户的评论"},
    )
    client.post(
        f"/v1/community/posts/{post_id}/reactions",
        headers=headers,
        json={"type": "like", "active": True},
    )

    response = client.request(
        "DELETE",
        "/v1/auth/me",
        headers=headers,
        json={"confirmation": "DELETE"},
    )

    assert response.status_code == 204
    assert client.get("/v1/auth/me", headers=headers).status_code == 401

    with session_factory() as session:
        assert session.get(Account, account_id) is None
        assert session.get(Account, other_account_id) is not None
        assert _count(session, OnboardingProfile) == 0
        assert _count(session, HardwareProfile) == 0
        assert _count(session, SavedBuild) == 0
        assert _count(session, CommunityPost) == 0
        assert _count(session, CommunityComment) == 0
        assert _count(session, CommunityReaction) == 0
        assert session.scalar(
            select(func.count()).select_from(AuthSmsCode).where(
                AuthSmsCode.phone == "13800138000"
            )
        ) == 0


def test_delete_current_account_requires_auth_and_exact_confirmation() -> None:
    client, _ = make_client()
    token, _ = login(client, "13800138000")

    missing_auth = client.request(
        "DELETE", "/v1/auth/me", json={"confirmation": "DELETE"}
    )
    wrong_confirmation = client.request(
        "DELETE",
        "/v1/auth/me",
        headers={"Authorization": f"Bearer {token}"},
        json={"confirmation": "delete"},
    )

    assert missing_auth.status_code == 401
    assert wrong_confirmation.status_code == 422


def _count(session: Session, model: type) -> int:
    return session.scalar(select(func.count()).select_from(model)) or 0
