# Self-Owned Game FPS Estimation Model Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a reviewed-anchor FPS estimator that returns average FPS for every supported CPU/GPU/game/resolution combination without relying on blocked PC-Builds data.

**Architecture:** Keep the existing exact-result table as historical evidence, but add a separate estimator path made of fixed game profiles, deterministic render-mode capabilities, reviewed axis/cross anchors, piecewise-linear interpolation, and a published calibration summary. The API uses an active calibrated model only; synthetic fixtures test the engine, while production reference values must come from self-measurement, written authorization, or open-license sources.

**Tech Stack:** Python 3.9+, FastAPI, Pydantic, SQLAlchemy 2, Alembic, pytest, Swift 6, SwiftUI.

---

## File map

- `backend/app/perf/profiles.py`: approved 15-game load classes, caps, and game-side render-feature support.
- `backend/app/perf/estimator.py`: pure interpolation, extrapolation, bottleneck, cap, and average-FPS prediction.
- `backend/app/perf/anchor_importer.py`: reviewed anchor JSON validation.
- `backend/app/perf/anchor_repository.py`: anchor and calibration persistence/query operations.
- `backend/app/perf/calibration.py`: validation-set MAPE and publishable calibration summaries.
- `backend/app/perf/models.py`: reviewed hardware profiles, anchors, and calibration models alongside the historical exact table.
- `backend/app/perf/service.py`: average-only estimator API.
- `backend/app/cli.py`: import and calibration-report commands.
- `May/May/Networking/AppAPIClient.swift`: average-only response DTOs.
- `May/May/Models/PerformanceTestFlow.swift`: average-only result state.
- `May/May/Screens/DIYBuildView.swift`: average-only result presentation.

### Task 1: Approved game profiles and render-mode policy

**Files:**
- Create: `backend/app/perf/profiles.py`
- Create: `backend/tests/test_perf_profiles.py`

- [ ] **Step 1: Write failing profile coverage and render-mode tests**

```python
from app.perf.profiles import (
    APPROVED_GAME_PROFILES,
    GameLoadType,
    GPUCapabilities,
    RenderMode,
    render_mode_for,
)


def test_profiles_cover_the_approved_15_games() -> None:
    assert list(APPROVED_GAME_PROFILES) == [
        "valorant", "cs2", "pubg", "delta-force", "teamfight-tactics",
        "league-of-legends", "call-of-duty-warzone", "cyberpunk-2077",
        "red-dead-redemption-2", "gta-v", "black-myth-wukong",
        "forza-horizon-6", "elden-ring", "cities-skylines",
        "minecraft-java-edition",
    ]
    assert APPROVED_GAME_PROFILES["valorant"].load_type is GameLoadType.CPU
    assert APPROVED_GAME_PROFILES["cyberpunk-2077"].load_type is GameLoadType.GPU
    assert APPROVED_GAME_PROFILES["pubg"].load_type is GameLoadType.MIXED
    assert APPROVED_GAME_PROFILES["elden-ring"].fps_cap == 60


def test_render_mode_uses_supported_quality_upscaling_and_standard_fg() -> None:
    cyberpunk = APPROVED_GAME_PROFILES["cyberpunk-2077"]
    dlss_fg = GPUCapabilities(True, True, True)
    dlss_only = GPUCapabilities(True, True, False)
    fsr_fg = GPUCapabilities(False, True, True)
    fsr_only = GPUCapabilities(False, True, False)
    assert render_mode_for(cyberpunk, dlss_fg) is RenderMode.DLSS_QUALITY_FG
    assert render_mode_for(cyberpunk, dlss_only) is RenderMode.DLSS_QUALITY
    assert render_mode_for(cyberpunk, fsr_fg) is RenderMode.FSR_QUALITY_FG
    assert render_mode_for(cyberpunk, fsr_only) is RenderMode.FSR_QUALITY
    assert render_mode_for(APPROVED_GAME_PROFILES["valorant"], dlss_fg) is RenderMode.NATIVE
```

- [ ] **Step 2: Run the tests and verify RED**

Run:

```bash
cd backend
/Users/may/Documents/AI装机/backend/.venv/bin/pytest tests/test_perf_profiles.py -q
```

Expected: import failure because `app.perf.profiles` does not exist.

- [ ] **Step 3: Implement the fixed profiles and capability policy**

```python
from dataclasses import dataclass
from enum import Enum
from typing import Dict, Optional


class GameLoadType(str, Enum):
    CPU = "cpu"
    GPU = "gpu"
    MIXED = "mixed"


class RenderMode(str, Enum):
    NATIVE = "native"
    DLSS_QUALITY = "dlss_quality"
    DLSS_QUALITY_FG = "dlss_quality_fg"
    FSR_QUALITY = "fsr_quality"
    FSR_QUALITY_FG = "fsr_quality_fg"


@dataclass(frozen=True)
class GameProfile:
    game_id: str
    load_type: GameLoadType
    supports_dlss: bool = False
    supports_fsr: bool = False
    supports_frame_generation: bool = False
    fps_cap: Optional[int] = None


@dataclass(frozen=True)
class GPUCapabilities:
    supports_dlss: bool
    supports_fsr: bool
    supports_standard_frame_generation: bool


APPROVED_GAME_PROFILES: Dict[str, GameProfile] = {
    "valorant": GameProfile("valorant", GameLoadType.CPU),
    "cs2": GameProfile("cs2", GameLoadType.CPU, supports_fsr=True),
    "pubg": GameProfile("pubg", GameLoadType.MIXED, supports_dlss=True),
    "delta-force": GameProfile("delta-force", GameLoadType.MIXED, True, True, True),
    "teamfight-tactics": GameProfile("teamfight-tactics", GameLoadType.CPU),
    "league-of-legends": GameProfile("league-of-legends", GameLoadType.CPU),
    "call-of-duty-warzone": GameProfile("call-of-duty-warzone", GameLoadType.MIXED, True, True, True),
    "cyberpunk-2077": GameProfile("cyberpunk-2077", GameLoadType.GPU, True, True, True),
    "red-dead-redemption-2": GameProfile("red-dead-redemption-2", GameLoadType.GPU, True, True),
    "gta-v": GameProfile("gta-v", GameLoadType.MIXED),
    "black-myth-wukong": GameProfile("black-myth-wukong", GameLoadType.GPU, True, True, True),
    "forza-horizon-6": GameProfile("forza-horizon-6", GameLoadType.GPU),
    "elden-ring": GameProfile("elden-ring", GameLoadType.GPU, fps_cap=60),
    "cities-skylines": GameProfile("cities-skylines", GameLoadType.CPU),
    "minecraft-java-edition": GameProfile("minecraft-java-edition", GameLoadType.CPU),
}
```

Implement `render_mode_for()` from the reviewed capability record. It must never infer features from a GPU ID or name:

```python
def render_mode_for(
    profile: GameProfile,
    gpu: GPUCapabilities,
) -> RenderMode:
    if profile.supports_dlss and gpu.supports_dlss:
        if profile.supports_frame_generation and gpu.supports_standard_frame_generation:
            return RenderMode.DLSS_QUALITY_FG
        return RenderMode.DLSS_QUALITY
    if profile.supports_fsr and gpu.supports_fsr:
        if profile.supports_frame_generation and gpu.supports_standard_frame_generation:
            return RenderMode.FSR_QUALITY_FG
        return RenderMode.FSR_QUALITY
    return RenderMode.NATIVE
```

- [ ] **Step 4: Run focused tests and commit**

```bash
cd backend
/Users/may/Documents/AI装机/backend/.venv/bin/pytest tests/test_perf_profiles.py -q
git add app/perf/profiles.py tests/test_perf_profiles.py
git commit -m "feat: define FPS game profiles"
```

Expected: focused tests pass.

### Task 2: Pure average-FPS interpolation engine

**Files:**
- Create: `backend/app/perf/estimator.py`
- Create: `backend/tests/test_perf_estimator.py`

- [ ] **Step 1: Write failing prediction tests**

```python
import pytest

from app.perf.estimator import LimitPoint, predict_average_fps


CPU_POINTS = [LimitPoint(50, 120), LimitPoint(100, 220)]
GPU_POINTS = [LimitPoint(40, 90), LimitPoint(80, 180)]


def test_prediction_uses_the_lower_hardware_limit() -> None:
    prediction = predict_average_fps(
        cpu_score=75,
        gpu_score=60,
        cpu_points=CPU_POINTS,
        gpu_points=GPU_POINTS,
        correction_factor=0.95,
        fps_cap=None,
    )
    assert prediction.cpu_limit == 170
    assert prediction.gpu_limit == 135
    assert prediction.average_fps == 128
    assert prediction.limiting_component == "gpu"


def test_prediction_extrapolates_monotonically_and_applies_cap() -> None:
    slow = predict_average_fps(40, 35, CPU_POINTS, GPU_POINTS, 1.0, 60)
    fast = predict_average_fps(120, 100, CPU_POINTS, GPU_POINTS, 1.0, 60)
    assert 1 <= slow.average_fps <= fast.average_fps
    assert fast.average_fps == 60


def test_prediction_requires_two_distinct_points_per_axis() -> None:
    with pytest.raises(ValueError, match="two distinct"):
        predict_average_fps(50, 50, [LimitPoint(50, 100)], GPU_POINTS, 1.0, None)
```

- [ ] **Step 2: Verify RED**

```bash
cd backend
/Users/may/Documents/AI装机/backend/.venv/bin/pytest tests/test_perf_estimator.py -q
```

Expected: import failure because `app.perf.estimator` does not exist.

- [ ] **Step 3: Implement piecewise interpolation and bounded extrapolation**

```python
from dataclasses import dataclass
from typing import Optional, Sequence


@dataclass(frozen=True)
class LimitPoint:
    performance_score: int
    average_fps: int


@dataclass(frozen=True)
class AverageFPSPrediction:
    average_fps: int
    cpu_limit: int
    gpu_limit: int
    limiting_component: str


def predict_average_fps(
    cpu_score: int,
    gpu_score: int,
    cpu_points: Sequence[LimitPoint],
    gpu_points: Sequence[LimitPoint],
    correction_factor: float,
    fps_cap: Optional[int],
) -> AverageFPSPrediction:
    cpu_limit = round(_interpolate(cpu_points, cpu_score))
    gpu_limit = round(_interpolate(gpu_points, gpu_score))
    limiting_component = "cpu" if cpu_limit <= gpu_limit else "gpu"
    estimated = max(1, round(min(cpu_limit, gpu_limit) * correction_factor))
    if fps_cap is not None:
        estimated = min(estimated, fps_cap)
    return AverageFPSPrediction(estimated, cpu_limit, gpu_limit, limiting_component)


def _interpolate(points: Sequence[LimitPoint], target_score: int) -> float:
    ordered = sorted(points, key=lambda point: point.performance_score)
    if len({point.performance_score for point in ordered}) != len(ordered):
        raise ValueError("performance scores must be distinct")
    if len(ordered) < 2:
        raise ValueError("each axis requires at least two distinct points")
    if any(right.average_fps < left.average_fps for left, right in zip(ordered, ordered[1:])):
        raise ValueError("average FPS must be monotonic")
    if target_score <= ordered[0].performance_score:
        lower, upper = ordered[0], ordered[1]
    elif target_score >= ordered[-1].performance_score:
        lower, upper = ordered[-2], ordered[-1]
    else:
        lower, upper = next(
            (left, right)
            for left, right in zip(ordered, ordered[1:])
            if left.performance_score <= target_score <= right.performance_score
        )
    distance = upper.performance_score - lower.performance_score
    ratio = (target_score - lower.performance_score) / distance
    return max(1.0, lower.average_fps + ratio * (upper.average_fps - lower.average_fps))
```

This sorts points, uses the two surrounding points, uses the nearest endpoint pair for extrapolation, rejects repeated scores, and clamps the returned limit to at least `1`.

- [ ] **Step 4: Add exact boundary tests and commit**

Add these exact boundary tests:

```python
def test_interpolation_handles_boundaries_and_unordered_points() -> None:
    unordered = [LimitPoint(100, 200), LimitPoint(50, 100)]
    at_point = predict_average_fps(50, 50, unordered, unordered, 1.0, None)
    below = predict_average_fps(25, 25, unordered, unordered, 1.0, None)
    above = predict_average_fps(125, 125, unordered, unordered, 1.0, None)
    assert at_point.average_fps == 100
    assert below.average_fps == 50
    assert above.average_fps == 250


def test_interpolation_rejects_duplicate_scores() -> None:
    duplicates = [LimitPoint(50, 100), LimitPoint(50, 110)]
    with pytest.raises(ValueError, match="distinct"):
        predict_average_fps(50, 50, duplicates, GPU_POINTS, 1.0, None)


def test_interpolation_rejects_non_monotonic_fit_points() -> None:
    decreasing = [LimitPoint(50, 110), LimitPoint(100, 100)]
    with pytest.raises(ValueError, match="monotonic"):
        predict_average_fps(75, 75, decreasing, GPU_POINTS, 1.0, None)
```

```bash
cd backend
/Users/may/Documents/AI装机/backend/.venv/bin/pytest tests/test_perf_estimator.py -q
git add app/perf/estimator.py tests/test_perf_estimator.py
git commit -m "feat: interpolate average FPS limits"
```

Expected: all estimator tests pass.

### Task 3: Anchor and calibration persistence

**Files:**
- Modify: `backend/app/perf/models.py`
- Create: `backend/app/perf/anchor_repository.py`
- Create: `backend/migrations/versions/20260715_0013_game_fps_estimator.py`
- Create: `backend/tests/test_perf_anchor_repository.py`
- Create: `backend/tests/test_game_fps_estimator_migration.py`

- [ ] **Step 1: Write failing model and repository tests**

```python
from datetime import datetime, timezone

from app.perf.anchor_repository import (
    get_hardware_performance_profiles,
    list_axis_anchors,
    upsert_game_performance_anchors,
    upsert_hardware_performance_profiles,
)
from app.perf.models import GamePerformanceAnchor, HardwarePerformanceProfile


def test_hardware_profile_round_trip(session) -> None:
    profile = HardwarePerformanceProfile(
        component_id="rtx-4070",
        category="gpu",
        performance_score=100,
        is_common=True,
        supports_dlss=True,
        supports_fsr=True,
        supports_standard_frame_generation=True,
        source_kind="self_measured",
        source_reference="lab-20260715",
        reviewed_at=datetime(2026, 7, 15, tzinfo=timezone.utc),
        import_batch="test",
    )
    assert upsert_hardware_performance_profiles(session, [profile]) == 1
    assert get_hardware_performance_profiles(session, ["rtx-4070"]) == {
        "rtx-4070": profile
    }


def test_anchor_unique_key_and_round_trip(session) -> None:
    anchor = GamePerformanceAnchor(
        game_id="cyberpunk-2077",
        axis="gpu",
        cpu_id="r7-9800x3d",
        gpu_id="rtx-4070",
        resolution="2k",
        render_mode="dlss_quality_fg",
        average_fps=105,
        sample_role="fit",
        game_version="2.31",
        driver_version="reviewed",
        source_kind="self_measured",
        source_reference="lab-20260715",
        tested_at=datetime(2026, 7, 15, tzinfo=timezone.utc),
        import_batch="test",
    )
    assert upsert_game_performance_anchors(session, [anchor]) == 1
    assert upsert_game_performance_anchors(session, [anchor]) == 1
    assert list_axis_anchors(session, "cyberpunk-2077", "2k", "dlss_quality_fg", "gpu") == [anchor]
```

Add parametrized insert tests that assert database checks reject invalid `category`, `performance_score`, `axis`, `resolution`, `render_mode`, `average_fps`, `sample_role`, and `source_kind` values. The migration test imports every model, upgrades a temporary SQLite database from `20260713_0012` to head, inspects all three new tables and indexes, downgrades to `20260713_0012`, and verifies they are gone.

- [ ] **Step 2: Verify RED**

```bash
cd backend
/Users/may/Documents/AI装机/backend/.venv/bin/pytest tests/test_perf_anchor_repository.py tests/test_game_fps_estimator_migration.py -q
```

Expected: missing model/repository/migration failures.

- [ ] **Step 3: Add normalized models**

Add these model shapes using SQLAlchemy `Mapped` fields and matching named checks/indexes:

```python
class HardwarePerformanceProfile(Base):
    __tablename__ = "hardware_performance_profile"

    component_id: Mapped[str] = mapped_column(
        String,
        ForeignKey("hardware_component.id", ondelete="CASCADE"),
        primary_key=True,
    )
    category: Mapped[str] = mapped_column(String)
    performance_score: Mapped[int] = mapped_column(Integer)
    is_common: Mapped[bool] = mapped_column(Boolean, default=False)
    supports_dlss: Mapped[bool] = mapped_column(Boolean, default=False)
    supports_fsr: Mapped[bool] = mapped_column(Boolean, default=False)
    supports_standard_frame_generation: Mapped[bool] = mapped_column(Boolean, default=False)
    source_kind: Mapped[str] = mapped_column(String)
    source_reference: Mapped[str] = mapped_column(String)
    reviewed_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    import_batch: Mapped[str] = mapped_column(String, index=True)


class GamePerformanceAnchor(Base):
    __tablename__ = "game_performance_anchor"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    game_id: Mapped[str] = mapped_column(String, index=True)
    axis: Mapped[str] = mapped_column(String)
    cpu_id: Mapped[str] = mapped_column(String, ForeignKey("hardware_component.id"))
    gpu_id: Mapped[str] = mapped_column(String, ForeignKey("hardware_component.id"))
    resolution: Mapped[str] = mapped_column(String)
    render_mode: Mapped[str] = mapped_column(String)
    average_fps: Mapped[int] = mapped_column(Integer)
    sample_role: Mapped[str] = mapped_column(String)
    game_version: Mapped[str] = mapped_column(String)
    driver_version: Mapped[str] = mapped_column(String)
    source_kind: Mapped[str] = mapped_column(String)
    source_reference: Mapped[str] = mapped_column(String)
    tested_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    import_batch: Mapped[str] = mapped_column(String, index=True)


class GamePerformanceCalibration(Base):
    __tablename__ = "game_performance_calibration"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    game_id: Mapped[str] = mapped_column(String)
    resolution: Mapped[str] = mapped_column(String)
    render_mode: Mapped[str] = mapped_column(String)
    model_version: Mapped[str] = mapped_column(String)
    correction_factor: Mapped[float] = mapped_column(Float)
    validation_mape: Mapped[float] = mapped_column(Float)
    validation_count: Mapped[int] = mapped_column(Integer)
    common_validation_mape: Mapped[float] = mapped_column(Float)
    common_validation_count: Mapped[int] = mapped_column(Integer)
    is_active: Mapped[bool] = mapped_column(Boolean, default=False)
    calibrated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
```

`HardwarePerformanceProfile` is the reviewed, rights-audited source of the interpolation score, common/rare validation segment, and GPU capabilities for every supported catalog CPU/GPU. Add checks for positive scores and make all three capability flags false when `category = 'cpu'`. Give anchors the unique key `(game_id, axis, cpu_id, gpu_id, resolution, render_mode, sample_role, game_version, driver_version)`. Give calibrations the unique key `(game_id, resolution, render_mode, model_version)` and index `(game_id, resolution, render_mode, is_active)`.

- [ ] **Step 4: Add migration `20260715_0013`**

The migration must declare:

```python
revision = "20260715_0013"
down_revision = "20260713_0012"
```

Create all three tables, foreign keys to `hardware_component.id`, checks matching the models, lookup indexes, and a downgrade that removes indexes before tables.

- [ ] **Step 5: Implement repository operations**

Implement these operations. `_as_utc()` rejects naive datetimes and converts aware values to UTC:

```python
def upsert_hardware_performance_profiles(
    session: Session,
    profiles: Sequence[HardwarePerformanceProfile],
) -> int:
    for profile in profiles:
        profile.reviewed_at = _as_utc(profile.reviewed_at)
        session.merge(profile)
    session.flush()
    return len(profiles)


def get_hardware_performance_profiles(
    session: Session,
    component_ids: Sequence[str],
) -> Dict[str, HardwarePerformanceProfile]:
    rows = session.scalars(
        select(HardwarePerformanceProfile).where(
            HardwarePerformanceProfile.component_id.in_(component_ids)
        )
    )
    return {row.component_id: row for row in rows}


def upsert_game_performance_anchors(
    session: Session,
    anchors: Sequence[GamePerformanceAnchor],
) -> int:
    for anchor in anchors:
        anchor.tested_at = _as_utc(anchor.tested_at)
        existing = session.scalar(
            select(GamePerformanceAnchor).where(
                GamePerformanceAnchor.game_id == anchor.game_id,
                GamePerformanceAnchor.axis == anchor.axis,
                GamePerformanceAnchor.cpu_id == anchor.cpu_id,
                GamePerformanceAnchor.gpu_id == anchor.gpu_id,
                GamePerformanceAnchor.resolution == anchor.resolution,
                GamePerformanceAnchor.render_mode == anchor.render_mode,
                GamePerformanceAnchor.sample_role == anchor.sample_role,
                GamePerformanceAnchor.game_version == anchor.game_version,
                GamePerformanceAnchor.driver_version == anchor.driver_version,
            )
        )
        if existing is None:
            session.add(anchor)
        elif anchor.tested_at >= _as_utc(existing.tested_at):
            for name in (
                "average_fps", "source_kind", "source_reference",
                "tested_at", "import_batch",
            ):
                setattr(existing, name, getattr(anchor, name))
    session.flush()
    return len(anchors)


def list_axis_anchors(
    session: Session,
    game_id: str,
    resolution: str,
    render_mode: str,
    axis: str,
) -> List[GamePerformanceAnchor]:
    statement = select(GamePerformanceAnchor).where(
        GamePerformanceAnchor.game_id == game_id,
        GamePerformanceAnchor.resolution == resolution,
        GamePerformanceAnchor.render_mode == render_mode,
        GamePerformanceAnchor.axis == axis,
        GamePerformanceAnchor.sample_role == "fit",
    )
    return list(session.scalars(statement))


def list_validation_anchors(
    session: Session,
    game_id: str,
    resolution: str,
    render_mode: str,
) -> List[GamePerformanceAnchor]:
    statement = select(GamePerformanceAnchor).where(
        GamePerformanceAnchor.game_id == game_id,
        GamePerformanceAnchor.resolution == resolution,
        GamePerformanceAnchor.render_mode == render_mode,
        GamePerformanceAnchor.sample_role == "validation",
    )
    return list(session.scalars(statement))


def get_active_calibration(
    session: Session,
    game_id: str,
    resolution: str,
    render_mode: str,
) -> Optional[GamePerformanceCalibration]:
    return session.scalar(
        select(GamePerformanceCalibration).where(
            GamePerformanceCalibration.game_id == game_id,
            GamePerformanceCalibration.resolution == resolution,
            GamePerformanceCalibration.render_mode == render_mode,
            GamePerformanceCalibration.is_active.is_(True),
        )
    )


def replace_active_calibration(
    session: Session,
    calibration: GamePerformanceCalibration,
) -> None:
    session.execute(
        update(GamePerformanceCalibration)
        .where(
            GamePerformanceCalibration.game_id == calibration.game_id,
            GamePerformanceCalibration.resolution == calibration.resolution,
            GamePerformanceCalibration.render_mode == calibration.render_mode,
        )
        .values(is_active=False)
    )
    calibration.is_active = True
    session.add(calibration)
    session.flush()


def _as_utc(value: datetime) -> datetime:
    if value.tzinfo is None:
        raise ValueError("timezone-aware datetime required")
    return value.astimezone(timezone.utc)
```

Repository writes flush but do not commit, so one reviewed bundle or one calibration activation stays atomic. Keep the first implementation direct and transactionally simple. If production imports exceed a few thousand rows, replace the per-row anchor lookup with bounded chunk prefetch without changing the public API.

- [ ] **Step 6: Verify migration round-trip and commit**

```bash
cd backend
/Users/may/Documents/AI装机/backend/.venv/bin/pytest tests/test_perf_anchor_repository.py tests/test_game_fps_estimator_migration.py -q
APP_POSTGRES_URL=sqlite+pysqlite:////tmp/fps-estimator-migration.sqlite /Users/may/Documents/AI装机/backend/.venv/bin/alembic upgrade head
APP_POSTGRES_URL=sqlite+pysqlite:////tmp/fps-estimator-migration.sqlite /Users/may/Documents/AI装机/backend/.venv/bin/alembic downgrade 20260713_0012
APP_POSTGRES_URL=sqlite+pysqlite:////tmp/fps-estimator-migration.sqlite /Users/may/Documents/AI装机/backend/.venv/bin/alembic upgrade head
git add app/perf/models.py app/perf/anchor_repository.py migrations/versions/20260715_0013_game_fps_estimator.py tests/test_perf_anchor_repository.py tests/test_game_fps_estimator_migration.py
git commit -m "feat: store FPS estimation anchors"
```

Expected: tests pass and Alembic ends at `20260715_0013 (head)`.

### Task 4: Reviewed hardware/anchor bundle importer and CLI

**Files:**
- Create: `backend/app/perf/anchor_importer.py`
- Modify: `backend/app/cli.py`
- Create: `backend/tests/test_perf_anchor_importer.py`
- Modify: `backend/tests/test_perf_collector_cli.py`

- [ ] **Step 1: Write failing reviewed-input tests**

Use this valid fixture so the performance score and GPU features are reviewed data, not inferred from the product name:

```json
{
  "import_batch": "self-measured-20260715",
  "test_conditions": {
    "quality": "high",
    "ray_tracing": false
  },
  "hardware_profiles": [
    {
      "component_id": "r7-9800x3d",
      "category": "cpu",
      "performance_score": 140,
      "is_common": true,
      "supports_dlss": false,
      "supports_fsr": false,
      "supports_standard_frame_generation": false,
      "source_kind": "self_measured",
      "source_reference": "lab-20260715",
      "reviewed_at": "2026-07-15T00:00:00Z"
    },
    {
      "component_id": "rtx-4070",
      "category": "gpu",
      "performance_score": 100,
      "is_common": true,
      "supports_dlss": true,
      "supports_fsr": true,
      "supports_standard_frame_generation": true,
      "source_kind": "self_measured",
      "source_reference": "lab-20260715",
      "reviewed_at": "2026-07-15T00:00:00Z"
    }
  ],
  "records": [
    {
      "game_id": "cyberpunk-2077",
      "axis": "gpu",
      "cpu_id": "r7-9800x3d",
      "gpu_id": "rtx-4070",
      "resolution": "2k",
      "render_mode": "dlss_quality_fg",
      "average_fps": 105,
      "sample_role": "fit",
      "game_version": "2.31",
      "driver_version": "reviewed",
      "source_kind": "self_measured",
      "source_reference": "lab-20260715",
      "tested_at": "2026-07-15T00:00:00Z"
    }
  ]
}
```

Tests must reject missing or non-high test conditions, enabled ray tracing, unknown games, unknown hardware IDs, mismatched component categories, non-positive performance scores, CPU capability flags, unsupported render modes, per-row quality/ray-tracing overrides, non-positive FPS, missing source proof, naive timestamps, duplicate keys, and `source_kind` outside `self_measured`, `licensed`, or `open_license`.

- [ ] **Step 2: Verify RED**

```bash
cd backend
/Users/may/Documents/AI装机/backend/.venv/bin/pytest tests/test_perf_anchor_importer.py -q
```

Expected: import failure because the anchor importer does not exist.

- [ ] **Step 3: Implement validation before database mutation**

Expose these immutable validated types:

```python
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
from typing import List, Set

import json


@dataclass(frozen=True)
class HardwarePerformanceProfileInput:
    component_id: str
    category: str
    performance_score: int
    is_common: bool
    supports_dlss: bool
    supports_fsr: bool
    supports_standard_frame_generation: bool
    source_kind: str
    source_reference: str
    reviewed_at: datetime
    import_batch: str


@dataclass(frozen=True)
class GamePerformanceAnchorInput:
    game_id: str
    axis: str
    cpu_id: str
    gpu_id: str
    resolution: str
    render_mode: str
    average_fps: int
    sample_role: str
    game_version: str
    driver_version: str
    source_kind: str
    source_reference: str
    tested_at: datetime
    import_batch: str


@dataclass(frozen=True)
class ReviewedFPSBundle:
    hardware_profiles: List[HardwarePerformanceProfileInput]
    anchors: List[GamePerformanceAnchorInput]


def read_reviewed_fps_bundle(
    path: Path,
    known_cpu_ids: Set[str],
    known_gpu_ids: Set[str],
) -> ReviewedFPSBundle:
    document = json.loads(path.read_text(encoding="utf-8"))
    batch = _required_text(document, "import_batch")
    hardware_profiles = _parse_hardware_profiles(
        document.get("hardware_profiles"), batch, known_cpu_ids, known_gpu_ids
    )
    profiles_by_id = {item.component_id: item for item in hardware_profiles}
    anchors = _parse_anchors(
        document.get("records"), batch, profiles_by_id, known_cpu_ids, known_gpu_ids
    )
    return ReviewedFPSBundle(hardware_profiles, anchors)
```

Implement `_required_text()`, `_aware_datetime()`, `_parse_hardware_profiles()`, and `_parse_anchors()` as pure validators. Each builds every dataclass in a temporary list, checks duplicate component/anchor keys, and raises `ValueError` before returning when any row is invalid. `_parse_anchors()` converts the reviewed GPU row to `GPUCapabilities`, requires the approved game profile and exact mode returned by `render_mode_for()`, and rejects fields named `quality`, `ray_tracing`, `minimum_fps`, `maximum_fps`, or `confidence`.

- [ ] **Step 4: Add `import-fps-anchors` CLI**

```bash
cd backend
/Users/may/Documents/AI装机/backend/.venv/bin/python -m app.cli import-fps-model-inputs data/reviewed-fps-inputs.json
```

CLI behavior:

```text
Imported H reviewed hardware profiles and N reviewed FPS anchors.
```

Load catalog CPU/GPU IDs from the configured database, validate the whole file, convert the dataclasses to the Task 3 ORM models, flush both repository upserts, and call `session.commit()` once. On any exception, call `session.rollback()`. Never activate a calibration automatically.

- [ ] **Step 5: Run tests and commit**

```bash
cd backend
/Users/may/Documents/AI装机/backend/.venv/bin/pytest tests/test_perf_anchor_importer.py tests/test_perf_collector_cli.py -q
git add app/perf/anchor_importer.py app/cli.py tests/test_perf_anchor_importer.py tests/test_perf_collector_cli.py
git commit -m "feat: import reviewed FPS model inputs"
```

### Task 5: Calibration, validation report, and activation gate

**Files:**
- Create: `backend/app/perf/calibration.py`
- Create: `backend/app/perf/readiness.py`
- Modify: `backend/app/cli.py`
- Create: `backend/tests/test_perf_calibration.py`
- Create: `backend/tests/test_perf_readiness.py`

- [ ] **Step 1: Write failing calibration tests**

```python
def test_calibration_uses_fit_rows_and_scores_only_validation_rows() -> None:
    result = calibrate_game_model(
        cpu_points=[LimitPoint(50, 100), LimitPoint(100, 200)],
        gpu_points=[LimitPoint(50, 90), LimitPoint(100, 180)],
        validation_samples=[
            ValidationSample(75, 75, 135, True),
            ValidationSample(100, 100, 171, False),
        ],
        fps_cap=None,
    )
    assert result.correction_factor == pytest.approx(0.975, abs=0.001)
    assert result.validation_count == 2
    assert result.common_validation_count == 1
    assert result.common_validation_mape <= 8.0


def test_model_is_not_publishable_without_two_axis_points_and_validation(session) -> None:
    readiness = build_estimator_readiness(session)
    assert readiness.ready is False
    assert "cyberpunk-2077/2k/dlss_quality_fg" in readiness.missing_models
```

- [ ] **Step 2: Verify RED**

```bash
cd backend
/Users/may/Documents/AI装机/backend/.venv/bin/pytest tests/test_perf_calibration.py tests/test_perf_readiness.py -q
```

- [ ] **Step 3: Implement calibration math**

Use this pure implementation so validation rows never become fit points:

```python
from dataclasses import dataclass
from statistics import mean, median
from typing import Optional, Sequence

from app.perf.estimator import LimitPoint, predict_average_fps


@dataclass(frozen=True)
class ValidationSample:
    cpu_score: int
    gpu_score: int
    actual_average_fps: int
    is_common: bool


@dataclass(frozen=True)
class CalibrationResult:
    correction_factor: float
    validation_mape: float
    validation_count: int
    common_validation_mape: float
    common_validation_count: int


def calibrate_game_model(
    cpu_points: Sequence[LimitPoint],
    gpu_points: Sequence[LimitPoint],
    validation_samples: Sequence[ValidationSample],
    fps_cap: Optional[int],
) -> CalibrationResult:
    if len({point.performance_score for point in cpu_points}) < 2:
        raise ValueError("CPU axis requires two distinct fit scores")
    if len({point.performance_score for point in gpu_points}) < 2:
        raise ValueError("GPU axis requires two distinct fit scores")
    if not validation_samples:
        raise ValueError("independent validation samples are required")
    if any(sample.actual_average_fps <= 0 for sample in validation_samples):
        raise ValueError("validation FPS must be positive")

    baselines = [
        predict_average_fps(
            sample.cpu_score,
            sample.gpu_score,
            cpu_points,
            gpu_points,
            1.0,
            fps_cap,
        ).average_fps
        for sample in validation_samples
    ]
    correction_factor = median(
        sample.actual_average_fps / predicted
        for sample, predicted in zip(validation_samples, baselines)
    )
    if not 0.5 <= correction_factor <= 1.5:
        raise ValueError("correction factor is outside the publishable range")

    errors = []
    common_errors = []
    for sample in validation_samples:
        predicted = predict_average_fps(
            sample.cpu_score,
            sample.gpu_score,
            cpu_points,
            gpu_points,
            correction_factor,
            fps_cap,
        ).average_fps
        error = abs(sample.actual_average_fps - predicted) / sample.actual_average_fps
        errors.append(error)
        if sample.is_common:
            common_errors.append(error)
    if not common_errors:
        raise ValueError("common-hardware validation samples are required")
    return CalibrationResult(
        correction_factor=correction_factor,
        validation_mape=mean(errors) * 100,
        validation_count=len(errors),
        common_validation_mape=mean(common_errors) * 100,
        common_validation_count=len(common_errors),
    )
```

- [ ] **Step 4: Implement readiness and activation**

`build_estimator_readiness()` must require, for every approved game/resolution/applicable render mode:

- reviewed hardware performance profiles for every active catalog CPU/GPU;
- two CPU fit scores;
- two GPU fit scores;
- independent validation rows making up at least 20% of all rows for that model;
- at least one common-hardware validation row;
- an active calibration;
- common-hardware validation MAPE ≤ 8%;
- offline overall MAPE retained even when rare hardware exceeds 8%.

Add CLI commands:

```bash
python -m app.cli calibrate-fps-models --version 2026-07-15
python -m app.cli check-fps-model-readiness --json data/fps-model-readiness.json
```

`calibrate-fps-models` joins each anchor to the reviewed CPU/GPU scores, builds CPU/GPU fit `LimitPoint` values only from `sample_role="fit"`, builds `ValidationSample` values only from `sample_role="validation"`, and creates an inactive calibration row first. It calls `replace_active_calibration()` only when the 20% holdout, common-sample, correction-range, and common MAPE gates pass; on failure the previous active row remains active. `check-fps-model-readiness` writes an atomic JSON report with hardware-profile coverage, row counts, active models, overall/common MAPE, and missing model keys, and never changes database state.

- [ ] **Step 5: Test and commit**

```bash
cd backend
/Users/may/Documents/AI装机/backend/.venv/bin/pytest tests/test_perf_calibration.py tests/test_perf_readiness.py -q
git add app/perf/calibration.py app/perf/readiness.py app/cli.py tests/test_perf_calibration.py tests/test_perf_readiness.py
git commit -m "feat: calibrate and gate FPS models"
```

### Task 6: Average-only estimator API

**Files:**
- Modify: `backend/app/perf/service.py`
- Modify: `backend/tests/test_perf_api.py`

- [ ] **Step 1: Replace exact-row response tests with average-only estimator tests**

Seed fit anchors and an active calibration, then assert:

```python
assert response.json() == {
    "status": "ready",
    "average_fps": 128,
    "advice": "高画质，支持时开启质量档超分和标准帧生成。",
    "missing_data": [],
    "missing_games": [],
    "game_results": [
        {"game": "cyberpunk-2077", "average_fps": 128}
    ],
}
```

Use separate seeded cases with these exact assertions:

```python
assert post_estimate(cpu_limited_client, ["valorant"]).json()["average_fps"] == 120
assert post_estimate(gpu_limited_client, ["cyberpunk-2077"]).json()["average_fps"] == 128
assert post_estimate(uncapped_fast_client, ["elden-ring"]).json()["average_fps"] == 60
assert post_estimate(dlss_without_fg_client, ["cyberpunk-2077"]).json()["average_fps"] == 91
assert post_estimate(two_game_client, ["valorant", "cyberpunk-2077"]).json()["average_fps"] == 124
assert len(post_estimate(all_models_client, ["all-games"]).json()["game_results"]) == 15
assert post_estimate(unknown_cpu_client, ["cs2"]).status_code == 422
assert post_estimate(inactive_model_client, ["cs2"]).json()["status"] == "needs_more_data"
```

Add an SSE assertion that the final `result` event contains the same average-only JSON shape. Historical `GamePerformanceEstimate` rows must not make an inactive estimator model ready.

- [ ] **Step 2: Verify RED**

```bash
cd backend
/Users/may/Documents/AI装机/backend/.venv/bin/pytest tests/test_perf_api.py -q
```

- [ ] **Step 3: Implement average-only request path**

Replace response types with:

```python
class GamePerfEstimate(BaseModel):
    game: str
    average_fps: int


class PerfEstimateResponse(BaseModel):
    status: Literal["ready", "partial", "needs_more_data"]
    average_fps: Optional[int]
    advice: str
    missing_data: List[str]
    missing_games: List[str]
    game_results: List[GamePerfEstimate]
```

For each requested game, select the render mode, load two axis point sets and the active calibration, call `predict_average_fps()`, and aggregate only successful game predictions. Do not use the historical PC-Builds exact table as a silent numeric fallback.

Use this helper boundary in `service.py`; repository queries remain in the service, while interpolation remains pure:

```python
def _estimate_game(
    session: Session,
    game_id: str,
    resolution: str,
    cpu_profile: HardwarePerformanceProfile,
    gpu_profile: HardwarePerformanceProfile,
) -> Optional[GamePerfEstimate]:
    game = APPROVED_GAME_PROFILES[game_id]
    mode = render_mode_for(
        game,
        GPUCapabilities(
            gpu_profile.supports_dlss,
            gpu_profile.supports_fsr,
            gpu_profile.supports_standard_frame_generation,
        ),
    ).value
    calibration = get_active_calibration(session, game_id, resolution, mode)
    if calibration is None:
        return None
    cpu_anchors = list_axis_anchors(session, game_id, resolution, mode, "cpu")
    gpu_anchors = list_axis_anchors(session, game_id, resolution, mode, "gpu")
    anchor_ids = [anchor.cpu_id for anchor in cpu_anchors]
    anchor_ids.extend(anchor.gpu_id for anchor in gpu_anchors)
    profiles = get_hardware_performance_profiles(session, anchor_ids)
    if len(profiles) != len(set(anchor_ids)):
        return None
    prediction = predict_average_fps(
        cpu_profile.performance_score,
        gpu_profile.performance_score,
        [LimitPoint(profiles[row.cpu_id].performance_score, row.average_fps) for row in cpu_anchors],
        [LimitPoint(profiles[row.gpu_id].performance_score, row.average_fps) for row in gpu_anchors],
        calibration.correction_factor,
        game.fps_cap,
    )
    return GamePerfEstimate(game=game_id, average_fps=prediction.average_fps)
```

`estimate_performance()` must require catalog rows with categories `cpu` and `gpu`, require reviewed hardware profiles for both requested IDs, reject unknown game IDs with HTTP 422, and call `_estimate_game()` in the approved request order. Return `ready` only when every requested game succeeds, `partial` when at least one succeeds, and `needs_more_data` when none succeeds. The aggregate is `round(mean(result.average_fps for result in game_results))`.

- [ ] **Step 4: Run API/full performance tests and commit**

```bash
cd backend
/Users/may/Documents/AI装机/backend/.venv/bin/pytest tests/test_perf_api.py tests/test_perf_estimator.py tests/test_perf_profiles.py -q
git add app/perf/service.py tests/test_perf_api.py
git commit -m "feat: serve calibrated average FPS estimates"
```

### Task 7: Average-only iOS result

**Files:**
- Modify: `May/May/Networking/AppAPIClient.swift`
- Modify: `May/May/Models/PerformanceTestFlow.swift`
- Modify: `May/May/Screens/DIYBuildView.swift`
- Modify: `May/MayTests/PerformanceTestFlowRulesTests.swift`

- [ ] **Step 1: Write failing Swift rules**

Update the DTO fixture and assert:

```swift
let response = PerformanceEstimatePayload(
    status: .ready,
    averageFPS: 128,
    missingGames: [],
    gameResults: [
        GamePerformanceResult(gameID: "cyberpunk-2077", averageFPS: 128)
    ]
)
flow.apply(response, for: request)
assertEqual(flow.result?.averageFPS, "128 FPS", "Result must use backend average FPS.")
```

Add source assertions that `lowFPS`, `maximumFPS`, confidence, bottleneck, and source timestamp are absent from performance DTO/result types.

- [ ] **Step 2: Verify RED**

```bash
swiftc May/May/Models/HardwareCatalog.swift May/May/Models/OnboardingProfile.swift May/May/Models/PerformanceTestFlow.swift May/MayTests/PerformanceTestFlowRulesTests.swift -o /tmp/performance-rules
```

Expected: compile failures until DTOs and result models are simplified.

- [ ] **Step 3: Simplify DTO and flow models**

Use:

```swift
struct GamePerformanceResult: Equatable {
    let gameID: String
    let averageFPS: Int
}

struct PerformanceEstimatePayload: Equatable {
    let status: PerformanceEstimateStatus
    let averageFPS: Int?
    let missingGames: [String]
    let gameResults: [GamePerformanceResult]
}

struct PerformanceTestResult: Equatable {
    let resolution: String
    let averageFPS: String
    let missingGameNames: [String]
    let gameResults: [GamePerformanceResult]
}
```

Keep request token/cancellation behavior unchanged.

- [ ] **Step 4: Simplify result UI**

The primary card displays only resolution, “高画质”, and average FPS. Per-game cards display only game name and average FPS. Keep loading, partial, empty, failed, retry, accessibility, and fixed disclosure states.

- [ ] **Step 5: Verify and commit**

```bash
swiftc May/May/Models/HardwareCatalog.swift May/May/Models/OnboardingProfile.swift May/May/Models/PerformanceTestFlow.swift May/MayTests/PerformanceTestFlowRulesTests.swift -o /tmp/performance-rules && /tmp/performance-rules
xcodebuild -project May/May.xcodeproj -scheme May -destination 'platform=iOS Simulator,name=iPhone 17' -configuration Debug build
git add May/May/Networking/AppAPIClient.swift May/May/Models/PerformanceTestFlow.swift May/May/Screens/DIYBuildView.swift May/MayTests/PerformanceTestFlowRulesTests.swift
git commit -m "feat: show average-only FPS estimates"
```

### Task 8: Final verification and honest readiness metadata

**Files:**
- Modify: `backend/progress.json`
- Create: `backend/data/fps-model-readiness.json`

- [ ] **Step 1: Generate readiness report**

Run against the development database containing only reviewed anchors:

```bash
cd backend
python -m app.cli check-fps-model-readiness --json data/fps-model-readiness.json
```

Expected: the report accurately lists active and missing game/resolution/render-mode models. It must not claim ready when production anchor data is absent.

- [ ] **Step 2: Run complete verification**

```bash
cd backend
/Users/may/Documents/AI装机/backend/.venv/bin/pytest -q
swiftc ../May/May/Models/HardwareCatalog.swift ../May/May/Models/OnboardingProfile.swift ../May/May/Models/PerformanceTestFlow.swift ../May/MayTests/PerformanceTestFlowRulesTests.swift -o /tmp/performance-rules && /tmp/performance-rules
cd ..
xcodebuild -project May/May.xcodeproj -scheme May -destination 'platform=iOS Simulator,name=iPhone 17' -configuration Debug build
```

- [ ] **Step 3: Update progress accurately**

Keep the game-performance implementation item completed, but state separately:

- estimator engine/API/iOS implementation status;
- reviewed anchor counts;
- active model counts;
- current validation MAPE;
- production readiness false until every published model meets its gate;
- no unlicensed third-party data or user-upload data is used.

- [ ] **Step 4: Commit metadata**

```bash
git add backend/progress.json backend/data/fps-model-readiness.json
git commit -m "docs: record FPS model readiness"
```

## Acceptance checklist

- [ ] Exactly 15 approved game profiles are classified as CPU, GPU, or mixed.
- [ ] High quality, ray tracing off, quality upscaling, and supported standard frame generation are deterministic.
- [ ] Average FPS is calculated as the lower CPU/GPU limit with per-game correction and cap.
- [ ] Interpolation and bounded extrapolation return a number for every supported catalog combination once a model is active.
- [ ] Unknown hardware IDs are rejected rather than invented.
- [ ] Reviewed anchors include source rights, game/driver versions, render mode, and fit/validation role.
- [ ] Validation data is not used for fitting.
- [ ] Active common-hardware models have validation MAPE ≤ 8%.
- [ ] API and iOS expose average FPS only; no low/max/confidence/user upload path remains.
- [ ] No blocked PC-Builds collection or unlicensed data is used as production input.
- [ ] Full backend tests, Swift rules, Alembic round-trip, and iPhone 17 build pass.
