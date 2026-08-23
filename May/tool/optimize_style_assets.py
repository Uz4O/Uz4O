#!/usr/bin/env python3
"""Shrink SwiftUI style assets while preserving Asset Catalog names.

Xcode Asset Catalogs do not accept WebP, so the native iOS equivalent uses
HEIC, which keeps the transparent background used by the style artwork.
Main artwork is capped at 1024 px and Explorer artwork at 640 px.
"""

from __future__ import annotations

import json
import os
import re
import shutil
import subprocess
import tempfile
from pathlib import Path

from PIL import Image


HEIC_QUALITY = 90
STYLE_MAX_SIDE = 1024
EXPLORER_MAX_SIDE = 640
SOURCE_EXTENSIONS = {".jpg", ".jpeg", ".png"}


def image_properties(path: Path) -> tuple[int, int, bool]:
    result = subprocess.run(
        ["sips", "-g", "pixelWidth", "-g", "pixelHeight", "-g", "hasAlpha", str(path)],
        check=True,
        capture_output=True,
        text=True,
    )
    width = re.search(r"pixelWidth: (\d+)", result.stdout)
    height = re.search(r"pixelHeight: (\d+)", result.stdout)
    alpha = re.search(r"hasAlpha: (yes|no)", result.stdout)
    if not width or not height or not alpha:
        raise RuntimeError(f"could not inspect image properties: {path}")
    return int(width.group(1)), int(height.group(1)), alpha.group(1) == "yes"


def has_transparent_pixels(path: Path) -> bool:
    with Image.open(path) as image:
        if "A" not in image.getbands():
            return False
        return image.getchannel("A").getextrema()[0] < 255


def referenced_source(imageset: Path) -> tuple[Path, Path, str]:
    contents = imageset / "Contents.json"
    contents_text = contents.read_text()
    data = json.loads(contents_text)
    filenames = [
        image["filename"]
        for image in data.get("images", [])
        if "filename" in image
    ]
    if len(filenames) != 1:
        raise RuntimeError(f"expected one referenced image in {imageset}, found {filenames}")

    source = imageset / filenames[0]
    if not source.is_file():
        raise RuntimeError(f"missing referenced image: {source}")
    return contents, source, contents_text


def main() -> None:
    ios_root = Path(__file__).resolve().parents[1]
    asset_root = ios_root / "May" / "Assets.xcassets"
    candidates: list[tuple[Path, Path, str, int]] = []

    for imageset in sorted(asset_root.glob("Style*.imageset")):
        contents, source, contents_text = referenced_source(imageset)
        if source.suffix.lower() == ".heic":
            continue
        if source.suffix.lower() not in SOURCE_EXTENSIONS:
            raise RuntimeError(f"unsupported source format: {source}")
        max_side = (
            EXPLORER_MAX_SIDE
            if imageset.name.endswith("Explorer.imageset")
            else STYLE_MAX_SIDE
        )
        candidates.append((contents, source, contents_text, max_side))

    if not candidates:
        print("All SwiftUI style assets are already optimized.")
        return

    source_bytes = sum(source.stat().st_size for _, source, _, _ in candidates)
    staged_assets: list[tuple[Path, Path, Path, str, int]] = []

    with tempfile.TemporaryDirectory(prefix="may-style-assets-") as temp_dir:
        staging_root = Path(temp_dir)
        for index, (contents, source, contents_text, max_side) in enumerate(candidates):
            staged = staging_root / f"{index:03d}.heic"
            subprocess.run(
                [
                    "sips",
                    "-Z",
                    str(max_side),
                    "-s",
                    "format",
                    "heic",
                    "-s",
                    "formatOptions",
                    str(HEIC_QUALITY),
                    str(source),
                    "--out",
                    str(staged),
                ],
                check=True,
                stdout=subprocess.DEVNULL,
            )

            source_width, source_height, _ = image_properties(source)
            width, height, output_alpha = image_properties(staged)
            if max(width, height) > max_side:
                raise RuntimeError(f"oversized generated image: {staged} ({width}x{height})")
            if has_transparent_pixels(source) and not output_alpha:
                raise RuntimeError(f"alpha channel was lost while converting {source}")
            if source_width / source_height != width / height:
                aspect_error = abs(source_width / source_height - width / height)
                if aspect_error > 0.002:
                    raise RuntimeError(f"aspect ratio changed while converting {source}")

            destination = source.with_suffix(".heic")
            new_contents = contents_text.replace(source.name, destination.name)
            if new_contents == contents_text:
                raise RuntimeError(f"could not update filename in {contents}")
            staged_assets.append((staged, destination, source, new_contents, max_side))

        output_bytes = sum(staged.stat().st_size for staged, *_ in staged_assets)

        for staged, destination, source, new_contents, _ in staged_assets:
            contents = source.parent / "Contents.json"
            staged_contents = contents.with_suffix(".json.tmp")
            shutil.copyfile(staged, destination)
            staged_contents.write_text(new_contents)
            os.replace(staged_contents, contents)
            source.unlink()

    main_count = sum(limit == STYLE_MAX_SIDE for *_, limit in staged_assets)
    explorer_count = sum(limit == EXPLORER_MAX_SIDE for *_, limit in staged_assets)
    print(f"Optimized {main_count} main style assets and {explorer_count} Explorer assets.")
    print(f"Source size: {source_bytes / 1048576:.2f} MiB")
    print(f"HEIC size: {output_bytes / 1048576:.2f} MiB")


if __name__ == "__main__":
    main()
