#!/usr/bin/env python3
"""Generate compact, tightly cropped assets for the immersive style explorer.

Requires Pillow (`python3 -m pip install Pillow`). Run from any directory:

    python3 flutter_app/tool/generate_explorer_assets.py

Each pixel source is the matching Swift `*Explorer.imageset/explorer.png`.
Images are converted to RGBA, cropped to the bounding box whose alpha is
greater than 8, and proportionally resized only when the longest side exceeds
640 pixels. Output filenames preserve the Flutter stems and use WebP.
"""

from __future__ import annotations

import shutil
from pathlib import Path

from PIL import Image


ALPHA_THRESHOLD = 8
MAX_LONGEST_SIDE = 640
WEBP_QUALITY = 90
WEBP_METHOD = 4

# Swift asset base name, Flutter black output stem, Flutter white output stem.
# These are the 42 unique styles shown by the Swift explorer: the 34 original
# styles plus the eight generated catalog styles. The first five intentionally
# retain the legacy Flutter stems referenced by the style list.
STYLE_MAPPINGS = (
    (
        "StyleLianLiVisionCompact",
        "style_vision_compact_black",
        "style_vision_compact_white",
    ),
    ("StyleROGGR701", "style_rog_gr701_black", "style_rog_gr701_white"),
    (
        "StyleUnknownPlayerPhantomWing",
        "style_phantom_wing_black",
        "style_phantom_wing_white",
    ),
    (
        "StyleJonsboBO400",
        "style_jonsbo_bo400_black",
        "style_jonsbo_bo400_white",
    ),
    (
        "StyleAigoXingcanChen",
        "style_xingcan_chen_black",
        "style_xingcan_chen_white",
    ),
    (
        "StyleASUSAP202",
        "style_catalog_StyleASUSAP202Black",
        "style_catalog_StyleASUSAP202White",
    ),
    (
        "StyleHYTEY70",
        "style_catalog_StyleHYTEY70Black",
        "style_catalog_StyleHYTEY70White",
    ),
    (
        "StyleAOCShockingBow",
        "style_catalog_StyleAOCShockingBowBlack",
        "style_catalog_StyleAOCShockingBowWhite",
    ),
    (
        "StyleJonsboBO400CG",
        "style_catalog_StyleJonsboBO400CGBlack",
        "style_catalog_StyleJonsboBO400CGWhite",
    ),
    (
        "StyleLianLiVisionMin",
        "style_catalog_StyleLianLiVisionMinBlack",
        "style_catalog_StyleLianLiVisionMinWhite",
    ),
    (
        "StyleHangjiaS960",
        "style_catalog_StyleHangjiaS960Black",
        "style_catalog_StyleHangjiaS960White",
    ),
    (
        "StyleLianLiV150INF",
        "style_catalog_StyleLianLiV150INFBlack",
        "style_catalog_StyleLianLiV150INFWhite",
    ),
    (
        "StyleJonsboTK1",
        "style_catalog_StyleJonsboTK1Black",
        "style_catalog_StyleJonsboTK1White",
    ),
    (
        "StyleJonsboD33Wood",
        "style_catalog_StyleJonsboD33WoodBlack",
        "style_catalog_StyleJonsboD33WoodWhite",
    ),
    (
        "StyleJonsboD34",
        "style_catalog_StyleJonsboD34Black",
        "style_catalog_StyleJonsboD34White",
    ),
    (
        "StyleAigoXuanYingG20",
        "style_catalog_StyleAigoXuanYingG20Black",
        "style_catalog_StyleAigoXuanYingG20White",
    ),
    (
        "StyleValkyrieVK3",
        "style_catalog_StyleValkyrieVK3Black",
        "style_catalog_StyleValkyrieVK3White",
    ),
    (
        "StyleLianLiO11EVORGB",
        "style_catalog_StyleLianLiO11EVORGBBlack",
        "style_catalog_StyleLianLiO11EVORGBWhite",
    ),
    (
        "StylePhanteksEvolvS2",
        "style_catalog_StylePhanteksEvolvS2Black",
        "style_catalog_StylePhanteksEvolvS2White",
    ),
    (
        "StylePhanteksEvolvX2Matrix",
        "style_catalog_StylePhanteksEvolvX2MatrixBlack",
        "style_catalog_StylePhanteksEvolvX2MatrixWhite",
    ),
    (
        "StyleJonsboTK4",
        "style_catalog_StyleJonsboTK4Black",
        "style_catalog_StyleJonsboTK4White",
    ),
    (
        "StyleAigoXingcanChenAir",
        "style_catalog_StyleAigoXingcanChenAirBlack",
        "style_catalog_StyleAigoXingcanChenAirWhite",
    ),
    (
        "StylePhanteksNV7",
        "style_catalog_StylePhanteksNV7Black",
        "style_catalog_StylePhanteksNV7White",
    ),
    (
        "StyleLianLiO11DMiniV2",
        "style_catalog_StyleLianLiO11DMiniV2Black",
        "style_catalog_StyleLianLiO11DMiniV2White",
    ),
    (
        "StyleASUSTUF502Ammo",
        "style_catalog_StyleASUSTUF502AmmoBlack",
        "style_catalog_StyleASUSTUF502AmmoWhite",
    ),
    (
        "StyleROGGR801",
        "style_catalog_StyleROGGR801Black",
        "style_catalog_StyleROGGR801White",
    ),
    (
        "StyleMSIVIXTA300R",
        "style_catalog_StyleMSIVIXTA300RBlack",
        "style_catalog_StyleMSIVIXTA300RWhite",
    ),
    (
        "StyleHangjiaS960V2",
        "style_catalog_StyleHangjiaS960V2Black",
        "style_catalog_StyleHangjiaS960V2White",
    ),
    (
        "StyleHangjiaGX750C",
        "style_catalog_StyleHangjiaGX750CBlack",
        "style_catalog_StyleHangjiaGX750CWhite",
    ),
    (
        "StyleCoolerMasterMF400Mesh",
        "style_catalog_StyleCoolerMasterMF400MeshBlack",
        "style_catalog_StyleCoolerMasterMF400MeshWhite",
    ),
    (
        "StyleSugonCiyuanCangPX",
        "style_catalog_StyleSugonCiyuanCangPXBlack",
        "style_catalog_StyleSugonCiyuanCangPXWhite",
    ),
    (
        "StyleTitanStarship",
        "style_catalog_StyleTitanStarshipBlack",
        "style_catalog_StyleTitanStarshipWhite",
    ),
    (
        "StyleFangtangC34Pro",
        "style_catalog_StyleFangtangC34ProBlack",
        "style_catalog_StyleFangtangC34ProWhite",
    ),
    (
        "StyleCougarV235",
        "style_catalog_StyleCougarV235Black",
        "style_catalog_StyleCougarV235White",
    ),
    (
        "StyleUnknownPlayerP80Mesh",
        "style_catalog_StyleUnknownPlayerP80MeshBlack",
        "style_catalog_StyleUnknownPlayerP80MeshWhite",
    ),
    (
        "StyleColorfulC25A",
        "style_catalog_StyleColorfulC25ABlack",
        "style_catalog_StyleColorfulC25AWhite",
    ),
    (
        "StyleXingcanChenScreen",
        "style_catalog_StyleXingcanChenScreenBlack",
        "style_catalog_StyleXingcanChenScreenWhite",
    ),
    (
        "StyleWanjiaWenjieMin",
        "style_catalog_StyleWanjiaWenjieMinBlack",
        "style_catalog_StyleWanjiaWenjieMinWhite",
    ),
    (
        "StyleWanjiaDreamerScreen",
        "style_catalog_StyleWanjiaDreamerScreenBlack",
        "style_catalog_StyleWanjiaDreamerScreenWhite",
    ),
    (
        "StylePhanteksXTV3Breeze",
        "style_catalog_StylePhanteksXTV3BreezeBlack",
        "style_catalog_StylePhanteksXTV3BreezeWhite",
    ),
    (
        "StyleHangjiaG63Waraxe",
        "style_catalog_StyleHangjiaG63WaraxeBlack",
        "style_catalog_StyleHangjiaG63WaraxeWhite",
    ),
    (
        "StyleValkyrieVK03M",
        "style_catalog_StyleValkyrieVK03MBlack",
        "style_catalog_StyleValkyrieVK03MWhite",
    ),
)


def alpha_bbox(image: Image.Image) -> tuple[int, int, int, int]:
    alpha = image.getchannel("A")
    mask = alpha.point(lambda value: 255 if value > ALPHA_THRESHOLD else 0)
    bounds = mask.getbbox()
    if bounds is None:
        raise ValueError("image has no pixels above the alpha threshold")
    return bounds


def transformed_image(source: Path) -> Image.Image:
    with Image.open(source) as original:
        image = original.convert("RGBA")
        image = image.crop(alpha_bbox(image))

        longest_side = max(image.size)
        if longest_side > MAX_LONGEST_SIDE:
            scale = MAX_LONGEST_SIDE / longest_side
            target_size = tuple(max(1, round(side * scale)) for side in image.size)
            image = image.resize(target_size, Image.Resampling.LANCZOS)

        return image


def generate_image(source: Path, destination: Path) -> None:
    image = transformed_image(source)
    image.save(
        destination,
        format="WEBP",
        quality=WEBP_QUALITY,
        method=WEBP_METHOD,
    )


def verify_image(source: Path, destination: Path) -> None:
    expected = transformed_image(source)
    with Image.open(destination) as generated:
        actual = generated.convert("RGBA")
        if actual.size != expected.size:
            raise RuntimeError(
                f"generated dimensions do not match the transformed Swift source: "
                f"{destination}"
            )


def main() -> None:
    flutter_root = Path(__file__).resolve().parents[1]
    images_dir = flutter_root / "assets" / "images"
    output_dir = images_dir / "explorer"
    output_dir.mkdir(parents=True, exist_ok=True)

    asset_catalog = flutter_root.parent / "May" / "May" / "Assets.xcassets"
    mappings: list[tuple[Path, Path]] = []
    for swift_base, black_output_stem, white_output_stem in STYLE_MAPPINGS:
        for color, output_stem in (
            ("Black", black_output_stem),
            ("White", white_output_stem),
        ):
            source = (
                asset_catalog
                / f"{swift_base}{color}Explorer.imageset"
                / "explorer.png"
            )
            mappings.append((source, output_dir / f"{output_stem}.webp"))

    if len(STYLE_MAPPINGS) != 42 or len(mappings) != 84:
        raise RuntimeError("STYLE_MAPPINGS must contain exactly 42 black/white pairs")

    mapped_sources = {source for source, _ in mappings}
    available_sources = set(
        asset_catalog.glob("Style*Explorer.imageset/explorer.png")
    )
    if mapped_sources != available_sources:
        unmapped = sorted(str(path) for path in available_sources - mapped_sources)
        unknown = sorted(str(path) for path in mapped_sources - available_sources)
        raise RuntimeError(
            "Swift Explorer source mapping is not exhaustive; "
            f"unmapped={unmapped}, unknown={unknown}"
        )

    missing = [str(source) for source, _ in mappings if not source.is_file()]
    if missing:
        raise FileNotFoundError(f"missing source assets: {', '.join(missing)}")

    expected_outputs = {destination.name for _, destination in mappings}
    if len(expected_outputs) != 84:
        raise RuntimeError("mappings must produce exactly 84 unique WebP names")

    for source, destination in mappings:
        generate_image(source, destination)

    for source, destination in mappings:
        verify_image(source, destination)

    unexpected = sorted(
        path.name
        for path in output_dir.glob("*.webp")
        if path.name not in expected_outputs
    )
    if unexpected:
        raise RuntimeError(
            "explorer output contains unexpected WebP files: " + ", ".join(unexpected)
        )

    generated = tuple(output_dir.glob("*.webp"))
    if len(generated) != 84:
        raise RuntimeError(f"expected 84 generated WebPs, found {len(generated)}")

    topology_source = (
        asset_catalog
        / "TopologyContourTexture.imageset"
        / "topology-contour-texture@2x.png"
    )
    topology_destination = images_dir / "topology_contour_texture.png"
    if not topology_source.is_file():
        raise FileNotFoundError(f"missing topology texture: {topology_source}")
    shutil.copyfile(topology_source, topology_destination)

    print(
        f"Generated and dimension-verified {len(generated)} Explorer WebPs from the "
        f"Swift Explorer assets in {output_dir} (alpha > {ALPHA_THRESHOLD}, "
        f"longest side <= {MAX_LONGEST_SIDE})."
    )
    print(f"Copied topology texture to {topology_destination}.")


if __name__ == "__main__":
    main()
