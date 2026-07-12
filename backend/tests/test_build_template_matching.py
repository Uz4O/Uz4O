import pytest

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
