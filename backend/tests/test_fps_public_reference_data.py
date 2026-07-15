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
        {"i5-13600k", "r7-5800x3d", "r7-9800x3d"},
        {"rtx-4070", "rtx-4070-super", "rtx-4090-d"},
    )

    assert len(bundle.hardware_profiles) == 3
    assert len(bundle.anchors) == 2
    assert [anchor.average_fps for anchor in bundle.anchors] == [116, 546]
    assert all(
        anchor.source_kind == "public_reference" for anchor in bundle.anchors
    )
