from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.core.config import Settings
from app.core.rate_limit import FixedWindowRateLimiter, RedisFixedWindowRateLimiter, create_rate_limiter
from app.db import Base, get_session
from app.main import create_app


TEST_SECRET = "test-secret-with-at-least-32-bytes"


def make_client(max_requests: int = 2) -> TestClient:
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
            high_cost_rate_limit_max_requests=max_requests,
            high_cost_rate_limit_window_seconds=60,
            auth_sms_rate_limit_max_requests=max_requests,
            auth_login_rate_limit_max_requests=max_requests,
            auth_rate_limit_window_seconds=60,
            community_write_rate_limit_max_requests=max_requests,
            community_write_rate_limit_window_seconds=60,
        )
    )

    def override_session():
        with session_factory() as session:
            yield session

    app.dependency_overrides[get_session] = override_session
    return TestClient(app)


def test_high_cost_endpoint_returns_429_after_limit_is_exceeded() -> None:
    client = make_client(max_requests=2)
    payload = {"text": "i7-14700F + RTX4060 + H610 主板 + 500W 电源，商家报价 6999"}

    assert client.post("/v1/review/analyze", json=payload).status_code == 200
    assert client.post("/v1/review/analyze", json=payload).status_code == 200

    limited = client.post("/v1/review/analyze", json=payload)

    assert limited.status_code == 429
    assert limited.json()["detail"] == "Rate limit exceeded"
    assert int(limited.headers["retry-after"]) > 0


def test_content_endpoint_is_not_counted_as_high_cost() -> None:
    client = make_client(max_requests=1)

    assert client.get("/v1/guide").status_code == 200
    assert client.get("/v1/guide").status_code == 200

    payload = {"text": "i7-14700F + RTX4060 + H610 主板 + 500W 电源，商家报价 6999"}
    assert client.post("/v1/review/analyze", json=payload).status_code == 200
    assert client.post("/v1/review/analyze", json=payload).status_code == 429


def test_sms_send_returns_429_after_limit_is_exceeded() -> None:
    client = make_client(max_requests=2)
    payload = {"phone": "13800138000"}

    assert client.post("/v1/auth/sms/send", json=payload).status_code == 200
    assert client.post("/v1/auth/sms/send", json=payload).status_code == 200

    limited = client.post("/v1/auth/sms/send", json=payload)

    assert limited.status_code == 429
    assert limited.json()["detail"] == "SMS rate limit exceeded"
    assert int(limited.headers["retry-after"]) > 0


def test_login_returns_429_after_limit_is_exceeded() -> None:
    client = make_client(max_requests=1)
    send_response = client.post("/v1/auth/sms/send", json={"phone": "13800138000"})
    code = send_response.json()["debug_code"]
    payload = {"phone": "13800138000", "code": code}

    assert client.post("/v1/auth/login", json=payload).status_code == 200

    limited = client.post("/v1/auth/login", json=payload)

    assert limited.status_code == 429
    assert limited.json()["detail"] == "Login rate limit exceeded"
    assert int(limited.headers["retry-after"]) > 0


def test_community_write_returns_429_after_limit_is_exceeded() -> None:
    client = make_client(max_requests=2)
    send_response = client.post("/v1/auth/sms/send", json={"phone": "13800138000"})
    code = send_response.json()["debug_code"]
    login_response = client.post(
        "/v1/auth/login",
        json={"phone": "13800138000", "code": code},
    )
    token = login_response.json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}
    payload = {
        "summary": "分享一套 5000 元游戏配置",
        "body": "这套配置优先把预算放在显卡和电源上，适合 1080p 高刷游戏。",
        "tags": ["装机配置", "游戏主机"],
        "parts": ["CPU：i5-14600K", "显卡：RTX 4060"],
        "image_asset": None,
    }

    assert client.post("/v1/community/posts", headers=headers, json=payload).status_code == 200
    assert client.post("/v1/community/posts", headers=headers, json=payload).status_code == 200

    limited = client.post("/v1/community/posts", headers=headers, json=payload)

    assert limited.status_code == 429
    assert limited.json()["detail"] == "Community write rate limit exceeded"
    assert int(limited.headers["retry-after"]) > 0
    assert client.get("/v1/community/feed").status_code == 200


class FakeRedis:
    def __init__(self) -> None:
        self.counts: dict[str, int] = {}
        self.expirations: dict[str, int] = {}

    def incr(self, key: str) -> int:
        self.counts[key] = self.counts.get(key, 0) + 1
        return self.counts[key]

    def expire(self, key: str, seconds: int) -> None:
        self.expirations[key] = seconds

    def ttl(self, key: str) -> int:
        return self.expirations.get(key, -1)


class FailingRedis:
    def incr(self, key: str) -> int:
        raise RuntimeError("redis unavailable")

    def expire(self, key: str, seconds: int) -> None:
        raise RuntimeError("redis unavailable")

    def ttl(self, key: str) -> int:
        raise RuntimeError("redis unavailable")


def test_redis_rate_limiter_shares_counts_across_instances() -> None:
    redis = FakeRedis()
    first_worker = RedisFixedWindowRateLimiter(
        max_requests=2,
        window_seconds=60,
        namespace="high-cost",
        redis_client=redis,
    )
    second_worker = RedisFixedWindowRateLimiter(
        max_requests=2,
        window_seconds=60,
        namespace="high-cost",
        redis_client=redis,
    )

    assert first_worker.check("token:abc", now=120.0) is None
    assert second_worker.check("token:abc", now=120.0) is None

    retry_after = first_worker.check("token:abc", now=120.0)

    assert retry_after == 60
    assert redis.counts == {"rate-limit:high-cost:token:abc:2": 3}
    assert redis.expirations == {"rate-limit:high-cost:token:abc:2": 60}


def test_redis_rate_limiter_falls_back_to_local_window_when_redis_fails() -> None:
    limiter = RedisFixedWindowRateLimiter(
        max_requests=1,
        window_seconds=60,
        namespace="high-cost",
        redis_client=FailingRedis(),
    )

    assert limiter.check("token:abc", now=120.0) is None
    assert limiter.check("token:abc", now=120.0) == 60


def test_create_rate_limiter_falls_back_when_redis_url_is_invalid() -> None:
    limiter = create_rate_limiter(
        max_requests=1,
        window_seconds=60,
        namespace="high-cost",
        redis_url="http://redis-secret@example.com",
    )

    assert isinstance(limiter, FixedWindowRateLimiter)
    assert limiter.check("token:abc", now=120.0) is None
    assert limiter.check("token:abc", now=120.0) == 60
