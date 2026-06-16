from pathlib import Path

from app.cli import main


def test_import_build_templates_command_imports_json(monkeypatch, tmp_path: Path, capsys) -> None:
    captured = {}
    path = tmp_path / "build-templates.json"
    path.write_text(
        """
[
  {
    "id": "gaming-7000-2k",
    "title": "7000 元 2K 游戏配置",
    "budget_min": 6500,
    "budget_max": 7500,
    "use_cases": ["gaming"],
    "tags": ["2k", "quiet"],
    "components": {"cpu": "i5-14600k", "motherboard": "b760m", "ram": "ram-6000-cl30", "psu": "psu-750w"},
    "estimated_total": 7000,
    "explanation": "适合 2K 游戏。"
  }
]
""",
        encoding="utf-8",
    )

    class FakeSession:
        def __enter__(self):
            return self

        def __exit__(self, exc_type, exc, tb):
            return False

    def fake_create_session_factory(settings):
        return lambda: FakeSession()

    def fake_upsert_build_templates(session, templates):
        captured["templates"] = templates
        return len(templates)

    monkeypatch.setattr("app.cli.create_session_factory", fake_create_session_factory)
    monkeypatch.setattr("app.cli.upsert_build_templates", fake_upsert_build_templates)
    monkeypatch.setattr("sys.argv", ["ai-pc-builder-api", "import-build-templates", str(path)])

    main()

    assert captured["templates"][0].id == "gaming-7000-2k"
    assert capsys.readouterr().out == "Imported 1 build templates.\n"
