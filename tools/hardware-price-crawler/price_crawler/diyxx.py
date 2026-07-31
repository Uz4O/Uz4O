import csv
from dataclasses import dataclass
import json
from pathlib import Path
import re
from typing import Dict, Iterable, List, Optional, Sequence
from urllib.parse import urlencode
from urllib.request import Request, urlopen


DEFAULT_DIYXX_API = "https://diyxx.com/api/products"


@dataclass(frozen=True)
class DiyxxGPUProduct:
    product_id: str
    brand: str
    model: str
    price: int
    previous_price: Optional[int]
    updated_at: str
    status: str
    gpu_chip: str
    memory_size: Optional[int]

    @property
    def display_name(self) -> str:
        return "{} {}".format(self.brand, self.model).strip()


def fetch_diyxx_gpu_products(
    api_url: str = DEFAULT_DIYXX_API,
    page_size: int = 200,
    timeout_seconds: float = 20,
) -> List[DiyxxGPUProduct]:
    products: List[DiyxxGPUProduct] = []
    page = 1
    total = None
    while total is None or len(products) < total:
        query = urlencode(
            {"category": "gpu", "page": page, "page_size": page_size}
        )
        request = Request(
            "{}?{}".format(api_url, query),
            headers={"User-Agent": "UzBox-Hardware-Price-Collector/1.0"},
        )
        with urlopen(request, timeout=timeout_seconds) as response:
            payload = json.loads(response.read().decode("utf-8"))
        if not isinstance(payload, dict) or not isinstance(payload.get("items"), list):
            raise ValueError("diyxx products response has an invalid shape")
        total = int(payload.get("total") or 0)
        batch = [_parse_product(item) for item in payload["items"]]
        products.extend(item for item in batch if item is not None)
        if not payload["items"]:
            break
        page += 1
    return products


def match_whitelist_target(
    product: DiyxxGPUProduct,
    whitelist_rows: Sequence[Dict[str, str]],
) -> Optional[str]:
    candidates = sorted(
        whitelist_rows,
        key=lambda row: len(_model_token(row["name"])),
        reverse=True,
    )
    model = _normalize(product.model)
    for row in candidates:
        target_id = row["target_id"]
        if target_id == "rtx-5090-d-v2":
            if "5090D" in model and "V2" in model:
                return target_id
            continue
        if target_id.startswith("rx-9060-xt-"):
            expected_memory = 8 if target_id.endswith("8gb") else 12
            if "9060XT" in model and _memory_size(product) == expected_memory:
                return target_id
            continue
        token = _model_token(row["name"])
        if token and token in model:
            return target_id
    return None


def write_diyxx_gpu_snapshot(
    output_dir: Path,
    whitelist_csv: Path,
    products: Iterable[DiyxxGPUProduct],
) -> Dict[str, object]:
    output_dir = Path(output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)
    whitelist_rows = _read_csv(whitelist_csv)
    products = list(products)
    matches = {
        product.product_id: match_whitelist_target(product, whitelist_rows)
        for product in products
    }
    grouped: Dict[str, List[DiyxxGPUProduct]] = {}
    for product in products:
        target_id = matches[product.product_id]
        if target_id:
            grouped.setdefault(target_id, []).append(product)

    raw_path = output_dir / "diyxx-gpu-products.csv"
    with raw_path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(
            handle,
            fieldnames=[
                "target_id",
                "source_product_id",
                "brand",
                "model",
                "price",
                "previous_price",
                "updated_at",
                "status",
                "gpu_chip",
                "memory_size",
            ],
        )
        writer.writeheader()
        for product in products:
            writer.writerow(
                {
                    "target_id": matches[product.product_id] or "",
                    "source_product_id": product.product_id,
                    "brand": product.brand,
                    "model": product.model,
                    "price": product.price,
                    "previous_price": product.previous_price or "",
                    "updated_at": product.updated_at,
                    "status": product.status,
                    "gpu_chip": product.gpu_chip,
                    "memory_size": product.memory_size or "",
                }
            )

    whitelist_path = output_dir / "gpu-whitelist-prices.csv"
    extra_fields = [
        "source_brand",
        "source_model",
        "source_product_id",
        "source_updated_at",
        "matched_product_count",
        "price_source",
    ]
    fieldnames = list(whitelist_rows[0]) + [
        field for field in extra_fields if field not in whitelist_rows[0]
    ]
    with whitelist_path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        for row in whitelist_rows:
            matched = grouped.get(row["target_id"], [])
            output = dict(row)
            if matched:
                selected = min(
                    matched,
                    key=lambda product: (
                        product.price,
                        product.model,
                        product.product_id,
                    ),
                )
                output.update(
                    {
                        "name": selected.display_name,
                        "new_price": selected.price,
                        "source_brand": selected.brand,
                        "source_model": selected.model,
                        "source_product_id": selected.product_id,
                        "source_updated_at": selected.updated_at,
                        "matched_product_count": len(matched),
                        "price_source": DEFAULT_DIYXX_API,
                    }
                )
            writer.writerow(output)

    matched_count = sum(len(items) for items in grouped.values())
    summary = {
        "source": DEFAULT_DIYXX_API,
        "product_count": len(products),
        "matched_product_count": matched_count,
        "matched_whitelist_count": len(grouped),
        "unmatched_whitelist_ids": [
            row["target_id"]
            for row in whitelist_rows
            if row["target_id"] not in grouped
        ],
        "raw_csv": str(raw_path),
        "whitelist_csv": str(whitelist_path),
    }
    (output_dir / "summary.json").write_text(
        json.dumps(summary, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    return summary


def _parse_product(payload) -> Optional[DiyxxGPUProduct]:
    if not isinstance(payload, dict):
        return None
    price = _optional_int(payload.get("price"))
    if price is None or price <= 0 or payload.get("status") != "active":
        return None
    specs = payload.get("specs") if isinstance(payload.get("specs"), dict) else {}
    return DiyxxGPUProduct(
        product_id=str(payload.get("id") or ""),
        brand=str(payload.get("brand") or "").strip(),
        model=str(payload.get("model") or "").strip(),
        price=price,
        previous_price=_optional_int(payload.get("previousPrice")),
        updated_at=str(payload.get("updatedAt") or ""),
        status=str(payload.get("status") or ""),
        gpu_chip=str(specs.get("gpuChip") or "").strip(),
        memory_size=_optional_int(specs.get("memorySize")),
    )


def _memory_size(product: DiyxxGPUProduct) -> Optional[int]:
    if product.memory_size is not None:
        return product.memory_size
    match = re.search(r"(?<!\d)(\d{1,2})G(?:B)?(?!\d)", product.model.upper())
    return int(match.group(1)) if match else None


def _model_token(name: str) -> str:
    token = _normalize(name)
    for prefix in ("NVIDIAGEFORCERTX", "NVIDIARTX", "GEFORCERTX", "INTELARC", "RTX", "RX", "ARC"):
        if token.startswith(prefix):
            return token[len(prefix) :]
    return token


def _normalize(value: str) -> str:
    return re.sub(r"[^A-Z0-9]", "", value.upper())


def _optional_int(value) -> Optional[int]:
    if value in (None, ""):
        return None
    return int(round(float(value)))


def _read_csv(path: Path) -> List[Dict[str, str]]:
    with Path(path).open(encoding="utf-8", newline="") as handle:
        rows = list(csv.DictReader(handle))
    if not rows:
        raise ValueError("GPU whitelist CSV is empty")
    return rows
