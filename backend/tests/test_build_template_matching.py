import pytest
from pydantic import ValidationError

from app.builds import service as build_service
from app.builds.models import BuildTemplate
from app.builds.service import BuildRequest, match_build_template


@pytest.mark.parametrize(
    ("games", "expected"),
    [
        (["瓦罗兰特"], "fps"),
        (["CS2"], "fps"),
        (["PUBG"], "fps"),
        (["瓦罗兰特", "CS2", "PUBG"], "fps"),
        (["什么都玩"], "balanced"),
        (["云顶之弈"], "balanced"),
        (["LOL"], "balanced"),
        (["COD"], "balanced"),
        (["城市天际线"], "balanced"),
        (["我的世界"], "balanced"),
        (["云顶之弈", "LOL", "COD", "城市天际线", "我的世界"], "balanced"),
        (["三角洲行动"], "aaa"),
        (["赛博朋克2077"], "aaa"),
        (["荒野大镖客2"], "aaa"),
        (["GTA5"], "aaa"),
        (["黑神话悟空"], "aaa"),
        (["地平线6"], "aaa"),
        (["艾尔登法环"], "aaa"),
        (
            [
                "三角洲行动",
                "赛博朋克2077",
                "荒野大镖客2",
                "GTA5",
                "黑神话悟空",
                "地平线6",
                "艾尔登法环",
            ],
            "aaa",
        ),
        (["瓦罗兰特", "黑神话悟空"], "balanced"),
        (["什么都玩", "瓦罗兰特"], "balanced"),
        ([], "balanced"),
        (["未知游戏"], "balanced"),
        (["瓦罗兰特", "未知游戏"], "balanced"),
    ],
)
def test_classify_game_direction(games: list[str], expected: str) -> None:
    assert build_service.classify_game_direction(games) == expected


def ready_option_payload() -> dict:
    components = {
        "cpu": "i5-14600k",
        "motherboard": "b760m",
        "gpu": "rtx-4060",
        "ram": "ram-6000-cl30",
        "storage": "ssd-1tb",
        "psu": "psu-750w",
        "cooler": "cooler-air",
        "case": "case-mid-tower",
    }
    return {
        "status": "ready",
        "source": "template",
        "template_id": "base-7500-fps-new",
        "title": "7500 元 FPS 全新基底配置",
        "components": components,
        "estimated_total": 7500,
        "explanation": "人工审核模板。",
        "details": {
            "target_budget": 7500,
            "direction": "fps",
            "purchase_mode": "new",
            "gpu_vendor": "nvidia",
            "parts": [
                {
                    "role": role,
                    "component_id": component_id,
                    "name": component_id,
                    "condition": "new",
                    "reference_price": 100,
                    "price_source": "test",
                    "price_date": "2026-07-12",
                    "specs": {},
                }
                for role, component_id in components.items()
            ],
            "suitable_user": "FPS 玩家",
            "price_date": "2026-07-12",
        },
    }


def test_build_option_response_accepts_ready_template_payload() -> None:
    option = build_service.BuildOptionResponse.model_validate(ready_option_payload())

    assert option.status == "ready"
    assert option.source == "template"
    assert option.details.gpu_vendor == "nvidia"
    assert {"advantages", "disadvantages", "risks"}.isdisjoint(
        option.details.model_dump()
    )
    assert "compatibility" not in option.model_dump()


def test_build_option_response_requires_eight_unique_part_roles() -> None:
    payload = ready_option_payload()
    payload["details"]["parts"].pop()

    with pytest.raises(ValidationError, match="eight unique parts"):
        build_service.BuildOptionResponse.model_validate(payload)


def test_build_option_response_requires_components_to_match_parts() -> None:
    payload = ready_option_payload()
    payload["components"]["gpu"] = "different-gpu"

    with pytest.raises(ValidationError, match="components must match detailed parts"):
        build_service.BuildOptionResponse.model_validate(payload)


@pytest.mark.parametrize("field", ["template_id", "details"])
def test_build_option_response_requires_structured_template_fields(field: str) -> None:
    missing_payload = ready_option_payload()
    missing_payload.pop(field)
    with pytest.raises(ValidationError):
        build_service.BuildOptionResponse.model_validate(missing_payload)

    null_payload = ready_option_payload()
    null_payload[field] = None
    with pytest.raises(ValidationError):
        build_service.BuildOptionResponse.model_validate(null_payload)


@pytest.mark.parametrize(
    ("field", "value"),
    [
        ("status", "needs_ai_generation"),
        ("source", "rules_fallback"),
        ("source", "ai_pending"),
    ],
)
def test_build_option_response_rejects_non_template_variants(
    field: str,
    value: str,
) -> None:
    payload = ready_option_payload()
    payload[field] = value

    with pytest.raises(ValidationError):
        build_service.BuildOptionResponse.model_validate(payload)


def template(
    template_id: str,
    budget_min: int,
    budget_max: int,
    use_cases: list[str],
    tags: list[str],
) -> BuildTemplate:
    return BuildTemplate(
        id=template_id,
        title=template_id,
        budget_min=budget_min,
        budget_max=budget_max,
        use_cases=use_cases,
        tags=tags,
        components={
            "cpu": "i5-14600k",
            "motherboard": "b760m",
            "ram": "ram-6000-cl30",
            "psu": "psu-750w",
        },
        estimated_total=7000,
        explanation="适合 2K 游戏。",
    )


def test_matches_template_by_budget_use_case_and_preferences() -> None:
    result = match_build_template(
        BuildRequest(budget=7000, use_case="gaming", preferences=["2k", "quiet"]),
        [
            template("office-4000", 3500, 4500, ["office"], ["quiet"]),
            template("gaming-7000-2k", 6500, 7500, ["gaming"], ["2k", "quiet"]),
        ],
    )

    assert result is not None
    assert result.id == "gaming-7000-2k"


def test_match_build_template_returns_first_ranked_candidate() -> None:
    request = BuildRequest(budget=7000, use_case="gaming", preferences=["2k"])
    templates = [
        template("z-good", 6500, 7500, ["gaming"], ["2k"]),
        template("a-bad", 6500, 7500, ["gaming"], ["2k"]),
    ]

    ranked = build_service.rank_build_templates(request, templates)
    matched = match_build_template(request, templates)

    assert [candidate.id for candidate in ranked] == ["a-bad", "z-good"]
    assert matched is not None
    assert matched.id == "a-bad"


def test_structured_defaults_do_not_outrank_a_closer_legacy_template() -> None:
    request = BuildRequest(budget=7000, use_case="gaming")
    legacy = template("legacy-close", 6900, 7100, ["gaming"], [])
    structured = template("structured-wide", 6000, 8000, ["gaming"], [])
    structured.details = {"direction": "balanced", "purchase_mode": "new"}

    ranked = build_service.rank_build_templates(request, [structured, legacy])

    assert [candidate.id for candidate in ranked] == ["legacy-close", "structured-wide"]


def test_matches_template_from_frontend_build_payload() -> None:
    request = BuildRequest.model_validate(
        {
            "budget": 7000,
            "useCase": "游戏",
            "gameCategories": ["FPS", "2K"],
            "purchasePreference": "全新优先",
            "chassisColor": "曜石黑",
            "cpuPreference": "任意",
            "specifiedCPU": "",
        }
    )

    result = match_build_template(
        request,
        [
            template("office-7000", 6500, 7500, ["办公"], ["全新优先"]),
            template("gaming-7000-fps", 6500, 7500, ["游戏"], ["FPS", "2K", "曜石黑"]),
        ],
    )

    assert request.use_case == "游戏"
    assert request.preference_tokens == [
        "FPS",
        "2K",
        "全新优先",
        "曜石黑",
        "任意",
    ]
    assert result is not None
    assert result.id == "gaming-7000-fps"


def test_returns_none_when_no_template_is_close_enough() -> None:
    result = match_build_template(
        BuildRequest(budget=4200, use_case="creator", preferences=["white", "itx"]),
        [template("gaming-7000-2k", 6500, 7500, ["gaming"], ["2k"])],
    )

    assert result is None
