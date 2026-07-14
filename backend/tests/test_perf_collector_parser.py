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
        row("1920 x 1080", 77, 66, 89, "CPU bottleneck (11%)"),
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
    "resolution", ["11920x10800", "11920x1080", "1920x10801"]
)
def test_resolution_with_extra_digits_does_not_match(resolution: str) -> None:
    malformed = row(resolution, 77, 66, 89, "CPU bottleneck 11%")

    with pytest.raises(ParseError, match="missing"):
        parse_medium_results(table(malformed, *valid_rows()[1:]))


def test_combined_resolutions_in_one_cell_raise() -> None:
    combined = row(
        "1920x1080/2560x1440", 77, 66, 89, "CPU bottleneck 11%"
    )

    with pytest.raises(ParseError, match="multiple"):
        parse_medium_results(table(combined, *valid_rows()[1:]))


def test_resolution_allows_star_and_emoji_decoration() -> None:
    decorated = row("🎮 ★ 1920 × 1080 ★", 77, 66, 89, "CPU 11%")

    parsed = parse_medium_results(table(decorated, *valid_rows()[1:]))

    assert [item.resolution for item in parsed] == ["1080p", "2k", "4k"]


def test_nonempty_short_data_row_raises_even_when_target_rows_are_complete() -> None:
    short_row = "<tr><td>unexpected summary</td></tr>"

    with pytest.raises(ParseError, match="columns"):
        parse_medium_results(table(*valid_rows(), short_row))


@pytest.mark.parametrize(
    "average,minimum,maximum",
    [(10, 0, 20), (10, 11, 20), (21, 10, 20), (1000, 10, 2001)],
)
def test_invalid_fps_order_or_range_raises(average: int, minimum: int, maximum: int) -> None:
    rows = list(valid_rows())
    rows[0] = row("1920 x 1080", average, minimum, maximum, "CPU bottleneck 11%")

    with pytest.raises(ParseError, match="FPS"):
        parse_medium_results(table(*rows))


@pytest.mark.parametrize("average", ["-5", "1,2,3", "1,000", ".5", "12.5"])
def test_signed_or_comma_separated_fps_raises(average: str) -> None:
    rows = list(valid_rows())
    rows[0] = row("1920 x 1080", average, 1, 1200, "CPU bottleneck 11%")

    with pytest.raises(ParseError, match="FPS"):
        parse_medium_results(table(*rows))


@pytest.mark.parametrize("percent", ["-11%", "1,000%", ".5%", "11.5%"])
def test_signed_or_comma_separated_bottleneck_percent_raises(percent: str) -> None:
    rows = list(valid_rows())
    rows[0] = row("1920 x 1080", 77, 66, 89, f"CPU bottleneck {percent}")

    with pytest.raises(ParseError, match="percentage"):
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


def test_no_bottleneck_text_takes_priority_over_cpu_or_gpu_words() -> None:
    parsed = parse_medium_results(
        table(
            row("1920x1080", 80, 70, 90, "No bottleneck despite CPU 11%"),
            row("2560x1440", 60, 50, 70, "无瓶颈 GPU 9%"),
            row("3840x2160", 40, 30, 50, "No bottleneck 0%"),
        )
    )

    assert [(item.bottleneck_type, item.bottleneck_percent) for item in parsed] == [
        ("balanced", 11),
        ("balanced", 9),
        ("balanced", 0),
    ]


def test_ignores_emoji_and_star_noise_in_playability_column() -> None:
    header = (
        "<tr><th>Resolution</th><th>Average FPS</th><th>Minimum FPS</th>"
        "<th>Maximum FPS</th><th>Playability</th><th>Bottleneck</th></tr>"
    )
    noisy_rows = (
        "<tr><td>1920x1080</td><td>🎮 80 FPS</td><td>70 FPS</td><td>90 FPS ★</td>"
        "<td>🌟★★★ Excellent</td><td>CPU 12%</td></tr>",
        "<tr><td>2560x1440</td><td>60</td><td>50</td><td>70</td>"
        "<td>😊 ★★</td><td>GPU 8%</td></tr>",
        "<tr><td>3840x2160</td><td>40</td><td>30</td><td>50</td>"
        "<td>⚠️ ★</td><td>No bottleneck</td></tr>",
    )

    parsed = parse_medium_results(table(*noisy_rows, header=header))

    assert [(item.resolution, item.average_fps) for item in parsed] == [
        ("1080p", 80),
        ("2k", 60),
        ("4k", 40),
    ]


def test_uses_only_complete_candidate_results_table() -> None:
    incomplete = table(*valid_rows()[:2])
    complete = table(
        row("1920x1080", 80, 70, 90, "CPU 12%"),
        row("2560x1440", 60, 50, 70, "GPU 8%"),
        row("3840x2160", 40, 30, 50, "No bottleneck"),
    )

    parsed = parse_medium_results(incomplete + complete)

    assert [item.average_fps for item in parsed] == [80, 60, 40]


def test_skips_malformed_candidate_when_another_candidate_is_valid() -> None:
    malformed = table(*valid_rows(), "<tr><td>unexpected summary</td></tr>")
    valid = table(
        row("1920x1080", 80, 70, 90, "CPU 12%"),
        row("2560x1440", 60, 50, 70, "GPU 8%"),
        row("3840x2160", 40, 30, 50, "No bottleneck"),
    )

    parsed = parse_medium_results(malformed + valid)

    assert [item.average_fps for item in parsed] == [80, 60, 40]


def test_multiple_complete_candidate_tables_raise_ambiguous() -> None:
    first = table(*valid_rows())
    second = table(
        row("1920x1080", 80, 70, 90, "CPU 12%"),
        row("2560x1440", 60, 50, 70, "GPU 8%"),
        row("3840x2160", 40, 30, 50, "No bottleneck"),
    )

    with pytest.raises(ParseError, match="ambiguous"):
        parse_medium_results(first + second)
