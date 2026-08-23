import csv
import json
from pathlib import Path

import app.builds.low_budget_catalog as low_budget_catalog
from fastapi.testclient import TestClient
from sqlalchemy import create_engine, func, select
from sqlalchemy.orm import Session, sessionmaker
from sqlalchemy.pool import StaticPool
from app.builds.customization import (
    customization_candidates,
    deterministic_customization,
)
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
from app.builds.models import BuildTemplate
from app.builds.repository import upsert_build_templates
from app.builds.service import BuildRequest, BuildTemplatePart
from app.builds.templates import read_build_template_inputs
from app.catalog.prices import read_approved_price_rows
from app.catalog.rule_specs import is_cpu_gpu_pairing_allowed
from app.catalog.repository import (
    list_component_prices,
    list_components,
    seed_component_prices,
    seed_hardware_components,
    update_recommended_components,
)
from app.catalog.seed import read_catalog_components
from app.core.config import Settings
from app.db import Base, get_session
from app.main import create_app


BACKEND_ROOT = Path(__file__).resolve().parents[1]
PROJECT_ROOT = BACKEND_ROOT.parent
DATA_DIR = BACKEND_ROOT / "data"
TEMPLATE_PATH = DATA_DIR / "low-budget-base-build-templates.json"
PRICE_PATH = DATA_DIR / "low-budget-base-reference-prices.csv"
RECOMMENDATION_PATH = DATA_DIR / "low-budget-base-recommendation-ids.txt"
AUDIT_PATH = DATA_DIR / "low-budget-base-audit.json"
MARKDOWN_PATH = PROJECT_ROOT / "docs" / "3000-7000-yuan-base-builds.md"
HIGH_TEMPLATE_PATH = DATA_DIR / "high-budget-base-build-templates.json"
HIGH_PRICE_PATH = DATA_DIR / "high-budget-base-reference-prices.csv"
HIGH_RECOMMENDATION_PATH = DATA_DIR / "high-budget-base-recommendation-ids.txt"
OFFICE_PRICE_PATH = DATA_DIR / "office-base-reference-prices.csv"
OFFICE_RECOMMENDATION_PATH = DATA_DIR / "office-base-recommendation-ids.txt"
SWIFT_CATALOG_PATH = PROJECT_ROOT / "May" / "May" / "Models" / "HardwareCatalog.swift"

EXPECTED_CONDITIONS = {
    "new": {role: "new" for role in REQUIRED_PART_ROLES},
    "used": {role: "used" for role in REQUIRED_PART_ROLES},
    "mixed": {
        "cpu": "used",
        "motherboard": "new",
        "gpu": "used",
        "ram": "used",
        "storage": "new",
        "psu": "new",
        "cooler": "used",
        "case": "used",
    },
}

KNOWN_IMPOSSIBLE_COMBINATIONS = {
    (budget, direction, purchase_mode)
    for budget in (3_000, 3_500)
    for direction in DIRECTIONS
    for purchase_mode in ("new", "mixed")
} | {(4_000, direction, "new") for direction in DIRECTIONS}
PENDING_REVIEW_CONDITION_PAIRS = set()


def generated_templates():
    return generate_low_budget_templates()


def generated_report():
    return low_budget_catalog.generate_low_budget_report()


def test_4500_plus_public_options_always_return_all_three_purchase_modes() -> None:
    engine = create_engine(
        "sqlite+pysqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(engine)
    session_factory = sessionmaker(bind=engine)
    templates = read_build_template_inputs(TEMPLATE_PATH)
    recommendation_ids = [
        component_id
        for component_id in RECOMMENDATION_PATH.read_text(encoding="utf-8").splitlines()
        if component_id
    ]

    with Session(engine) as session:
        seed_hardware_components(
            session,
            [
                *read_catalog_components(SWIFT_CATALOG_PATH),
                *read_catalog_components(SUPPORT_PART_PATH),
            ],
        )
        seed_component_prices(
            session,
            read_approved_price_rows(PRICE_PATH, approved_at="2026-08-22"),
        )
        update_recommended_components(session, recommendation_ids)
        upsert_build_templates(session, templates)

    app = create_app(Settings(_env_file=None, postgres_url=None, redis_url=None))

    def override_session():
        with session_factory() as session:
            yield session

    app.dependency_overrides[get_session] = override_session
    response = TestClient(app).post(
        "/v1/build/options",
        json={
            "budget": 4500,
            "use_case": "游戏",
            "game_categories": ["黑神话悟空"],
            "direction": "aaa",
            "ray_tracing": True,
            "memory_size": "16GB",
            "storage_size": "512GB",
        },
    )

    assert response.status_code == 200
    body = response.json()
    assert {option["details"]["purchase_mode"] for option in body["options"]} == {
        "new",
        "used",
        "mixed",
    }
    assert body["unavailable_modes"] == []

    low_budget_special_game = TestClient(app).post(
        "/v1/build/options",
        json={
            "budget": 5100,
            "use_case": "游戏",
            "game_categories": ["PUBG"],
            "memory_size": "16GB",
            "storage_size": "512GB",
        },
    )
    assert low_budget_special_game.status_code == 200
    assert {
        option["details"]["purchase_mode"]
        for option in low_budget_special_game.json()["options"]
    } == {"new", "used", "mixed"}


def test_gpu_vendor_split_thresholds() -> None:
    assert low_budget_catalog._gpu_vendors_for(7_500, "aaa", "new") == (None,)
    assert low_budget_catalog._gpu_vendors_for(5_500, "aaa", "used") == (None,)
    assert low_budget_catalog._gpu_vendors_for(6_000, "aaa", "used") == (
        "nvidia",
        "amd",
    )
    assert low_budget_catalog._gpu_vendors_for(6_500, "aaa", "mixed") == (None,)
    assert low_budget_catalog._gpu_vendors_for(7_000, "aaa", "mixed") == (
        "nvidia",
        "amd",
    )


def test_generates_every_low_budget_direction_with_only_feasible_modes() -> None:
    templates = generated_templates()
    keys = {
        (
            template.details.target_budget,
            template.details.direction,
            template.details.purchase_mode,
            template.details.gpu_vendor,
        )
        for template in templates
    }

    assert BUDGET_TIERS == list(range(3_000, 7_001, 500))
    assert templates
    assert len({template.id for template in templates}) == len(templates)
    assert len(keys) == len(templates)

    available_budgets = set(BUDGET_TIERS)
    assert {
        template.details.target_budget for template in templates
    } == available_budgets

    for budget in available_budgets:
        assert {
            template.details.direction
            for template in templates
            if template.details.target_budget == budget
        } == set(DIRECTIONS)

    for template in templates:
        details = template.details
        expected_id = f"base-{details.target_budget}-{details.direction}-{details.purchase_mode}"
        if details.gpu_vendor == "amd" and details.target_budget >= 5_000 and details.direction != "fps":
            expected_id += "-amd"
        assert template.id == expected_id

    for budget in range(5_000, 7_001, 500):
        for direction in ("aaa", "balanced"):
            for purchase_mode in PURCHASE_MODES:
                actual = [
                    template
                    for template in templates
                    if template.details.target_budget == budget
                    and template.details.direction == direction
                    and template.details.purchase_mode == purchase_mode
                ]
                expected_vendor_count = len(
                    low_budget_catalog._gpu_vendors_for(
                        budget, direction, purchase_mode
                    )
                )
                assert len(actual) <= expected_vendor_count
                if expected_vendor_count == 2:
                    assert {
                        template.details.gpu_vendor for template in actual
                    } == {"nvidia", "amd"}


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
        allowed_shortfall = (
            1_000
            if template.id in {"base-5000-aaa-used-amd", "base-5000-aaa-mixed"}
            else 100
        )
        assert details.target_budget - allowed_shortfall <= template.estimated_total
        max_overage = 600 if details.target_budget == 3_000 else 500
        assert template.estimated_total <= details.target_budget + max_overage
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
    _, _, _, support_parts = low_budget_catalog._load_catalog()

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
        assert parts["ram"].specs["capacity_gb"] == 16
        required_psu_watt = minimum_psu_watt(
            parts["cpu"].component_id,
            parts["gpu"].component_id,
        )
        expected_psu = low_budget_catalog._smallest_psu(
            required_psu_watt,
            parts["psu"].condition,
            support_parts,
        )
        assert expected_psu is not None
        assert parts["psu"].component_id == expected_psu.component_id
        if (
            low_budget_catalog.GPU_TDP[parts["gpu"].component_id] >= 140
            and parts["gpu"].component_id != "rx-7650-gre"
        ):
            assert parts["psu"].component_id != "base-psu-550w"
        assert (
            parts["storage"].component_id
            == "base-ssd-fanxiang-s500-pro-512gb"
        )
        expected_vendor = (
            "nvidia" if parts["gpu"].component_id.startswith("rtx-") else "amd"
        )
        assert template.details.gpu_vendor == expected_vendor
        if parts["gpu"].condition == "new" and parts["gpu"].component_id.startswith(
            "rtx-40"
        ):
            assert parts["gpu"].component_id == "rtx-4060"
        assert not (
            parts["gpu"].condition == "new"
            and parts["gpu"].component_id == "rtx-4060-ti"
        )

        if "x3d" in parts["cpu"].component_id or parts["cpu"].component_id == "i5-12600kf":
            assert parts["cooler"].component_id == (
                "base-cooler-dual-tower-6-heatpipe"
            )


def test_6000_plus_builds_do_not_use_5600_series_cpus() -> None:
    for template in generated_templates():
        if template.details.target_budget < 6_000:
            continue
        cpu = next(part for part in template.details.parts if part.role == "cpu")
        assert cpu.component_id not in {"r5-5600", "r5-5600x"}, template.id


def test_every_low_budget_build_respects_the_cpu_gpu_pairing_table() -> None:
    for template in generated_templates():
        parts = {part.role: part for part in template.details.parts}
        assert is_cpu_gpu_pairing_allowed(
            parts["cpu"].component_id,
            parts["gpu"].component_id,
        ), template.id


def test_am4_board_uses_a520_only_below_4500_with_7650_gre_class_gpu() -> None:
    for template in generated_templates():
        parts = {part.role: part for part in template.details.parts}
        if parts["cpu"].component_id not in {"r5-5600", "r5-5600x"}:
            continue
        expected_board = (
            "asus-a520m-k"
            if template.details.target_budget < 4_500
            and GPU_PERFORMANCE[parts["gpu"].component_id]
            <= GPU_PERFORMANCE["rx-7650-gre"]
            else "asus-b550m-plus"
        )
        assert parts["motherboard"].component_id == expected_board, template.id


def test_5600x_is_not_paired_with_4070_super_or_7900_xt() -> None:
    forbidden_gpus = {"rtx-4070-super", "rx-7900-xt"}
    assert all(
        not (
            next(part for part in template.details.parts if part.role == "cpu").component_id
            == "r5-5600x"
            and next(part for part in template.details.parts if part.role == "gpu").component_id
            in forbidden_gpus
        )
        for template in generated_templates()
    )


def test_aaa_builds_only_step_up_motherboard_to_reach_budget_floor() -> None:
    _, motherboards, _, _ = low_budget_catalog._load_catalog()

    for template in generated_templates():
        if template.details.direction != "aaa":
            continue
        parts = {part.role: part for part in template.details.parts}
        expected = low_budget_catalog._cheapest_adequate_motherboard(
            parts["cpu"].component_id,
            str(parts["cpu"].specs["socket"]),
            parts["motherboard"].condition,
            motherboards,
        )
        assert expected is not None
        chosen_price = parts["motherboard"].reference_price
        cheapest_price = expected.price(parts["motherboard"].condition)
        assert cheapest_price is not None
        required_am4_board = (
            parts["cpu"].component_id in {"r5-5600", "r5-5600x"}
            and parts["motherboard"].component_id
            == (
                "asus-a520m-k"
                if template.details.target_budget < 4_500
                and GPU_PERFORMANCE[parts["gpu"].component_id]
                <= GPU_PERFORMANCE["rx-7650-gre"]
                else "asus-b550m-plus"
            )
        )
        if (
            parts["motherboard"].component_id != expected.component_id
            and not required_am4_board
        ):
            assert chosen_price <= template.details.target_budget * 0.15
        if (
            template.id not in {"base-5000-aaa-used-amd", "base-5000-aaa-mixed"}
            and not required_am4_board
        ):
            assert chosen_price <= cheapest_price + 300
        requires_b550 = (
            parts["cpu"].component_id in {"r5-5600", "r5-5600x"}
            and (
                template.details.target_budget >= 4_500
                or GPU_PERFORMANCE[parts["gpu"].component_id]
                > GPU_PERFORMANCE["rx-7650-gre"]
            )
        )
        if template.estimated_total - chosen_price + cheapest_price >= (
            template.details.target_budget - 100
        ) and not requires_b550:
            assert parts["motherboard"].component_id == expected.component_id


def test_b850_builds_only_use_user_approved_models() -> None:
    for template in generated_templates():
        motherboard = next(
            part for part in template.details.parts if part.role == "motherboard"
        )
        if motherboard.specs["chipset"] == "B850":
            assert motherboard.component_id in {
                "msi-b850m-power",
                "asus-b850m-awy",
            }


def test_fps_and_aaa_allocations_follow_their_performance_priorities() -> None:
    by_key = {
        (
            template.details.target_budget,
            template.details.purchase_mode,
            template.details.direction,
            template.details.gpu_vendor,
        ): template
        for template in generated_templates()
    }
    compared = 0

    for budget in BUDGET_TIERS:
        for purchase_mode in PURCHASE_MODES:
            fps = next(
                (
                    template
                    for template in generated_templates()
                    if template.details.target_budget == budget
                    and template.details.purchase_mode == purchase_mode
                    and template.details.direction == "fps"
                ),
                None,
            )
            aaa = (
                by_key.get(
                    (
                        budget,
                        purchase_mode,
                        "aaa",
                        fps.details.gpu_vendor,
                    )
                )
                if fps is not None
                else None
            )
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


def test_direction_scores_strictly_rank_cpu_and_gpu_priority() -> None:
    cpu_first = _ranking_candidate(cpu_performance=90, gpu_performance=50)
    gpu_first = _ranking_candidate(cpu_performance=60, gpu_performance=85)

    assert low_budget_catalog._score_candidate(
        cpu_first, "fps"
    ) > low_budget_catalog._score_candidate(gpu_first, "fps")
    assert low_budget_catalog._score_candidate(
        gpu_first, "aaa"
    ) > low_budget_catalog._score_candidate(cpu_first, "aaa")


def test_used_builds_at_5000_plus_avoid_legacy_mining_risk_gpus() -> None:
    legacy_prefixes = ("rtx-30", "rx-6")

    for template in generated_templates():
        if (
            template.details.target_budget < 5_000
            or template.details.purchase_mode != "used"
        ):
            continue
        gpu = next(part for part in template.details.parts if part.role == "gpu")
        assert not gpu.component_id.startswith(legacy_prefixes), template.id


def test_excluded_gpu_brand_is_allowed_only_at_or_below_5000() -> None:
    templates = generated_templates()
    assert all(
        "耕升" not in next(part for part in template.details.parts if part.role == "gpu").name
        for template in templates
        if template.details.target_budget > 5_000
    )


def test_9800x3d_requires_at_least_5060ti_class_gpu() -> None:
    minimum_gpu_performance = GPU_PERFORMANCE["rtx-5060-ti"]

    for template in generated_templates():
        parts = {part.role: part for part in template.details.parts}
        if parts["cpu"].component_id == "r7-9800x3d":
            assert (
                GPU_PERFORMANCE[parts["gpu"].component_id]
                >= minimum_gpu_performance
            ), template.id


def test_7000_used_fps_build_drops_9800x3d_for_a_modern_gpu() -> None:
    template = next(
        template
        for template in generated_templates()
        if template.details.target_budget == 7_000
        and template.details.direction == "fps"
        and template.details.purchase_mode == "used"
    )
    parts = {part.role: part for part in template.details.parts}

    assert parts["cpu"].component_id == "r7-7800x3d"
    assert not parts["gpu"].component_id.startswith(("rtx-30", "rx-6"))
    assert 6_900 <= template.estimated_total <= 7_500


def test_7000_new_aaa_build_keeps_value_parts() -> None:
    template = next(
        template
        for template in generated_templates()
        if template.id == "base-7000-aaa-new-amd"
    )
    parts = {part.role: part for part in template.details.parts}

    assert parts["motherboard"].component_id == "asus-prime-b650m-k"
    assert parts["cpu"].component_id == "r5-7500f"
    assert parts["gpu"].component_id == "rx-9070-gre"
    assert parts["ram"].specs["capacity_gb"] == 16
    assert parts["storage"].component_id == "base-ssd-fanxiang-s500-pro-512gb"
    assert parts["psu"].component_id == "base-psu-650w-gold"
    assert parts["psu"].reference_price == 299
    assert 6_900 <= template.estimated_total <= 7_500


def test_7000_mixed_nvidia_aaa_build_prioritizes_gpu() -> None:
    template = next(
        template
        for template in generated_templates()
        if template.id == "base-7000-aaa-mixed"
    )
    parts = {part.role: part for part in template.details.parts}

    assert parts["cpu"].component_id == "r5-9600x"
    assert parts["gpu"].component_id == "rtx-5060-ti"
    assert parts["gpu"].condition == "used"
    assert parts["motherboard"].reference_price <= 7_000 * 0.15
    assert 6_900 <= template.estimated_total <= 7_500


def test_5500_mixed_nvidia_aaa_build_reaches_5060_class() -> None:
    template = next(
        template
        for template in generated_templates()
        if template.id == "base-5500-aaa-mixed"
    )
    parts = {part.role: part for part in template.details.parts}

    assert GPU_PERFORMANCE[parts["gpu"].component_id] >= GPU_PERFORMANCE["rtx-5060"]
    assert 5_400 <= template.estimated_total <= 6_000


def test_6000_new_fps_uses_the_best_option_after_rtx_5060_price_update() -> None:
    template = next(
        template
        for template in generated_templates()
        if template.id == "base-6000-fps-new"
    )
    parts = {part.role: part for part in template.details.parts}

    assert parts["cpu"].component_id == "i5-12600kf"
    assert parts["gpu"].component_id == "rx-7700-xt"
    assert parts["ram"].specs["type"] == "DDR4"
    assert 5_900 <= template.estimated_total <= 6_500


def test_6000_new_aaa_build_uses_best_fitting_pair() -> None:
    template = next(
        template
        for template in generated_templates()
        if template.id == "base-6000-aaa-new-amd"
    )
    parts = {part.role: part for part in template.details.parts}

    assert parts["cpu"].component_id == "i5-12600kf"
    assert parts["gpu"].component_id == "rx-7700-xt"
    assert parts["gpu"].reference_price == 2_600
    assert 5_900 <= template.estimated_total <= 6_500


def test_6000_new_balanced_build_remains_balanced() -> None:
    template = next(
        template
        for template in generated_templates()
        if template.id == "base-6000-balanced-new-amd"
    )
    parts = {part.role: part for part in template.details.parts}

    assert parts["cpu"].component_id == "i5-12600kf"
    assert parts["gpu"].component_id == "rx-7700-xt"
    assert GPU_PERFORMANCE[parts["gpu"].component_id] >= 40
    assert 5_900 <= template.estimated_total <= 6_500


def test_6000_used_and_mixed_builds_keep_feasible_pairs() -> None:
    templates = [
        template
        for template in generated_templates()
        if template.details.target_budget == 6_000
        and template.details.purchase_mode in {"used", "mixed"}
    ]

    assert templates
    assert all(5_900 <= template.estimated_total <= 6_500 for template in templates)


def test_6500_mixed_fps_build_keeps_a_table_valid_cpu_priority() -> None:
    template = next(
        template
        for template in generated_templates()
        if template.id == "base-6500-fps-mixed"
    )
    parts = {part.role: part for part in template.details.parts}

    assert parts["cpu"].component_id == "r7-7800x3d"
    assert parts["gpu"].component_id == "rx-7700-xt"
    assert not parts["gpu"].component_id.startswith(("rtx-30", "rx-6"))
    assert 6_400 <= template.estimated_total <= 7_000


def test_4070_ti_remains_excluded_from_the_generated_gpu_pool() -> None:
    _, _, gpus, _ = low_budget_catalog._load_catalog()
    assert "rtx-4070-ti" not in {gpu.component_id for gpu in gpus}


def test_4070_ti_super_is_available_to_the_generated_gpu_pool() -> None:
    _, _, gpus, _ = low_budget_catalog._load_catalog()
    assert "rtx-4070-ti-super" in {gpu.component_id for gpu in gpus}


def test_support_components_use_current_user_models_and_prices() -> None:
    _, motherboards, _, support_parts = low_budget_catalog._load_catalog()
    boards = {part.component_id: part for part in motherboards}

    assert boards["asus-prime-b650m-k"].new_price == 700
    assert boards["asus-prime-b650m-k"].used_price == 450
    assert boards["asus-b550m-plus"].used_price == 450
    assert boards["asus-b550m-plus"].new_price == 750
    assert support_parts["base-ddr4-32gb-3200"].used_price == 550
    assert support_parts["base-ddr4-32gb-3200"].new_price == 750
    assert support_parts["base-ddr5-16gb-6000-c28"].used_price == 1350
    assert support_parts["base-ddr5-16gb-6000-c28"].new_price == 1650
    assert support_parts["base-ssd-512gb-tlc"].name == "宏碁掠夺者 GM7 512GB"
    assert support_parts["base-ssd-512gb-tlc"].used_price == 500
    assert support_parts["base-ssd-512gb-tlc"].new_price == 699
    assert support_parts["base-ssd-1tb-tlc"].name == "宏碁掠夺者 GM7 1TB"
    assert support_parts["base-ssd-1tb-tlc"].used_price == 900
    assert support_parts["base-ssd-1tb-tlc"].new_price == 1_199
    assert support_parts["base-ssd-2tb-tlc"].name == "宏碁掠夺者 GM7 1TB x2"
    assert support_parts["base-ssd-2tb-tlc"].used_price == 1_800
    assert support_parts["base-ssd-2tb-tlc"].new_price == 2_398
    assert (
        support_parts["base-ssd-fanxiang-s500-pro-512gb"].name
        == "梵想 S500 Pro 512GB"
    )
    assert support_parts["base-ssd-fanxiang-s500-pro-512gb"].used_price == 400
    assert support_parts["base-ssd-fanxiang-s500-pro-512gb"].new_price == 509
    assert support_parts["base-ssd-fanxiang-s790e-1tb"].name == "梵想 S790E 1TB"
    assert support_parts["base-ssd-fanxiang-s790e-1tb"].used_price == 750
    assert support_parts["base-ssd-fanxiang-s790e-1tb"].new_price == 968
    assert support_parts["base-psu-550w"].name == "玄武 550 V4 550W"
    assert support_parts["base-psu-550w"].new_price == 199
    assert support_parts["base-psu-650w-gold"].name == "安耐美 GN650 V3 650W"
    assert support_parts["base-psu-650w-gold"].used_price == 200
    assert support_parts["base-psu-650w-gold"].new_price == 299


def test_every_low_budget_am5_build_uses_ddr5_6000_c28() -> None:
    for template in generated_templates():
        parts = {part.role: part for part in template.details.parts}
        if parts["cpu"].specs["socket"] != "AM5":
            continue
        assert parts["ram"].specs["speed_mhz"] == 6_000, template.id
        assert parts["ram"].specs["cas_latency"] == 28, template.id


def test_cpu_whitelist_replaces_13600kf_with_12600kf() -> None:
    with CPU_PRICE_PATH.open(encoding="utf-8", newline="") as handle:
        rows = {row["target_id"]: row for row in csv.DictReader(handle)}

    assert "i5-13600kf" not in rows
    assert rows["i5-12600kf"]["used_price"] == "900"
    assert rows["i5-12600kf"]["new_tray_price"] == "900"


def test_rx_7800_xt_uses_the_updated_used_price() -> None:
    with GPU_PRICE_PATH.open(encoding="utf-8", newline="") as handle:
        rows = {row["target_id"]: row for row in csv.DictReader(handle)}

    assert rows["rx-7800-xt"]["used_price"] == "2700"
    assert rows["rx-9070-gre"]["used_price"] == "3500"
    assert rows["rx-9060-xt-8gb"]["used_price"] == "2000"
    assert rows["rx-7650-gre"]["new_price"] == "1900"


def test_5000_used_aaa_uses_the_strongest_table_valid_option() -> None:
    template = next(
        template
        for template in generated_templates()
        if template.id == "base-5000-aaa-used"
    )
    parts = {part.role: part for part in template.details.parts}

    assert parts["cpu"].component_id == "r5-5600x"
    assert parts["gpu"].component_id == "rtx-5060-ti"
    assert parts["gpu"].reference_price == 3099
    assert parts["motherboard"].component_id == "asus-b550m-plus"
    assert template.estimated_total == 5419


def test_5000_fps_new_uses_reviewed_rx_7650_gre_option() -> None:
    template = next(
        template
        for template in generated_templates()
        if template.id == "base-5000-fps-new"
    )
    parts = {part.role: part for part in template.details.parts}

    assert parts["gpu"].component_id == "rx-7650-gre"
    assert parts["gpu"].reference_price == 1900
    assert parts["psu"].component_id == "base-psu-750w-gold"
    assert template.estimated_total == 5268


def test_5000_fps_mixed_uses_reviewed_rx_9060_xt_8gb_option() -> None:
    template = next(
        template
        for template in generated_templates()
        if template.id == "base-5000-fps-mixed"
    )
    parts = {part.role: part for part in template.details.parts}

    assert parts["gpu"].component_id == "rx-9060-xt-8gb"
    assert parts["gpu"].reference_price == 2000
    assert template.estimated_total == 5138


def test_b760m_a_is_the_available_lga1700_base_board() -> None:
    with MOTHERBOARD_PRICE_PATH.open(encoding="utf-8", newline="") as handle:
        rows = {row["target_id"]: row for row in csv.DictReader(handle)}

    assert rows["msi-b760m-a"]["platform"] == "LGA1700"
    assert rows["msi-b760m-a"]["used_price"] == "550"
    assert rows["msi-b760m-a"]["new_price"] == "850"


def test_5000_mixed_amd_aaa_uses_12600kf_to_fund_a_stronger_gpu() -> None:
    template = next(
        template
        for template in generated_templates()
        if template.id == "base-5000-aaa-mixed-amd"
    )
    parts = {part.role: part for part in template.details.parts}

    assert parts["cpu"].component_id == "i5-12600kf"
    assert parts["gpu"].component_id == "rx-7700-xt"


def test_4000_fps_used_falls_back_to_rx_7650_gre_when_3070_ti_power_does_not_fit() -> None:
    template = next(
        template
        for template in generated_templates()
        if template.id == "base-4000-fps-used"
    )
    parts = {part.role: part for part in template.details.parts}

    assert parts["cpu"].component_id == "i5-12600kf"
    assert parts["gpu"].component_id == "rx-7650-gre"
    assert parts["psu"].component_id == "base-psu-750w-gold"


def test_3500_fps_used_avoids_legacy_mining_risk_when_modern_gpu_fits() -> None:
    template = next(
        template
        for template in generated_templates()
        if template.id == "base-3500-fps-used"
    )
    parts = {part.role: part for part in template.details.parts}

    assert parts["gpu"].component_id == "rx-7650-gre"
    assert not parts["gpu"].component_id.startswith(("rtx-30", "rx-6"))
    assert parts["gpu"].reference_price == 1_400


def test_4500_fps_used_uses_the_12600kf_pairing_column() -> None:
    template = next(
        template
        for template in generated_templates()
        if template.id == "base-4500-fps-used"
    )
    parts = {part.role: part for part in template.details.parts}

    assert parts["cpu"].component_id == "i5-12600kf"
    assert parts["motherboard"].component_id == "msi-b760m-a"
    assert parts["motherboard"].reference_price == 550
    assert parts["gpu"].component_id == "rx-7700-xt"
    assert template.estimated_total == 4679


def test_3060_ti_is_removed_from_the_gpu_whitelist() -> None:
    with GPU_PRICE_PATH.open(encoding="utf-8", newline="") as handle:
        rows = {row["target_id"]: row for row in csv.DictReader(handle)}

    assert "rtx-3060-ti" not in rows
    assert rows["rtx-3070-ti"]["used_price"] == "1600"


def test_rx_7650_gre_only_uses_550w_with_a_65w_class_cpu() -> None:
    _, _, _, support_parts = low_budget_catalog._load_catalog()

    assert minimum_psu_watt("r5-5600x", "rx-7650-gre") == 550
    assert minimum_psu_watt("i5-12600kf", "rx-7650-gre") == 670
    assert (
        low_budget_catalog._smallest_psu(
            minimum_psu_watt("i5-12600kf", "rx-7650-gre"),
            "new",
            support_parts,
        ).component_id
        == "base-psu-750w-gold"
    )


def test_rx_7700_xt_uses_at_least_750w_power_supply() -> None:
    assert minimum_psu_watt("r5-5600x", "rx-7700-xt") == 750


def test_rtx_3070_ti_uses_at_least_750w_power_supply() -> None:
    _, _, _, support_parts = low_budget_catalog._load_catalog()

    assert minimum_psu_watt("r5-5600x", "rtx-3070-ti") == 750
    assert (
        low_budget_catalog._smallest_psu(
            minimum_psu_watt("r5-5600x", "rtx-3070-ti"),
            "new",
            support_parts,
        ).component_id
        == "base-psu-750w-gold"
    )


def test_5000_aaa_reviewed_builds_remain_table_valid() -> None:
    templates = {item.id: item for item in generated_templates()}

    used_parts = {
        part.role: part for part in templates["base-5000-aaa-used"].details.parts
    }
    mixed_parts = {
        part.role: part for part in templates["base-5000-aaa-mixed-amd"].details.parts
    }

    assert used_parts["gpu"].component_id == "rtx-5060-ti"
    assert used_parts["motherboard"].component_id == "asus-b550m-plus"
    assert mixed_parts["cpu"].component_id == "i5-12600kf"
    assert mixed_parts["gpu"].component_id == "rx-7700-xt"
    assert mixed_parts["motherboard"].component_id == "msi-b760m-a"
    assert mixed_parts["psu"].component_id == "base-psu-750w-gold"


def test_rtx_4060_and_4060_ti_are_used_only_after_discontinuation() -> None:
    _, _, gpus, _ = low_budget_catalog._load_catalog()
    by_id = {gpu.component_id: gpu for gpu in gpus}

    assert by_id["rtx-4060"].used_price == 1_999
    assert by_id["rtx-4060"].new_price is None
    assert not low_budget_catalog._condition_is_allowed(by_id["rtx-4060"], "new")
    assert by_id["rtx-4060-ti"].used_price == 2_300
    assert by_id["rtx-4060-ti"].new_price is None
    assert low_budget_catalog._condition_is_allowed(by_id["rtx-4060-ti"], "used")


def test_selection_reports_over_budget_separately_from_no_candidate() -> None:
    cpus, motherboards, gpus, support_parts = low_budget_catalog._load_catalog()

    over_budget = low_budget_catalog._select_candidate(
        0,
        "fps",
        "used",
        cpus,
        motherboards,
        gpus,
        support_parts,
    )
    no_candidate = low_budget_catalog._select_candidate(
        3_000,
        "fps",
        "used",
        [],
        [],
        [],
        support_parts,
    )

    assert over_budget.candidate is None
    assert over_budget.skip_reason == "over_budget"
    assert no_candidate.candidate is None
    assert no_candidate.skip_reason == "no_feasible_candidate"


def test_reference_export_preserves_source_condition_prices(tmp_path) -> None:
    report = generated_report()
    templates = list(report.templates)
    paths = write_low_budget_artifacts(
        tmp_path,
        templates,
        source_parts=report.source_parts,
    )
    rows = _price_rows(paths.reference_prices_csv)
    referenced_ids = {
        part.component_id
        for template in report.templates
        for part in template.details.parts
    }
    referenced_ids.update(low_budget_catalog.CUSTOMIZATION_SUPPORT_IDS)
    source_by_id = {
        part.component_id: part
        for part in report.source_parts
        if part.component_id in referenced_ids
    }

    for component_id, row in rows.items():
        source = source_by_id[component_id]
        used_price = source.used_price
        new_price = source.new_price
        assert row["normal_price_min"] == (str(used_price) if used_price else "")
        assert row["normal_price_max"] == (str(new_price) if new_price else "")
        assert row["reference_price"] in {
            str(value) for value in (used_price, new_price) if value
        }

    assert rows["base-ddr4-32gb-3200"]["normal_price_min"] == "550"
    assert rows["base-ddr4-32gb-3200"]["normal_price_max"] == "750"
    assert "base-ddr4-32gb-3200" in paths.recommendation_ids.read_text(
        encoding="utf-8"
    ).splitlines()


def test_unreferenced_pending_psu_condition_is_excluded_from_low_budget_artifacts(
    tmp_path,
) -> None:
    report = generated_report()
    templates = list(report.templates)
    template_pairs = {
        (part.component_id, part.condition)
        for template in templates
        for part in template.details.parts
    }
    assert PENDING_REVIEW_CONDITION_PAIRS.isdisjoint(template_pairs)

    paths = write_low_budget_artifacts(
        tmp_path,
        templates,
        source_parts=report.source_parts,
    )
    assert PENDING_REVIEW_CONDITION_PAIRS.isdisjoint(
        _exported_condition_pairs(paths.reference_prices_csv)
    )


def test_reference_export_uses_the_generated_snapshot_after_source_mutation(
    tmp_path,
    monkeypatch,
) -> None:
    report = generated_report()
    templates = list(report.templates)
    mutated_cpu_path = tmp_path / CPU_PRICE_PATH.name
    original = CPU_PRICE_PATH.read_text(encoding="utf-8")
    mutated = original.replace(
        "r5-5600x,R5 5600X,720,820",
        "r5-5600x,R5 5600X,1,2",
    )
    assert mutated != original
    mutated_cpu_path.write_text(mutated, encoding="utf-8")
    monkeypatch.setattr(low_budget_catalog, "CPU_PRICE_PATH", mutated_cpu_path)

    paths = write_low_budget_artifacts(
        tmp_path / "artifacts",
        templates,
        source_parts=report.source_parts,
    )
    row = _price_rows(paths.reference_prices_csv)["r5-5600x"]
    observed = {
        part.condition: part.reference_price
        for template in templates
        for part in template.details.parts
        if part.component_id == "r5-5600x"
    }

    assert row["normal_price_min"] == str(observed["used"])
    assert row["normal_price_max"] == str(observed["new"])


def test_empty_and_partial_artifacts_report_actual_completion(tmp_path) -> None:
    full_templates = generated_templates()
    cases = (
        ("empty", [], [], 0, 0),
        ("partial", [full_templates[0]], [], 1, 1),
    )
    for name, templates, completed_tiers, completed_pairs, visible_tiers in cases:
        paths = write_low_budget_artifacts(tmp_path / name, templates)
        audit = json.loads(paths.audit_json.read_text(encoding="utf-8"))
        markdown = paths.review_markdown.read_text(encoding="utf-8")

        assert audit["completed_tiers"] == completed_tiers
        assert audit["completed_tier_direction_count"] == completed_pairs
        assert audit["completed_template_count"] == len(templates)
        assert {item["reason"] for item in audit["skipped_combinations"]} == {
            "missing_evidence"
        }
        assert audit["missing_data"] == audit["skipped_combinations"]
        assert audit["failed_templates"] == []
        assert f"{len(completed_tiers)}/9个价位" in markdown
        assert (
            sum(line.startswith("## ") for line in markdown.splitlines())
            == visible_tiers
        )


def test_failed_template_audit_is_derived_from_skip_evidence(tmp_path) -> None:
    failed = low_budget_catalog.SkippedCombination(
        target_budget=3_000,
        direction="fps",
        purchase_mode="new",
        reason="generation_error",
    )
    paths = write_low_budget_artifacts(
        tmp_path,
        [],
        skipped_combinations=[failed],
    )
    audit = json.loads(paths.audit_json.read_text(encoding="utf-8"))

    assert audit["failed_templates"] == [failed.as_dict()]
    assert failed.as_dict() not in audit["missing_data"]


def test_skipped_modes_are_absent_and_audited(
    tmp_path,
) -> None:
    report = generated_report()
    templates = list(report.templates)
    generated_keys = {
        (
            template.details.target_budget,
            template.details.direction,
            template.details.purchase_mode,
            template.details.gpu_vendor,
        )
        for template in templates
    }
    skipped_keys = {
        (item.target_budget, item.direction, item.purchase_mode, item.gpu_vendor)
        for item in report.skipped_combinations
    }
    assert skipped_keys.isdisjoint(generated_keys)

    paths = write_low_budget_artifacts(
        tmp_path,
        templates,
        skipped_combinations=report.skipped_combinations,
        source_parts=report.source_parts,
    )
    audit = json.loads(paths.audit_json.read_text(encoding="utf-8"))
    skip_reasons = {
        (
            item["target_budget"],
            item["direction"],
            item["purchase_mode"],
            item.get("gpu_vendor"),
        ): item["reason"]
        for item in audit["skipped_combinations"]
    }
    assert audit["completed_template_count"] == len(templates)
    assert audit["completed_tiers"] == BUDGET_TIERS
    assert audit["completed_tier_direction_count"] == 27
    assert len(audit["skipped_combinations"]) == len(report.skipped_combinations)
    assert set(skip_reasons.values()) <= {
        "over_budget",
        "no_feasible_candidate",
    }
    assert audit["missing_data"] == []
    assert audit["failed_templates"] == []


def test_high_then_low_price_import_keeps_generated_templates_valid() -> None:
    engine = create_engine("sqlite+pysqlite:///:memory:")
    Base.metadata.create_all(engine)
    components = [
        *read_catalog_components(SWIFT_CATALOG_PATH),
        *read_catalog_components(SUPPORT_PART_PATH),
    ]
    high_prices = read_approved_price_rows(
        HIGH_PRICE_PATH,
        approved_at="2026-07-12",
    )
    low_prices = read_approved_price_rows(
        PRICE_PATH,
        approved_at="2026-07-12",
    )
    high_templates = read_build_template_inputs(HIGH_TEMPLATE_PATH)
    low_templates = read_build_template_inputs(TEMPLATE_PATH)
    recommendation_ids = sorted(
        {
            component_id
            for template in [*high_templates, *low_templates]
            for component_id in template.components.values()
        }
    )

    with Session(engine) as session:
        seed_hardware_components(session, components)
        update_recommended_components(session, recommendation_ids)
        seed_component_prices(session, high_prices)
        seed_component_prices(session, low_prices)
        imported = upsert_build_templates(
            session,
            [*high_templates, *low_templates],
        )
        stored = session.scalar(select(func.count()).select_from(BuildTemplate))

    assert high_templates
    assert low_templates
    assert imported == stored == len(high_templates) + len(low_templates)


def test_6000_yuan_32gb_1tb_request_uses_feasible_lower_reviewed_bases() -> None:
    engine = create_engine("sqlite+pysqlite:///:memory:")
    Base.metadata.create_all(engine)
    components = [
        *read_catalog_components(SWIFT_CATALOG_PATH),
        *read_catalog_components(SUPPORT_PART_PATH),
    ]
    prices = [
        *read_approved_price_rows(HIGH_PRICE_PATH, approved_at="2026-08-21"),
        *read_approved_price_rows(PRICE_PATH, approved_at="2026-08-21"),
        *read_approved_price_rows(OFFICE_PRICE_PATH, approved_at="2026-08-21"),
    ]
    templates = [
        *read_build_template_inputs(TEMPLATE_PATH),
        *read_build_template_inputs(HIGH_TEMPLATE_PATH),
    ]
    recommendation_ids = sorted(
        {
            component_id
            for path in (
                RECOMMENDATION_PATH,
                HIGH_RECOMMENDATION_PATH,
                OFFICE_RECOMMENDATION_PATH,
            )
            for component_id in path.read_text(encoding="utf-8").splitlines()
            if component_id
        }
    )

    with Session(engine) as session:
        seed_hardware_components(session, components)
        seed_component_prices(session, prices)
        update_recommended_components(session, recommendation_ids)
        upsert_build_templates(session, templates)
        stored_templates = list(session.scalars(select(BuildTemplate)))
        components_by_id = {item.id: item for item in list_components(session)}
        prices_by_id = {
            item.component_id: item for item in list_component_prices(session)
        }

        expected_modes = (("used", "nvidia"), ("new", "amd"), ("mixed", "amd"))
        for purchase_mode, gpu_vendor in expected_modes:
            request = BuildRequest(
                budget=6000,
                use_case="游戏",
                direction="balanced",
                memory_size="32GB",
                storage_size="1TB",
                gpu_preference=gpu_vendor,
            )
            candidates = customization_candidates(
                request,
                stored_templates,
                components_by_id,
                prices_by_id,
                purchase_mode=purchase_mode,
                gpu_vendor=gpu_vendor,
            )
            option = deterministic_customization(
                request,
                candidates,
                components_by_id,
                prices_by_id,
            )

            assert option is not None
            assert 5800 <= option.estimated_total <= 6300
            parts = {part.role: part for part in option.details.parts}
            assert parts["ram"].specs["capacity_gb"] == 32
            if parts["motherboard"].specs["socket"] == "AM5":
                assert parts["ram"].specs["speed_mhz"] == 6000
                assert parts["ram"].specs["cas_latency"] == 28
            assert parts["storage"].specs["capacity_gb"] == 1024
            if purchase_mode == "mixed" and gpu_vendor == "amd":
                assert parts["psu"].component_id == "base-psu-750w-gold"

        direction_options = {}
        for direction in ("fps", "aaa"):
            request = BuildRequest(
                budget=7000,
                use_case="游戏",
                direction=direction,
                memory_size="16GB",
                storage_size="1TB",
                needs_wireless_network=True,
                preferences=["FPS" if direction == "fps" else "3A", "全新"],
            )
            candidates = customization_candidates(
                request,
                stored_templates,
                components_by_id,
                prices_by_id,
                purchase_mode="new",
                gpu_vendor=None,
            )
            option = deterministic_customization(
                request,
                candidates,
                components_by_id,
                prices_by_id,
            )

            assert option is not None
            direction_options[direction] = {
                part.role: part for part in option.details.parts
            }

        assert direction_options["fps"]["cpu"].component_id == "i5-12600kf"
        assert direction_options["fps"]["gpu"].component_id == "rtx-5060"
        assert direction_options["aaa"]["cpu"].component_id not in {
            "r5-5600",
            "r5-5600x",
        }
        assert (
            direction_options["aaa"]["gpu"].specs["perf_index"]
            > direction_options["fps"]["gpu"].specs["perf_index"]
        )


def test_writes_deterministic_review_and_import_artifacts(tmp_path) -> None:
    report = generated_report()
    templates = list(report.templates)
    markdown = render_low_budget_markdown(
        templates,
        report.skipped_combinations,
    )
    paths = write_low_budget_artifacts(
        tmp_path,
        templates,
        skipped_combinations=report.skipped_combinations,
        source_parts=report.source_parts,
    )

    lines = markdown.splitlines()
    assert sum(line.startswith("## ") for line in lines) == len(BUDGET_TIERS)
    assert sum(line.startswith("### ") for line in lines) == len(templates)
    assert "**优点：**" not in markdown
    assert "**缺点：**" not in markdown
    assert "**风险：**" not in markdown

    payload = json.loads(paths.templates_json.read_text(encoding="utf-8"))
    assert len(payload) == len(templates)
    assert payload[0]["details"]["target_budget"] == 3_000
    assert all(
        {"advantages", "disadvantages", "risks"}.isdisjoint(item["details"])
        for item in payload
    )
    committed_payload = json.loads(TEMPLATE_PATH.read_text(encoding="utf-8"))
    assert all(
        {"advantages", "disadvantages", "risks"}.isdisjoint(item["details"])
        for item in committed_payload
    )
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


def _ranking_candidate(cpu_performance: int, gpu_performance: int):
    gpu = BuildTemplatePart(
        role="gpu",
        component_id="rx-ranking-test",
        name="ranking test GPU",
        condition="used",
        reference_price=1,
        price_source="test",
        price_date="2026-07-12",
        specs={},
    )
    return low_budget_catalog.Candidate(
        parts=(gpu,),
        total=1,
        cpu_performance=cpu_performance,
        gpu_performance=gpu_performance,
    )


def _price_rows(path: Path):
    with path.open(encoding="utf-8", newline="") as handle:
        return {row["target_id"]: row for row in csv.DictReader(handle)}


def _exported_condition_pairs(path: Path):
    pairs = set()
    for component_id, row in _price_rows(path).items():
        if row["normal_price_min"]:
            pairs.add((component_id, "used"))
        if row["normal_price_max"]:
            pairs.add((component_id, "new"))
    return pairs
