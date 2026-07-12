from datetime import datetime, timezone
from statistics import mean
from typing import List, Literal, Optional, Sequence

from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from app.catalog.models import HardwareComponent
from app.catalog.repository import get_components_by_ids
from app.perf.collector_manifest import APPROVED_GAMES
from app.perf.models import GamePerformanceEstimate
from app.perf.repository import get_performance_estimates


PerfStatus = Literal["ready", "partial", "needs_more_data"]
Confidence = Literal["low", "medium", "high"]
Resolution = Literal["1080p", "2k", "4k"]

ALL_GAME_IDS = [game[0] for game in APPROVED_GAMES]


class PerfHardwareInput(BaseModel):
    cpu: str = Field(min_length=1, max_length=160)
    gpu: str = Field(min_length=1, max_length=160)


class PerfEstimateRequest(BaseModel):
    hardware: PerfHardwareInput
    resolution: Resolution
    games: List[str] = Field(min_length=1, max_length=12)


class GamePerfEstimate(BaseModel):
    game: str
    average_fps: int
    low_fps: int
    maximum_fps: int
    bottleneck: Optional[str]
    bottleneck_percent: Optional[int]
    confidence: Confidence
    source_fetched_at: datetime


class PerfEstimateResponse(BaseModel):
    status: PerfStatus
    average_fps: Optional[int]
    low_fps: Optional[int]
    maximum_fps: Optional[int]
    bottleneck: Optional[str]
    bottleneck_percent: Optional[int]
    confidence: Confidence
    advice: str
    missing_data: List[str]
    missing_games: List[str]
    source_fetched_at: Optional[datetime]
    game_results: List[GamePerfEstimate]


def estimate_performance(session: Session, request: PerfEstimateRequest) -> PerfEstimateResponse:
    requested_games = _requested_games(request.games)
    components = {
        component.id: component
        for component in get_components_by_ids(session, [request.hardware.cpu, request.hardware.gpu])
    }
    missing_data = _missing_data(
        components.get(request.hardware.cpu),
        components.get(request.hardware.gpu),
    )
    if missing_data:
        return _no_data_response(requested_games, missing_data)

    rows_by_game = {
        row.game_id: row
        for row in get_performance_estimates(
            session,
            request.hardware.cpu,
            request.hardware.gpu,
            requested_games,
            request.resolution,
            "medium",
        )
    }
    rows = [rows_by_game[game_id] for game_id in requested_games if game_id in rows_by_game]
    missing_games = [game_id for game_id in requested_games if game_id not in rows_by_game]
    if not rows:
        return _no_data_response(missing_games, [])

    game_results = [_game_result(row) for row in rows]
    bottleneck_row = max(
        (row for row in rows if row.bottleneck_percent is not None),
        key=lambda row: row.bottleneck_percent,
        default=None,
    )
    return PerfEstimateResponse(
        status="partial" if missing_games else "ready",
        average_fps=round(mean(row.average_fps for row in rows)),
        low_fps=min(row.minimum_fps for row in rows),
        maximum_fps=max(row.maximum_fps for row in rows),
        bottleneck=bottleneck_row.bottleneck_type if bottleneck_row else None,
        bottleneck_percent=bottleneck_row.bottleneck_percent if bottleneck_row else None,
        confidence="medium",
        advice="结果为中等画质下的性能估算。",
        missing_data=[],
        missing_games=missing_games,
        source_fetched_at=min(_as_utc(row.source_fetched_at) for row in rows),
        game_results=game_results,
    )


def _requested_games(games: Sequence[str]) -> List[str]:
    if "all-games" in games:
        return ALL_GAME_IDS
    return list(dict.fromkeys(games))


def _game_result(row: GamePerformanceEstimate) -> GamePerfEstimate:
    return GamePerfEstimate(
        game=row.game_id,
        average_fps=row.average_fps,
        low_fps=row.minimum_fps,
        maximum_fps=row.maximum_fps,
        bottleneck=row.bottleneck_type,
        bottleneck_percent=row.bottleneck_percent,
        confidence="medium",
        source_fetched_at=_as_utc(row.source_fetched_at),
    )


def _no_data_response(
    missing_games: List[str],
    missing_data: List[str],
) -> PerfEstimateResponse:
    return PerfEstimateResponse(
        status="needs_more_data",
        average_fps=None,
        low_fps=None,
        maximum_fps=None,
        bottleneck=None,
        bottleneck_percent=None,
        confidence="low",
        advice="当前硬件和游戏组合暂时没有可靠的 FPS 数据。",
        missing_data=missing_data,
        missing_games=missing_games,
        source_fetched_at=None,
        game_results=[],
    )


def _missing_data(
    cpu: Optional[HardwareComponent],
    gpu: Optional[HardwareComponent],
) -> List[str]:
    missing = []
    if cpu is None:
        missing.append("cpu")
    if gpu is None:
        missing.append("gpu")
    return missing


def _as_utc(value: datetime) -> datetime:
    if value.tzinfo is None:
        return value.replace(tzinfo=timezone.utc)
    return value.astimezone(timezone.utc)
