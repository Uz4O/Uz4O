import csv
import json
from pathlib import Path

from app.builds.low_budget_catalog import (
    BUDGET_TIERS,
    CPU_PERFORMANCE,
    CPU_PRICE_PATH,
    DIRECTIONS,
    GPU_PERFORMANCE,
    GPU_PRICE_PATH,
    MOTHERBOARD_PRICE_PATH,
    PURCHASE_MODES,
    REQUIRED_PART_ROLES,
    SUPPORT_PART_PATH,
    generate_low_budget_templates,
    minimum_psu_watt,
    render_low_budget_markdown,
    write_low_budget_artifacts,
)


BACKEND_ROOT = Path(__file__).resolve().parents[1]
PROJECT_ROOT = BACKEND_ROOT.parent
DATA_DIR = BACKEND_ROOT / "data"
TEMPLATE_PATH = DATA_DIR / "low-budget-base-build-templates.json"
PRICE_PATH = DATA_DIR / "low-budget-base-reference-prices.csv"
RECOMMENDATION_PATH = DATA_DIR / "low-budget-base-recommendation-ids.txt"
AUDIT_PATH = DATA_DIR / "low-budget-base-audit.json"
MARKDOWN_PATH = PROJECT_ROOT / "docs" / "3000-7000-yuan-base-builds.md"

EXPECTED_CONDITIONS = {
    "new": {role: "new" for role in REQUIRED_PART_ROLES},
    "used": {role: "used" for role in REQUIRED_PART_ROLES},
    "mixed": {
        "cpu": "used",
        "motherboard": "new",
        "gpu": "new",
        "ram": "used",
        "storage": "new",
        "psu": "new",
        "cooler": "used",
        "case": "used",
    },
}

KNOWN_IMPOSSIBLE_COMBINATIONS = {
    (budget, direction, purchase_mode)
    for budget in (3_000, 3_500, 4_000)
    for direction in DIRECTIONS
    for purchase_mode in ("new", "mixed")
}


def generated_templates():
    return generate_low_budget_templates()


def test_generates_every_low_budget_direction_with_only_feasible_modes() -> None:
    templates = generated_templates()
    keys = {
        (
            template.details.target_budget,
            template.details.direction,
            template.details.purchase_mode,
        )
        for template in templates
    }

    assert BUDGET_TIERS == list(range(3_000, 7_001, 500))
    assert len(templates) >= len(BUDGET_TIERS) * len(DIRECTIONS)
    assert len({template.id for template in templates}) == len(templates)
    assert len(keys) == len(templates)

    for budget in BUDGET_TIERS:
        assert {
            template.details.direction
            for template in templates
            if template.details.target_budget == budget
        } == set(DIRECTIONS)

    for template in templates:
        details = template.details
        assert template.id == (
            f"base-{details.target_budget}-{details.direction}-{details.purchase_mode}"
        )


def test_every_template_has_eight_source_priced_parts_and_an_exact_total() -> None:
    source_prices = _source_prices()

    for template in generated_templates():
        details = template.details
        parts = {part.role: part for part in details.parts}

        assert len(details.parts) == len(REQUIRED_PART_ROLES)
        assert set(parts) == REQUIRED_PART_ROLES
        assert set(template.components) == REQUIRED_PART_ROLES
        assert template.components == {
            role: part.component_id for role, part in parts.items()
        }
        assert all(part.reference_price > 0 for part in parts.values())
        assert all(part.price_source for part in parts.values())
        assert all(part.price_date for part in parts.values())
        assert template.estimated_total == sum(
            part.reference_price for part in parts.values()
        )
        assert template.estimated_total <= details.target_budget + 200
        assert details.advantages
        assert details.disadvantages
        assert details.risks
        assert details.suitable_user

        for part in parts.values():
            price, source = source_prices[(part.component_id, part.condition)]
            assert part.reference_price == price
            assert part.price_source == source


def test_purchase_conditions_follow_the_three_exact_modes() -> None:
    for template in generated_templates():
        actual = {
            part.role: part.condition for part in template.details.parts
        }
        assert actual == EXPECTED_CONDITIONS[template.details.purchase_mode]


def test_generated_parts_are_compatible_and_new_slots_are_available() -> None:
    for template in generated_templates():
        parts = {part.role: part for part in template.details.parts}

        assert parts["cpu"].component_id in CPU_PERFORMANCE
        assert parts["gpu"].component_id in GPU_PERFORMANCE
        assert parts["cpu"].specs["socket"] == parts["motherboard"].specs[
            "socket"
        ]
        assert parts["motherboard"].specs["mem_type"] == parts["ram"].specs[
            "type"
        ]
        assert parts["psu"].specs["watt"] >= minimum_psu_watt(
            parts["cpu"].component_id,
            parts["gpu"].component_id,
        )
        if parts["gpu"].condition == "new":
            assert not parts["gpu"].component_id.startswith("rtx-40")

        if "x3d" in parts["cpu"].component_id or parts["cpu"].component_id == "i5-13600kf":
            assert parts["cooler"].component_id == (
                "base-cooler-dual-tower-6-heatpipe"
            )


def test_fps_and_aaa_allocations_follow_their_performance_priorities() -> None:
    by_key = {
        (
            template.details.target_budget,
            template.details.purchase_mode,
            template.details.direction,
        ): template
        for template in generated_templates()
    }
    compared = 0

    for budget in BUDGET_TIERS:
        for purchase_mode in PURCHASE_MODES:
            fps = by_key.get((budget, purchase_mode, "fps"))
            aaa = by_key.get((budget, purchase_mode, "aaa"))
            if fps is None or aaa is None:
                continue
            fps_parts = {part.role: part for part in fps.details.parts}
            aaa_parts = {part.role: part for part in aaa.details.parts}

            assert CPU_PERFORMANCE[fps_parts["cpu"].component_id] >= CPU_PERFORMANCE[
                aaa_parts["cpu"].component_id
            ]
            assert GPU_PERFORMANCE[aaa_parts["gpu"].component_id] >= GPU_PERFORMANCE[
                fps_parts["gpu"].component_id
            ]
            compared += 1

    assert compared >= len(BUDGET_TIERS)


def test_known_impossible_modes_are_absent_and_audited_as_over_budget(
    tmp_path,
) -> None:
    templates = generated_templates()
    generated_keys = {
        (
            template.details.target_budget,
            template.details.direction,
            template.details.purchase_mode,
        )
        for template in templates
    }
    assert KNOWN_IMPOSSIBLE_COMBINATIONS.isdisjoint(generated_keys)

    paths = write_low_budget_artifacts(tmp_path, templates)
    audit = json.loads(paths.audit_json.read_text(encoding="utf-8"))
    expected_skips = [
        {
            "target_budget": budget,
            "direction": direction,
            "purchase_mode": purchase_mode,
            "reason": "over_budget",
        }
        for budget in BUDGET_TIERS
        for direction in DIRECTIONS
        for purchase_mode in PURCHASE_MODES
        if (budget, direction, purchase_mode) not in generated_keys
    ]

    assert audit["completed_template_count"] == len(templates)
    assert audit["completed_tiers"] == BUDGET_TIERS
    assert audit["completed_tier_direction_count"] == 27
    assert audit["skipped_combinations"] == expected_skips
    assert audit["missing_data"] == []
    assert audit["failed_templates"] == []
    assert KNOWN_IMPOSSIBLE_COMBINATIONS.issubset(
        {
            (
                item["target_budget"],
                item["direction"],
                item["purchase_mode"],
            )
            for item in audit["skipped_combinations"]
        }
    )


def test_writes_deterministic_review_and_import_artifacts(tmp_path) -> None:
    templates = generated_templates()
    markdown = render_low_budget_markdown(templates)
    paths = write_low_budget_artifacts(tmp_path, templates)

    lines = markdown.splitlines()
    assert sum(line.startswith("## ") for line in lines) == len(BUDGET_TIERS)
    assert sum(line.startswith("### ") for line in lines) == len(templates)

    payload = json.loads(paths.templates_json.read_text(encoding="utf-8"))
    assert len(payload) == len(templates)
    assert payload[0]["details"]["target_budget"] == 3_000
    assert paths.review_markdown.read_text(encoding="utf-8") == markdown
    assert paths.templates_json.read_bytes() == TEMPLATE_PATH.read_bytes()
    assert paths.reference_prices_csv.read_bytes() == PRICE_PATH.read_bytes()
    assert paths.recommendation_ids.read_bytes() == RECOMMENDATION_PATH.read_bytes()
    assert paths.audit_json.read_bytes() == AUDIT_PATH.read_bytes()
    assert markdown.encode() == MARKDOWN_PATH.read_bytes()


def _source_prices():
    prices = {}
    csv_sources = (
        (CPU_PRICE_PATH, "used_price", "new_tray_price"),
        (GPU_PRICE_PATH, "used_price", "new_price"),
        (MOTHERBOARD_PRICE_PATH, "used_price", "new_price"),
    )
    for path, used_column, new_column in csv_sources:
        with path.open(encoding="utf-8", newline="") as handle:
            for row in csv.DictReader(handle):
                if row.get(used_column):
                    prices[(row["target_id"], "used")] = (
                        int(row[used_column]),
                        path.name,
                    )
                if row.get(new_column):
                    prices[(row["target_id"], "new")] = (
                        int(row[new_column]),
                        path.name,
                    )

    for item in json.loads(SUPPORT_PART_PATH.read_text(encoding="utf-8")):
        if item.get("used_price"):
            prices[(item["id"], "used")] = (
                item["used_price"],
                item["used_source"],
            )
        if item.get("new_price"):
            prices[(item["id"], "new")] = (
                item["new_price"],
                item["new_source"],
            )
    return prices
