"""Import zhuangjidiy.com parts without changing existing catalog rows.

Run from the backend environment with ``--dry-run`` first. ``--apply`` is the
only mode that commits new components and their prices.
"""

from __future__ import annotations

import argparse
import json
import sys
from datetime import datetime, timezone
from pathlib import Path


TOOL_ROOT = Path(__file__).resolve().parent
REPO_ROOT = TOOL_ROOT.parents[1]
sys.path.insert(0, str(TOOL_ROOT))
sys.path.insert(0, str(REPO_ROOT / "backend"))

from price_crawler.zhuangjidiy import deduplicate_parts, fetch_zhuangjidiy_parts  # noqa: E402


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--apply", action="store_true", help="commit new rows")
    parser.add_argument("--dry-run", action="store_true", help="fetch and report only (default)")
    parser.add_argument("--output", type=Path, help="write fetched rows as JSON")
    parser.add_argument("--delay", type=float, default=0.15)
    args = parser.parse_args()

    parts = fetch_zhuangjidiy_parts(delay_seconds=args.delay)
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps([part.__dict__ for part in parts], ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    from sqlalchemy import select

    from app.catalog.models import ComponentPrice, HardwareComponent
    from app.core.config import Settings
    from app.db import create_session_factory

    session_factory = create_session_factory(Settings())
    with session_factory() as session:
        existing = list(session.scalars(select(HardwareComponent)))
        new_parts, stats = deduplicate_parts(
            parts,
            ({"id": row.id, "category": row.category, "brand": row.brand, "name": row.name} for row in existing),
        )
        print(json.dumps({**stats, "apply": args.apply}, ensure_ascii=False))
        if not args.apply:
            return

        existing_price_ids = set(session.scalars(select(ComponentPrice.component_id)))
        now = datetime.now(timezone.utc)
        imported = 0
        pending_prices = []
        for part in new_parts:
            if part.component_id in existing_price_ids:
                continue
            session.add(
                HardwareComponent(
                    id=part.component_id,
                    category=part.category,
                    name=part.name,
                    brand=part.brand,
                    detail_raw=part.detail_raw,
                    specs=part.specs,
                    is_recommended=False,
                    status="active",
                )
            )
            pending_prices.append(
                ComponentPrice(
                    component_id=part.component_id,
                    reference_price=part.price,
                    price_range_low=None,
                    price_range_high=None,
                    source="zhuangjidiy.com",
                    accepted_count=0,
                    rejected_count=0,
                    review_reasons=[],
                    approved_at=now,
                )
            )
            imported += 1
        session.flush()
        session.add_all(pending_prices)
        session.commit()
        print(json.dumps({"imported": imported, "skipped_existing_prices": len(new_parts) - imported}, ensure_ascii=False))


if __name__ == "__main__":
    main()
