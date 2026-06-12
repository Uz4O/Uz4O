import argparse
from pathlib import Path

from app.catalog.repository import seed_hardware_components
from app.catalog.seed import extract_catalog_components
from app.core.config import Settings
from app.db import create_session_factory


def main() -> None:
    parser = argparse.ArgumentParser(prog="ai-pc-builder-api")
    subparsers = parser.add_subparsers(dest="command", required=True)

    seed_parser = subparsers.add_parser("seed-hardware")
    seed_parser.add_argument("catalog_path", type=Path)

    args = parser.parse_args()
    if args.command == "seed-hardware":
        components = extract_catalog_components(args.catalog_path)
        session_factory = create_session_factory(Settings())
        with session_factory() as session:
            count = seed_hardware_components(session, components)
        print(f"Seeded {count} hardware components.")


if __name__ == "__main__":
    main()
