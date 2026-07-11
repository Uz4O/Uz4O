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


def test_ingest_gpu_whitelist_prices_command_imports_used_and_new_prices(
    monkeypatch,
    tmp_path: Path,
    capsys,
) -> None:
    captured = {}
    csv_path = tmp_path / "gpu-whitelist-prices.csv"
    csv_path.write_text(
        "\n".join(
            [
                "target_id,name,used_price,new_price",
                "rtx-5070,RTX 5070,4300,5200",
            ]
        ),
        encoding="utf-8",
    )

    class FakeSession:
        def __enter__(self):
            return self

        def __exit__(self, exc_type, exc, tb):
            return False

    def fake_create_session_factory(settings):
        return lambda: FakeSession()

    def fake_seed_gpu_whitelist_prices(session, rows):
        captured["rows"] = list(rows)
        return len(captured["rows"])

    monkeypatch.setattr("app.cli.create_session_factory", fake_create_session_factory)
    monkeypatch.setattr("app.cli.seed_gpu_whitelist_prices", fake_seed_gpu_whitelist_prices)
    monkeypatch.setattr(
        "sys.argv",
        [
            "ai-pc-builder-api",
            "ingest-gpu-whitelist-prices",
            str(csv_path),
            "--approved-at",
            "2026-07-07",
        ],
    )

    main()

    assert captured["rows"][0].component_id == "rtx-5070"
    assert captured["rows"][0].used_price == 4300
    assert captured["rows"][0].new_price == 5200
    assert capsys.readouterr().out == "Imported 1 GPU whitelist prices.\n"


def test_ingest_motherboard_whitelist_prices_command_imports_status(
    monkeypatch,
    tmp_path: Path,
    capsys,
) -> None:
    captured = {}
    csv_path = tmp_path / "motherboard-whitelist-prices.csv"
    csv_path.write_text(
        "\n".join(
            [
                "target_id,name,platform,used_price,new_price,status",
                "asus-b550m-plus,华硕 B550M PLUS 重炮手,AM4,400,,discontinued",
            ]
        ),
        encoding="utf-8",
    )

    class FakeSession:
        def __enter__(self):
            return self

        def __exit__(self, exc_type, exc, tb):
            return False

    def fake_create_session_factory(settings):
        return lambda: FakeSession()

    def fake_seed_motherboard_whitelist_prices(session, rows):
        captured["rows"] = list(rows)
        return len(captured["rows"])

    monkeypatch.setattr("app.cli.create_session_factory", fake_create_session_factory)
    monkeypatch.setattr("app.cli.seed_motherboard_whitelist_prices", fake_seed_motherboard_whitelist_prices)
    monkeypatch.setattr(
        "sys.argv",
        [
            "ai-pc-builder-api",
            "ingest-motherboard-whitelist-prices",
            str(csv_path),
            "--approved-at",
            "2026-07-07",
        ],
    )

    main()

    assert captured["rows"][0].component_id == "asus-b550m-plus"
    assert captured["rows"][0].used_price == 400
    assert captured["rows"][0].new_price is None
    assert captured["rows"][0].status == "discontinued"
    assert capsys.readouterr().out == "Imported 1 motherboard whitelist prices.\n"


def test_ingest_cpu_whitelist_prices_command_imports_used_and_new_tray_prices(
    monkeypatch,
    tmp_path: Path,
    capsys,
) -> None:
    captured = {}
    csv_path = tmp_path / "cpu-whitelist-prices.csv"
    csv_path.write_text(
        "\n".join(
            [
                "target_id,name,used_price,new_tray_price",
                "r7-9800x3d,R7 9800X3D,2400,2700",
            ]
        ),
        encoding="utf-8",
    )

    class FakeSession:
        def __enter__(self):
            return self

        def __exit__(self, exc_type, exc, tb):
            return False

    def fake_create_session_factory(settings):
        return lambda: FakeSession()

    def fake_seed_cpu_whitelist_prices(session, rows):
        captured["rows"] = list(rows)
        return len(captured["rows"])

    monkeypatch.setattr("app.cli.create_session_factory", fake_create_session_factory)
    monkeypatch.setattr("app.cli.seed_cpu_whitelist_prices", fake_seed_cpu_whitelist_prices)
    monkeypatch.setattr(
        "sys.argv",
        [
            "ai-pc-builder-api",
            "ingest-cpu-whitelist-prices",
            str(csv_path),
            "--approved-at",
            "2026-07-07",
        ],
    )

    main()

    assert captured["rows"][0].component_id == "r7-9800x3d"
    assert captured["rows"][0].used_price == 2400
    assert captured["rows"][0].new_tray_price == 2700
    assert capsys.readouterr().out == "Imported 1 CPU whitelist prices.\n"
