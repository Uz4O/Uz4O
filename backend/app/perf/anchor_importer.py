import json
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
from statistics import mean, median
from typing import Dict, List, Mapping, Set
from urllib.parse import urlparse

from app.perf.profiles import (
    APPROVED_GAME_PROFILES,
    GPUCapabilities,
    render_mode_for,
)


SOURCE_KINDS = {
    "self_measured",
    "licensed",
    "open_license",
    "public_reference",
}
RESOLUTIONS = {"1080p", "2k", "4k"}
FORBIDDEN_ANCHOR_FIELDS = {
    "quality",
    "ray_tracing",
    "minimum_fps",
    "maximum_fps",
    "confidence",
}


@dataclass(frozen=True)
class HardwarePerformanceProfileInput:
    component_id: str
    category: str
    performance_score: int
    is_common: bool
    supports_dlss: bool
    supports_fsr: bool
    supports_standard_frame_generation: bool
    source_kind: str
    source_reference: str
    reviewed_at: datetime
    import_batch: str


@dataclass(frozen=True)
class GamePerformanceAnchorInput:
    game_id: str
    axis: str
    cpu_id: str
    gpu_id: str
    resolution: str
    render_mode: str
    average_fps: int
    sample_role: str
    game_version: str
    driver_version: str
    source_kind: str
    source_reference: str
    tested_at: datetime
    import_batch: str


@dataclass(frozen=True)
class ReviewedFPSBundle:
    hardware_profiles: List[HardwarePerformanceProfileInput]
    anchors: List[GamePerformanceAnchorInput]


def read_reviewed_fps_bundle(
    path: Path,
    known_cpu_ids: Set[str],
    known_gpu_ids: Set[str],
) -> ReviewedFPSBundle:
    document = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(document, dict):
        raise ValueError("reviewed FPS input must be a JSON object")
    import_batch = _required_text(document, "import_batch")
    _validate_test_conditions(document.get("test_conditions"))
    hardware_profiles = _parse_hardware_profiles(
        document.get("hardware_profiles"),
        import_batch,
        known_cpu_ids,
        known_gpu_ids,
    )
    profiles_by_id = {item.component_id: item for item in hardware_profiles}
    anchors = _parse_anchors(
        document.get("records"),
        import_batch,
        profiles_by_id,
        known_cpu_ids,
        known_gpu_ids,
    )
    return ReviewedFPSBundle(hardware_profiles, anchors)


def _validate_test_conditions(conditions) -> None:
    if not isinstance(conditions, dict) or conditions != {
        "quality": "high",
        "ray_tracing": False,
    }:
        raise ValueError(
            "test conditions must use high quality with ray tracing disabled"
        )


def _parse_hardware_profiles(
    raw_profiles,
    import_batch: str,
    known_cpu_ids: Set[str],
    known_gpu_ids: Set[str],
) -> List[HardwarePerformanceProfileInput]:
    if not isinstance(raw_profiles, list):
        raise ValueError("hardware_profiles must be a list")
    profiles = []
    seen_ids = set()
    for row in raw_profiles:
        if not isinstance(row, dict):
            raise ValueError("hardware profile must be an object")
        component_id = _required_text(row, "component_id")
        if component_id in seen_ids:
            raise ValueError(f"duplicate hardware profile: {component_id}")
        seen_ids.add(component_id)

        if component_id in known_cpu_ids:
            expected_category = "cpu"
        elif component_id in known_gpu_ids:
            expected_category = "gpu"
        else:
            raise ValueError(f"unknown hardware: {component_id}")
        category = _required_text(row, "category")
        if category != expected_category:
            raise ValueError(
                f"category for {component_id} must be {expected_category}"
            )

        performance_score = _positive_int(
            row.get("performance_score"),
            "performance score",
        )
        is_common = _required_bool(row, "is_common")
        supports_dlss = _required_bool(row, "supports_dlss")
        supports_fsr = _required_bool(row, "supports_fsr")
        supports_fg = _required_bool(
            row,
            "supports_standard_frame_generation",
        )
        if category == "cpu" and any(
            (supports_dlss, supports_fsr, supports_fg)
        ):
            raise ValueError("CPU capabilities must all be false")

        source_kind = _source_kind(row)
        source_reference = _required_text(row, "source_reference", "source reference")
        if source_kind == "public_reference":
            _http_url(source_reference)
        reviewed_at = _aware_datetime(row.get("reviewed_at"), "reviewed_at")
        profiles.append(
            HardwarePerformanceProfileInput(
                component_id=component_id,
                category=category,
                performance_score=performance_score,
                is_common=is_common,
                supports_dlss=supports_dlss,
                supports_fsr=supports_fsr,
                supports_standard_frame_generation=supports_fg,
                source_kind=source_kind,
                source_reference=source_reference,
                reviewed_at=reviewed_at,
                import_batch=import_batch,
            )
        )
    return profiles


def _parse_anchors(
    raw_anchors,
    import_batch: str,
    profiles_by_id: Mapping[str, HardwarePerformanceProfileInput],
    known_cpu_ids: Set[str],
    known_gpu_ids: Set[str],
) -> List[GamePerformanceAnchorInput]:
    if not isinstance(raw_anchors, list):
        raise ValueError("records must be a list")
    anchors = []
    seen_keys = set()
    for row in raw_anchors:
        if not isinstance(row, dict):
            raise ValueError("FPS anchor must be an object")
        forbidden = FORBIDDEN_ANCHOR_FIELDS.intersection(row)
        if forbidden:
            raise ValueError(
                "unsupported fields: " + ", ".join(sorted(forbidden))
            )

        game_id = _required_text(row, "game_id")
        if game_id not in APPROVED_GAME_PROFILES:
            raise ValueError(f"unknown game: {game_id}")
        cpu_id = _required_text(row, "cpu_id")
        if cpu_id not in known_cpu_ids:
            raise ValueError(f"unknown CPU: {cpu_id}")
        gpu_id = _required_text(row, "gpu_id")
        if gpu_id not in known_gpu_ids:
            raise ValueError(f"unknown GPU: {gpu_id}")
        if cpu_id not in profiles_by_id or gpu_id not in profiles_by_id:
            raise ValueError("every anchor needs reviewed CPU and GPU profiles")

        sample_role = _required_text(row, "sample_role")
        axis = _required_text(row, "axis")
        if sample_role == "fit" and axis not in {"cpu", "gpu"}:
            raise ValueError("fit axis must be cpu or gpu")
        if sample_role == "validation" and axis != "cross":
            raise ValueError("validation axis must be cross")
        if sample_role not in {"fit", "validation"}:
            raise ValueError("sample role must be fit or validation")

        resolution = _required_text(row, "resolution")
        if resolution not in RESOLUTIONS:
            raise ValueError(f"unsupported resolution: {resolution}")
        fps_cap = APPROVED_GAME_PROFILES[game_id].fps_cap
        source_kind = _source_kind(row)
        public_sources = None
        if source_kind == "public_reference":
            if "average_fps" in row or "source_reference" in row:
                raise ValueError(
                    "public reference FPS is derived from its sources"
                )
            average_fps, public_sources = _public_reference_sources(
                row.get("sources"),
                fps_cap,
                game_id,
                axis,
                cpu_id,
                gpu_id,
                resolution,
                known_cpu_ids,
                known_gpu_ids,
            )
        else:
            average_fps = _validated_fps(
                row.get("average_fps"),
                fps_cap,
                game_id,
            )

        gpu = profiles_by_id[gpu_id]
        expected_mode = render_mode_for(
            APPROVED_GAME_PROFILES[game_id],
            GPUCapabilities(
                gpu.supports_dlss,
                gpu.supports_fsr,
                gpu.supports_standard_frame_generation,
            ),
        ).value
        render_mode = _required_text(row, "render_mode")
        if render_mode != expected_mode:
            raise ValueError(
                f"render mode for {game_id}/{gpu_id} must be {expected_mode}"
            )

        game_version = _required_text(row, "game_version")
        driver_version = _required_text(row, "driver_version")
        if public_sources is None:
            source_reference = _required_text(
                row,
                "source_reference",
                "source reference",
            )
        else:
            source_reference = json.dumps(
                {
                    "test_conditions": {
                        "cpu_id": cpu_id,
                        "game_id": game_id,
                        "gpu_id": gpu_id,
                        "quality": "high",
                        "ray_tracing": False,
                        "render_mode": render_mode,
                        "resolution": resolution,
                    },
                    "sources": public_sources,
                },
                ensure_ascii=False,
                separators=(",", ":"),
                sort_keys=True,
            )
        tested_at = _aware_datetime(row.get("tested_at"), "tested_at")
        key = (
            game_id,
            axis,
            cpu_id,
            gpu_id,
            resolution,
            render_mode,
            sample_role,
            game_version,
            driver_version,
        )
        if key in seen_keys:
            raise ValueError(f"duplicate FPS anchor: {key}")
        seen_keys.add(key)
        anchors.append(
            GamePerformanceAnchorInput(
                game_id=game_id,
                axis=axis,
                cpu_id=cpu_id,
                gpu_id=gpu_id,
                resolution=resolution,
                render_mode=render_mode,
                average_fps=average_fps,
                sample_role=sample_role,
                game_version=game_version,
                driver_version=driver_version,
                source_kind=source_kind,
                source_reference=source_reference,
                tested_at=tested_at,
                import_batch=import_batch,
            )
        )
    return anchors


def _required_text(
    row: Mapping,
    key: str,
    label: str = "",
) -> str:
    value = row.get(key)
    if not isinstance(value, str) or not value.strip():
        raise ValueError(f"{label or key} is required")
    return value.strip()


def _source_kind(row: Mapping) -> str:
    value = _required_text(row, "source_kind", "source kind")
    if value not in SOURCE_KINDS:
        raise ValueError(f"unsupported source kind: {value}")
    return value


def _public_reference_sources(
    raw_sources,
    fps_cap,
    game_id: str,
    axis: str,
    cpu_id: str,
    gpu_id: str,
    resolution: str,
    known_cpu_ids: Set[str],
    known_gpu_ids: Set[str],
):
    if not isinstance(raw_sources, list) or len(raw_sources) not in {2, 3}:
        raise ValueError("public reference needs 2 or 3 sources")
    sources = []
    publishers = set()
    urls = set()
    for row in raw_sources:
        if not isinstance(row, dict):
            raise ValueError("public reference source must be an object")
        publisher = _required_text(row, "publisher")
        publisher_key = publisher.casefold()
        if publisher_key in publishers:
            raise ValueError("public references need independent publishers")
        publishers.add(publisher_key)
        url = _http_url(_required_text(row, "url"))
        if url in urls:
            raise ValueError("public references need unique URLs")
        urls.add(url)
        published_at = _aware_datetime(
            row.get("published_at"),
            "published_at",
        )
        tested_cpu_id = row.get("cpu_id", cpu_id)
        tested_gpu_id = row.get("gpu_id", gpu_id)
        if tested_cpu_id not in known_cpu_ids:
            raise ValueError(f"unknown source CPU: {tested_cpu_id}")
        if tested_gpu_id not in known_gpu_ids:
            raise ValueError(f"unknown source GPU: {tested_gpu_id}")
        if axis == "gpu" and tested_gpu_id != gpu_id:
            raise ValueError("GPU-axis sources must test the anchor GPU")
        if axis == "cpu" and tested_cpu_id != cpu_id:
            raise ValueError("CPU-axis sources must test the anchor CPU")
        if axis == "cross" and (
            tested_cpu_id != cpu_id or tested_gpu_id != gpu_id
        ):
            raise ValueError("validation sources must test the anchor hardware")
        gpu_bottleneck_observed = None
        if axis == "cpu":
            gpu_bottleneck_observed = _required_bool(
                row,
                "gpu_bottleneck_observed",
            )
            if gpu_bottleneck_observed:
                raise ValueError("CPU-axis sources must not be GPU bottlenecked")
        average_fps, measurement_kind, samples = _public_source_average(
            row,
            fps_cap,
            game_id,
        )
        source = {
            "average_fps": average_fps,
            "cpu_id": tested_cpu_id,
            "gpu_id": tested_gpu_id,
            "measurement_kind": measurement_kind,
            "published_at": published_at.isoformat(),
            "publisher": publisher,
            "quality": _source_quality(row, axis),
            "resolution": _source_resolution(row, axis, resolution),
            "url": url,
        }
        if gpu_bottleneck_observed is not None:
            source["gpu_bottleneck_observed"] = gpu_bottleneck_observed
        if samples is not None:
            source["samples"] = samples
        sources.append(source)
    fps_values = [item["average_fps"] for item in sources]
    median_fps = median(fps_values)
    if (max(fps_values) - min(fps_values)) / median_fps > 0.15:
        raise ValueError("public reference FPS values differ by more than 15%")
    return int(median_fps + 0.5), sources


def _public_source_average(row: Mapping, fps_cap, game_id: str):
    has_average = "average_fps" in row
    has_samples = "samples" in row
    if has_average == has_samples:
        raise ValueError(
            "public source needs average_fps or realtime samples"
        )
    if has_average:
        return (
            _validated_fps(row.get("average_fps"), fps_cap, game_id),
            "published_average",
            None,
        )
    raw_samples = row.get("samples")
    if not isinstance(raw_samples, list) or not 1 <= len(raw_samples) <= 20:
        raise ValueError("realtime estimate needs 1 to 20 samples")
    samples = []
    timestamps = set()
    for sample in raw_samples:
        if not isinstance(sample, dict):
            raise ValueError("realtime sample must be an object")
        at_seconds = sample.get("at_seconds")
        if (
            isinstance(at_seconds, bool)
            or not isinstance(at_seconds, int)
            or at_seconds < 0
        ):
            raise ValueError("sample timestamp must be non-negative")
        if at_seconds in timestamps:
            raise ValueError("realtime sample timestamps must be unique")
        timestamps.add(at_seconds)
        samples.append(
            {
                "at_seconds": at_seconds,
                "fps": _validated_fps(
                    sample.get("fps"),
                    fps_cap,
                    game_id,
                ),
            }
        )
    sampled_average = int(mean(item["fps"] for item in samples) + 0.5)
    return sampled_average, "realtime_samples", samples


def _source_quality(row: Mapping, axis: str) -> str:
    quality = row.get("quality", "high")
    allowed = {"high", "ultra"}
    if axis == "cpu":
        allowed.add("unknown")
    if quality not in allowed:
        raise ValueError("unsupported public source quality")
    return quality


def _source_resolution(row: Mapping, axis: str, default: str) -> str:
    resolution = row.get("resolution", default)
    if resolution not in RESOLUTIONS and not (
        axis == "cpu" and resolution == "unknown"
    ):
        raise ValueError("unsupported public source resolution")
    return resolution


def _validated_fps(value, fps_cap, game_id: str) -> int:
    average_fps = _positive_int(value, "average FPS")
    if average_fps > 2000:
        raise ValueError("average FPS must be at most 2000")
    if fps_cap is not None and average_fps > fps_cap:
        raise ValueError(f"average FPS exceeds {game_id} FPS cap")
    return average_fps


def _http_url(value: str) -> str:
    parsed = urlparse(value)
    if parsed.scheme not in {"http", "https"} or not parsed.netloc:
        raise ValueError("public reference must use an HTTP URL")
    return value


def _required_bool(row: Mapping, key: str) -> bool:
    value = row.get(key)
    if not isinstance(value, bool):
        raise ValueError(f"{key} must be a boolean")
    return value


def _positive_int(value, label: str) -> int:
    if isinstance(value, bool) or not isinstance(value, int) or value <= 0:
        raise ValueError(f"{label} must be a positive integer")
    return value


def _aware_datetime(value, label: str) -> datetime:
    if not isinstance(value, str):
        raise ValueError(f"{label} must be an ISO timestamp")
    try:
        parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError as error:
        raise ValueError(f"{label} must be an ISO timestamp") from error
    if parsed.tzinfo is None or parsed.utcoffset() is None:
        raise ValueError(f"{label} timezone is required")
    return parsed
