from dataclasses import dataclass
from datetime import datetime
import json
from pathlib import Path
from typing import List, Optional
from urllib.parse import urlparse


@dataclass(frozen=True)
class PerformanceEstimateInput:
    cpu_id: str
    gpu_id: str
    game_id: str
    resolution: str
    quality: str
    average_fps: int
    minimum_fps: int
    maximum_fps: int
    bottleneck_type: Optional[str]
    bottleneck_percent: Optional[int]
    source_url: str
    source_fetched_at: datetime
    import_batch: str


def read_performance_batch(path: Path) -> List[PerformanceEstimateInput]:
    payload = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(payload, dict):
        raise ValueError("performance batch must be a JSON object")
    quality = payload.get("quality")
    if quality != "medium":
        raise ValueError("performance batch quality must be medium")
    source_fetched_at = _aware_datetime(payload.get("generated_at"))
    import_batch = payload.get("import_batch", path.stem)
    if not isinstance(import_batch, str) or not import_batch.strip():
        raise ValueError("import_batch must be a non-empty string")
    records = payload.get("records")
    if not isinstance(records, list):
        raise ValueError("records must be a list")

    estimates = []
    combinations = set()
    for record in records:
        if not isinstance(record, dict):
            raise ValueError("each performance record must be an object")
        values = {
            key: _required_string(record, key)
            for key in ("cpu_id", "gpu_id", "game_id", "resolution", "source_url")
        }
        if values["resolution"] not in {"1080p", "2k", "4k"}:
            raise ValueError("resolution must be 1080p, 2k, or 4k")
        parsed_url = urlparse(values["source_url"])
        if parsed_url.scheme not in {"http", "https"} or not parsed_url.netloc:
            raise ValueError("source_url must be an absolute HTTP URL")

        minimum_fps = _required_int(record, "minimum_fps")
        average_fps = _required_int(record, "average_fps")
        maximum_fps = _required_int(record, "maximum_fps")
        if not 0 < minimum_fps <= average_fps <= maximum_fps <= 2000:
            raise ValueError("invalid FPS ordering or range")

        bottleneck_type = record.get("bottleneck_type")
        if bottleneck_type not in {None, "cpu", "gpu", "balanced"}:
            raise ValueError("invalid bottleneck_type")
        bottleneck_percent = record.get("bottleneck_percent")
        if bottleneck_percent is not None and (
            isinstance(bottleneck_percent, bool)
            or not isinstance(bottleneck_percent, int)
            or not 0 <= bottleneck_percent <= 100
        ):
            raise ValueError("invalid bottleneck_percent")

        combination = (
            values["cpu_id"],
            values["gpu_id"],
            values["game_id"],
            values["resolution"],
            quality,
        )
        if combination in combinations:
            raise ValueError("performance batch contains a duplicate combination")
        combinations.add(combination)
        estimates.append(
            PerformanceEstimateInput(
                **values,
                quality=quality,
                minimum_fps=minimum_fps,
                average_fps=average_fps,
                maximum_fps=maximum_fps,
                bottleneck_type=bottleneck_type,
                bottleneck_percent=bottleneck_percent,
                source_fetched_at=source_fetched_at,
                import_batch=import_batch,
            )
        )
    return estimates


def _aware_datetime(value) -> datetime:
    if not isinstance(value, str):
        raise ValueError("generated_at must be a timezone-aware datetime")
    try:
        parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError as error:
        raise ValueError("generated_at must be a timezone-aware datetime") from error
    if parsed.tzinfo is None or parsed.utcoffset() is None:
        raise ValueError("generated_at must be a timezone-aware datetime")
    return parsed


def _required_string(record: dict, key: str) -> str:
    value = record.get(key)
    if not isinstance(value, str) or not value.strip():
        raise ValueError(f"{key} must be a non-empty string")
    return value


def _required_int(record: dict, key: str) -> int:
    value = record.get(key)
    if isinstance(value, bool) or not isinstance(value, int):
        raise ValueError(f"{key} must be an integer")
    return value
