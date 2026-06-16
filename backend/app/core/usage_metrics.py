from dataclasses import dataclass
from threading import Lock
from typing import Dict


@dataclass
class EndpointUsage:
    requests: int = 0
    rate_limited_requests: int = 0
    cache_hits: int = 0
    cache_misses: int = 0
    estimated_cost_cents: int = 0
    actual_ai_cost_cents: int = 0
    external_ai_failures: int = 0


class HighCostUsageMetrics:
    def __init__(self) -> None:
        self._lock = Lock()
        self._by_endpoint: Dict[str, EndpointUsage] = {}

    def record_request(self, endpoint: str) -> None:
        with self._lock:
            self._usage_for(endpoint).requests += 1

    def record_rate_limited(self, endpoint: str) -> None:
        with self._lock:
            self._usage_for(endpoint).rate_limited_requests += 1

    def record_cache_status(self, endpoint: str, status: str) -> None:
        with self._lock:
            usage = self._usage_for(endpoint)
            if status == "HIT":
                usage.cache_hits += 1
            elif status == "MISS":
                usage.cache_misses += 1

    def record_estimated_cost(self, endpoint: str, cents: int) -> None:
        if cents <= 0:
            return
        with self._lock:
            self._usage_for(endpoint).estimated_cost_cents += cents

    def record_actual_ai_cost(self, endpoint: str, cents: int) -> None:
        if cents <= 0:
            return
        with self._lock:
            self._usage_for(endpoint).actual_ai_cost_cents += cents

    def record_external_ai_failure(self, endpoint: str) -> None:
        with self._lock:
            self._usage_for(endpoint).external_ai_failures += 1

    def snapshot(self) -> Dict[str, object]:
        with self._lock:
            by_endpoint = {
                endpoint: {
                    "requests": usage.requests,
                    "rate_limited_requests": usage.rate_limited_requests,
                    "cache_hits": usage.cache_hits,
                    "cache_misses": usage.cache_misses,
                    "estimated_cost_cents": usage.estimated_cost_cents,
                    "actual_ai_cost_cents": usage.actual_ai_cost_cents,
                    "external_ai_failures": usage.external_ai_failures,
                }
                for endpoint, usage in sorted(self._by_endpoint.items())
            }
            return {
                "total_requests": sum(item["requests"] for item in by_endpoint.values()),
                "rate_limited_requests": sum(
                    item["rate_limited_requests"] for item in by_endpoint.values()
                ),
                "cache_hits": sum(item["cache_hits"] for item in by_endpoint.values()),
                "cache_misses": sum(item["cache_misses"] for item in by_endpoint.values()),
                "estimated_cost_cents": sum(
                    item["estimated_cost_cents"] for item in by_endpoint.values()
                ),
                "actual_ai_cost_cents": sum(
                    item["actual_ai_cost_cents"] for item in by_endpoint.values()
                ),
                "external_ai_failures": sum(
                    item["external_ai_failures"] for item in by_endpoint.values()
                ),
                "by_endpoint": by_endpoint,
            }

    def _usage_for(self, endpoint: str) -> EndpointUsage:
        usage = self._by_endpoint.get(endpoint)
        if usage is None:
            usage = EndpointUsage()
            self._by_endpoint[endpoint] = usage
        return usage
