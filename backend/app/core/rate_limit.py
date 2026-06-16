import hashlib
import time
from dataclasses import dataclass
from typing import Any, Dict, Optional, Union

from fastapi import Header, HTTPException, Request

from app.auth.models import Account


@dataclass
class RateLimitBucket:
    window_started_at: float
    count: int


class FixedWindowRateLimiter:
    def __init__(self, max_requests: int, window_seconds: int) -> None:
        self.max_requests = max_requests
        self.window_seconds = window_seconds
        self._buckets: Dict[str, RateLimitBucket] = {}

    def check(self, key: str, now: Optional[float] = None) -> Optional[int]:
        if self.max_requests <= 0 or self.window_seconds <= 0:
            return None

        current_time = now if now is not None else time.monotonic()
        bucket = self._buckets.get(key)
        if bucket is None or current_time - bucket.window_started_at >= self.window_seconds:
            self._buckets[key] = RateLimitBucket(
                window_started_at=current_time,
                count=1,
            )
            return None

        if bucket.count >= self.max_requests:
            retry_after = self.window_seconds - (current_time - bucket.window_started_at)
            return max(1, int(retry_after))

        bucket.count += 1
        return None


class RedisFixedWindowRateLimiter:
    def __init__(
        self,
        max_requests: int,
        window_seconds: int,
        namespace: str,
        redis_client: Any,
    ) -> None:
        self.max_requests = max_requests
        self.window_seconds = window_seconds
        self.namespace = namespace
        self.redis_client = redis_client
        self._fallback_limiter = FixedWindowRateLimiter(
            max_requests=max_requests,
            window_seconds=window_seconds,
        )

    def check(self, key: str, now: Optional[float] = None) -> Optional[int]:
        if self.max_requests <= 0 or self.window_seconds <= 0:
            return None

        current_time = now if now is not None else time.time()
        bucket = int(current_time // self.window_seconds)
        redis_key = f"rate-limit:{self.namespace}:{key}:{bucket}"
        try:
            count = int(self.redis_client.incr(redis_key))
            if count == 1:
                self.redis_client.expire(redis_key, self.window_seconds)
            if count <= self.max_requests:
                return None

            ttl = int(self.redis_client.ttl(redis_key))
            if ttl <= 0:
                ttl = self.window_seconds
            return max(1, ttl)
        except Exception:
            return self._fallback_limiter.check(key, now=current_time)


def create_rate_limiter(
    max_requests: int,
    window_seconds: int,
    namespace: str,
    redis_url: Optional[str],
) -> Union[FixedWindowRateLimiter, RedisFixedWindowRateLimiter]:
    if redis_url:
        try:
            from redis import Redis
        except ImportError:
            return FixedWindowRateLimiter(max_requests=max_requests, window_seconds=window_seconds)
        try:
            redis_client = Redis.from_url(redis_url, decode_responses=True)
        except Exception:
            return FixedWindowRateLimiter(max_requests=max_requests, window_seconds=window_seconds)
        return RedisFixedWindowRateLimiter(
            max_requests=max_requests,
            window_seconds=window_seconds,
            namespace=namespace,
            redis_client=redis_client,
        )

    return FixedWindowRateLimiter(max_requests=max_requests, window_seconds=window_seconds)


def high_cost_rate_limit(
    request: Request,
    authorization: Optional[str] = Header(default=None),
) -> None:
    settings = request.app.state.settings
    endpoint = request.url.path
    if not settings.high_cost_rate_limit_enabled:
        request.app.state.high_cost_usage_metrics.record_request(endpoint)
        return

    limiter: FixedWindowRateLimiter = request.app.state.high_cost_rate_limiter
    retry_after = limiter.check(_high_cost_key(request, authorization))
    if retry_after is not None:
        request.app.state.high_cost_usage_metrics.record_rate_limited(endpoint)
        raise HTTPException(
            status_code=429,
            detail="Rate limit exceeded",
            headers={"Retry-After": str(retry_after)},
        )
    request.app.state.high_cost_usage_metrics.record_request(endpoint)


def auth_sms_rate_limit(request: Request) -> None:
    _check_named_limiter(
        request=request,
        limiter_name="auth_sms_rate_limiter",
        key_prefix="sms",
        detail="SMS rate limit exceeded",
    )


def auth_login_rate_limit(request: Request) -> None:
    _check_named_limiter(
        request=request,
        limiter_name="auth_login_rate_limiter",
        key_prefix="login",
        detail="Login rate limit exceeded",
    )


def community_write_rate_limit(request: Request, account: Account) -> None:
    settings = request.app.state.settings
    if not settings.community_write_rate_limit_enabled:
        return

    limiter: FixedWindowRateLimiter = request.app.state.community_write_rate_limiter
    retry_after = limiter.check(f"community-write:{account.id}")
    if retry_after is not None:
        raise HTTPException(
            status_code=429,
            detail="Community write rate limit exceeded",
            headers={"Retry-After": str(retry_after)},
        )


def _check_named_limiter(
    request: Request,
    limiter_name: str,
    key_prefix: str,
    detail: str,
) -> None:
    settings = request.app.state.settings
    if not settings.auth_rate_limit_enabled:
        return

    limiter: FixedWindowRateLimiter = getattr(request.app.state, limiter_name)
    retry_after = limiter.check(f"{key_prefix}:{_client_host(request)}")
    if retry_after is not None:
        raise HTTPException(
            status_code=429,
            detail=detail,
            headers={"Retry-After": str(retry_after)},
        )


def _high_cost_key(request: Request, authorization: Optional[str]) -> str:
    if authorization and authorization.startswith("Bearer "):
        token = authorization.removeprefix("Bearer ").strip()
        digest = hashlib.sha256(token.encode("utf-8")).hexdigest()
        return f"token:{digest}"

    return f"ip:{_client_host(request)}"


def _client_host(request: Request) -> str:
    return request.client.host if request.client else "unknown"
