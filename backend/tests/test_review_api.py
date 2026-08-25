import json

from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker
from sqlalchemy.pool import StaticPool

from app.catalog.repository import seed_hardware_components
from app.catalog.seed import CatalogComponent
from app.core.config import Settings
from app.db import Base, get_session
from app.main import create_app


def make_client() -> TestClient:
    engine = create_engine(
        "sqlite+pysqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(engine)
    session_factory = sessionmaker(bind=engine)
    with Session(engine) as session:
        seed_hardware_components(
            session,
            [
                CatalogComponent(
                    id="i7-14700f",
                    category="cpu",
                    name="i7-14700F",
                    brand="Intel",
                    detail_raw="14代 Raptor Lake Refresh · LGA1700",
                    specs={"socket": "LGA1700", "tdp": 219, "perf_index": 90},
                ),
                CatalogComponent(
                    id="rtx-4060",
                    category="gpu",
                    name="RTX 4060",
                    brand="NVIDIA",
                    detail_raw="8GB · Ada",
                    specs={"tdp": 115, "perf_index": 40},
                ),
                CatalogComponent(
                    id="h610m",
                    category="motherboard",
                    name="H610M",
                    brand="华硕",
                    detail_raw="Intel · LGA1700 · H610",
                    specs={"socket": "LGA1700", "mem_type": "DDR4", "chipset": "H610"},
                ),
                CatalogComponent(
                    id="psu-500w",
                    category="psu",
                    name="500W 电源",
                    brand="未知",
                    detail_raw="500W",
                    specs={"watt": 500},
                ),
                CatalogComponent(
                    id="i5-12400f",
                    category="cpu",
                    name="i5-12400F",
                    brand="Intel",
                    detail_raw="12代 Alder Lake · LGA1700",
                    specs={"socket": "LGA1700", "tdp": 117, "perf_index": 60},
                ),
                CatalogComponent(
                    id="i3-12100f",
                    category="cpu",
                    name="i3-12100F",
                    brand="Intel",
                    detail_raw="12代 Alder Lake · LGA1700",
                    specs={"socket": "LGA1700", "tdp": 89, "perf_index": 30},
                ),
                CatalogComponent(
                    id="e5-2680v4",
                    category="cpu",
                    name="E5-2680 v4",
                    brand="Intel",
                    detail_raw="Xeon E5 洋垃圾平台",
                    specs={"socket": "LGA2011-3", "tdp": 120, "perf_index": 20},
                ),
                CatalogComponent(
                    id="rtx-4090",
                    category="gpu",
                    name="RTX 4090",
                    brand="NVIDIA",
                    detail_raw="24GB · Ada",
                    specs={"tdp": 450, "perf_index": 110},
                ),
                CatalogComponent(
                    id="gt-730",
                    category="gpu",
                    name="GT 730",
                    brand="NVIDIA",
                    detail_raw="亮机卡",
                    specs={"tdp": 49, "perf_index": 10},
                ),
                CatalogComponent(
                    id="b760m",
                    category="motherboard",
                    name="B760M",
                    brand="微星",
                    detail_raw="Intel · LGA1700 · B760",
                    specs={"socket": "LGA1700", "mem_type": "DDR4", "chipset": "B760"},
                ),
                CatalogComponent(
                    id="psu-650w-gold",
                    category="psu",
                    name="650W 金牌电源",
                    brand="航嘉",
                    detail_raw="650W 80Plus Gold",
                    specs={"watt": 650},
                ),
                CatalogComponent(
                    id="psu-1000w-gold",
                    category="psu",
                    name="1000W 金牌电源",
                    brand="海韵",
                    detail_raw="1000W 80Plus Gold",
                    specs={"watt": 1000},
                ),
                CatalogComponent(
                    id="ddr4-16gb",
                    category="ram",
                    name="DDR4 16GB",
                    brand="金士顿",
                    detail_raw="DDR4 8GB×2 3200",
                    specs={"type": "DDR4", "capacity_gb": 16},
                ),
                CatalogComponent(
                    id="ddr4-8gb",
                    category="ram",
                    name="DDR4 8GB",
                    brand="金士顿",
                    detail_raw="DDR4 8GB 3200",
                    specs={"type": "DDR4", "capacity_gb": 8},
                ),
                CatalogComponent(
                    id="ssd-256gb",
                    category="storage",
                    name="256GB SSD",
                    brand="致态",
                    detail_raw="NVMe TLC 256GB",
                    specs={"capacity_gb": 256},
                ),
            ],
        )
        session.commit()

    app = create_app(Settings(_env_file=None, postgres_url=None, redis_url=None))

    def override_session():
        with session_factory() as session:
            yield session

    app.dependency_overrides[get_session] = override_session
    return TestClient(app)


def test_review_analyze_flags_unbalanced_seller_configuration() -> None:
    client = make_client()

    response = client.post(
        "/v1/review/analyze",
        json={
            "text": "i7-14700F + RTX4060 + H610 主板 + DDR4 16GB + 500W 电源",
            "direction": "aaa",
            "resolution": "2160p",
        },
    )

    assert response.status_code == 200
    body = response.json()
    assert body["risk_level"] == "error"
    assert "seller_price" not in body
    assert "reference_total" not in body
    assert body["direction"] == "balanced"
    assert body["resolution"] == "1440p"
    assert body["pairing_rating"]["status"] == "failed"
    assert body["pairing_rating"]["score"] is None
    assert body["pairing_rating"]["grade"] is None
    assert body["performance_rating"]["status"] == "graded"
    assert body["performance_rating"]["score"] is not None
    assert body["performance_rating"]["grade"] in {"C", "B", "A", "S"}
    assert "不建议直接买" in body["summary"]
    assert body["detected_components"]["cpu"]["component_id"] == "i7-14700f"
    assert body["detected_components"]["gpu"]["component_id"] == "rtx-4060"
    assert body["detected_components"]["motherboard"]["component_id"] == "h610m"
    assert any(finding["code"] == "cpu_gpu_imbalance" for finding in body["findings"])
    assert any(finding["code"] == "low_end_board_for_i7" for finding in body["findings"])
    assert not any("price" in finding["code"] for finding in body["findings"])
    assert body["recommendations"]
    assert all(
        recommendation["severity"] in {"required", "recommended", "optional"}
        and recommendation["reason"]
        and recommendation["action"]
        and recommendation["expected_impact"]
        for recommendation in body["recommendations"]
    )
    assert "具体品牌和型号" in body["questions_for_seller"][0]
    assert "重新配一套" not in body["reply_text"]


def test_review_analyze_rejects_too_short_input() -> None:
    client = make_client()

    response = client.post("/v1/review/analyze", json={"text": "RTX4060"})

    assert response.status_code == 422


def test_review_analyze_blocks_marketing_terms_without_models() -> None:
    client = make_client()

    response = client.post(
        "/v1/review/analyze",
        json={"text": "i7级处理器 + 电竞级独显 + 军工主板 + 600W 电源，整机售价 4999"},
    )

    assert response.status_code == 200
    body = response.json()
    assert body["risk_level"] == "error"
    assert any(finding["code"] == "marketing_terms_without_models" for finding in body["findings"])
    assert any(finding["code"] == "insufficient_core_information" for finding in body["findings"])
    assert "信息不足" in body["summary"]


def test_review_analyze_warns_for_low_cpu_high_gpu() -> None:
    client = make_client()

    response = client.post(
        "/v1/review/analyze",
        json={"text": "i3-12100F + RTX4090 + B760M 主板 + DDR4 16GB + 1000W 金牌电源"},
    )

    assert response.status_code == 200
    body = response.json()
    assert any(finding["code"] == "gpu_cpu_imbalance" for finding in body["findings"])
    assert body["pairing_rating"]["status"] == "graded"
    assert body["pairing_rating"]["grade"] == "C"
    recommendation = next(
        item for item in body["recommendations"] if item["title"] == "缩小 CPU 与显卡的档次差距"
    )
    assert recommendation["severity"] == "recommended"
    assert recommendation["component_ids"] == ["i3-12100f", "rtx-4090"]
    assert "CPU 与显卡的性能档次更协调" in recommendation["expected_impact"]


def test_review_analyze_flags_low_capacity_single_channel_memory_and_storage() -> None:
    client = make_client()

    response = client.post(
        "/v1/review/analyze",
        json={
            "text": "i5-12400F + RTX4060 + B760M 主板 + DDR4 8GB 单条 + 256GB SSD + 650W 金牌电源"
        },
    )

    assert response.status_code == 200
    body = response.json()
    assert {"ram_capacity_low", "ram_single_channel", "storage_capacity_low"}.issubset(
        {finding["code"] for finding in body["findings"]}
    )
    assert {"把内存补到至少 16GB", "改为双通道内存", "确认硬盘容量是否够用"}.issubset(
        {item["title"] for item in body["recommendations"]}
    )


def test_review_analyze_errors_when_psu_wattage_cannot_cover_detected_parts() -> None:
    client = make_client()

    response = client.post(
        "/v1/review/analyze",
        json={"text": "i3-12100F + RTX4090 + B760M 主板 + DDR4 16GB + 500W 电源"},
    )

    assert response.status_code == 200
    body = response.json()
    assert body["risk_level"] == "error"
    assert any(finding["code"] == "psu_wattage_insufficient" for finding in body["findings"])
    assert body["pairing_rating"]["status"] == "failed"
    assert body["pairing_rating"]["grade"] is None
    assert any(
        item["severity"] == "required" and "电源" in item["action"]
        for item in body["recommendations"]
    )


def test_review_analyze_marks_missing_core_information_incomplete() -> None:
    client = make_client()

    response = client.post(
        "/v1/review/analyze",
        json={"text": "CPU：i5-12400F\n显卡：RTX 4060\n其余配件型号待商家确认"},
    )

    assert response.status_code == 200
    body = response.json()
    assert body["pairing_rating"]["status"] == "incomplete"
    assert body["pairing_rating"]["grade"] is None
    assert body["pairing_rating"]["score"] is None
    assert any(item["severity"] == "required" for item in body["recommendations"])


def test_review_public_grades_are_limited_to_c_through_s() -> None:
    client = make_client()

    response = client.post(
        "/v1/review/analyze",
        json={"text": "i3-12100F + RTX4090 + B760M 主板 + DDR4 16GB + 1000W 金牌电源"},
    )

    assert response.status_code == 200
    ratings = [response.json()["pairing_rating"], response.json()["performance_rating"]]
    assert all(rating["grade"] in {"C", "B", "A", "S"} for rating in ratings)
    assert all(rating["status"] == "graded" for rating in ratings)


def test_review_analyze_ignores_price_text() -> None:
    client = make_client()

    response = client.post(
        "/v1/review/analyze",
        json={"text": "i5-12400F + RTX4060 + B760M 主板 + 650W 金牌电源，报价 5200"},
    )

    assert response.status_code == 200
    body = response.json()
    assert "seller_price" not in body
    assert "reference_total" not in body
    assert not any("price" in finding["code"] for finding in body["findings"])
    review_output = json.dumps(
        {
            "summary": body["summary"],
            "findings": body["findings"],
            "recommendations": body["recommendations"],
            "reply_text": body["reply_text"],
        },
        ensure_ascii=False,
    )
    assert "价格" not in review_output
    assert "性价比" not in review_output
    assert "price" not in review_output.lower()


def test_review_analyze_legacy_context_fields_do_not_change_result() -> None:
    client = make_client()
    text = "i5-12400F + RTX4060 + B760M 主板 + DDR4 16GB + 650W 金牌电源"

    baseline = client.post("/v1/review/analyze", json={"text": text})
    legacy_fps = client.post(
        "/v1/review/analyze",
        json={"text": text, "direction": "fps", "resolution": "1080p"},
    )
    legacy_office = client.post(
        "/v1/review/analyze",
        json={"text": text, "direction": "office", "resolution": "2160p"},
    )

    assert baseline.status_code == 200
    assert legacy_fps.status_code == 200
    assert legacy_office.status_code == 200
    assert baseline.json() == legacy_fps.json() == legacy_office.json()
    assert legacy_fps.headers["x-cache"] == "HIT"
    assert legacy_office.headers["x-cache"] == "HIT"


def test_review_analyze_flags_outdated_clearance_hardware() -> None:
    client = make_client()

    response = client.post(
        "/v1/review/analyze",
        json={"text": "E5-2680 v4 + GT730 独显 + 500W 电源，商家写高性能游戏主机，报价 2999"},
    )

    assert response.status_code == 200
    body = response.json()
    assert body["risk_level"] == "error"
    assert any(finding["code"] == "outdated_clearance_hardware" for finding in body["findings"])


def test_review_analyze_image_uses_ocr_text(monkeypatch) -> None:
    client = make_client()

    def fake_ocr(image_bytes: bytes) -> str:
        assert image_bytes == b"fake image"
        return "i7-14700F + RTX4060 + H610 主板 + 500W 电源，商家报价 6999"

    monkeypatch.setattr("app.api.review.extract_text_from_image_bytes", fake_ocr, raising=False)

    response = client.post(
        "/v1/review/analyze/image",
        data={"direction": "fps", "resolution": "1080p"},
        files={"image": ("config.png", b"fake image", "image/png")},
    )

    assert response.status_code == 200
    body = response.json()
    assert body["risk_level"] == "error"
    assert body["direction"] == "balanced"
    assert body["resolution"] == "1440p"
    assert body["source_text"].startswith("i7-14700F")
    assert any(finding["code"] == "cpu_gpu_imbalance" for finding in body["findings"])


def test_review_analyze_image_allows_phone_screenshot_size(monkeypatch) -> None:
    client = make_client()

    def fake_ocr(image_bytes: bytes) -> str:
        assert len(image_bytes) > 1_000_000
        return "i7-14700F + RTX4060 + H610 主板 + 500W 电源，商家报价 6999"

    monkeypatch.setattr("app.api.review.extract_text_from_image_bytes", fake_ocr, raising=False)

    response = client.post(
        "/v1/review/analyze/image",
        files={"image": ("config.png", b"x" * 1_200_000, "image/png")},
    )

    assert response.status_code == 200


def test_review_analyze_stream_returns_progress_and_result_events() -> None:
    client = make_client()

    response = client.post(
        "/v1/review/analyze/stream",
        json={"text": "i7-14700F + RTX4060 + H610 主板 + 500W 电源，商家报价 6999"},
    )

    assert response.status_code == 200
    assert response.headers["content-type"].startswith("text/event-stream")
    events = _sse_events(response.text)
    assert [event["event"] for event in events] == ["progress", "progress", "cache", "result"]
    assert events[0]["data"]["stage"] == "received"
    assert events[1]["data"]["stage"] == "analyzing"
    assert events[2]["data"] == {"status": "MISS"}
    assert events[3]["data"]["risk_level"] == "error"
    assert "seller_price" not in events[3]["data"]


def test_review_analyze_stream_reuses_cached_result() -> None:
    client = make_client()
    payload = {"text": "i7-14700F + RTX4060 + H610 主板 + 500W 电源，商家报价 6999"}

    first = client.post("/v1/review/analyze/stream", json=payload)
    second = client.post("/v1/review/analyze/stream", json=payload)

    assert first.status_code == 200
    assert second.status_code == 200
    assert _sse_events(first.text)[2]["data"] == {"status": "MISS"}
    assert _sse_events(second.text)[2]["data"] == {"status": "HIT"}


def _sse_events(raw: str) -> list[dict]:
    events = []
    for chunk in raw.strip().split("\n\n"):
        lines = chunk.splitlines()
        event_name = next(line.removeprefix("event: ") for line in lines if line.startswith("event: "))
        data = next(line.removeprefix("data: ") for line in lines if line.startswith("data: "))
        events.append({"event": event_name, "data": json.loads(data)})
    return events
