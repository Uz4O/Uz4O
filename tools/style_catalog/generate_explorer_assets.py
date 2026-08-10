#!/usr/bin/env python3
"""Generate immersive-explorer thumbnails, bounds metadata, and topology texture."""

from __future__ import annotations

import json
import math
from pathlib import Path

import cv2
import numpy as np


ROOT = Path(__file__).resolve().parents[2]
ASSETS = ROOT / "May/May/Assets.xcassets"
CATALOG = ROOT / "May/May/Models/AestheticExplorerAssetCatalog.swift"
THUMBNAIL_MAX_DIMENSION = 640


def assigned_image(imageset: Path) -> Path:
    contents = json.loads((imageset / "Contents.json").read_text(encoding="utf-8"))
    filename = next(
        image["filename"] for image in contents["images"] if image.get("filename")
    )
    return imageset / filename


def normalized_bounds(image: np.ndarray) -> tuple[float, float, float, float]:
    alpha = image[:, :, 3]
    points = cv2.findNonZero((alpha > 8).astype(np.uint8))
    if points is None:
        return 0, 0, 1, 1
    x, y, width, height = cv2.boundingRect(points)
    image_height, image_width = alpha.shape
    return (
        x / image_width,
        y / image_height,
        width / image_width,
        height / image_height,
    )


def thumbnail(source: Path) -> np.ndarray:
    image = cv2.imread(str(source), cv2.IMREAD_UNCHANGED)
    if image is None:
        raise ValueError(f"无法读取图片: {source}")
    if image.ndim == 2:
        image = cv2.cvtColor(image, cv2.COLOR_GRAY2BGRA)
    elif image.shape[2] == 3:
        image = cv2.cvtColor(image, cv2.COLOR_BGR2BGRA)

    height, width = image.shape[:2]
    scale = min(1, THUMBNAIL_MAX_DIMENSION / max(width, height))
    if scale < 1:
        image = cv2.resize(
            image,
            (max(1, round(width * scale)), max(1, round(height * scale))),
            interpolation=cv2.INTER_AREA,
        )
    return image


def generate_thumbnails() -> tuple[dict[str, str], dict[str, tuple[float, ...]]]:
    mappings: dict[str, str] = {}
    bounds: dict[str, tuple[float, ...]] = {}
    imagesets = sorted(
        path
        for path in ASSETS.glob("Style*.imageset")
        if path.stem.endswith(("Black", "White"))
    )

    for imageset in imagesets:
        original_name = imageset.stem
        explorer_name = f"{original_name}Explorer"
        output_dir = ASSETS / f"{explorer_name}.imageset"
        output_dir.mkdir(parents=True, exist_ok=True)
        output = output_dir / "explorer.png"
        image = thumbnail(assigned_image(imageset))
        if not cv2.imwrite(str(output), image):
            raise ValueError(f"无法写入图片: {output}")
        contents = {
            "images": [
                {"filename": output.name, "idiom": "universal", "scale": "1x"}
            ],
            "info": {"author": "xcode", "version": 1},
        }
        (output_dir / "Contents.json").write_text(
            json.dumps(contents, ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
        )
        visible_bounds = normalized_bounds(image)
        mappings[original_name] = explorer_name
        bounds[original_name] = visible_bounds
        bounds[explorer_name] = visible_bounds

    return mappings, bounds


def crossing(
    start: tuple[float, float],
    start_value: float,
    end: tuple[float, float],
    end_value: float,
    level: float,
) -> tuple[int, int] | None:
    start_delta = start_value - level
    end_delta = end_value - level
    if not ((start_delta < 0 <= end_delta) or (start_delta >= 0 > end_delta)):
        return None
    denominator = start_delta - end_delta
    if abs(denominator) <= np.finfo(float).eps:
        return round(start[0]), round(start[1])
    progress = start_delta / denominator
    return (
        round(start[0] + (end[0] - start[0]) * progress),
        round(start[1] + (end[1] - start[1]) * progress),
    )


def generate_topology_texture() -> None:
    columns, rows = 40, 86
    width, height = 880, 1640
    levels = (-0.62, -0.34, -0.06, 0.22, 0.50)
    values = np.zeros((rows + 1, columns + 1), dtype=np.float64)
    turn = math.pi * 2
    for row in range(rows + 1):
        y = row / rows
        for column in range(columns + 1):
            x = column / columns
            broad = math.sin(turn * (2 * x + math.sin(turn * y) * 0.28))
            detail = math.cos(turn * (3 * y - math.sin(turn * x) * 0.18))
            diagonal = math.sin(turn * (x + y))
            values[row, column] = broad * 0.58 + detail * 0.27 + diagonal * 0.15

    texture = np.zeros((height, width, 4), dtype=np.uint8)
    cell_width, cell_height = width / columns, height / rows
    color = (148, 148, 148, 26)
    for level in levels:
        for row in range(rows):
            for column in range(columns):
                left = column * cell_width
                top = row * cell_height
                right = left + cell_width
                bottom = top + cell_height
                top_left = (left, top)
                top_right = (right, top)
                bottom_right = (right, bottom)
                bottom_left = (left, bottom)
                points = [
                    crossing(top_left, values[row, column], top_right, values[row, column + 1], level),
                    crossing(top_right, values[row, column + 1], bottom_right, values[row + 1, column + 1], level),
                    crossing(bottom_right, values[row + 1, column + 1], bottom_left, values[row + 1, column], level),
                    crossing(bottom_left, values[row + 1, column], top_left, values[row, column], level),
                ]
                points = [point for point in points if point is not None]
                pairs = (points[:2], points[2:4]) if len(points) == 4 else (points[:2],)
                for pair in pairs:
                    if len(pair) == 2:
                        cv2.line(texture, pair[0], pair[1], color, 3, cv2.LINE_AA)

    output_dir = ASSETS / "TopologyContourTexture.imageset"
    output_dir.mkdir(parents=True, exist_ok=True)
    output = output_dir / "topology-contour-texture@2x.png"
    if not cv2.imwrite(str(output), texture):
        raise ValueError(f"无法写入图片: {output}")
    contents = {
        "images": [
            {"idiom": "universal", "scale": "1x"},
            {"filename": output.name, "idiom": "universal", "scale": "2x"},
            {"idiom": "universal", "scale": "3x"},
        ],
        "info": {"author": "xcode", "version": 1},
    }
    (output_dir / "Contents.json").write_text(
        json.dumps(contents, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )


def render_catalog(
    mappings: dict[str, str], bounds: dict[str, tuple[float, ...]]
) -> str:
    mapping_lines = [
        f'        "{source}": "{target}"'
        for source, target in sorted(mappings.items())
    ]
    bounds_lines = []
    for name, (x, y, width, height) in sorted(bounds.items()):
        bounds_lines.append(
            f'        "{name}": CGRect(x: {x:.8f}, y: {y:.8f}, '
            f'width: {width:.8f}, height: {height:.8f})'
        )
    return """// Generated by tools/style_catalog/generate_explorer_assets.py. Do not edit manually.

import CoreGraphics

enum AestheticExplorerAssetCatalog {
    static func imageName(for originalName: String) -> String {
        thumbnailNames[originalName] ?? originalName
    }

    static func visibleBounds(for imageName: String) -> CGRect? {
        visibleBounds[imageName]
    }

    private static let thumbnailNames: [String: String] = [
""" + ",\n".join(mapping_lines) + """
    ]

    private static let visibleBounds: [String: CGRect] = [
""" + ",\n".join(bounds_lines) + """
    ]
}
"""


def main() -> None:
    mappings, bounds = generate_thumbnails()
    generate_topology_texture()
    CATALOG.write_text(render_catalog(mappings, bounds), encoding="utf-8")
    print(f"已生成 {len(mappings)} 张沉浸缩略图和等高线纹理")


if __name__ == "__main__":
    main()
