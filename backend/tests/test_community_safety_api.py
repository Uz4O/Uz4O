from fastapi.testclient import TestClient
from sqlalchemy import create_engine, func, select
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.auth.models import Account
from app.community.safety_models import CommunityReport
from app.core.config import Settings
from app.db import Base, get_session
from app.main import create_app


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


def login(client: TestClient, phone: str) -> tuple[dict[str, str], str]:
    code = client.post("/v1/auth/sms/send", json={"phone": phone}).json()["debug_code"]
    response = client.post("/v1/auth/login", json={"phone": phone, "code": code}).json()
    return {"Authorization": f"Bearer {response['access_token']}"}, response["account"]["id"]


def create_post(client: TestClient, headers: dict[str, str]) -> dict:
    response = client.post(
        "/v1/community/posts",
        headers=headers,
        json={"summary": "社区安全测试方案", "body": "用于测试举报和屏蔽流程的正文"},
    )
    assert response.status_code == 200
    return response.json()


def test_report_is_idempotent_and_requires_authentication() -> None:
    client, session_factory = make_client()
    owner_headers, _ = login(client, "13800138000")
    reporter_headers, _ = login(client, "13900139000")
    target = create_post(client, owner_headers)
    payload = {
        "target_type": "post",
        "target_id": target["id"],
        "reason": "spam",
        "details": "重复广告",
    }

    missing_auth = client.post("/v1/community/reports", json=payload)
    first = client.post("/v1/community/reports", headers=reporter_headers, json=payload)
    second = client.post("/v1/community/reports", headers=reporter_headers, json=payload)

    assert missing_auth.status_code == 401
    assert first.status_code == 200
    assert second.status_code == 200
    assert second.json()["id"] == first.json()["id"]
    with session_factory() as session:
        assert session.scalar(select(func.count()).select_from(CommunityReport)) == 1


def test_block_hides_author_and_invalid_supplied_token_is_rejected() -> None:
    client, _ = make_client()
    viewer_headers, _ = login(client, "13800138000")
    author_headers, author_id = login(client, "13900139000")
    target = create_post(client, author_headers)

    block = client.post(f"/v1/community/blocks/{author_id}", headers=viewer_headers)
    filtered = client.get("/v1/community/feed", headers=viewer_headers)
    anonymous = client.get("/v1/community/feed")
    invalid = client.get(
        "/v1/community/feed", headers={"Authorization": "Bearer invalid-token"}
    )
    unblock = client.delete(f"/v1/community/blocks/{author_id}", headers=viewer_headers)

    assert block.status_code == 200
    assert filtered.json()["posts"] == []
    assert [post["id"] for post in anonymous.json()["posts"]] == [target["id"]]
    assert invalid.status_code == 401
    assert unblock.status_code == 204


def test_delete_routes_are_owner_only_and_update_visibility() -> None:
    client, _ = make_client()
    owner_headers, _ = login(client, "13800138000")
    other_headers, _ = login(client, "13900139000")
    target = create_post(client, owner_headers)
    comment = client.post(
        f"/v1/community/posts/{target['id']}/comments",
        headers=owner_headers,
        json={"body": "由作者删除的评论"},
    ).json()

    assert client.delete(
        f"/v1/community/comments/{comment['id']}", headers=other_headers
    ).status_code == 404
    assert client.delete(
        f"/v1/community/comments/{comment['id']}", headers=owner_headers
    ).status_code == 204
    assert client.delete(
        f"/v1/community/posts/{target['id']}", headers=other_headers
    ).status_code == 404
    assert client.delete(
        f"/v1/community/posts/{target['id']}", headers=owner_headers
    ).status_code == 204
    assert client.get(f"/v1/community/posts/{target['id']}").status_code == 404


def test_response_identity_and_moderation_authorization() -> None:
    client, session_factory = make_client()
    owner_headers, owner_id = login(client, "13800138000")
    reporter_headers, _ = login(client, "13900139000")
    moderator_headers, moderator_id = login(client, "13700137000")
    target = create_post(client, owner_headers)
    report = client.post(
        "/v1/community/reports",
        headers=reporter_headers,
        json={
            "target_type": "post",
            "target_id": target["id"],
            "reason": "privacy",
            "details": "包含个人信息",
        },
    ).json()

    assert target["author"]["id"] == owner_id
    assert target["author_id"] == owner_id
    assert target["is_owned_by_current_account"] is True
    assert client.get(
        "/v1/community/moderation/reports", headers=owner_headers
    ).status_code == 403

    with session_factory() as session:
        moderator = session.get(Account, moderator_id)
        moderator.is_moderator = True
        session.commit()

    listing = client.get("/v1/community/moderation/reports", headers=moderator_headers)
    decision = client.patch(
        f"/v1/community/moderation/reports/{report['id']}",
        headers=moderator_headers,
        json={"status": "resolved", "resolution_note": "已完成核验"},
    )

    assert listing.status_code == 200
    assert [item["id"] for item in listing.json()] == [report["id"]]
    assert decision.status_code == 200
    assert decision.json()["status"] == "resolved"
