import csv
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
from typing import List, Optional

from zoneinfo import ZoneInfo


@dataclass(frozen=True)
class ApprovedPriceRow:
    component_id: str
    reference_price: int
    price_range_low: Optional[int]
    price_range_high: Optional[int]
    accepted_count: int
    rejected_count: int
    review_reasons: List[str]
    source: str
    approved_at: datetime


@dataclass(frozen=True)
class GPUWhitelistPriceRow:
    component_id: str
    name: str
    used_price: Optional[int]
    new_price: Optional[int]
    source: str
    approved_at: datetime


@dataclass(frozen=True)
class MotherboardWhitelistPriceRow:
    component_id: str
    name: str
    platform: str
    used_price: Optional[int]
    new_price: Optional[int]
    status: str
    source: str
    approved_at: datetime


def read_approved_price_rows(path: Path, approved_at: str) -> List[ApprovedPriceRow]:
    approved_at_dt = datetime.fromisoformat(approved_at).replace(tzinfo=ZoneInfo("Asia/Shanghai"))
    with Path(path).open(encoding="utf-8", newline="") as handle:
        rows = []
        for row in csv.DictReader(handle):
            if not row.get("reference_price"):
                continue
            rows.append(
                ApprovedPriceRow(
                    component_id=row["target_id"],
                    reference_price=int(float(row["reference_price"])),
                    price_range_low=_optional_int(row.get("normal_price_min")),
                    price_range_high=_optional_int(row.get("normal_price_max")),
                    accepted_count=int(row.get("accepted_count") or 0),
                    rejected_count=int(row.get("rejected_count") or 0),
                    review_reasons=[reason for reason in (row.get("review_reasons") or "").split("|") if reason],
                    source="approved-reference-prices.csv",
                    approved_at=approved_at_dt,
                )
            )
    return rows


def read_gpu_whitelist_price_rows(path: Path, approved_at: str) -> List[GPUWhitelistPriceRow]:
    approved_at_dt = datetime.fromisoformat(approved_at).replace(tzinfo=ZoneInfo("Asia/Shanghai"))
    with Path(path).open(encoding="utf-8", newline="") as handle:
        rows = []
        for row in csv.DictReader(handle):
            rows.append(
                GPUWhitelistPriceRow(
                    component_id=row["target_id"],
                    name=row["name"],
                    used_price=_optional_int(row.get("used_price")),
                    new_price=_optional_int(row.get("new_price")),
                    source=Path(path).name,
                    approved_at=approved_at_dt,
                )
            )
    return rows


def read_motherboard_whitelist_price_rows(path: Path, approved_at: str) -> List[MotherboardWhitelistPriceRow]:
    approved_at_dt = datetime.fromisoformat(approved_at).replace(tzinfo=ZoneInfo("Asia/Shanghai"))
    with Path(path).open(encoding="utf-8", newline="") as handle:
        rows = []
        for row in csv.DictReader(handle):
            rows.append(
                MotherboardWhitelistPriceRow(
                    component_id=row["target_id"],
                    name=row["name"],
                    platform=row["platform"],
                    used_price=_optional_int(row.get("used_price")),
                    new_price=_optional_int(row.get("new_price")),
                    status=row["status"],
                    source=Path(path).name,
                    approved_at=approved_at_dt,
                )
            )
    return rows


def _optional_int(value: Optional[str]) -> Optional[int]:
    if value in (None, ""):
        return None
    return int(float(value))
