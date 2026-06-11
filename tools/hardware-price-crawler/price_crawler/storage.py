import csv
from dataclasses import asdict
from pathlib import Path
from typing import Dict, Iterable, List

from .pricing import HardwareTarget, ProductAssessment, RawProduct, ReferencePrice


def write_hardware_targets(path: Path, targets: Iterable[HardwareTarget]) -> None:
    _write_rows(path, ["category", "id", "name", "brand", "detail"], [asdict(item) for item in targets])


def read_hardware_targets(path: Path) -> List[HardwareTarget]:
    with Path(path).open(encoding="utf-8", newline="") as handle:
        return [HardwareTarget(**row) for row in csv.DictReader(handle)]


def write_raw_products(path: Path, products: Iterable[RawProduct]) -> None:
    fields = ["target_id", "category", "query", "sku", "title", "price", "shop", "url", "captured_at"]
    _write_rows(path, fields, [asdict(item) for item in products])


def read_raw_products(path: Path) -> List[RawProduct]:
    with Path(path).open(encoding="utf-8", newline="") as handle:
        return [
            RawProduct(
                target_id=row["target_id"],
                category=row["category"],
                query=row["query"],
                sku=row["sku"],
                title=row["title"],
                price=float(row["price"]),
                shop=row["shop"],
                url=row["url"],
                captured_at=row["captured_at"],
            )
            for row in csv.DictReader(handle)
        ]


def write_reference_prices(path: Path, references: Iterable[ReferencePrice]) -> None:
    fields = [
        "category",
        "target_id",
        "name",
        "brand",
        "reference_price",
        "normal_price_min",
        "normal_price_max",
        "accepted_count",
        "rejected_count",
        "review_reasons",
    ]
    rows = []
    for item in references:
        rows.append(
            {
                "category": item.target.category,
                "target_id": item.target.id,
                "name": item.target.name,
                "brand": item.target.brand,
                "reference_price": item.reference_price,
                "normal_price_min": item.normal_price_min,
                "normal_price_max": item.normal_price_max,
                "accepted_count": item.accepted_count,
                "rejected_count": item.rejected_count,
                "review_reasons": "|".join(item.review_reasons),
            }
        )
    _write_rows(path, fields, rows)


def write_review_required(
    path: Path,
    references: Iterable[ReferencePrice],
    rejected_products: Iterable[ProductAssessment],
) -> None:
    fields = ["record_type", "target_id", "name_or_title", "price", "reason", "url"]
    rows = []
    for item in references:
        if item.review_reasons:
            rows.append(
                {
                    "record_type": "reference",
                    "target_id": item.target.id,
                    "name_or_title": item.target.name,
                    "price": item.reference_price,
                    "reason": "|".join(item.review_reasons),
                    "url": "",
                }
            )
    for item in rejected_products:
        rows.append(
            {
                "record_type": "rejected_product",
                "target_id": item.product.target_id,
                "name_or_title": item.product.title,
                "price": item.product.price,
                "reason": item.reason,
                "url": item.product.url,
            }
        )
    _write_rows(path, fields, rows)


def read_previous_prices(path: Path) -> Dict[str, float]:
    path = Path(path)
    if not path.exists():
        return {}
    with path.open(encoding="utf-8", newline="") as handle:
        return {
            row["target_id"]: float(row["reference_price"])
            for row in csv.DictReader(handle)
            if row["reference_price"]
        }


def _write_rows(path: Path, fieldnames: List[str], rows: Iterable[dict]) -> None:
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)
