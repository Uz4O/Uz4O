from app.cli import main


def test_check_data_readiness_command_reports_counts(monkeypatch, capsys) -> None:
    class FakeSession:
        def __enter__(self):
            return self

        def __exit__(self, exc_type, exc, tb):
            return False

    class FakeReadiness:
        ready = False
        component_count = 715
        price_count = 120
        active_template_count = 3
        recommended_counts = {
            "cpu": 12,
            "gpu": 10,
            "motherboard": 8,
            "ram": 4,
            "storage": 4,
            "psu": 4,
        }
        priced_recommended_counts = {
            "cpu": 12,
            "gpu": 9,
            "motherboard": 8,
            "ram": 4,
            "storage": 4,
            "psu": 4,
        }
        missing_recommended_categories = []
        missing_priced_recommended_categories = []

    def fake_create_session_factory(settings):
        return lambda: FakeSession()

    def fake_build_data_readiness(session):
        return FakeReadiness()

    monkeypatch.setattr("app.cli.create_session_factory", fake_create_session_factory)
    monkeypatch.setattr("app.cli.build_data_readiness", fake_build_data_readiness)
    monkeypatch.setattr("sys.argv", ["ai-pc-builder-api", "check-data-readiness"])

    main()

    assert capsys.readouterr().out == (
        "Data readiness: not_ready\n"
        "Hardware components: 715\n"
        "Component prices: 120\n"
        "Active build templates: 3\n"
        "Recommended cpu: 12\n"
        "Recommended gpu: 10\n"
        "Recommended motherboard: 8\n"
        "Recommended ram: 4\n"
        "Recommended storage: 4\n"
        "Recommended psu: 4\n"
        "Priced recommended cpu: 12\n"
        "Priced recommended gpu: 9\n"
        "Priced recommended motherboard: 8\n"
        "Priced recommended ram: 4\n"
        "Priced recommended storage: 4\n"
        "Priced recommended psu: 4\n"
    )


def test_check_data_readiness_command_reports_missing_categories(monkeypatch, capsys) -> None:
    class FakeSession:
        def __enter__(self):
            return self

        def __exit__(self, exc_type, exc, tb):
            return False

    class FakeReadiness:
        ready = False
        component_count = 715
        price_count = 1
        active_template_count = 0
        recommended_counts = {
            "cpu": 0,
            "gpu": 0,
            "motherboard": 0,
            "ram": 0,
            "storage": 0,
            "psu": 0,
        }
        priced_recommended_counts = {
            "cpu": 0,
            "gpu": 0,
            "motherboard": 0,
            "ram": 0,
            "storage": 0,
            "psu": 0,
        }
        missing_recommended_categories = ["cpu", "gpu", "motherboard", "ram", "storage", "psu"]
        missing_priced_recommended_categories = ["cpu", "gpu", "motherboard", "ram", "storage", "psu"]

    def fake_create_session_factory(settings):
        return lambda: FakeSession()

    def fake_build_data_readiness(session):
        return FakeReadiness()

    monkeypatch.setattr("app.cli.create_session_factory", fake_create_session_factory)
    monkeypatch.setattr("app.cli.build_data_readiness", fake_build_data_readiness)
    monkeypatch.setattr("sys.argv", ["ai-pc-builder-api", "check-data-readiness"])

    main()

    output = capsys.readouterr().out
    assert "Missing recommended categories: cpu, gpu, motherboard, ram, storage, psu" in output
    assert "Missing priced recommended categories: cpu, gpu, motherboard, ram, storage, psu" in output
