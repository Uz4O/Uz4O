#!/usr/bin/env python3
"""Batch-cutout images and generate style-page catalog entries."""

from __future__ import annotations

import argparse
import json
import os
import re
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

import cv2
import numpy as np


ROOT = Path(__file__).resolve().parents[2]
DEFAULT_ASSETS = ROOT / "May/May/Assets.xcassets"
DEFAULT_CATALOG = ROOT / "May/May/Models/AestheticGeneratedCatalog.swift"
DEFAULT_REGISTRY = ROOT / "tools/style_catalog/schemes.json"


def swift(value: object) -> str:
    return json.dumps(value, ensure_ascii=False)


def slug(value: str) -> str:
    return re.sub(r"[^a-z0-9]+", "-", value.lower()).strip("-")


def pascal(value: str) -> str:
    words = re.findall(r"[A-Z]?[a-z]+|[A-Z]+(?![a-z])|\d+", value)
    return "".join(word[:1].upper() + word[1:] for word in words) or "Style"


def cutout(source: Path, target: Path, iterations: int) -> None:
    image = cv2.imread(str(source), cv2.IMREAD_COLOR)
    if image is None:
        raise ValueError(f"无法读取图片: {source}")

    height, width = image.shape[:2]
    margin = max(8, round(min(width, height) * 0.03))
    rectangle = (margin, margin, width - margin * 2, height - margin * 2)
    mask = np.zeros((height, width), np.uint8)
    background_model = np.zeros((1, 65), np.float64)
    foreground_model = np.zeros((1, 65), np.float64)

    cv2.grabCut(
        image,
        mask,
        rectangle,
        background_model,
        foreground_model,
        iterations,
        cv2.GC_INIT_WITH_RECT,
    )

    foreground = np.where(
        (mask == cv2.GC_FGD) | (mask == cv2.GC_PR_FGD), 255, 0
    ).astype(np.uint8)
    alpha = cv2.GaussianBlur(foreground, (3, 3), 0)
    result = cv2.cvtColor(image, cv2.COLOR_BGR2BGRA)
    result[:, :, 3] = alpha

    target.parent.mkdir(parents=True, exist_ok=True)
    if not cv2.imwrite(str(target), result):
        raise ValueError(f"无法写入图片: {target}")


def asset_name(style_id: str, color: str) -> str:
    return f"Style{pascal(style_id)}{color.capitalize()}"


def make_asset(scheme: dict, color: str, assets_root: Path, iterations: int) -> str:
    name = asset_name(scheme["id"], color)
    image_path = assets_root / f"{name}.imageset" / f"{slug(scheme['id'])}-{color}.png"
    source = Path(scheme["images"][color]).expanduser()
    cutout(source if source.is_absolute() else ROOT / source, image_path, iterations)
    contents = {
        "images": [
            {"filename": image_path.name, "idiom": "universal", "scale": "1x"}
        ],
        "info": {"author": "xcode", "version": 1},
    }
    (image_path.parent / "Contents.json").write_text(
        json.dumps(contents, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    return name


def load_schemes(path: Path) -> list[dict]:
    if not path.exists():
        return []
    data = json.loads(path.read_text(encoding="utf-8"))
    return data["schemes"] if isinstance(data, dict) else data


def part_lines(scheme: dict) -> list[str]:
    prefix = slug(scheme["id"])
    lines = []
    for part in scheme["parts"]:
        alternatives = [
            f"alternative({swift(item['name'])}, {item['price']}, {swift(item.get('detail', '平替选项'))})"
            for item in part.get("alternatives", [])
        ]
        lines.append(
            f"        part({swift(prefix)}, {swift(part['name'])}, {swift(part['detail'])}, "
            f"{part['price']}, [{', '.join(alternatives)}]),"
        )
    if lines:
        lines[-1] = lines[-1].rstrip(",")
    return lines


def style_lines(scheme: dict, images: dict[str, str]) -> list[str]:
    total = sum(part["price"] for part in scheme["parts"])
    cost = f"AestheticPriceRange(low: {total}, high: {total})"
    zero = "AestheticPriceRange(low: 0, high: 0)"
    title = scheme["title"]
    summary = scheme.get("summary", f"{title}组成的展示方案")
    tags = scheme.get("tags", ["展示方案"])
    signature = scheme.get("signature", f"保留{title}机箱和基础风扇布局")
    high_detail = scheme.get("highDetail", f"保留{title}的主要散热与灯效配件")
    complete_detail = scheme.get("completeDetail", f"完整保留{title}方案配件")

    return [
        "        style(",
        f"            id: {swift(scheme['id'])},",
        f"            title: {swift(title)},",
        f"            summary: {swift(summary)},",
        f"            image: {swift(images['black'])},",
        f"            tags: {swift(tags)},",
        f"            signature: {swift(signature)},",
        f"            highDetail: {swift(high_detail)},",
        f"            completeDetail: {swift(complete_detail)},",
        f"            costs: [{cost}, {cost}, {cost}],",
        f"            premiums: [{zero}, {zero}, {zero}]",
        "        )",
    ]


def render_catalog(schemes: list[dict], images: dict[str, dict[str, str]]) -> str:
    styles: list[str] = []
    parts: list[str] = []
    image_entries: list[str] = []

    for index, scheme in enumerate(schemes):
        styles.extend(style_lines(scheme, images[scheme["id"]]))
        if index < len(schemes) - 1:
            styles[-1] += ","
        parts.append(f'        {swift(scheme["id"])}: [')
        parts.extend(part_lines(scheme))
        parts.append("        ]")
        if index < len(schemes) - 1:
            parts[-1] += ","
        image_entries.append(
            f'        {swift(scheme["id"])}: (black: {swift(images[scheme["id"]]["black"])}, '
            f'white: {swift(images[scheme["id"]]["white"])})'
        )

    return """// Generated by tools/style_catalog/add_style_schemes.py. Do not edit manually.\n\nimport Foundation\n\nenum AestheticGeneratedCatalog {\n    static let styles: [AestheticBuildStyle] = [\n""" + "\n".join(styles) + """\n    ]\n\n    private static let imageNames: [String: (black: String, white: String)] = [\n""" + ",\n".join(image_entries) + """\n    ]\n\n    private static let partsByStyleID: [String: [AestheticStylePart]] = [\n""" + "\n".join(parts) + """\n    ]\n\n    static func image(for styleID: String, color: AestheticStyleColor) -> String? {\n        guard let names = imageNames[styleID] else { return nil }\n        return color == .black ? names.black : names.white\n    }\n\n    static func parts(for styleID: String) -> [AestheticStylePart]? {\n        partsByStyleID[styleID]\n    }\n\n    private static func style(\n        id: String,\n        title: String,\n        summary: String,\n        image: String,\n        tags: [String],\n        signature: String,\n        highDetail: String,\n        completeDetail: String,\n        costs: [AestheticPriceRange],\n        premiums: [AestheticPriceRange]\n    ) -> AestheticBuildStyle {\n        AestheticBuildStyle(\n            id: id,\n            title: title,\n            summary: summary,\n            image: image,\n            tags: tags,\n            options: [\n                AestheticRestorationOption(tier: .core, fidelity: 65, styleCost: costs[0], premium: premiums[0], keeps: signature, tradeoff: \"使用基础散热和必要风扇\"),\n                AestheticRestorationOption(tier: .high, fidelity: 85, styleCost: costs[1], premium: premiums[1], keeps: highDetail, tradeoff: \"不补满装饰风扇\"),\n                AestheticRestorationOption(tier: .complete, fidelity: 95, styleCost: costs[2], premium: premiums[2], keeps: completeDetail, tradeoff: \"保留同风格型号替代空间\")\n            ]\n        )\n    }\n\n    private static func part(\n        _ prefix: String,\n        _ name: String,\n        _ detail: String,\n        _ price: Int,\n        _ alternatives: [AestheticStyleAlternative]\n    ) -> AestheticStylePart {\n        AestheticStylePart(\n            id: \"\\(prefix)-\\(name)\",\n            name: name,\n            detail: detail,\n            price: price,\n            whitePrice: nil,\n            alternatives: alternatives\n        )\n    }\n\n    private static func alternative(_ name: String, _ price: Int, _ detail: String) -> AestheticStyleAlternative {\n        AestheticStyleAlternative(id: name, name: name, price: price, detail: detail)\n    }\n}\n"""


def main() -> None:
    parser = argparse.ArgumentParser(description="批量抠图并接入装机风格页")
    parser.add_argument("manifest", type=Path, help="方案 JSON 文件")
    parser.add_argument("--assets-root", type=Path, default=DEFAULT_ASSETS)
    parser.add_argument("--catalog", type=Path, default=DEFAULT_CATALOG)
    parser.add_argument("--registry", type=Path, default=DEFAULT_REGISTRY)
    parser.add_argument("--iterations", type=int, default=5)
    parser.add_argument("--jobs", type=int, default=min(8, os.cpu_count() or 1))
    args = parser.parse_args()

    data = json.loads(args.manifest.read_text(encoding="utf-8"))
    incoming = data["schemes"] if isinstance(data, dict) else data
    schemes_by_id = {scheme["id"]: scheme for scheme in load_schemes(args.registry)}
    schemes_by_id.update({scheme["id"]: scheme for scheme in incoming})
    schemes = list(schemes_by_id.values())
    ids = [scheme["id"] for scheme in schemes]
    if len(ids) != len(set(ids)):
        raise ValueError("方案 id 不能重复")

    def process(scheme: dict) -> tuple[str, dict[str, str]]:
        names = {
            color: make_asset(scheme, color, args.assets_root, args.iterations)
            for color in ("black", "white")
        }
        return scheme["id"], names

    with ThreadPoolExecutor(max_workers=max(1, args.jobs)) as executor:
        generated = dict(executor.map(process, schemes))

    args.catalog.parent.mkdir(parents=True, exist_ok=True)
    args.catalog.write_text(render_catalog(schemes, generated), encoding="utf-8")
    for scheme in schemes:
        for color in ("black", "white"):
            name = asset_name(scheme["id"], color)
            output = args.assets_root / f"{name}.imageset" / f"{slug(scheme['id'])}-{color}.png"
            try:
                scheme["images"][color] = str(output.relative_to(ROOT))
            except ValueError:
                scheme["images"][color] = str(output)
    args.registry.parent.mkdir(parents=True, exist_ok=True)
    args.registry.write_text(
        json.dumps({"schemes": schemes}, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(f"已处理 {len(incoming)} 套新方案，当前生成目录共 {len(schemes)} 套")
    print(f"风格目录: {args.catalog}")


if __name__ == "__main__":
    main()
