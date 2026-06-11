from pathlib import Path
import re
from typing import List

from .pricing import HardwareTarget


CATEGORY_SECTIONS = {
    "cpus": "cpu",
    "gpus": "gpu",
    "motherboards": "motherboard",
}

ITEM_PATTERN = re.compile(
    r'HardwareCatalogItem\(id:\s*"(?P<id>[^"]+)",\s*'
    r'name:\s*"(?P<name>[^"]+)",\s*'
    r'brand:\s*"(?P<brand>[^"]+)",\s*'
    r'detail:\s*"(?P<detail>[^"]+)"\)'
)


def extract_hardware_targets(path: Path) -> List[HardwareTarget]:
    source = Path(path).read_text(encoding="utf-8")
    targets = []
    for section_name, category in CATEGORY_SECTIONS.items():
        section = _extract_array_section(source, section_name)
        for match in ITEM_PATTERN.finditer(section):
            targets.append(
                HardwareTarget(
                    category=category,
                    id=match.group("id"),
                    name=match.group("name"),
                    brand=match.group("brand"),
                    detail=match.group("detail"),
                )
            )
    return targets


def _extract_array_section(source: str, name: str) -> str:
    marker = re.search(r"static let {}:\s*\[HardwareCatalogItem\]\s*=\s*\[".format(name), source)
    if not marker:
        raise ValueError("Could not find HardwareCatalog section: {}".format(name))

    start = marker.end()
    depth = 1
    for index in range(start, len(source)):
        if source[index] == "[":
            depth += 1
        elif source[index] == "]":
            depth -= 1
            if depth == 0:
                return source[start:index]
    raise ValueError("Unclosed HardwareCatalog section: {}".format(name))

