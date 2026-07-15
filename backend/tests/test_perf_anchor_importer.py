import copy
import json

import pytest

from app.perf.anchor_importer import read_reviewed_fps_bundle


CPU_IDS = {"r7-9800x3d", "i5-13600k"}
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


def public_reference_document() -> dict:
    document = valid_document()
    document["records"][0].pop("average_fps")
    document["records"][0].pop("source_reference")
    document["records"][0].update(
        source_kind="public_reference",
        sources=[
            {
                "publisher": "独立频道 A",
                "url": "https://www.youtube.com/watch?v=source-a",
                "published_at": "2026-07-01T00:00:00Z",
                "average_fps": 100,
            },
            {
                "publisher": "独立频道 B",
                "url": "https://www.bilibili.com/video/BV1sourceB",
                "published_at": "2026-07-02T00:00:00+08:00",
                "cpu_id": "i5-13600k",
                "average_fps": 109,
            },
        ],
    )
    return document


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


def test_public_references_use_rounded_median_and_preserve_sources(tmp_path) -> None:
    bundle = read_reviewed_fps_bundle(
        write_document(tmp_path, public_reference_document()),
        CPU_IDS,
        GPU_IDS,
    )

    anchor = bundle.anchors[0]
    assert anchor.average_fps == 105
    reference = json.loads(anchor.source_reference)
    assert reference["test_conditions"] == {
        "cpu_id": "r7-9800x3d",
        "game_id": "cyberpunk-2077",
        "gpu_id": "rtx-4070",
        "quality": "high",
        "ray_tracing": False,
        "render_mode": "dlss_quality_fg",
        "resolution": "2k",
    }
    assert [item["publisher"] for item in reference["sources"]] == [
        "独立频道 A",
        "独立频道 B",
    ]
    assert reference["sources"][1]["cpu_id"] == "i5-13600k"


def test_public_reference_can_estimate_average_from_realtime_samples(
    tmp_path,
) -> None:
    document = public_reference_document()
    source = document["records"][0]["sources"][0]
    source.pop("average_fps")
    source["samples"] = [
        {"at_seconds": 20, "fps": 95},
        {"at_seconds": 40, "fps": 100},
        {"at_seconds": 60, "fps": 105},
        {"at_seconds": 80, "fps": 110},
        {"at_seconds": 100, "fps": 115},
    ]

    bundle = read_reviewed_fps_bundle(
        write_document(tmp_path, document),
        CPU_IDS,
        GPU_IDS,
    )

    assert bundle.anchors[0].average_fps == 107
    sources = json.loads(bundle.anchors[0].source_reference)["sources"]
    assert sources[0]["measurement_kind"] == "realtime_samples"
    assert sources[0]["average_fps"] == 105
    assert sources[0]["samples"] == source["samples"]


@pytest.mark.parametrize(
    ("change", "message"),
    [
        (lambda sources: sources.pop(), "2 or 3"),
        (
            lambda sources: sources[1].update(publisher="独立频道 A"),
            "independent publishers",
        ),
        (
            lambda sources: sources[1].update(url="not-a-url"),
            "HTTP URL",
        ),
        (
            lambda sources: sources[1].update(average_fps=130),
            "differ by more than 15%",
        ),
    ],
)
def test_rejects_unusable_public_reference_groups(
    tmp_path,
    change,
    message,
) -> None:
    document = public_reference_document()
    change(document["records"][0]["sources"])

    with pytest.raises(ValueError, match=message):
        read_reviewed_fps_bundle(
            write_document(tmp_path, document),
            CPU_IDS,
            GPU_IDS,
        )


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
