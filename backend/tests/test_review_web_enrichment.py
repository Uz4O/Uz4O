import json

from app.core.config import Settings
from app.review.web_enrichment import enrich_component_from_web


def test_web_enrichment_uses_search_results_as_untrusted_evidence(monkeypatch) -> None:
    requests = []

    class FakeResponse:
        def __init__(self, payload):
            self.payload = payload

        def raise_for_status(self):
            return None

        def json(self):
            return self.payload

    class FakeClient:
        def __init__(self, timeout):
            self.timeout = timeout

        def __enter__(self):
            return self

        def __exit__(self, exc_type, exc, traceback):
            return None

        def post(self, url, headers=None, json=None):
            requests.append({"url": url, "headers": headers, "json": json})
            if "tavily" in url:
                return FakeResponse(
                    {
                        "results": [
                            {
                                "title": "Example GPU official specifications",
                                "url": "https://vendor.example/gpu/specs",
                                "content": "Example GPU has 250 W board power and a 16-pin connector.",
                            }
                        ]
                    }
                )
            return FakeResponse(
                {
                    "choices": [
                        {
                            "message": {
                                "content": json_module.dumps(
                                    {
                                        "name": "Example GPU",
                                        "brand": "Example",
                                        "specs": {"tdp": 250, "gpu_connector": "16-pin"},
                                    }
                                )
                            }
                        }
                    ]
                }
            )

    json_module = json
    monkeypatch.setattr("app.review.web_enrichment.httpx.Client", FakeClient)

    result = enrich_component_from_web(
        "Example GPU",
        "gpu",
        Settings(
            _env_file=None,
            review_search_api_key="search-secret",
            ai_provider_api_key="deepseek-secret",
            ai_provider_base_url="https://api.deepseek.com",
        ),
    )

    assert result is not None
    assert result.name == "Example GPU"
    assert result.specs == {"tdp": 250, "gpu_connector": "16-pin"}
    assert result.sources[0].url == "https://vendor.example/gpu/specs"
    assert requests[0]["json"]["query"] == "Example GPU 官方 规格 参数"
    assert "只提取硬件规格" in requests[1]["json"]["messages"][0]["content"]


def test_web_enrichment_is_disabled_without_both_api_keys(monkeypatch) -> None:
    def unexpected_client(*args, **kwargs):
        raise AssertionError("network must not be called")

    monkeypatch.setattr("app.review.web_enrichment.httpx.Client", unexpected_client)

    assert (
        enrich_component_from_web(
            "Example GPU",
            "gpu",
            Settings(_env_file=None, review_search_api_key="search-secret"),
        )
        is None
    )
