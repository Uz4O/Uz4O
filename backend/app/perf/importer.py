from dataclasses import dataclass
from datetime import datetime
import json
from pathlib import Path
from typing import List, Optional

from app.perf.collector_manifest import SourceMapping, load_manifest


DEFAULT_MANIFEST_PATH = (
    Path(__file__).resolve().parents[2] / "data/pc-builds-fps-mappings.json"
)


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


def read_performance_batch(
    path: Path,
    manifest_path: Path = DEFAULT_MANIFEST_PATH,
) -> List[PerformanceEstimateInput]:
    payload = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(payload, dict):
        raise ValueError("performance batch must be a JSON object")
    quality = payload.get("quality")
    if quality != "medium":
        raise ValueError("performance batch quality must be medium")
    _aware_datetime(payload.get("generated_at"), "generated_at")
    import_batch = payload.get("import_batch", path.stem)
    if not isinstance(import_batch, str) or not import_batch.strip():
        raise ValueError("import_batch must be a non-empty string")
    records = payload.get("records")
    if not isinstance(records, list):
        raise ValueError("records must be a list")
    manifest = load_manifest(manifest_path)
    mappings = (
        {item.app_id: item for item in manifest.cpus},
        {item.app_id: item for item in manifest.gpus},
        {item.app_id: item for item in manifest.games},
    )

    estimates = []
    combinations = set()
    resolution_groups = {}
    for record in records:
        if not isinstance(record, dict):
            raise ValueError("each performance record must be an object")
        values = {
            key: _required_string(record, key)
            for key in ("cpu_id", "gpu_id", "game_id", "resolution", "source_url")
        }
        if values["resolution"] not in {"1080p", "2k", "4k"}:
            raise ValueError("resolution must be 1080p, 2k, or 4k")
        source_ids = tuple(
            _required_string(record, key)
            for key in ("source_cpu_id", "source_gpu_id", "source_game_id")
        )
        source_mappings = tuple(
            _exact_mapping(section, app_id, source_id)
            for section, app_id, source_id in zip(
                mappings,
                (values["cpu_id"], values["gpu_id"], values["game_id"]),
                source_ids,
            )
        )
        expected_url = _source_url(*source_mappings)
        if values["source_url"] != expected_url:
            raise ValueError("source identity does not match reviewed manifest")

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
        source_fetched_at = _aware_datetime(
            record.get("source_fetched_at"),
            "source_fetched_at",
        )

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
        group = (
            values["cpu_id"],
            values["gpu_id"],
            values["game_id"],
            values["source_url"],
        )
        resolution_groups.setdefault(group, set()).add(values["resolution"])
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
    if any(
        resolutions != {"1080p", "2k", "4k"}
        for resolutions in resolution_groups.values()
    ):
        raise ValueError(
            "each performance source group must contain exactly 1080p, 2k, and 4k"
        )
    return estimates


def _aware_datetime(value, field: str) -> datetime:
    if not isinstance(value, str):
        raise ValueError(f"{field} must be a timezone-aware datetime")
    try:
        parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError as error:
        raise ValueError(f"{field} must be a timezone-aware datetime") from error
    if parsed.tzinfo is None or parsed.utcoffset() is None:
        raise ValueError(f"{field} must be a timezone-aware datetime")
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


def _exact_mapping(
    mappings: dict,
    app_id: str,
    source_id: str,
) -> SourceMapping:
    mapping = mappings.get(app_id)
    if (
        mapping is None
        or mapping.status != "exact"
        or mapping.source_id != source_id
        or not mapping.source_slug
    ):
        raise ValueError("source identity does not match reviewed manifest")
    return mapping


def _source_url(
    cpu: SourceMapping,
    gpu: SourceMapping,
    game: SourceMapping,
) -> str:
    return (
        "https://pc-builds.com/zh/fps-calculator/result/"
        f"{cpu.source_id}{gpu.source_id}{game.source_id}/"
        f"{cpu.source_slug}/{gpu.source_slug}/{game.source_slug}/1920x1080/"
    )
