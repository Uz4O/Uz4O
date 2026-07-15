import copy
import json

import pytest

from app.perf.anchor_importer import read_reviewed_fps_bundle


CPU_IDS = {"r7-9800x3d"}
GPU_IDS = {"rtx-4070"}


def valid_document() -> dict:
    return {
        "import_batch": "self-measured-20260715",
        "test_conditions": {
            "quality": "high",
            "ray_tracing": False,
        },
        "hardware_profiles": [
            {
                "component_id": "r7-9800x3d",
                "category": "cpu",
                "performance_score": 140,
                "is_common": True,
                "supports_dlss": False,
                "supports_fsr": False,
                "supports_standard_frame_generation": False,
                "source_kind": "self_measured",
                "source_reference": "lab-20260715",
                "reviewed_at": "2026-07-15T00:00:00Z",
            },
            {
                "component_id": "rtx-4070",
                "category": "gpu",
                "performance_score": 100,
                "is_common": True,
                "supports_dlss": True,
                "supports_fsr": True,
                "supports_standard_frame_generation": True,
                "source_kind": "self_measured",
                "source_reference": "lab-20260715",
                "reviewed_at": "2026-07-15T00:00:00Z",
            },
        ],
        "records": [
            {
                "game_id": "cyberpunk-2077",
                "axis": "gpu",
                "cpu_id": "r7-9800x3d",
                "gpu_id": "rtx-4070",
                "resolution": "2k",
                "render_mode": "dlss_quality_fg",
                "average_fps": 105,
                "sample_role": "fit",
                "game_version": "2.31",
                "driver_version": "reviewed",
                "source_kind": "self_measured",
                "source_reference": "lab-20260715",
                "tested_at": "2026-07-15T00:00:00Z",
            }
        ],
    }


def write_document(tmp_path, document: dict):
    path = tmp_path / "reviewed-fps.json"
    path.write_text(json.dumps(document), encoding="utf-8")
    return path


def test_reads_a_fully_reviewed_bundle(tmp_path) -> None:
    bundle = read_reviewed_fps_bundle(
        write_document(tmp_path, valid_document()),
        CPU_IDS,
        GPU_IDS,
    )

    assert [item.component_id for item in bundle.hardware_profiles] == [
        "r7-9800x3d",
        "rtx-4070",
    ]
    assert bundle.hardware_profiles[1].performance_score == 100
    assert bundle.hardware_profiles[1].reviewed_at.tzinfo is not None
    assert len(bundle.anchors) == 1
    assert bundle.anchors[0].render_mode == "dlss_quality_fg"
    assert bundle.anchors[0].import_batch == "self-measured-20260715"


@pytest.mark.parametrize(
    "conditions",
    [
        None,
        {"quality": "medium", "ray_tracing": False},
        {"quality": "high", "ray_tracing": True},
    ],
)
def test_requires_high_quality_with_ray_tracing_disabled(
    tmp_path,
    conditions,
) -> None:
    document = valid_document()
    if conditions is None:
        document.pop("test_conditions")
    else:
        document["test_conditions"] = conditions

    with pytest.raises(ValueError, match="high quality.*ray tracing disabled"):
        read_reviewed_fps_bundle(
            write_document(tmp_path, document),
            CPU_IDS,
            GPU_IDS,
        )


@pytest.mark.parametrize(
    ("section", "index", "overrides", "message"),
    [
        ("hardware_profiles", 1, {"component_id": "unknown"}, "unknown hardware"),
        ("hardware_profiles", 1, {"category": "cpu"}, "category"),
        ("hardware_profiles", 1, {"performance_score": 0}, "performance score"),
        ("hardware_profiles", 0, {"supports_dlss": True}, "CPU capabilities"),
        ("hardware_profiles", 1, {"source_kind": "unknown"}, "source kind"),
        ("hardware_profiles", 1, {"source_reference": ""}, "source reference"),
        (
            "hardware_profiles",
            1,
            {"reviewed_at": "2026-07-15T00:00:00"},
            "timezone",
        ),
        ("records", 0, {"game_id": "unknown"}, "unknown game"),
        ("records", 0, {"cpu_id": "unknown"}, "unknown CPU"),
        ("records", 0, {"gpu_id": "unknown"}, "unknown GPU"),
        ("records", 0, {"render_mode": "native"}, "render mode"),
        ("records", 0, {"average_fps": 0}, "average FPS"),
        ("records", 0, {"axis": "cross"}, "fit axis"),
        ("records", 0, {"source_kind": "unknown"}, "source kind"),
        ("records", 0, {"source_reference": ""}, "source reference"),
        ("records", 0, {"tested_at": "2026-07-15T00:00:00"}, "timezone"),
    ],
)
def test_rejects_invalid_reviewed_values(
    tmp_path,
    section,
    index,
    overrides,
    message,
) -> None:
    document = valid_document()
    document[section][index].update(overrides)

    with pytest.raises(ValueError, match=message):
        read_reviewed_fps_bundle(
            write_document(tmp_path, document),
            CPU_IDS,
            GPU_IDS,
        )


def test_rejects_anchor_above_the_games_fixed_fps_cap(tmp_path) -> None:
    document = valid_document()
    document["records"][0].update(
        game_id="elden-ring",
        render_mode="native",
        average_fps=61,
    )

    with pytest.raises(ValueError, match="FPS cap"):
        read_reviewed_fps_bundle(
            write_document(tmp_path, document),
            CPU_IDS,
            GPU_IDS,
        )


@pytest.mark.parametrize(
    "forbidden_field",
    ["quality", "ray_tracing", "minimum_fps", "maximum_fps", "confidence"],
)
def test_rejects_fields_outside_the_fixed_average_only_conditions(
    tmp_path,
    forbidden_field,
) -> None:
    document = valid_document()
    document["records"][0][forbidden_field] = "not-allowed"

    with pytest.raises(ValueError, match="unsupported fields"):
        read_reviewed_fps_bundle(
            write_document(tmp_path, document),
            CPU_IDS,
            GPU_IDS,
        )


@pytest.mark.parametrize("duplicate_section", ["hardware_profiles", "records"])
def test_rejects_duplicate_keys(tmp_path, duplicate_section) -> None:
    document = valid_document()
    document[duplicate_section].append(
        copy.deepcopy(document[duplicate_section][0])
    )

    with pytest.raises(ValueError, match="duplicate"):
        read_reviewed_fps_bundle(
            write_document(tmp_path, document),
            CPU_IDS,
            GPU_IDS,
        )
