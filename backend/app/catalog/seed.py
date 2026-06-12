import re
from pathlib import Path
from typing import Dict, List

from pydantic import BaseModel


CATEGORY_SECTIONS = {
    "cpus": "cpu",
    "gpus": "gpu",
    "motherboards": "motherboard",
    "rams": "ram",
    "storages": "storage",
    "powerSupplies": "psu",
}

ITEM_PATTERN = re.compile(
    r'HardwareCatalogItem\(id:\s*"(?P<id>[^"]+)",\s*'
    r'name:\s*"(?P<name>[^"]+)",\s*'
    r'brand:\s*"(?P<brand>[^"]+)",\s*'
    r'detail:\s*"(?P<detail>[^"]+)"\)'
)


class CatalogComponent(BaseModel):
    id: str
    category: str
    name: str
    brand: str
    detail_raw: str
    specs: Dict[str, object]


def extract_catalog_components(path: Path) -> List[CatalogComponent]:
    source = Path(path).read_text(encoding="utf-8")
    components: List[CatalogComponent] = []
    for section_name, category in CATEGORY_SECTIONS.items():
        section = _extract_array_section(source, section_name)
        for match in ITEM_PATTERN.finditer(section):
            detail = match.group("detail")
            components.append(
                CatalogComponent(
                    id=match.group("id"),
                    category=category,
                    name=match.group("name"),
                    brand=match.group("brand"),
                    detail_raw=detail,
                    specs=parse_detail_specs(category, detail),
                )
            )
    return components


def parse_detail_specs(category: str, detail: str) -> Dict[str, object]:
    parts = [part.strip() for part in detail.split("·")]
    if category == "cpu":
        return _parse_cpu_specs(parts)
    if category == "motherboard":
        return _parse_motherboard_specs(parts)
    if category == "ram":
        return _parse_ram_specs(detail, parts)
    if category == "storage":
        return _parse_storage_specs(parts)
    if category == "psu":
        return _parse_psu_specs(parts)
    if category == "gpu":
        return _parse_gpu_specs(parts)
    return {}


def _extract_array_section(source: str, name: str) -> str:
    marker = re.search(rf"static let {name}:\s*\[HardwareCatalogItem\]\s*=\s*\[", source)
    if not marker:
        raise ValueError(f"Could not find HardwareCatalog section: {name}")

    start = marker.end()
    depth = 1
    for index in range(start, len(source)):
        if source[index] == "[":
            depth += 1
        elif source[index] == "]":
            depth -= 1
            if depth == 0:
                return source[start:index]
    raise ValueError(f"Unclosed HardwareCatalog section: {name}")


def _parse_cpu_specs(parts: List[str]) -> Dict[str, object]:
    specs: Dict[str, object] = {}
    if len(parts) >= 1:
        generation_match = re.match(r"^(?P<generation>\S+)\s+(?P<platform>.+)$", parts[0])
        if generation_match:
            specs["generation"] = generation_match.group("generation")
            specs["platform"] = generation_match.group("platform")
        else:
            specs["platform"] = parts[0]
    socket = _first_matching(parts, r"^(LGA\d+|AM\d+)$")
    if socket:
        specs["socket"] = socket
    return specs


def _parse_motherboard_specs(parts: List[str]) -> Dict[str, object]:
    specs: Dict[str, object] = {}
    if parts:
        specs["platform"] = parts[0]
    socket = _first_matching(parts, r"^(LGA\d+|AM\d+)$")
    if socket:
        specs["socket"] = socket
    if len(parts) >= 3:
        specs["chipset"] = parts[2]
    return specs


def _parse_ram_specs(detail: str, parts: List[str]) -> Dict[str, object]:
    specs: Dict[str, object] = {}
    if parts:
        specs["type"] = parts[0]
    capacity = re.search(r"(\d+)GB", detail)
    if capacity:
        specs["capacity_gb"] = int(capacity.group(1))
    speed = re.search(r"(\d+)MHz", detail)
    if speed:
        specs["speed_mhz"] = int(speed.group(1))
    latency = re.search(r"\bCL(\d+)\b", detail)
    if latency:
        specs["cas_latency"] = int(latency.group(1))
    return specs


def _parse_storage_specs(parts: List[str]) -> Dict[str, object]:
    specs: Dict[str, object] = {}
    if parts:
        capacity = _capacity_to_gb(parts[0])
        if capacity:
            specs["capacity_gb"] = capacity
    if len(parts) >= 2:
        specs["type"] = parts[1]
    return specs


def _parse_psu_specs(parts: List[str]) -> Dict[str, object]:
    specs: Dict[str, object] = {}
    if parts:
        watt = re.search(r"(\d+)W", parts[0])
        if watt:
            specs["watt"] = int(watt.group(1))
    if len(parts) >= 2:
        specs["rating"] = parts[1]
    return specs


def _parse_gpu_specs(parts: List[str]) -> Dict[str, object]:
    return {"vendor": parts[0]} if parts else {}


def _first_matching(parts: List[str], pattern: str) -> str:
    for part in parts:
        if re.match(pattern, part):
            return part
    return ""


def _capacity_to_gb(value: str) -> int:
    tb_match = re.search(r"(\d+)TB", value)
    if tb_match:
        return int(tb_match.group(1)) * 1024
    gb_match = re.search(r"(\d+)GB", value)
    if gb_match:
        return int(gb_match.group(1))
    return 0
