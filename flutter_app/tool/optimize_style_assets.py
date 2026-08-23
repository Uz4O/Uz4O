#!/usr/bin/env python3
"""Shrink the local style and Explorer assets without changing their paths' stems.

The app displays the style artwork at phone-sized dimensions, so the source
artwork is capped at 1024 px and encoded as WebP. Explorer artwork is already
cropped to at most 640 px by ``generate_explorer_assets.py``; it is only
re-encoded here.
"""

from __future__ import annotations

from io import BytesIO
from pathlib import Path

from PIL import Image


WEBP_QUALITY = 90
WEBP_METHOD = 4
STYLE_MAX_SIDE = 1024
EXPLORER_MAX_SIDE = 640


def optimized_bytes(source: Path, max_side: int) -> tuple[bytes, tuple[int, int]]:
    with Image.open(source) as original:
        mode = "RGBA" if "A" in original.getbands() else "RGB"
        image = original.convert(mode)
        if max(image.size) > max_side:
            scale = max_side / max(image.size)
            target_size = tuple(
                max(1, round(side * scale)) for side in image.size
            )
            image = image.resize(target_size, Image.Resampling.LANCZOS)

        output = BytesIO()
        image.save(
            output,
            format="WEBP",
            quality=WEBP_QUALITY,
            method=WEBP_METHOD,
        )
        return output.getvalue(), image.size


def optimize_directory(
    directory: Path, patterns: tuple[str, ...], max_side: int
) -> tuple[int, int, int]:
    sources = sorted(
        {
            path
            for pattern in patterns
            for path in directory.glob(pattern)
            if path.is_file()
        }
    )
    staged: list[tuple[Path, Path, int, tuple[int, int]]] = []
    source_bytes = 0
    output_bytes = 0

    for source in sources:
        destination = source.with_suffix(".webp")
        payload, size = optimized_bytes(source, max_side)
        destination.write_bytes(payload)
        staged.append((source, destination, len(payload), size))
        source_bytes += source.stat().st_size
        output_bytes += len(payload)

    for source, destination, _, expected_size in staged:
        with Image.open(destination) as generated:
            if generated.size != expected_size:
                raise RuntimeError(
                    f"unexpected dimensions for {destination}: {generated.size}"
                )
        source.unlink()

    return len(staged), source_bytes, output_bytes


def main() -> None:
    flutter_root = Path(__file__).resolve().parents[1]
    images_dir = flutter_root / "assets" / "images"

    style_count, style_before, style_after = optimize_directory(
        images_dir,
        ("style_*.png", "style_*.jpg", "style_*.jpeg"),
        STYLE_MAX_SIDE,
    )
    explorer_count, explorer_before, explorer_after = optimize_directory(
        images_dir / "explorer", ("*.png",), EXPLORER_MAX_SIDE
    )

    print(
        f"Optimized {style_count} style assets: "
        f"{style_before / 1048576:.2f} MiB -> {style_after / 1048576:.2f} MiB"
    )
    print(
        f"Optimized {explorer_count} Explorer assets: "
        f"{explorer_before / 1048576:.2f} MiB -> {explorer_after / 1048576:.2f} MiB"
    )


if __name__ == "__main__":
    main()
