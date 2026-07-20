import json
from datetime import datetime, timezone

import pytest

from app.builds.ai_provider import AIProviderError, select_build_with_deepseek
from app.builds.models import BuildTemplate
from app.builds.service import BuildRequest
from app.catalog.models import ComponentPrice, HardwareComponent
from app.core.config import Settings


def test_deepseek_provider_rejects_unsafe_base_url_before_network_request() -> None:
    with pytest.raises(AIProviderError, match="AI provider base URL is invalid"):
        select_build_with_deepseek(
            BuildRequest(budget=7000, use_case="gaming", direction="fps"),
            [base_template()],
            {"cpu-1": component()},
            {"cpu-1": component_price()},
            Settings(
                _env_file=None,
                ai_provider_api_key="deepseek-secret",
                ai_provider_base_url="http://127.0.0.1:9000",
            ),
        )


def test_deepseek_provider_sends_requirements_and_accepts_patch_only_output(
    monkeypatch,
) -> None:
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
                                    "base_template_id": "base-7000-fps-new",
                                    "patches": {
                                        "cpu": "cpu-1",
                                        "storage": "server-managed-storage",
                                    },
                                    "reasons": ["保留 FPS 方向并满足容量需求。"],
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
            "useCase": "游戏兼办公",
            "gameCategories": ["CS2"],
            "direction": "fps",
            "officeApps": ["Premiere"],
            "needsWirelessNetwork": True,
            "memorySize": "32GB",
            "storageSize": "2TB",
        }
    )

    result = select_build_with_deepseek(
        request,
        [base_template()],
        {"cpu-1": component()},
        {"cpu-1": component_price()},
        Settings(
            _env_file=None,
            ai_provider_api_key="deepseek-secret",
            ai_provider_base_url="https://api.deepseek.com",
        ),
    )

    user_payload = json.loads(captured_payload["messages"][1]["content"])
    assert user_payload["request"]["direction"] == "fps"
    assert user_payload["request"]["office_apps"] == ["Premiere"]
    assert user_payload["request"]["needs_wireless_network"] is True
    assert user_payload["request"]["memory_size"] == "32GB"
    assert user_payload["request"]["storage_size"] == "2TB"
    assert result.base_template_id == "base-7000-fps-new"
    assert result.patches == {"cpu": "cpu-1"}


def test_deepseek_provider_rejects_complete_or_invented_build_output(monkeypatch) -> None:
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
                                    "base_template_id": "base-7000-fps-new",
                                    "patches": {"cpu": "invented-cpu"},
                                    "reasons": ["错误输出"],
                                    "components": {"cpu": "invented-cpu"},
                                }
                            )
                        }
                    }
                ]
            }

    class FakeClient:
        def __init__(self, timeout):
            pass

        def __enter__(self):
            return self

        def __exit__(self, exc_type, exc, traceback):
            return None

        def post(self, url, headers, json):
            return FakeResponse()

    monkeypatch.setattr("app.builds.ai_provider.httpx.Client", FakeClient)
    with pytest.raises(AIProviderError, match="patch-only schema"):
        select_build_with_deepseek(
            BuildRequest(budget=7000, use_case="游戏", direction="fps"),
            [base_template()],
            {"cpu-1": component()},
            {"cpu-1": component_price()},
            Settings(
                _env_file=None,
                ai_provider_api_key="deepseek-secret",
                ai_provider_base_url="https://api.deepseek.com",
            ),
        )


def base_template() -> BuildTemplate:
    return BuildTemplate(
        id="base-7000-fps-new",
        title="7000 FPS 全新基底",
        budget_min=7000,
        budget_max=7499,
        use_cases=["游戏"],
        tags=["FPS", "全新", "NVIDIA"],
        components={"cpu": "cpu-1"},
        estimated_total=1300,
        explanation="人工审核基底",
        details={
            "target_budget": 7000,
            "direction": "fps",
            "purchase_mode": "new",
            "gpu_vendor": "nvidia",
            "parts": [
                {
                    "role": "cpu",
                    "component_id": "cpu-1",
                    "name": "CPU 1",
                    "condition": "new",
                    "reference_price": 1300,
                    "price_source": "manual",
                    "price_date": "2026-07-20",
                    "specs": {"perf_index": 80, "tdp": 120},
                }
            ],
            "suitable_user": "FPS",
            "price_date": "2026-07-20",
        },
        status="active",
    )


def component() -> HardwareComponent:
    return HardwareComponent(
        id="cpu-1",
        category="cpu",
        name="CPU 1",
        brand="AMD",
        detail_raw="AM5",
        specs={"perf_index": 80, "tdp": 120},
        is_recommended=True,
        status="active",
    )


def component_price() -> ComponentPrice:
    return ComponentPrice(
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
