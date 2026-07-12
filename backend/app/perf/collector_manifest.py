import json
import re
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import List, Literal, Optional, Tuple


MappingStatus = Literal["exact", "review", "missing"]


@dataclass
class SourceMapping:
    app_id: str
    app_name: str
    source_id: Optional[str]
    source_slug: Optional[str]
    source_name: Optional[str]
    device_type: str
    status: MappingStatus


@dataclass
class CollectorManifest:
    cpus: List[SourceMapping]
    gpus: List[SourceMapping]
    games: List[SourceMapping]


APPROVED_GAMES = [
    ("valorant", "Valorant", None),
    ("cs2", "Counter-Strike 2", None),
    ("pubg", "PUBG", None),
    ("delta-force", "Delta Force", None),
    ("teamfight-tactics", "Teamfight Tactics", None),
    ("league-of-legends", "League of Legends", None),
    ("call-of-duty-warzone", "Call of Duty: Warzone", "Call of Duty: Warzone"),
    ("cyberpunk-2077", "Cyberpunk 2077", None),
    ("red-dead-redemption-2", "Red Dead Redemption 2", None),
    ("gta-v", "Grand Theft Auto V", None),
    ("black-myth-wukong", "Black Myth: Wukong", None),
    ("forza-horizon-6", "Forza Horizon 6", None),
    ("elden-ring", "Elden Ring", None),
    ("cities-skylines", "Cities: Skylines", None),
    ("minecraft-java-edition", "Minecraft: Java Edition", None),
]

ITEM_PATTERN = re.compile(
    r'HardwareCatalogItem\(id:\s*"(?P<id>[^"]+)",\s*name:\s*"(?P<name>[^"]+)"'
)


def load_manifest(path: Path) -> CollectorManifest:
    data = json.loads(Path(path).read_text(encoding="utf-8"))
    manifest = CollectorManifest(
        **{
            section: [SourceMapping(**item) for item in data[section]]
            for section in ("cpus", "gpus", "games")
        }
    )
    for item in manifest.cpus + manifest.gpus + manifest.games:
        if item.status not in ("exact", "review", "missing"):
            raise ValueError(f"Invalid mapping status for {item.app_id}: {item.status}")
        if item.status == "exact" and not all(
            (item.source_id, item.source_slug, item.source_name)
        ):
            raise ValueError(f"Incomplete exact mapping for {item.app_id}")
    return manifest


def target_page_count(manifest: CollectorManifest) -> int:
    return (
        sum(item.status == "exact" for item in manifest.cpus)
        * sum(item.status == "exact" for item in manifest.gpus)
        * sum(item.status == "exact" for item in manifest.games)
    )


def extract_hardware_scope(swift_path: Path) -> Tuple[List[SourceMapping], List[SourceMapping]]:
    source = Path(swift_path).read_text(encoding="utf-8")
    return _extract_scope(source, "cpus"), _extract_scope(source, "gpus")


def write_manifest(swift_path: Path, manifest_path: Path) -> CollectorManifest:
    cpus, gpus = extract_hardware_scope(swift_path)
    games = [
        SourceMapping(app_id, app_name, None, None, source_name, "game", "review")
        for app_id, app_name, source_name in APPROVED_GAMES
    ]
    path = Path(manifest_path)
    if path.exists():
        existing = load_manifest(path)
        cpus = _preserve_mappings(cpus, existing.cpus)
        gpus = _preserve_mappings(gpus, existing.gpus)
        games = _preserve_mappings(games, existing.games)
    manifest = CollectorManifest(cpus=cpus, gpus=gpus, games=games)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        json.dumps(asdict(manifest), ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    return manifest


def _extract_scope(source: str, section_name: str) -> List[SourceMapping]:
    marker = re.search(
        rf"static let {section_name}:\s*\[HardwareCatalogItem\]\s*=\s*\[",
        source,
    )
    if not marker:
        raise ValueError(f"Could not find HardwareCatalog section: {section_name}")
    end = source.find("\n    ]", marker.end())
    if end < 0:
        raise ValueError(f"Unclosed HardwareCatalog section: {section_name}")
    return [
        SourceMapping(match.group("id"), match.group("name"), None, None, None, "desktop", "review")
        for match in ITEM_PATTERN.finditer(source, marker.end(), end)
    ]


def _preserve_mappings(
    generated: List[SourceMapping], existing: List[SourceMapping]
) -> List[SourceMapping]:
    by_id = {item.app_id: item for item in existing}
    for item in generated:
        previous = by_id.get(item.app_id)
        if previous:
            item.source_id = previous.source_id
            item.source_slug = previous.source_slug
            item.source_name = previous.source_name
            item.status = previous.status
    return generated
