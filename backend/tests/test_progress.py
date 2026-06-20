from pathlib import Path

from fastapi.testclient import TestClient

from app.core.config import Settings
from app.main import create_app
from app.progress import load_progress


def test_progress_file_tracks_the_backend_roadmap() -> None:
    progress = load_progress(Path("progress.json"))

    assert progress.project == "AI 装机助手后端"
    assert progress.estimated_completion == "后端精进项：约 1-2 天；不包含你提供数据、密钥和服务器策略的时间"
    assert len(progress.phases) == 6
    assert progress.total_items == 93
    assert progress.completed_items == 79
    assert progress.completion_percentage == 85
    assert [item.title for item in progress.user_action_items] == [
        "硬件尺寸字段人工补充",
        "生产短信服务与登录密钥配置",
        "Sign in with Apple 登录配置",
        "生产推荐池与价格/模板数据发布",
        "DeepSeek API Key 与配置模板",
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
    assert "85%" in response.text
    assert "预计完成时间" in response.text
    assert "后端精进项：约 1-2 天；不包含你提供数据、密钥和服务器策略的时间" in response.text
    assert "需要你完成" in response.text
    assert "下面这些不是后端代码缺口" in response.text
    assert "硬件尺寸字段人工补充" in response.text
    assert "生产短信服务与登录密钥配置" in response.text
    assert "Sign in with Apple 登录配置" in response.text
    assert "生产推荐池与价格/模板数据发布" in response.text
    assert "DeepSeek API Key 与配置模板" in response.text
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
