import json
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Mapping, Set

from app.perf.profiles import (
    APPROVED_GAME_PROFILES,
    GPUCapabilities,
    render_mode_for,
)


SOURCE_KINDS = {"self_measured", "licensed", "open_license"}
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
        average_fps = _positive_int(row.get("average_fps"), "average FPS")
        if average_fps > 2000:
            raise ValueError("average FPS must be at most 2000")
        fps_cap = APPROVED_GAME_PROFILES[game_id].fps_cap
        if fps_cap is not None and average_fps > fps_cap:
            raise ValueError(f"average FPS exceeds {game_id} FPS cap")

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
        source_kind = _source_kind(row)
        source_reference = _required_text(row, "source_reference", "source reference")
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
