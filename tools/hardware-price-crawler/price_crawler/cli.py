import argparse
from collections import defaultdict
from datetime import datetime
from pathlib import Path

from .catalog import extract_hardware_targets
from .pricing import HardwareTarget, assess_product, build_reference_price
from .scraper import scrape_jd_targets
from .storage import (
    read_hardware_targets,
    read_previous_prices,
    read_raw_products,
    write_hardware_targets,
    write_raw_products,
    write_reference_prices,
    write_review_required,
)


TOOL_ROOT = Path(__file__).resolve().parents[1]
REPO_ROOT = TOOL_ROOT.parents[1]
DEFAULT_CATALOG = REPO_ROOT / "May/May/Models/HardwareCatalog.swift"
DEFAULT_HARDWARE = TOOL_ROOT / "data/hardware.csv"
DEFAULT_APPROVED = TOOL_ROOT / "data/approved-reference-prices.csv"
DEFAULT_PROFILE = TOOL_ROOT / "data/browser-profile"


def main() -> None:
    parser = _build_parser()
    args = parser.parse_args()
    args.handler(args)


def _build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="人工监督的京东硬件参考价采集工具")
    subparsers = parser.add_subparsers(required=True)

    catalog_parser = subparsers.add_parser("catalog", help="从 Swift HardwareCatalog 提取硬件清单")
    catalog_parser.add_argument("--source", type=Path, default=DEFAULT_CATALOG)
    catalog_parser.add_argument("--output", type=Path, default=DEFAULT_HARDWARE)
    catalog_parser.set_defaults(handler=_catalog)

    crawl_parser = subparsers.add_parser("crawl", help="打开可见浏览器并采集京东搜索结果")
    crawl_parser.add_argument("--hardware", type=Path, default=DEFAULT_HARDWARE)
    crawl_parser.add_argument("--output", type=Path)
    crawl_parser.add_argument("--profile", type=Path, default=DEFAULT_PROFILE)
    crawl_parser.add_argument("--category", choices=["cpu", "gpu", "motherboard"])
    crawl_parser.add_argument("--limit", type=int, default=0, help="本次最多采集的型号数，0 表示全部")
    crawl_parser.add_argument("--delay", type=float, default=5)
    crawl_parser.add_argument("--channel", default="msedge", help="Playwright 浏览器频道，默认 msedge")
    crawl_parser.add_argument("--skip-login-pause", action="store_true")
    crawl_parser.set_defaults(handler=_crawl)

    build_parser = subparsers.add_parser("build-prices", help="从原始商品生成参考价和复核清单")
    build_parser.add_argument("--hardware", type=Path, default=DEFAULT_HARDWARE)
    build_parser.add_argument("--raw", type=Path, required=True)
    build_parser.add_argument("--previous", type=Path, default=DEFAULT_APPROVED)
    build_parser.add_argument("--output-dir", type=Path)
    build_parser.set_defaults(handler=_build_prices)
    return parser


def _catalog(args) -> None:
    targets = extract_hardware_targets(args.source)
    write_hardware_targets(args.output, targets)
    counts = defaultdict(int)
    for target in targets:
        counts[target.category] += 1
    print("已写入 {}：CPU {}，GPU {}，主板 {}".format(args.output, counts["cpu"], counts["gpu"], counts["motherboard"]))


def _crawl(args) -> None:
    targets = read_hardware_targets(args.hardware)
    if args.category:
        targets = [item for item in targets if item.category == args.category]
    if args.limit > 0:
        targets = targets[: args.limit]
    if not targets:
        raise SystemExit("没有可采集的硬件型号，请先运行 catalog 或检查筛选条件。")

    output = args.output or _new_run_dir() / "raw-products.csv"

    def save_progress(products):
        write_raw_products(output, products)

    scrape_jd_targets(
        targets=targets,
        profile_path=args.profile,
        delay_seconds=args.delay,
        channel=args.channel,
        pause_for_login=not args.skip_login_pause,
        after_target=save_progress,
    )
    print("原始商品已写入 {}".format(output))


def _build_prices(args) -> None:
    targets = read_hardware_targets(args.hardware)
    products = read_raw_products(args.raw)
    previous_prices = read_previous_prices(args.previous)
    products_by_target = defaultdict(list)
    for product in products:
        products_by_target[product.target_id].append(product)

    references = []
    rejected = []
    for target in targets:
        assessments = [assess_product(target, item) for item in products_by_target[target.id]]
        rejected.extend(item for item in assessments if not item.accepted)
        references.append(build_reference_price(target, assessments, previous_prices.get(target.id)))

    output_dir = args.output_dir or _new_run_dir()
    write_reference_prices(output_dir / "reference-prices.csv", references)
    write_review_required(output_dir / "review-required.csv", references, rejected)
    print("参考价已写入 {}".format(output_dir / "reference-prices.csv"))
    print("人工复核清单已写入 {}".format(output_dir / "review-required.csv"))


def _new_run_dir() -> Path:
    return TOOL_ROOT / "data/runs" / datetime.now().strftime("%Y%m%d-%H%M%S")
