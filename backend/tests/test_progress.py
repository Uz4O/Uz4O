from pathlib import Path

from fastapi.testclient import TestClient

from app.core.config import Settings
from app.main import create_app
from app.progress import load_progress


def test_progress_file_tracks_the_backend_roadmap() -> None:
    progress = load_progress(Path("progress.json"))

    assert progress.project == "AI 装机助手后端"
    assert progress.estimated_completion == (
        "AI装机核心生成流程已完成并部署；剩余覆盖率和物理兼容精度依赖补充审核价格、"
        "型号梯度与尺寸数据"
    )
    assert len(progress.phases) == 6
    assert progress.total_items == 104
    assert progress.completed_items == 91
    assert progress.completion_percentage == 88
    assert [item.title for item in progress.user_action_items] == [
        "硬件尺寸字段人工补充",
        "生产短信服务与登录密钥配置",
        "Sign in with Apple 登录配置",
        "社区图片上传配置",
        "服务器 SSH 暴力破解防护",
        "数据库备份与恢复演练",
        "社区内容审核服务选择",
        "生产域名、HTTPS 与 CORS 白名单确认",
    ]


def test_fastapi_scaffold_is_the_initial_completed_item() -> None:
    progress = load_progress(Path("progress.json"))

    scaffold = progress.phases[0].items[0]
    assert scaffold.title == "FastAPI 后端脚手架"
    assert scaffold.status == "completed"


def test_progress_separates_local_catalog_coverage_from_production_data() -> None:
    progress = load_progress(Path("progress.json"))
    phase = next(phase for phase in progress.phases if phase.name == "Phase 1 · 决策类 AI")
    items = {item.title: item for item in phase.items}

    local_catalog = items["3000-30000元装机基底配置库"]
    production_catalog = items["生产推荐池与价格/模板数据发布"]
    build_options = items["AI装机三种采购方案接口与前端联调"]
    gpu_budget_optimization = items["显卡厂商与预算利用率优化"]
    deterministic_customization = items["AI装机硬需求确定性下探"]

    assert local_catalog.status == "completed"
    assert "415套" in local_catalog.description
    assert "487套" in local_catalog.description
    assert "每1000元" in local_catalog.description
    assert production_catalog.status == "completed"
    assert "275套" in production_catalog.description
    assert "3000-20000元" in production_catalog.description
    assert build_options.status == "completed"
    assert "/v1/build/options" in build_options.description
    assert gpu_budget_optimization.status == "completed"
    assert "上限为加800元" in gpu_budget_optimization.description
    assert "低于预算200元以上的配置不返回" in gpu_budget_optimization.description
    assert "缺一项则整单失败" in gpu_budget_optimization.description
    assert deterministic_customization.status == "completed"
    assert "默认最多超300元" in deterministic_customization.description


def test_postgres_foundation_is_completed_before_seed_import_starts() -> None:
    progress = load_progress(Path("progress.json"))

    postgres = progress.phases[0].items[1]
    seed_import = progress.phases[0].items[2]

    assert postgres.title == "PostgreSQL 数据库地基"
    assert postgres.status == "completed"
    assert postgres.completed_at == "2026-06-13"
    assert seed_import.title == "硬件库种子导入"
    assert seed_import.status == "completed"
    assert seed_import.completed_at == "2026-06-13"


def test_progress_dashboard_renders_summary_and_phases() -> None:
    client = TestClient(
        create_app(Settings(_env_file=None, postgres_url=None, redis_url=None))
    )

    response = client.get("/progress")

    assert response.status_code == 200
    assert "AI 装机助手后端" in response.text
    assert "88%" in response.text
    assert "预计完成时间" in response.text
    assert "AI装机核心生成流程已完成并部署" in response.text
    assert "需要你完成" in response.text
    assert "下面这些不是后端代码缺口" in response.text
    assert "硬件尺寸字段人工补充" in response.text
    assert "生产短信服务与登录密钥配置" in response.text
    assert "Sign in with Apple 登录配置" in response.text
    assert "社区图片上传配置" in response.text
    assert "服务器 SSH 暴力破解防护" in response.text
    assert "数据库备份与恢复演练" in response.text
    assert "社区内容审核服务选择" in response.text
    assert "生产域名、HTTPS 与 CORS 白名单确认" in response.text
    assert "持续精进" in response.text
    assert "用户隐私与社区安全闭环" not in response.text


def test_root_redirects_to_progress_dashboard() -> None:
    client = TestClient(
        create_app(Settings(_env_file=None, postgres_url=None, redis_url=None))
    )

    response = client.get("/", follow_redirects=False)

    assert response.status_code == 307
    assert response.headers["location"] == "/progress"
