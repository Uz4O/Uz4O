from pathlib import Path

from fastapi.testclient import TestClient

from app.core.config import Settings
from app.main import create_app
from app.progress import load_progress


def test_progress_file_tracks_the_backend_roadmap() -> None:
    progress = load_progress(Path("progress.json"))

    assert progress.project == "AI 装机助手后端"
    assert len(progress.phases) == 5
    assert progress.total_items == 14
    assert progress.completed_items == 3
    assert progress.completion_percentage == 21


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
    assert "21%" in response.text
    assert "PostgreSQL 数据库地基" in response.text
    assert "FastAPI 后端脚手架" in response.text
    assert "Phase 4 · 打磨" in response.text


def test_root_redirects_to_progress_dashboard() -> None:
    client = TestClient(
        create_app(Settings(_env_file=None, postgres_url=None, redis_url=None))
    )

    response = client.get("/", follow_redirects=False)

    assert response.status_code == 307
    assert response.headers["location"] == "/progress"
