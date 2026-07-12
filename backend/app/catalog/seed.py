import json
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


def read_catalog_components(path: Path) -> List[CatalogComponent]:
    path = Path(path)
    if path.suffix.lower() != ".json":
        return extract_catalog_components(path)
    payload = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(payload, list):
        raise ValueError("Hardware component JSON must contain a list")
    return [CatalogComponent.model_validate(item) for item in payload]


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
                    specs=parse_detail_specs(
                        category,
                        detail,
                        name=match.group("name"),
                        component_id=match.group("id"),
                    ),
                )
            )
    return components


def parse_detail_specs(
    category: str,
    detail: str,
    name: str = "",
    component_id: str = "",
) -> Dict[str, object]:
    parts = [part.strip() for part in detail.split("·")]
    if category == "cpu":
        return _parse_cpu_specs(parts, name or component_id)
    if category == "motherboard":
        return _parse_motherboard_specs(parts, name or component_id)
    if category == "ram":
        return _parse_ram_specs(detail, parts)
    if category == "storage":
        return _parse_storage_specs(parts)
    if category == "psu":
        return _parse_psu_specs(parts)
    if category == "gpu":
        return _parse_gpu_specs(parts, name or component_id)
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


def _parse_cpu_specs(parts: List[str], name: str) -> Dict[str, object]:
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
    perf_index = _cpu_perf_index(name, specs.get("generation", ""))
    if perf_index:
        specs["perf_index"] = perf_index
    tdp = _cpu_tdp(name)
    if tdp:
        specs["tdp"] = tdp
    return specs


def _parse_motherboard_specs(parts: List[str], name: str) -> Dict[str, object]:
    specs: Dict[str, object] = {}
    if parts:
        specs["platform"] = parts[0]
    socket = _first_matching(parts, r"^(LGA\d+|AM\d+)$")
    if socket:
        specs["socket"] = socket
    if len(parts) >= 3:
        specs["chipset"] = parts[2]
    mem_type = _motherboard_mem_type(name, specs.get("socket", ""), specs.get("chipset", ""))
    if mem_type:
        specs["mem_type"] = mem_type
    form_factor = _motherboard_form_factor(name)
    if form_factor:
        specs["form_factor"] = form_factor
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


def _parse_gpu_specs(parts: List[str], name: str) -> Dict[str, object]:
    specs: Dict[str, object] = {"vendor": parts[0]} if parts else {}
    perf_index = _gpu_perf_index(name)
    if perf_index:
        specs["perf_index"] = perf_index
    tdp = _gpu_tdp(name)
    if not tdp and perf_index:
        tdp = _estimated_gpu_tdp(perf_index)
    if tdp:
        specs["tdp"] = tdp
    return specs


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


def _cpu_perf_index(name: str, generation: object) -> int:
    normalized = name.lower()
    if normalized.startswith("ultra"):
        match = re.search(r"ultra\s+([579])\s+(\d+)", normalized)
        if not match:
            return 0
        tier = int(match.group(1))
        model = int(match.group(2))
        base = {5: 82, 7: 92, 9: 100}[tier]
        return base + (4 if normalized.endswith("k") else 0) + max((model - 235) // 10, 0)

    intel_match = re.search(r"i([3579])-?(\d{4,5})", normalized)
    if intel_match:
        tier = int(intel_match.group(1))
        model = intel_match.group(2)
        gen = int(model[:2]) if len(model) >= 5 else int(model[:2])
        tier_base = {3: 36, 5: 64, 7: 76, 9: 90}[tier]
        gen_bonus = max(gen - 10, 0) * 4
        suffix_bonus = 4 if normalized.endswith(("k", "kf", "ks")) else 0
        f_penalty = -1 if normalized.endswith("f") else 0
        return tier_base + gen_bonus + suffix_bonus + f_penalty

    amd_match = re.search(r"r([579])\s*-?\s*(\d{4})", normalized)
    if amd_match:
        tier = int(amd_match.group(1))
        model = amd_match.group(2)
        series = int(model[0])
        tier_base = {5: 56, 7: 74, 9: 88}[tier]
        series_bonus = max(series - 5, 0) * 5
        x_bonus = 4 if "x" in normalized else 0
        x3d_bonus = 7 if "x3d" in normalized else 0
        return tier_base + series_bonus + x_bonus + x3d_bonus
    return 0


def _cpu_tdp(name: str) -> int:
    normalized = name.lower()
    if normalized.startswith("ultra"):
        return 181 if normalized.endswith("k") else 125
    if re.search(r"i[79]-", normalized):
        return 253 if normalized.endswith(("ks", "k", "kf")) else 219
    if re.search(r"i5-", normalized):
        return 181 if normalized.endswith(("k", "kf")) else 117
    if re.search(r"i3-", normalized):
        return 89
    if re.search(r"r9\s*-?", normalized):
        return 170 if "x" in normalized else 120
    if re.search(r"r7\s*-?", normalized):
        return 120 if "x" in normalized else 88
    if re.search(r"r5\s*-?", normalized):
        return 105 if "x" in normalized else 88
    return 0


def _gpu_perf_index(name: str) -> int:
    normalized = name.lower()
    nvidia_match = re.search(r"(gtx|rtx)\s*(\d{4})", normalized)
    if nvidia_match:
        family = nvidia_match.group(1)
        model = int(nvidia_match.group(2))
        series = model // 1000
        tier = (model % 1000) // 10
        if family == "gtx":
            base = {10: 22, 16: 35}.get(series * 10 if series == 1 else series, 25)
            return base + max(tier - 50, 0) // 2 + _gpu_suffix_bonus(normalized)
        return series * 12 + tier * 5 + _gpu_suffix_bonus(normalized)

    amd_match = re.search(r"rx\s*(\d{4})", normalized)
    if amd_match:
        model = int(amd_match.group(1))
        series = model // 1000
        tier = (model % 1000) // 10
        return series * 11 + tier * 5 + _gpu_suffix_bonus(normalized)
    return 0


def _gpu_suffix_bonus(normalized_name: str) -> int:
    bonus = 0
    if "super" in normalized_name:
        bonus += 4
    if " ti" in normalized_name or "-ti" in normalized_name:
        bonus += 5
    if "xtx" in normalized_name:
        bonus += 8
    elif " xt" in normalized_name or "-xt" in normalized_name:
        bonus += 5
    if "gre" in normalized_name:
        bonus += 3
    return bonus


def _gpu_tdp(name: str) -> int:
    normalized = name.lower()
    tdp_by_prefix = [
        ("rtx 5090", 575),
        ("rtx 5080", 360),
        ("rtx 5070 ti", 300),
        ("rtx 5070", 250),
        ("rtx 5060 ti", 180),
        ("rtx 5060", 145),
        ("rtx 4090", 450),
        ("rtx 4080", 320),
        ("rtx 4070 ti", 285),
        ("rtx 4070", 200),
        ("rtx 4060 ti", 160),
        ("rtx 4060", 115),
        ("rtx 3090", 350),
        ("rtx 3080", 320),
        ("rtx 3070", 220),
        ("rtx 3060 ti", 200),
        ("rtx 3060", 170),
        ("rtx 3050", 130),
        ("gtx 1660", 125),
        ("gtx 1650", 75),
        ("rx 7900", 315),
        ("rx 7800", 263),
        ("rx 7700", 245),
        ("rx 7600", 165),
        ("rx 6800", 250),
        ("rx 6700", 230),
        ("rx 6600", 132),
    ]
    compact = normalized.replace("-", " ")
    for prefix, tdp in tdp_by_prefix:
        if compact.startswith(prefix):
            return tdp
    return 0


def _estimated_gpu_tdp(perf_index: int) -> int:
    return max(75, min(round(perf_index * 3), 450))


def _motherboard_mem_type(name: str, socket: object, chipset: object) -> str:
    normalized = name.lower()
    socket_value = str(socket)
    chipset_value = str(chipset).upper()
    if "ddr4" in normalized or re.search(r"\bd4\b", normalized):
        return "DDR4"
    if "ddr5" in normalized or re.search(r"\bd5\b", normalized):
        return "DDR5"
    if socket_value in {"AM5", "LGA1851"}:
        return "DDR5"
    if socket_value in {"AM4", "LGA1200"}:
        return "DDR4"
    if chipset_value.startswith(("B650", "X670", "B850", "X870", "A620")):
        return "DDR5"
    return ""


def _motherboard_form_factor(name: str) -> str:
    if not name:
        return ""
    normalized = name.upper()
    if "ITX" in normalized or re.search(r"\b[A-Z]\d{3}I\b", normalized):
        return "itx"
    if "MATX" in normalized or re.search(r"\b[A-Z]\d{3}M\b", normalized):
        return "micro_atx"
    return "atx"
