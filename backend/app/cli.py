import argparse
from pathlib import Path

from app.builds.repository import upsert_build_templates
from app.builds.templates import read_build_template_inputs
from app.catalog.prices import (
    read_approved_price_rows,
    read_cpu_whitelist_price_rows,
    read_gpu_whitelist_price_rows,
    read_motherboard_whitelist_price_rows,
)
from app.catalog.readiness import REQUIRED_RECOMMENDED_CATEGORIES, build_data_readiness
from app.catalog.repository import seed_component_prices
from app.catalog.repository import seed_cpu_whitelist_prices
from app.catalog.repository import seed_gpu_whitelist_prices
from app.catalog.repository import seed_hardware_components
from app.catalog.repository import seed_motherboard_whitelist_prices
from app.catalog.repository import update_recommended_components
from app.catalog.seed import read_catalog_components
from app.core.config import Settings
from app.db import create_session_factory


def main() -> None:
    parser = argparse.ArgumentParser(prog="ai-pc-builder-api")
    subparsers = parser.add_subparsers(dest="command", required=True)

    seed_parser = subparsers.add_parser("seed-hardware")
    seed_parser.add_argument("catalog_path", type=Path)

    prices_parser = subparsers.add_parser("ingest-prices")
    prices_parser.add_argument("csv_path", type=Path)
    prices_parser.add_argument("--approved-at", required=True)

    gpu_prices_parser = subparsers.add_parser("ingest-gpu-whitelist-prices")
    gpu_prices_parser.add_argument("csv_path", type=Path)
    gpu_prices_parser.add_argument("--approved-at", required=True)

    motherboard_prices_parser = subparsers.add_parser("ingest-motherboard-whitelist-prices")
    motherboard_prices_parser.add_argument("csv_path", type=Path)
    motherboard_prices_parser.add_argument("--approved-at", required=True)

    cpu_prices_parser = subparsers.add_parser("ingest-cpu-whitelist-prices")
    cpu_prices_parser.add_argument("csv_path", type=Path)
    cpu_prices_parser.add_argument("--approved-at", required=True)

    build_templates_parser = subparsers.add_parser("import-build-templates")
    build_templates_parser.add_argument("json_path", type=Path)

    recommendations_parser = subparsers.add_parser("import-recommendations")
    recommendations_parser.add_argument("ids_path", type=Path)
    recommendations_parser.add_argument("--replace", action="store_true")

    subparsers.add_parser("check-data-readiness")

    args = parser.parse_args()
    if args.command == "seed-hardware":
        components = read_catalog_components(args.catalog_path)
        session_factory = create_session_factory(Settings())
        with session_factory() as session:
            count = seed_hardware_components(session, components)
        print(f"Seeded {count} hardware components.")
    if args.command == "ingest-prices":
        prices = read_approved_price_rows(args.csv_path, approved_at=args.approved_at)
        session_factory = create_session_factory(Settings())
        with session_factory() as session:
            count = seed_component_prices(session, prices)
        print(f"Imported {count} component prices.")
    if args.command == "ingest-gpu-whitelist-prices":
        prices = read_gpu_whitelist_price_rows(args.csv_path, approved_at=args.approved_at)
        session_factory = create_session_factory(Settings())
        with session_factory() as session:
            count = seed_gpu_whitelist_prices(session, prices)
        print(f"Imported {count} GPU whitelist prices.")
    if args.command == "ingest-motherboard-whitelist-prices":
        prices = read_motherboard_whitelist_price_rows(args.csv_path, approved_at=args.approved_at)
        session_factory = create_session_factory(Settings())
        with session_factory() as session:
            count = seed_motherboard_whitelist_prices(session, prices)
        print(f"Imported {count} motherboard whitelist prices.")
    if args.command == "ingest-cpu-whitelist-prices":
        prices = read_cpu_whitelist_price_rows(args.csv_path, approved_at=args.approved_at)
        session_factory = create_session_factory(Settings())
        with session_factory() as session:
            count = seed_cpu_whitelist_prices(session, prices)
        print(f"Imported {count} CPU whitelist prices.")
    if args.command == "import-build-templates":
        templates = read_build_template_inputs(args.json_path)
        session_factory = create_session_factory(Settings())
        with session_factory() as session:
            count = upsert_build_templates(session, templates)
        print(f"Imported {count} build templates.")
    if args.command == "import-recommendations":
        component_ids = _read_component_ids(args.ids_path)
        session_factory = create_session_factory(Settings())
        with session_factory() as session:
            result = update_recommended_components(
                session,
                component_ids,
                replace=args.replace,
            )
        print(f"Marked {result.updated_count} recommended components.")
        if result.missing_ids:
            print("Missing component ids: " + ", ".join(result.missing_ids))
    if args.command == "check-data-readiness":
        session_factory = create_session_factory(Settings())
        with session_factory() as session:
            readiness = build_data_readiness(session)
        print(f"Data readiness: {'ready' if readiness.ready else 'not_ready'}")
        print(f"Hardware components: {readiness.component_count}")
        print(f"Component prices: {readiness.price_count}")
        print(f"Active build templates: {readiness.active_template_count}")
        for category in REQUIRED_RECOMMENDED_CATEGORIES:
            print(f"Recommended {category}: {readiness.recommended_counts[category]}")
        for category in REQUIRED_RECOMMENDED_CATEGORIES:
            print(f"Priced recommended {category}: {readiness.priced_recommended_counts[category]}")
        if readiness.missing_recommended_categories:
            print(
                "Missing recommended categories: "
                + ", ".join(readiness.missing_recommended_categories)
            )
        if readiness.missing_priced_recommended_categories:
            print(
                "Missing priced recommended categories: "
                + ", ".join(readiness.missing_priced_recommended_categories)
            )

def _read_component_ids(path: Path) -> list[str]:
    component_ids = []
    for line in path.read_text(encoding="utf-8").splitlines():
        stripped = line.strip()
        if stripped and not stripped.startswith("#"):
            component_ids.append(stripped)
    return component_ids


if __name__ == "__main__":
    main()
