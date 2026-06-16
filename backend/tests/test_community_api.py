from fastapi.testclient import TestClient
from sqlalchemy import event
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.core.config import Settings
from app.db import Base, get_session
from app.main import create_app


TEST_SECRET = "test-secret-with-at-least-32-bytes"


def make_client(**settings_overrides) -> TestClient:
    engine = create_engine(
        "sqlite+pysqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(engine)
    session_factory = sessionmaker(bind=engine)
    settings = {
        "_env_file": None,
        "postgres_url": None,
        "redis_url": None,
        "auth_token_secret": TEST_SECRET,
        "auth_sms_debug": True,
    }
    settings.update(settings_overrides)
    app = create_app(Settings(**settings))

    def override_session():
        with session_factory() as session:
            yield session

    app.dependency_overrides[get_session] = override_session
    app.state.test_engine = engine
    return TestClient(app)


def login(client: TestClient, phone: str) -> str:
    send_response = client.post("/v1/auth/sms/send", json={"phone": phone})
    assert send_response.status_code == 200
    code = send_response.json()["debug_code"]
    login_response = client.post(
        "/v1/auth/login",
        json={"phone": phone, "code": code},
    )
    assert login_response.status_code == 200
    return login_response.json()["access_token"]


def post_payload() -> dict:
    return {
        "summary": "分享一套 5000 元游戏配置",
        "body": "这套配置优先把预算放在显卡和电源上，适合 1080p 高刷游戏。",
        "tags": ["装机配置", "游戏主机"],
        "parts": ["CPU：i5-14600K", "显卡：RTX 4060"],
        "image_asset": None,
    }


def test_feed_starts_empty_and_posting_requires_auth() -> None:
    client = make_client()

    feed = client.get("/v1/community/feed")
    assert feed.status_code == 200
    assert feed.json()["posts"] == []

    unauthenticated = client.post("/v1/community/posts", json=post_payload())
    assert unauthenticated.status_code == 401


def test_create_post_read_detail_comment_and_react() -> None:
    client = make_client()
    token = login(client, "13800138000")
    headers = {"Authorization": f"Bearer {token}"}

    create_response = client.post("/v1/community/posts", headers=headers, json=post_payload())
    assert create_response.status_code == 200
    created = create_response.json()
    assert created["id"]
    assert created["status"] == "published"
    assert created["author"]["avatar_initial"] == "用"
    assert created["stats"] == {"likes": 0, "comments": 0, "saves": 0}

    feed = client.get("/v1/community/feed?topic=装机配置")
    assert [post["id"] for post in feed.json()["posts"]] == [created["id"]]
    assert feed.json()["posts"][0]["author"]["name"] == "用户8000"

    detail = client.get(f"/v1/community/posts/{created['id']}")
    assert detail.status_code == 200
    assert detail.json()["post"]["summary"] == "分享一套 5000 元游戏配置"
    assert detail.json()["post"]["author"]["name"] == "用户8000"
    assert detail.json()["comments"] == []

    comment_response = client.post(
        f"/v1/community/posts/{created['id']}/comments",
        headers=headers,
        json={"body": "这套配置思路清楚，电源余量也比较稳。"},
    )
    assert comment_response.status_code == 200
    assert comment_response.json()["status"] == "published"

    like_response = client.post(
        f"/v1/community/posts/{created['id']}/reactions",
        headers=headers,
        json={"type": "like", "active": True},
    )
    assert like_response.status_code == 200
    assert like_response.json()["stats"]["likes"] == 1

    save_response = client.post(
        f"/v1/community/posts/{created['id']}/reactions",
        headers=headers,
        json={"type": "save", "active": True},
    )
    assert save_response.status_code == 200
    assert save_response.json()["stats"]["saves"] == 1

    unlike_response = client.post(
        f"/v1/community/posts/{created['id']}/reactions",
        headers=headers,
        json={"type": "like", "active": False},
    )
    assert unlike_response.status_code == 200
    assert unlike_response.json()["stats"]["likes"] == 0

    detail_after = client.get(f"/v1/community/posts/{created['id']}")
    assert detail_after.json()["post"]["stats"]["comments"] == 1
    assert len(detail_after.json()["comments"]) == 1
    assert detail_after.json()["comments"][0]["author"]["name"] == "用户8000"


def test_community_moderation_marks_blocked_content_for_review() -> None:
    client = make_client()
    token = login(client, "13900139000")
    headers = {"Authorization": f"Bearer {token}"}
    payload = post_payload()
    payload["body"] = "加微信返现，广告推广"

    response = client.post("/v1/community/posts", headers=headers, json=payload)

    assert response.status_code == 200
    assert response.json()["status"] == "pending_review"
    assert client.get("/v1/community/feed").json()["posts"] == []


def test_community_moderation_catches_separated_blocked_content() -> None:
    client = make_client()
    token = login(client, "13900139000")
    headers = {"Authorization": f"Bearer {token}"}
    payload = post_payload()
    payload["body"] = "想了解更多可以加 微 信，价格还能返-现。"

    response = client.post("/v1/community/posts", headers=headers, json=payload)

    assert response.status_code == 200
    assert response.json()["status"] == "pending_review"
    assert client.get("/v1/community/feed").json()["posts"] == []


def test_community_rejects_image_asset_until_upload_is_configured() -> None:
    client = make_client()
    token = login(client, "13800138000")
    headers = {"Authorization": f"Bearer {token}"}
    payload = post_payload()
    payload["image_asset"] = "https://example.com/unreviewed-image.jpg"

    response = client.post("/v1/community/posts", headers=headers, json=payload)

    assert response.status_code == 400
    assert response.json() == {"detail": "Community image upload is not configured"}
    assert client.get("/v1/community/feed").json()["posts"] == []


def test_community_post_rejects_oversized_tag_or_part() -> None:
    client = make_client()
    token = login(client, "13800138000")
    headers = {"Authorization": f"Bearer {token}"}

    payload = post_payload()
    payload["tags"] = ["x" * 65]
    tag_response = client.post("/v1/community/posts", headers=headers, json=payload)
    assert tag_response.status_code == 422

    payload = post_payload()
    payload["parts"] = ["x" * 181]
    part_response = client.post("/v1/community/posts", headers=headers, json=payload)
    assert part_response.status_code == 422


def test_community_upload_requires_auth_and_reports_missing_storage_config() -> None:
    client = make_client()

    unauthenticated = client.post(
        "/v1/community/upload",
        json={"file_name": "build.jpg", "content_type": "image/jpeg", "size_bytes": 1024},
    )
    assert unauthenticated.status_code == 401

    token = login(client, "13800138000")
    response = client.post(
        "/v1/community/upload",
        headers={"Authorization": f"Bearer {token}"},
        json={"file_name": "build.jpg", "content_type": "image/jpeg", "size_bytes": 1024},
    )

    assert response.status_code == 503
    assert response.json() == {"detail": "Community image upload is not configured"}


def test_community_upload_returns_oss_form_signature_when_configured() -> None:
    client = make_client(
        community_image_upload_enabled=True,
        community_image_oss_bucket="ai-pc-community",
        community_image_oss_region="cn-hangzhou",
        community_image_oss_access_key_id="test-access-key-id",
        community_image_oss_access_key_secret="test-access-key-secret",
    )
    token = login(client, "13800138000")

    response = client.post(
        "/v1/community/upload",
        headers={"Authorization": f"Bearer {token}"},
        json={"file_name": "build.jpg", "content_type": "image/jpeg", "size_bytes": 1024},
    )

    assert response.status_code == 200
    body = response.json()
    assert body["upload_url"] == "https://ai-pc-community.oss-cn-hangzhou.aliyuncs.com"
    assert body["asset_key"].startswith("community/")
    assert body["asset_key"].endswith(".jpg")
    assert body["headers"] == {"Content-Type": "image/jpeg"}
    assert body["form_fields"]["key"] == body["asset_key"]
    assert body["form_fields"]["success_action_status"] == "200"
    assert body["form_fields"]["x-oss-signature-version"] == "OSS4-HMAC-SHA256"
    assert body["form_fields"]["x-oss-credential"].startswith("test-access-key-id/")
    assert body["form_fields"]["x-oss-date"]
    assert body["form_fields"]["policy"]
    assert body["form_fields"]["x-oss-signature"]
    assert "test-access-key-secret" not in response.text


def test_community_post_accepts_signed_asset_key_when_upload_is_configured() -> None:
    client = make_client(
        community_image_upload_enabled=True,
        community_image_oss_bucket="ai-pc-community",
        community_image_oss_region="cn-hangzhou",
        community_image_oss_access_key_id="test-access-key-id",
        community_image_oss_access_key_secret="test-access-key-secret",
    )
    token = login(client, "13800138000")
    headers = {"Authorization": f"Bearer {token}"}
    upload = client.post(
        "/v1/community/upload",
        headers=headers,
        json={"file_name": "build.jpg", "content_type": "image/jpeg", "size_bytes": 1024},
    )
    payload = post_payload()
    payload["image_asset"] = upload.json()["asset_key"]

    response = client.post("/v1/community/posts", headers=headers, json=payload)

    assert response.status_code == 200
    assert response.json()["image_asset"] == payload["image_asset"]


def test_community_post_rejects_external_image_asset_even_when_upload_is_configured() -> None:
    client = make_client(
        community_image_upload_enabled=True,
        community_image_oss_bucket="ai-pc-community",
        community_image_oss_region="cn-hangzhou",
        community_image_oss_access_key_id="test-access-key-id",
        community_image_oss_access_key_secret="test-access-key-secret",
    )
    token = login(client, "13800138000")
    payload = post_payload()
    payload["image_asset"] = "https://example.com/unreviewed-image.jpg"

    response = client.post(
        "/v1/community/posts",
        headers={"Authorization": f"Bearer {token}"},
        json=payload,
    )

    assert response.status_code == 400
    assert response.json() == {"detail": "Invalid community image asset"}


def test_community_upload_rejects_unsupported_file_types() -> None:
    client = make_client()
    token = login(client, "13800138000")

    response = client.post(
        "/v1/community/upload",
        headers={"Authorization": f"Bearer {token}"},
        json={"file_name": "build.svg", "content_type": "image/svg+xml", "size_bytes": 1024},
    )

    assert response.status_code == 422
    assert response.json()["detail"] == "Unsupported community image type"


def test_community_upload_rejects_mismatched_file_extension() -> None:
    client = make_client()
    token = login(client, "13800138000")

    response = client.post(
        "/v1/community/upload",
        headers={"Authorization": f"Bearer {token}"},
        json={"file_name": "build.jpg", "content_type": "image/png", "size_bytes": 1024},
    )

    assert response.status_code == 422
    assert response.json()["detail"] == "Community image extension does not match content type"


def test_community_feed_loads_authors_in_bulk() -> None:
    client = make_client()
    for index, phone in enumerate(["13800138000", "13900139000", "13700137000"]):
        headers = {"Authorization": f"Bearer {login(client, phone)}"}
        payload = post_payload()
        payload["summary"] = f"分享一套 {index + 1} 号游戏配置"
        response = client.post("/v1/community/posts", headers=headers, json=payload)
        assert response.status_code == 200

    select_count = 0

    def count_selects(*args):
        nonlocal select_count
        statement = args[2]
        if statement.lstrip().upper().startswith("SELECT"):
            select_count += 1

    event.listen(client.app.state.test_engine, "before_cursor_execute", count_selects)
    try:
        response = client.get("/v1/community/feed?topic=装机配置")
    finally:
        event.remove(client.app.state.test_engine, "before_cursor_execute", count_selects)

    assert response.status_code == 200
    assert len(response.json()["posts"]) == 3
    assert select_count <= 2


def test_community_feed_supports_bounded_pagination() -> None:
    client = make_client()
    for index, phone in enumerate(["13800138000", "13900139000", "13700137000"]):
        headers = {"Authorization": f"Bearer {login(client, phone)}"}
        payload = post_payload()
        payload["summary"] = f"分享一套 {index + 1} 号游戏配置"
        response = client.post("/v1/community/posts", headers=headers, json=payload)
        assert response.status_code == 200

    response = client.get("/v1/community/feed", params={"limit": 2, "offset": 0})
    invalid_limit = client.get("/v1/community/feed", params={"limit": 101})
    invalid_offset = client.get("/v1/community/feed", params={"offset": -1})

    assert response.status_code == 200
    assert len(response.json()["posts"]) == 2
    assert invalid_limit.status_code == 422
    assert invalid_offset.status_code == 422


def test_community_detail_comments_support_bounded_pagination() -> None:
    client = make_client()
    token = login(client, "13800138000")
    headers = {"Authorization": f"Bearer {token}"}
    post = client.post("/v1/community/posts", headers=headers, json=post_payload()).json()
    for index in range(3):
        response = client.post(
            f"/v1/community/posts/{post['id']}/comments",
            headers=headers,
            json={"body": f"第 {index + 1} 条评论，电源余量看起来比较稳。"},
        )
        assert response.status_code == 200

    response = client.get(
        f"/v1/community/posts/{post['id']}",
        params={"comments_limit": 2, "comments_offset": 0},
    )
    invalid_limit = client.get(f"/v1/community/posts/{post['id']}", params={"comments_limit": 101})
    invalid_offset = client.get(f"/v1/community/posts/{post['id']}", params={"comments_offset": -1})

    assert response.status_code == 200
    assert len(response.json()["comments"]) == 2
    assert invalid_limit.status_code == 422
    assert invalid_offset.status_code == 422
