from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.core.config import Settings
from app.db import Base, get_session
from app.main import create_app


TEST_SECRET = "test-secret-with-at-least-32-bytes"


def make_client() -> TestClient:
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


def build_payload(title: str = "7000 元 2K 游戏配置") -> dict:
    return {
        "title": title,
        "budget": 7000,
        "total_price": 6888,
        "use_case": "gaming",
        "plan": {
            "parts": [
                {"role": "cpu", "component_id": "i5-14600k", "name": "i5-14600K"},
                {"role": "gpu", "component_id": "rtx-5070", "name": "RTX 5070"},
            ],
            "risks": [],
        },
    }


def test_saved_builds_require_authentication() -> None:
    client = make_client()

    response = client.get("/v1/builds")

    assert response.status_code == 401


def test_create_list_and_delete_saved_build_for_current_account() -> None:
    client = make_client()
    token = login(client, "13800138000")
    headers = {"Authorization": f"Bearer {token}"}

    create_response = client.post("/v1/builds", headers=headers, json=build_payload())

    assert create_response.status_code == 200
    created = create_response.json()
    assert created["id"]
    assert created["title"] == "7000 元 2K 游戏配置"
    assert created["plan"]["parts"][0]["component_id"] == "i5-14600k"

    list_response = client.get("/v1/builds", headers=headers)
    assert list_response.status_code == 200
    assert [item["id"] for item in list_response.json()] == [created["id"]]

    delete_response = client.delete(f"/v1/builds/{created['id']}", headers=headers)
    assert delete_response.status_code == 204

    empty_response = client.get("/v1/builds", headers=headers)
    assert empty_response.json() == []


def test_saved_builds_are_isolated_by_account() -> None:
    client = make_client()
    owner_headers = {"Authorization": f"Bearer {login(client, '13800138000')}"}
    other_headers = {"Authorization": f"Bearer {login(client, '13900139000')}"}

    created = client.post("/v1/builds", headers=owner_headers, json=build_payload()).json()

    other_list = client.get("/v1/builds", headers=other_headers)
    assert other_list.status_code == 200
    assert other_list.json() == []

    forbidden_delete = client.delete(f"/v1/builds/{created['id']}", headers=other_headers)
    assert forbidden_delete.status_code == 404

    owner_list = client.get("/v1/builds", headers=owner_headers)
    assert [item["id"] for item in owner_list.json()] == [created["id"]]


def test_saved_builds_support_bounded_pagination() -> None:
    client = make_client()
    headers = {"Authorization": f"Bearer {login(client, '13800138000')}"}
    for index in range(3):
        response = client.post(
            "/v1/builds",
            headers=headers,
            json=build_payload(title=f"{index + 1} 号保存配置"),
        )
        assert response.status_code == 200

    response = client.get("/v1/builds", headers=headers, params={"limit": 2, "offset": 0})
    invalid_limit = client.get("/v1/builds", headers=headers, params={"limit": 101})
    invalid_offset = client.get("/v1/builds", headers=headers, params={"offset": -1})

    assert response.status_code == 200
    assert len(response.json()) == 2
    assert invalid_limit.status_code == 422
    assert invalid_offset.status_code == 422


def test_saved_build_rejects_oversized_plan_payload() -> None:
    client = make_client()
    headers = {"Authorization": f"Bearer {login(client, '13800138000')}"}
    payload = build_payload()
    payload["plan"] = {"notes": "x" * 25_000}

    response = client.post("/v1/builds", headers=headers, json=payload)

    assert response.status_code == 422
