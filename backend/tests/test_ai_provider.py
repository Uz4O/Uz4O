import json
from datetime import datetime, timezone

import pytest

from app.builds.ai_provider import AIProviderError, select_build_with_deepseek
from app.builds.service import BuildRequest
from app.catalog.models import ComponentPrice, HardwareComponent
from app.core.config import Settings


def test_deepseek_provider_rejects_unsafe_base_url_before_network_request() -> None:
    with pytest.raises(AIProviderError, match="AI provider base URL is invalid"):
        select_build_with_deepseek(
            BuildRequest(budget=7000, use_case="gaming", preferences=[]),
            candidates_by_role={},
            price_by_component_id={},
            settings=Settings(
                _env_file=None,
                ai_provider_api_key="deepseek-secret",
                ai_provider_base_url="http://127.0.0.1:9000",
            ),
        )


def test_deepseek_provider_sends_frontend_preference_tokens(monkeypatch) -> None:
    captured_payload = {}

    class FakeResponse:
        def raise_for_status(self):
            return None

        def json(self):
            return {
                "choices": [
                    {
                        "message": {
                            "content": json.dumps(
                                {
                                    "components": {"cpu": "cpu-1"},
                                    "explanation": "受控选择。",
                                }
                            )
                        }
                    }
                ]
            }

    class FakeClient:
        def __init__(self, timeout):
            self.timeout = timeout

        def __enter__(self):
            return self

        def __exit__(self, exc_type, exc, traceback):
            return None

        def post(self, url, headers, json):
            captured_payload.update(json)
            return FakeResponse()

    monkeypatch.setattr("app.builds.ai_provider.httpx.Client", FakeClient)

    request = BuildRequest.model_validate(
        {
            "budget": 7000,
            "useCase": "游戏",
            "preferences": ["静音"],
            "gameCategories": ["FPS"],
            "purchasePreference": "全新优先",
            "chassisColorPreference": "曜石黑",
        }
    )
    component = HardwareComponent(
        id="cpu-1",
        category="cpu",
        name="CPU 1",
        brand="Intel",
        detail_raw="LGA1700",
        specs={"perf_index": 80},
        is_recommended=True,
        status="active",
    )
    price = ComponentPrice(
        component_id="cpu-1",
        reference_price=1200,
        price_range_low=1100,
        price_range_high=1300,
        source="manual",
        accepted_count=1,
        rejected_count=0,
        review_reasons=[],
        approved_at=datetime.now(timezone.utc),
    )

    select_build_with_deepseek(
        request,
        candidates_by_role={"cpu": [component]},
        price_by_component_id={"cpu-1": price},
        settings=Settings(
            _env_file=None,
            ai_provider_api_key="deepseek-secret",
            ai_provider_base_url="https://api.deepseek.com",
        ),
    )

    user_payload = json.loads(captured_payload["messages"][1]["content"])
    assert user_payload["preferences"] == ["静音", "FPS", "全新优先", "曜石黑"]
    assert {
        "phone",
        "account_id",
        "apple_sub",
        "nickname",
    }.isdisjoint(user_payload)
