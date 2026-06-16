from pathlib import Path

from app.cli import main


def test_import_recommendations_command_reads_ids_file(monkeypatch, tmp_path: Path, capsys) -> None:
    captured = {}
    path = tmp_path / "recommended-components.txt"
    path.write_text(
        """
# 人工确认推荐池
i5-14600k
rtx-4060

""",
        encoding="utf-8",
    )

    class FakeSession:
        def __enter__(self):
            return self

        def __exit__(self, exc_type, exc, tb):
            return False

    class FakeResult:
        updated_count = 2
        missing_ids = []

    def fake_create_session_factory(settings):
        return lambda: FakeSession()

    def fake_update_recommended_components(session, component_ids, replace):
        captured["component_ids"] = component_ids
        captured["replace"] = replace
        return FakeResult()

    monkeypatch.setattr("app.cli.create_session_factory", fake_create_session_factory)
    monkeypatch.setattr("app.cli.update_recommended_components", fake_update_recommended_components)
    monkeypatch.setattr(
        "sys.argv",
        ["ai-pc-builder-api", "import-recommendations", str(path), "--replace"],
    )

    main()

    assert captured == {
        "component_ids": ["i5-14600k", "rtx-4060"],
        "replace": True,
    }
    assert capsys.readouterr().out == "Marked 2 recommended components.\n"


def test_import_recommendations_command_reports_missing_ids(monkeypatch, tmp_path: Path, capsys) -> None:
    path = tmp_path / "recommended-components.txt"
    path.write_text("missing-cpu\n", encoding="utf-8")

    class FakeSession:
        def __enter__(self):
            return self

        def __exit__(self, exc_type, exc, tb):
            return False

    class FakeResult:
        updated_count = 0
        missing_ids = ["missing-cpu"]

    def fake_create_session_factory(settings):
        return lambda: FakeSession()

    def fake_update_recommended_components(session, component_ids, replace):
        return FakeResult()

    monkeypatch.setattr("app.cli.create_session_factory", fake_create_session_factory)
    monkeypatch.setattr("app.cli.update_recommended_components", fake_update_recommended_components)
    monkeypatch.setattr(
        "sys.argv",
        ["ai-pc-builder-api", "import-recommendations", str(path)],
    )

    main()

    assert capsys.readouterr().out == (
        "Marked 0 recommended components.\n"
        "Missing component ids: missing-cpu\n"
    )
