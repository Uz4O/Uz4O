import argparse
from collections import Counter
from dataclasses import asdict
from datetime import datetime, timezone
import json
from pathlib import Path
import tempfile

import httpx
from sqlalchemy import select

from app.builds.repository import upsert_build_templates
from app.builds.templates import read_build_template_inputs
from app.catalog.prices import (
    read_approved_price_rows,
    read_cpu_whitelist_price_rows,
    read_gpu_whitelist_price_rows,
    read_motherboard_whitelist_price_rows,
)
from app.catalog.readiness import REQUIRED_RECOMMENDED_CATEGORIES, build_data_readiness
from app.catalog.models import HardwareComponent
from app.catalog.repository import seed_component_prices
from app.catalog.repository import seed_cpu_whitelist_prices
from app.catalog.repository import seed_gpu_whitelist_prices
from app.catalog.repository import seed_hardware_components
from app.catalog.repository import seed_motherboard_whitelist_prices
from app.catalog.repository import update_recommended_components
from app.catalog.seed import read_catalog_components
from app.core.config import Settings
from app.db import create_session_factory
from app.perf.collector import CollectionBlocked, Collector, CollectorPolicy
from app.perf.collector_manifest import load_manifest, target_page_count, write_manifest
from app.perf.collector_store import CollectionTask, CollectorStore
from app.perf.anchor_importer import read_reviewed_fps_bundle
from app.perf.anchor_repository import (
    upsert_game_performance_anchors,
    upsert_hardware_performance_profiles,
)
from app.perf.importer import DEFAULT_MANIFEST_PATH, read_performance_batch
from app.perf.models import GamePerformanceAnchor, HardwarePerformanceProfile
from app.perf.repository import upsert_performance_estimates


def _non_negative_int(value: str) -> int:
    parsed = int(value)
    if parsed < 0:
        raise argparse.ArgumentTypeError("must be non-negative")
    return parsed


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

    perf_manifest_parser = subparsers.add_parser("build-perf-manifest")
    perf_manifest_parser.add_argument("swift_catalog", type=Path)
    perf_manifest_parser.add_argument("manifest_json", type=Path)

    check_perf_manifest_parser = subparsers.add_parser("check-perf-manifest")
    check_perf_manifest_parser.add_argument("manifest_json", type=Path)
    check_perf_manifest_parser.add_argument("--json", type=Path)

    seed_perf_parser = subparsers.add_parser("seed-perf-collection")
    seed_perf_parser.add_argument("manifest_json", type=Path)
    seed_perf_parser.add_argument("sqlite_path", type=Path)

    run_perf_parser = subparsers.add_parser("run-perf-collection")
    run_perf_parser.add_argument("sqlite_path", type=Path)
    run_perf_parser.add_argument("--max-tasks", type=_non_negative_int)
    run_perf_parser.add_argument("--delay-seconds", type=float, default=2.0)

    export_perf_parser = subparsers.add_parser("export-perf-collection")
    export_perf_parser.add_argument("sqlite_path", type=Path)
    export_perf_parser.add_argument("output_json", type=Path)

    import_perf_parser = subparsers.add_parser("import-perf-estimates")
    import_perf_parser.add_argument("json_path", type=Path)
    import_perf_parser.add_argument(
        "--manifest-json",
        type=Path,
        default=DEFAULT_MANIFEST_PATH,
    )

    import_model_inputs_parser = subparsers.add_parser("import-fps-model-inputs")
    import_model_inputs_parser.add_argument("json_path", type=Path)

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
    if args.command == "build-perf-manifest":
        manifest = write_manifest(args.swift_catalog, args.manifest_json)
        print(
            f"Wrote {len(manifest.cpus)} CPUs, {len(manifest.gpus)} GPUs, "
            f"and {len(manifest.games)} games."
        )
    if args.command == "check-perf-manifest":
        manifest = load_manifest(args.manifest_json)
        counts = Counter(
            item.status for item in manifest.cpus + manifest.gpus + manifest.games
        )
        for status in ("exact", "review", "missing"):
            print(f"{status}: {counts[status]}")
        print(f"Derived result-page count: {target_page_count(manifest)}")
        if args.json:
            _write_perf_coverage_report(manifest, args.json)
    if args.command == "seed-perf-collection":
        manifest = load_manifest(args.manifest_json)
        cpus = [item for item in manifest.cpus if item.status == "exact"]
        gpus = [item for item in manifest.gpus if item.status == "exact"]
        games = [item for item in manifest.games if item.status == "exact"]
        tasks = [
            CollectionTask(
                cpu.app_id,
                gpu.app_id,
                game.app_id,
                "https://pc-builds.com/zh/fps-calculator/result/"
                f"{cpu.source_id}{gpu.source_id}{game.source_id}/"
                f"{cpu.source_slug}/{gpu.source_slug}/{game.source_slug}/1920x1080/",
                source_cpu_id=cpu.source_id,
                source_gpu_id=gpu.source_id,
                source_game_id=game.source_id,
            )
            for cpu in cpus
            for gpu in gpus
            for game in games
        ]
        with CollectorStore(args.sqlite_path) as store:
            count = store.seed_tasks(tasks)
        print(f"Seeded {count} tasks.")
    if args.command == "run-perf-collection":
        policy = CollectorPolicy(delay_seconds=args.delay_seconds)
        try:
            with CollectorStore(args.sqlite_path) as store, httpx.Client(
                timeout=policy.timeout_seconds
            ) as client:
                summary = Collector(store, client, policy).run(args.max_tasks)
        except CollectionBlocked as error:
            print(f"Collection blocked: {error}")
            raise SystemExit(2)
        values = asdict(summary)
        print(
            "Collection summary: "
            + " ".join(f"{key}={value}" for key, value in values.items())
        )
    if args.command == "export-perf-collection":
        with CollectorStore(args.sqlite_path) as store:
            records = [
                {
                    **{
                        key: value
                        for key, value in task.items()
                        if key != "results"
                    },
                    **row,
                }
                for task in store.successful_records()
                for row in task["results"]
            ]
        payload = {
            "generated_at": datetime.now(timezone.utc).isoformat(),
            "quality": "medium",
            "records": records,
        }
        args.output_json.parent.mkdir(parents=True, exist_ok=True)
        temporary_path = None
        try:
            with tempfile.NamedTemporaryFile(
                mode="w",
                encoding="utf-8",
                dir=args.output_json.parent,
                prefix=f".{args.output_json.name}.",
                suffix=".tmp",
                delete=False,
            ) as temporary_file:
                temporary_path = Path(temporary_file.name)
                json.dump(payload, temporary_file, ensure_ascii=False, indent=2)
                temporary_file.write("\n")
            temporary_path.replace(args.output_json)
        finally:
            if temporary_path:
                temporary_path.unlink(missing_ok=True)
        print(f"Exported {len(records)} records.")
    if args.command == "import-perf-estimates":
        estimates = read_performance_batch(args.json_path, args.manifest_json)
        session_factory = create_session_factory(Settings())
        with session_factory() as session:
            count = upsert_performance_estimates(session, estimates)
        print(f"Imported {count} game performance estimates.")
    if args.command == "import-fps-model-inputs":
        session_factory = create_session_factory(Settings())
        with session_factory() as session:
            component_rows = session.execute(
                select(HardwareComponent.id, HardwareComponent.category).where(
                    HardwareComponent.category.in_(("cpu", "gpu"))
                )
            )
            component_ids = {"cpu": set(), "gpu": set()}
            for component_id, category in component_rows:
                component_ids[category].add(component_id)
            bundle = read_reviewed_fps_bundle(
                args.json_path,
                component_ids["cpu"],
                component_ids["gpu"],
            )
            try:
                profile_count = upsert_hardware_performance_profiles(
                    session,
                    [
                        HardwarePerformanceProfile(**asdict(item))
                        for item in bundle.hardware_profiles
                    ],
                )
                anchor_count = upsert_game_performance_anchors(
                    session,
                    [GamePerformanceAnchor(**asdict(item)) for item in bundle.anchors],
                )
                session.commit()
            except Exception:
                session.rollback()
                raise
        print(
            f"Imported {profile_count} reviewed hardware profiles and "
            f"{anchor_count} reviewed FPS anchors."
        )

def _read_component_ids(path: Path) -> list[str]:
    component_ids = []
    for line in path.read_text(encoding="utf-8").splitlines():
        stripped = line.strip()
        if stripped and not stripped.startswith("#"):
            component_ids.append(stripped)
    return component_ids


def _write_perf_coverage_report(manifest, path: Path) -> None:
    statuses = ("exact", "review", "missing")
    sections = {}
    for name in ("cpus", "gpus", "games"):
        items = getattr(manifest, name)
        counts = Counter(item.status for item in items)
        sections[name] = {
            "total": len(items),
            **{status: counts[status] for status in statuses},
        }
    overall = Counter(
        item.status
        for name in ("cpus", "gpus", "games")
        for item in getattr(manifest, name)
    )
    payload = {
        "sections": sections,
        "overall": {
            "total": sum(section["total"] for section in sections.values()),
            **{status: overall[status] for status in statuses},
        },
        "derived_result_page_count": target_page_count(manifest),
    }
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary_path = None
    try:
        with tempfile.NamedTemporaryFile(
            mode="w",
            encoding="utf-8",
            dir=path.parent,
            prefix=f".{path.name}.",
            suffix=".tmp",
            delete=False,
        ) as temporary_file:
            temporary_path = Path(temporary_file.name)
            json.dump(payload, temporary_file, ensure_ascii=False, indent=2)
            temporary_file.write("\n")
        temporary_path.replace(path)
    finally:
        if temporary_path:
            temporary_path.unlink(missing_ok=True)


if __name__ == "__main__":
    main()
