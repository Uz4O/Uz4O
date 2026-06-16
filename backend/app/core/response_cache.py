import hashlib
import json
import time
from dataclasses import dataclass
from typing import Any, Dict, Optional

from pydantic import BaseModel


@dataclass
class ResponseCacheEntry:
    stored_at: float
    value: Dict[str, Any]


class ResponseCache:
    def __init__(self, ttl_seconds: int, max_entries: int) -> None:
        self.ttl_seconds = ttl_seconds
        self.max_entries = max_entries
        self._entries: Dict[str, ResponseCacheEntry] = {}

    def get(self, key: str, now: Optional[float] = None) -> Optional[Dict[str, Any]]:
        if self.ttl_seconds <= 0 or self.max_entries <= 0:
            return None

        current_time = now if now is not None else time.monotonic()
        entry = self._entries.get(key)
        if entry is None:
            return None
        if current_time - entry.stored_at >= self.ttl_seconds:
            self._entries.pop(key, None)
            return None
        return dict(entry.value)

    def set(self, key: str, value: Dict[str, Any], now: Optional[float] = None) -> None:
        if self.ttl_seconds <= 0 or self.max_entries <= 0:
            return

        if len(self._entries) >= self.max_entries and key not in self._entries:
            oldest_key = min(
                self._entries,
                key=lambda entry_key: self._entries[entry_key].stored_at,
            )
            self._entries.pop(oldest_key, None)
        current_time = now if now is not None else time.monotonic()
        self._entries[key] = ResponseCacheEntry(stored_at=current_time, value=dict(value))


def response_cache_key(namespace: str, payload: BaseModel) -> str:
    raw = json.dumps(
        payload.model_dump(mode="json"),
        ensure_ascii=False,
        separators=(",", ":"),
        sort_keys=True,
    )
    digest = hashlib.sha256(raw.encode("utf-8")).hexdigest()
    return f"{namespace}:{digest}"
