from dataclasses import dataclass
from html.parser import HTMLParser
import re
from typing import Dict, List, Literal, Optional, Tuple


Resolution = Literal["1080p", "2k", "4k"]
BottleneckType = Literal["cpu", "gpu", "balanced"]
_NUMERIC_TOKEN = r"[+-]?(?:[0-9][0-9,.]*|\.[0-9][0-9,.]*)"


@dataclass(frozen=True)
class ParsedPerformanceRow:
    resolution: Resolution
    average_fps: int
    minimum_fps: int
    maximum_fps: int
    bottleneck_type: Optional[BottleneckType]
    bottleneck_percent: Optional[int]


class ParseError(ValueError):
    pass


class _TableParser(HTMLParser):
    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.tables: List[List[List[str]]] = []
        self._table: Optional[List[List[str]]] = None
        self._row: Optional[List[str]] = None
        self._cell: Optional[List[str]] = None

    def handle_starttag(self, tag: str, attrs: List[Tuple[str, Optional[str]]]) -> None:
        if tag == "table":
            self._table = []
        elif tag == "tr" and self._table is not None:
            self._row = []
        elif tag in {"th", "td"} and self._row is not None:
            self._cell = []

    def handle_data(self, data: str) -> None:
        if self._cell is not None:
            self._cell.append(data)

    def handle_endtag(self, tag: str) -> None:
        if tag in {"th", "td"} and self._cell is not None and self._row is not None:
            self._row.append(" ".join("".join(self._cell).split()))
            self._cell = None
        elif tag == "tr" and self._row is not None and self._table is not None:
            self._table.append(self._row)
            self._row = None
        elif tag == "table" and self._table is not None:
            self.tables.append(self._table)
            self._table = None


def _header_kind(text: str) -> Optional[str]:
    value = text.casefold().strip()
    compact = re.sub(r"[\s_\-]+", "", value)
    if "resolution" in compact or "解析度" in compact or "分辨率" in compact:
        return "resolution"
    if "average" in compact or "平均" in compact:
        return "average"
    if (
        "minimum" in compact
        or re.search(r"\bmin\b", value)
        or "最小" in compact
        or compact == "分钟"
    ):
        return "minimum"
    if "maximum" in compact or re.search(r"\bmax\b", value) or "最大" in compact:
        return "maximum"
    if "bottleneck" in compact or "瓶颈" in compact:
        return "bottleneck"
    return None


def _find_results_tables(
    tables: List[List[List[str]]],
) -> List[Tuple[List[List[str]], Dict[str, int], int]]:
    required = {"resolution", "average", "minimum", "maximum", "bottleneck"}
    candidates = []
    for table in tables:
        for row_index, row in enumerate(table):
            columns = {_header_kind(text): index for index, text in enumerate(row)}
            columns.pop(None, None)
            if required <= columns.keys():
                candidates.append((table, columns, row_index))
                break
    if not candidates:
        raise ParseError("results table with required columns not found")
    return candidates


def _resolution(text: str) -> Optional[Resolution]:
    value = re.sub(r"\s+", "", text.casefold()).replace("×", "x")
    if "1920x1080" in value or value in {"1080p", "fhd"}:
        return "1080p"
    if "2560x1440" in value or value in {"2k", "1440p", "qhd"}:
        return "2k"
    if "3840x2160" in value or value in {"4k", "2160p", "uhd"}:
        return "4k"
    return None


def _integer(text: str, label: str) -> int:
    numbers = re.findall(_NUMERIC_TOKEN, text)
    if len(numbers) != 1 or re.fullmatch(r"[0-9]+", numbers[0]) is None:
        raise ParseError(f"invalid {label} FPS value: {text!r}")
    return int(numbers[0])


def _bottleneck(text: str) -> Tuple[BottleneckType, Optional[int]]:
    value = " ".join(text.casefold().split())
    if "无瓶颈" in value or "no bottleneck" in value or "balanced" in value:
        kind: BottleneckType = "balanced"
    elif "cpu" in value:
        kind = "cpu"
    elif "gpu" in value:
        kind = "gpu"
    else:
        raise ParseError(f"unsupported bottleneck value: {text!r}")

    percentages = re.findall(rf"({_NUMERIC_TOKEN})\s*%", value)
    if len(percentages) > 1 or (
        percentages and re.fullmatch(r"[0-9]+", percentages[0]) is None
    ):
        raise ParseError(f"invalid bottleneck percentage: {text!r}")
    if "%" in value and not percentages:
        raise ParseError(f"invalid bottleneck percentage: {text!r}")
    percent = int(percentages[0]) if percentages else None
    if percent is not None and not 0 <= percent <= 100:
        raise ParseError(f"invalid bottleneck percentage: {percent}")
    return kind, percent


def _parse_results_table(
    table: List[List[str]], columns: Dict[str, int], header_index: int
) -> List[ParsedPerformanceRow]:
    parsed: Dict[Resolution, ParsedPerformanceRow] = {}

    for cells in table[header_index + 1 :]:
        if len(cells) <= max(columns.values()):
            if any(cell.strip() for cell in cells):
                raise ParseError("results table data row has too few columns")
            continue
        resolution = _resolution(cells[columns["resolution"]])
        if resolution is None:
            continue
        if resolution in parsed:
            raise ParseError(f"duplicate resolution: {resolution}")

        average = _integer(cells[columns["average"]], "average")
        minimum = _integer(cells[columns["minimum"]], "minimum")
        maximum = _integer(cells[columns["maximum"]], "maximum")
        if not 0 < minimum <= average <= maximum <= 2000:
            raise ParseError(
                f"invalid FPS values for {resolution}: minimum={minimum}, "
                f"average={average}, maximum={maximum}"
            )
        kind, percent = _bottleneck(cells[columns["bottleneck"]])
        parsed[resolution] = ParsedPerformanceRow(
            resolution=resolution,
            average_fps=average,
            minimum_fps=minimum,
            maximum_fps=maximum,
            bottleneck_type=kind,
            bottleneck_percent=percent,
        )

    order: Tuple[Resolution, ...] = ("1080p", "2k", "4k")
    missing = [resolution for resolution in order if resolution not in parsed]
    if missing:
        raise ParseError(f"missing target resolutions: {', '.join(missing)}")
    return [parsed[resolution] for resolution in order]


def parse_medium_results(html: str) -> List[ParsedPerformanceRow]:
    parser = _TableParser()
    parser.feed(html)
    candidates = _find_results_tables(parser.tables)
    parsed = []
    errors = []
    for table, columns, header_index in candidates:
        try:
            parsed.append(_parse_results_table(table, columns, header_index))
        except ParseError as error:
            errors.append(error)

    if len(parsed) > 1:
        raise ParseError("ambiguous results tables")
    if parsed:
        return parsed[0]
    if len(candidates) == 1:
        raise errors[0]
    raise ParseError("no valid results table found")
