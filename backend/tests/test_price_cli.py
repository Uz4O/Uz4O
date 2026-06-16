from pathlib import Path

from app.cli import main


def test_ingest_prices_command_imports_approved_csv(monkeypatch, tmp_path: Path, capsys) -> None:
    captured = {}
    csv_path = tmp_path / "approved-reference-prices.csv"
    csv_path.write_text(
        "\n".join(
            [
                "category,target_id,name,brand,reference_price,normal_price_min,normal_price_max,accepted_count,rejected_count,review_reasons",
                "cpu,i5-14600k,i5-14600K,Intel,1499,1450,1550,4,0,manual_check",
            ]
        ),
        encoding="utf-8",
    )

    class FakeSession:
        def __enter__(self):
            return self

        def __exit__(self, exc_type, exc, tb):
            return False

    def fake_session_factory():
        return FakeSession()

    def fake_create_session_factory(settings):
        return fake_session_factory

    def fake_seed_component_prices(session, rows):
        captured["rows"] = list(rows)
        return len(captured["rows"])

    monkeypatch.setattr("app.cli.create_session_factory", fake_create_session_factory)
    monkeypatch.setattr("app.cli.seed_component_prices", fake_seed_component_prices)
    monkeypatch.setattr(
        "sys.argv",
        [
            "ai-pc-builder-api",
            "ingest-prices",
            str(csv_path),
            "--approved-at",
            "2026-06-15",
        ],
    )

    main()

    assert captured["rows"][0].component_id == "i5-14600k"
    assert captured["rows"][0].reference_price == 1499
    assert capsys.readouterr().out == "Imported 1 component prices.\n"
