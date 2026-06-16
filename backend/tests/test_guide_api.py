from fastapi.testclient import TestClient

from app.core.config import Settings
from app.main import create_app


def test_guide_endpoint_returns_component_intros_and_steps() -> None:
    client = TestClient(
        create_app(Settings(_env_file=None, postgres_url=None, redis_url=None))
    )

    response = client.get("/v1/guide")

    assert response.status_code == 200
    payload = response.json()
    assert payload["version"] == "2026-06-16"
    assert payload["intro"]["title"] == "先认识这些配件"
    assert len(payload["component_intro_items"]) == 8
    assert len(payload["assembly_steps"]) == 10

    cpu = payload["component_intro_items"][0]
    assert cpu == {
        "id": "cpu",
        "title": "CPU",
        "subtitle": "负责运算处理",
        "symbol": "cpu",
        "image_name": "GuidePartCPU",
        "model_name": "desktop-cpu-mobile",
        "detail_points": [
            {
                "id": "appearance",
                "title": "外观识别",
                "text": "方形芯片，上表面有型号标识，底部有密集触点。",
                "symbol": "magnifyingglass",
            },
            {
                "id": "install",
                "title": "安装位置",
                "text": "安装在主板的 CPU 插槽上，并固定散热器。",
                "symbol": "mappin.circle",
            },
        ],
    }

    first_step = payload["assembly_steps"][0]
    assert first_step == {
        "id": "cpu",
        "number": 1,
        "title": "安装 CPU",
        "summary": "将 CPU 放入主板插槽",
        "action": "抬起拉杆并打开压框，对准三角标记后轻放 CPU",
        "caution": "不要触碰插槽触点，不要用力按压",
        "symbol": "cpu",
    }

    assert payload["assembly_steps"][-1]["id"] == "finish"
    assert payload["assembly_steps"][-1]["number"] == 10


def test_guide_endpoint_returns_interactive_install_metadata() -> None:
    client = TestClient(
        create_app(Settings(_env_file=None, postgres_url=None, redis_url=None))
    )

    response = client.get("/v1/guide")

    assert response.status_code == 200
    payload = response.json()
    assert payload["interactive_installs"]["cpu"]["anchor_name"] == (
        "cpuSocketInstallAnchor"
    )
    assert payload["interactive_installs"]["cpu"]["model_names"] == [
        "modern-atx-motherboard-mobile",
        "desktop-cpu-mobile",
    ]
    assert payload["interactive_installs"]["memory"]["anchor_names"] == [
        "dimmSlotA2InstallAnchor",
        "dimmSlotB2InstallAnchor",
    ]
    assert payload["interactive_installs"]["ssd"]["anchor_name"] == (
        "m2SlotInstallAnchor"
    )
    assert payload["interactive_installs"]["cpu"]["phases"][0] == {
        "id": "position-board",
        "title": "摆正主板",
        "subtitle": "先确认 AM5 插槽位置",
        "symbol": "rectangle.3.group",
    }
