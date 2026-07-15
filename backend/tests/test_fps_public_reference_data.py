from pathlib import Path

from app.perf.anchor_importer import read_reviewed_fps_bundle


DATA_PATH = (
    Path(__file__).resolve().parents[1]
    / "data"
    / "fps-public-reference-2026-07-15.json"
)


def test_bundled_public_reference_batch_is_reviewable() -> None:
    bundle = read_reviewed_fps_bundle(
        DATA_PATH,
        {"i5-13600k", "r7-5800x3d"},
        {"rtx-4070"},
    )

    assert len(bundle.hardware_profiles) == 2
    assert len(bundle.anchors) == 1
    assert bundle.anchors[0].average_fps == 116
    assert bundle.anchors[0].source_kind == "public_reference"
