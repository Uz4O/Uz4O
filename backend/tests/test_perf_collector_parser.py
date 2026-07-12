import gzip
from pathlib import Path
from typing import Optional, Tuple

import pytest

from app.perf.collector_parser import ParseError, parse_medium_results


FIXTURE = Path(__file__).parents[1] / "data" / "pc-builds-fps-example.html.gz"


def row(resolution: str, average: int, minimum: int, maximum: int, bottleneck: str) -> str:
    return (
        f"<tr><td>{resolution}</td><td>{average}</td><td>{minimum}</td>"
        f"<td>{maximum}</td><td>{bottleneck}</td></tr>"
    )


def table(*rows: str, header: Optional[str] = None) -> str:
    header = header or (
        "<tr><th>Resolution</th><th>Average FPS</th><th>Minimum FPS</th>"
        "<th>Maximum FPS</th><th>Bottleneck</th></tr>"
    )
    return f"<table>{header}{''.join(rows)}</table>"


def valid_rows() -> Tuple[str, str, str]:
    return (
        row("1920 x 1080", 77, 66, 89, "CPU bottleneck 11%"),
        row("2560 x 1440", 58, 49, 66, "No bottleneck 0%"),
        row("3840 x 2160", 38, 32, 44, "No bottleneck 0%"),
    )


def test_parses_verified_gzip_fixture_in_fixed_resolution_order() -> None:
    with gzip.open(FIXTURE, "rt", encoding="utf-8") as fixture:
        parsed = parse_medium_results(fixture.read())

    assert [
        (item.resolution, item.average_fps, item.minimum_fps, item.maximum_fps)
        for item in parsed
    ] == [
        ("1080p", 77, 66, 89),
        ("2k", 58, 49, 66),
        ("4k", 38, 32, 44),
    ]
    assert (parsed[0].bottleneck_type, parsed[0].bottleneck_percent) == ("cpu", 11)
    assert [(item.bottleneck_type, item.bottleneck_percent) for item in parsed[1:]] == [
        ("balanced", 0),
        ("balanced", 0),
    ]


def test_missing_target_resolution_raises() -> None:
    with pytest.raises(ParseError, match="missing"):
        parse_medium_results(table(*valid_rows()[:2]))


def test_duplicate_target_resolution_raises() -> None:
    with pytest.raises(ParseError, match="duplicate"):
        parse_medium_results(table(*valid_rows(), valid_rows()[0]))


@pytest.mark.parametrize(
    "average,minimum,maximum",
    [(10, 0, 20), (10, 11, 20), (21, 10, 20), (1000, 10, 2001)],
)
def test_invalid_fps_order_or_range_raises(average: int, minimum: int, maximum: int) -> None:
    rows = list(valid_rows())
    rows[0] = row("1920 x 1080", average, minimum, maximum, "CPU bottleneck 11%")

    with pytest.raises(ParseError, match="FPS"):
        parse_medium_results(table(*rows))


@pytest.mark.parametrize(
    "html",
    [
        "<table><tr><th>Name</th><th>Value</th></tr><tr><td>Average</td><td>77</td></tr></table>",
        table(
            *valid_rows(),
            header="<tr><th>Resolution</th><th>Average</th><th>Minimum</th><th>Bottleneck</th></tr>",
        ),
    ],
)
def test_missing_results_table_or_required_column_raises(html: str) -> None:
    with pytest.raises(ParseError, match="table"):
        parse_medium_results(html)


def test_supports_english_headers_and_bottleneck_text() -> None:
    parsed = parse_medium_results(
        table(
            row("1920x1080", 80, 70, 90, "CPU 12%"),
            row("2560x1440", 60, 50, 70, "GPU bottleneck 8%"),
            row("3840x2160", 40, 30, 50, "No bottleneck"),
        )
    )

    assert [(item.bottleneck_type, item.bottleneck_percent) for item in parsed] == [
        ("cpu", 12),
        ("gpu", 8),
        ("balanced", None),
    ]
