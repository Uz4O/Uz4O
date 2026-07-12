# PC-Builds FPS Data Acquisition Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build an internal, resumable PC-Builds FPS collector, import validated medium-quality 1080p/2k/4k estimates into the backend, and replace the iOS performance-test demo values with exact backend results.

**Architecture:** A versioned mapping manifest defines the App-to-PC-Builds IDs. A polite single-worker collector writes tasks and parsed records to a local SQLite staging database, then exports a reviewed JSON batch. The backend imports that batch into a normalized table and serves exact lookups through the existing performance endpoint; the iOS screen requests and renders those results without contacting PC-Builds directly.

**Tech Stack:** Python 3.9+, httpx, stdlib HTML parsing/regular expressions, sqlite3, SQLAlchemy 2, Alembic, FastAPI, pytest, Swift 6, SwiftUI, URLSession, xcodebuild.

---

## File map

- `backend/app/perf/collector_manifest.py`: mapping manifest types, Swift catalog extraction, mapping validation, task-count calculation.
- `backend/app/perf/collector_parser.py`: parse and validate the three medium-quality FPS rows from a result page.
- `backend/app/perf/collector_store.py`: SQLite task queue and parsed-result persistence.
- `backend/app/perf/collector.py`: polite HTTP runner, retry policy, challenge detection, global-stop behavior.
- `backend/app/perf/importer.py`: reviewed JSON batch reader and database upsert orchestration.
- `backend/app/perf/models.py`: normalized `GamePerformanceEstimate` SQLAlchemy model.
- `backend/app/perf/repository.py`: exact FPS lookup and idempotent upsert functions.
- `backend/app/perf/service.py`: API request/response models and exact lookup aggregation.
- `backend/app/cli.py`: manifest, collection, export, and import subcommands.
- `backend/data/pc-builds-fps-mappings.json`: versioned CPU/GPU/game mapping decisions.
- `backend/data/pc-builds-fps-example.html.gz`: one verified parser fixture only.
- `backend/migrations/versions/20260712_0012_game_performance_estimate.py`: production table migration.
- `backend/tests/test_perf_collector_manifest.py`: scope and exact-mapping task tests.
- `backend/tests/test_perf_collector_parser.py`: fixture parsing and validation tests.
- `backend/tests/test_perf_collector_store.py`: resume and state-transition tests.
- `backend/tests/test_perf_collector.py`: retry, rate-limit, challenge, and stop tests.
- `backend/tests/test_perf_importer.py`: JSON validation and idempotent import tests.
- `backend/tests/test_perf_repository.py`: exact database lookup tests.
- `backend/tests/test_perf_api.py`: ready, partial, missing, and all-games API tests.
- `May/May/Networking/AppAPIClient.swift`: performance request/response DTOs and API call.
- `May/May/Models/PerformanceTestFlow.swift`: 15-game catalog, request state, response presentation model.
- `May/May/Screens/DIYBuildView.swift`: async loading, error/partial states, and real result cards.
- `May/MayTests/PerformanceTestFlowRulesTests.swift`: game scope and response-presentation rules.
- `backend/progress.json`: accurately track the benchmark-backed performance capability after verification.

### Task 1: Versioned scope and mapping manifest

**Files:**
- Create: `backend/app/perf/collector_manifest.py`
- Create: `backend/data/pc-builds-fps-mappings.json`
- Create: `backend/tests/test_perf_collector_manifest.py`
- Modify: `backend/app/cli.py`

- [ ] **Step 1: Write failing manifest tests**

```python
from pathlib import Path

from app.perf.collector_manifest import load_manifest, target_page_count


def test_manifest_covers_app_scope_and_uses_warzone_for_cod() -> None:
    manifest = load_manifest(Path("data/pc-builds-fps-mappings.json"))

    assert len(manifest.cpus) == 101
    assert len(manifest.gpus) == 77
    assert len(manifest.games) == 15
    assert next(game for game in manifest.games if game.app_id == "call-of-duty-warzone").source_name == "Call of Duty: Warzone"
    assert all(item.device_type == "desktop" for item in manifest.cpus + manifest.gpus)


def test_only_exact_mappings_generate_pages() -> None:
    manifest = load_manifest(Path("data/pc-builds-fps-mappings.json"))
    exact_cpus = sum(item.status == "exact" for item in manifest.cpus)
    exact_gpus = sum(item.status == "exact" for item in manifest.gpus)
    exact_games = sum(item.status == "exact" for item in manifest.games)

    assert target_page_count(manifest) == exact_cpus * exact_gpus * exact_games
```

- [ ] **Step 2: Run the tests and verify RED**

Run:

```bash
cd backend
.venv/bin/pytest tests/test_perf_collector_manifest.py -q
```

Expected: collection fails because `collector_manifest` and the manifest file do not exist.

- [ ] **Step 3: Implement the minimal manifest model and validator**

```python
# backend/app/perf/collector_manifest.py
import json
from dataclasses import dataclass
from pathlib import Path
from typing import List, Literal, Optional

MappingStatus = Literal["exact", "review", "missing"]


@dataclass(frozen=True)
class SourceMapping:
    app_id: str
    app_name: str
    source_id: Optional[str]
    source_slug: Optional[str]
    source_name: Optional[str]
    device_type: str
    status: MappingStatus


@dataclass(frozen=True)
class CollectorManifest:
    cpus: List[SourceMapping]
    gpus: List[SourceMapping]
    games: List[SourceMapping]


def load_manifest(path: Path) -> CollectorManifest:
    payload = json.loads(path.read_text(encoding="utf-8"))
    sections = {
        key: [SourceMapping(**item) for item in payload[key]]
        for key in ("cpus", "gpus", "games")
    }
    manifest = CollectorManifest(**sections)
    for item in manifest.cpus + manifest.gpus + manifest.games:
        if item.status == "exact" and (not item.source_id or not item.source_slug or not item.source_name):
            raise ValueError(f"Exact mapping is incomplete: {item.app_id}")
    return manifest


def target_page_count(manifest: CollectorManifest) -> int:
    return (
        sum(item.status == "exact" for item in manifest.cpus)
        * sum(item.status == "exact" for item in manifest.gpus)
        * sum(item.status == "exact" for item in manifest.games)
    )
```

- [ ] **Step 4: Generate the versioned manifest from the real Swift catalog**

Add `extract_hardware_scope(swift_path: Path) -> tuple[list[SourceMapping], list[SourceMapping]]` using this exact literal pattern:

```python
ITEM_PATTERN = re.compile(
    r'HardwareCatalogItem\(id: "(?P<id>[^"]+)", name: "(?P<name>[^"]+)", brand: "(?P<brand>Intel|AMD|NVIDIA)"'
)
```

Split CPU and GPU matches using the `static let cpus` and `static let gpus` source ranges. Emit every hardware entry initially as `review`; insert the 15 approved game rows with the names from the design document. Preserve any manually reviewed source fields when regenerating the file.

Run:

```bash
cd backend
.venv/bin/python -m app.cli build-perf-manifest ../May/May/Models/HardwareCatalog.swift data/pc-builds-fps-mappings.json
```

Expected: `Wrote 101 CPUs, 77 GPUs, and 15 games.`

- [ ] **Step 5: Review public source mappings without guessing**

For every row, record the visible PC-Builds detail-page ID, slug, exact display name, and Desktop classification. Use `exact` only when model, suffix, and VRAM match. Use `review` for ambiguous D/GRE/VRAM variants and `missing` when no public result exists. Run the coverage report after each review batch:

```bash
cd backend
.venv/bin/python -m app.cli check-perf-manifest data/pc-builds-fps-mappings.json
```

Expected output includes exact, review, and missing counts plus the derived result-page count. Stop mapping if the site presents a challenge; do not bypass it.

- [ ] **Step 6: Run manifest tests and commit**

```bash
cd backend
.venv/bin/pytest tests/test_perf_collector_manifest.py -q
git add app/perf/collector_manifest.py data/pc-builds-fps-mappings.json tests/test_perf_collector_manifest.py app/cli.py
git commit -m "feat: define FPS collection scope"
```

Expected: tests pass and the commit contains only manifest-related files.

### Task 2: Result-page parser and validation

**Files:**
- Create: `backend/app/perf/collector_parser.py`
- Create: `backend/data/pc-builds-fps-example.html.gz`
- Create: `backend/tests/test_perf_collector_parser.py`

- [ ] **Step 1: Save one permitted internal fixture**

Save the already verified public result page for Ryzen 5 5600 + RTX 4060 + Cyberpunk 2077 as gzip. The fixture must contain only the result table needed by the parser, not ads or unrelated page content.

- [ ] **Step 2: Write failing parser tests**

```python
import gzip
from pathlib import Path

import pytest

from app.perf.collector_parser import ParseError, parse_medium_results


def test_parses_three_verified_medium_rows() -> None:
    html = gzip.decompress(Path("data/pc-builds-fps-example.html.gz").read_bytes()).decode()
    rows = parse_medium_results(html)

    assert [(row.resolution, row.average_fps, row.minimum_fps, row.maximum_fps) for row in rows] == [
        ("1080p", 77, 66, 89),
        ("2k", 58, 49, 66),
        ("4k", 38, 32, 44),
    ]
    assert rows[0].bottleneck_type == "cpu"
    assert rows[0].bottleneck_percent == 11


def test_rejects_missing_or_impossible_rows() -> None:
    with pytest.raises(ParseError):
        parse_medium_results("<table><tr><td>1920 × 1080</td><td>10</td><td>20</td><td>5</td></tr></table>")
```

- [ ] **Step 3: Verify RED**

```bash
cd backend
.venv/bin/pytest tests/test_perf_collector_parser.py -q
```

Expected: import failure for `collector_parser`.

- [ ] **Step 4: Implement a dependency-free bounded parser**

Define:

```python
@dataclass(frozen=True)
class ParsedPerformanceRow:
    resolution: Literal["1080p", "2k", "4k"]
    average_fps: int
    minimum_fps: int
    maximum_fps: int
    bottleneck_type: Optional[Literal["cpu", "gpu", "balanced"]]
    bottleneck_percent: Optional[int]


class ParseError(ValueError):
    pass
```

Use `html.parser.HTMLParser` to collect only table rows. Locate the table whose headers contain the Chinese or English equivalents of resolution, average, minimum, maximum, and bottleneck. Map `1920 × 1080`, `2560 × 1440`, and `3840 × 2160` to the API resolution values. Require exactly one of each row and validate `0 < minimum <= average <= maximum <= 2000`.

- [ ] **Step 5: Run parser tests and commit**

```bash
cd backend
.venv/bin/pytest tests/test_perf_collector_parser.py -q
git add app/perf/collector_parser.py data/pc-builds-fps-example.html.gz tests/test_perf_collector_parser.py
git commit -m "feat: parse PC Builds FPS results"
```

Expected: parser tests pass.

### Task 3: Resumable SQLite task store

**Files:**
- Create: `backend/app/perf/collector_store.py`
- Create: `backend/tests/test_perf_collector_store.py`

- [ ] **Step 1: Write failing state-machine tests**

```python
from app.perf.collector_store import CollectorStore, CollectionTask


def test_successful_tasks_resume_without_duplicate_work(tmp_path) -> None:
    store = CollectorStore(tmp_path / "collector.sqlite")
    task = CollectionTask("i5-14600k", "rtx-4060", "cyberpunk-2077", "https://example/result")
    store.seed_tasks([task, task])
    claimed = store.claim_next()
    assert claimed is not None
    store.record_success(claimed.id, [], "sha256")
    assert store.claim_next() is None


def test_blocked_response_pauses_pending_tasks(tmp_path) -> None:
    store = CollectorStore(tmp_path / "collector.sqlite")
    store.seed_tasks([CollectionTask("cpu", "gpu", "game", "https://example/result")])
    store.pause_all("http_429")
    assert store.claim_next() is None
```

- [ ] **Step 2: Verify RED**

```bash
cd backend
.venv/bin/pytest tests/test_perf_collector_store.py -q
```

Expected: import failure for `collector_store`.

- [ ] **Step 3: Implement the SQLite schema and atomic transitions**

Use stdlib `sqlite3` with these tables:

```sql
CREATE TABLE task (
  id INTEGER PRIMARY KEY,
  cpu_id TEXT NOT NULL,
  gpu_id TEXT NOT NULL,
  game_id TEXT NOT NULL,
  source_url TEXT NOT NULL UNIQUE,
  status TEXT NOT NULL DEFAULT 'pending',
  attempts INTEGER NOT NULL DEFAULT 0,
  next_attempt_at TEXT,
  error TEXT,
  response_hash TEXT,
  updated_at TEXT NOT NULL
);

CREATE TABLE result (
  task_id INTEGER NOT NULL,
  resolution TEXT NOT NULL,
  average_fps INTEGER NOT NULL,
  minimum_fps INTEGER NOT NULL,
  maximum_fps INTEGER NOT NULL,
  bottleneck_type TEXT,
  bottleneck_percent INTEGER,
  PRIMARY KEY (task_id, resolution),
  FOREIGN KEY (task_id) REFERENCES task(id) ON DELETE CASCADE
);

CREATE TABLE collector_state (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL
);
```

`claim_next()` must reset a process-interrupted `fetching` row to `retryable`, then atomically claim the oldest eligible pending/retryable task. `record_success()` replaces that task's three result rows in one transaction.

- [ ] **Step 4: Run tests and commit**

```bash
cd backend
.venv/bin/pytest tests/test_perf_collector_store.py -q
git add app/perf/collector_store.py tests/test_perf_collector_store.py
git commit -m "feat: add resumable FPS collection store"
```

Expected: store tests pass.

### Task 4: Polite collector runner and CLI

**Files:**
- Create: `backend/app/perf/collector.py`
- Create: `backend/tests/test_perf_collector.py`
- Modify: `backend/app/cli.py`

- [ ] **Step 1: Write failing runner tests with `httpx.MockTransport`**

```python
import httpx
import pytest

from app.perf.collector import CollectionBlocked, Collector, CollectorPolicy
from app.perf.collector_store import CollectorStore, CollectionTask


@pytest.fixture
def store(tmp_path):
    value = CollectorStore(tmp_path / "collector.sqlite")
    value.seed_tasks([CollectionTask("cpu", "gpu", "game", "https://example/result")])
    return value


def test_429_stops_the_run_and_honors_retry_after(store) -> None:
    transport = httpx.MockTransport(lambda request: httpx.Response(429, headers={"Retry-After": "120"}))
    collector = Collector(store, httpx.Client(transport=transport), CollectorPolicy(delay_seconds=0))

    with pytest.raises(CollectionBlocked):
        collector.run(max_tasks=1)

    assert store.pause_reason() == "http_429_retry_after_120"


def test_cloudflare_challenge_stops_without_retry_loop(store) -> None:
    transport = httpx.MockTransport(lambda request: httpx.Response(200, text="Just a moment... challenge-platform"))
    collector = Collector(store, httpx.Client(transport=transport), CollectorPolicy(delay_seconds=0))

    with pytest.raises(CollectionBlocked):
        collector.run(max_tasks=1)
```

- [ ] **Step 2: Verify RED**

```bash
cd backend
.venv/bin/pytest tests/test_perf_collector.py -q
```

Expected: import failure for `collector`.

- [ ] **Step 3: Implement the runner**

```python
@dataclass(frozen=True)
class CollectorPolicy:
    delay_seconds: float = 2.0
    jitter_seconds: float = 0.4
    max_attempts: int = 3
    timeout_seconds: float = 20.0


class CollectionBlocked(RuntimeError):
    pass


def is_challenge(response: httpx.Response) -> bool:
    sample = response.text[:20_000].lower()
    return "challenge-platform" in sample or "cf-chl" in sample or "captcha" in sample
```

For each claimed task: send a normal GET with a stable descriptive user agent, stop on 403/429/challenge, mark 404 missing, retry transport/5xx failures up to three attempts, parse successful HTML, store the SHA-256 response hash, then sleep `delay + random.uniform(0, jitter)`. Stop after three consecutive parse errors.

- [ ] **Step 4: Add explicit CLI commands**

Add:

```text
build-perf-manifest SWIFT_CATALOG MANIFEST_JSON
check-perf-manifest MANIFEST_JSON
seed-perf-collection MANIFEST_JSON SQLITE_PATH
run-perf-collection SQLITE_PATH [--max-tasks N] [--delay-seconds 2]
export-perf-collection SQLITE_PATH OUTPUT_JSON
```

`seed-perf-collection` generates one URL per exact CPU/GPU/game combination, using 1920x1080 in the path because the result page contains all three target resolutions. `export-perf-collection` exports only succeeded and validated tasks.

- [ ] **Step 5: Run tests and a one-task internal smoke test**

```bash
cd backend
.venv/bin/pytest tests/test_perf_collector.py tests/test_perf_collector_store.py tests/test_perf_collector_parser.py -q
.venv/bin/python -m app.cli seed-perf-collection data/pc-builds-fps-mappings.json data/pc-builds-fps.sqlite
.venv/bin/python -m app.cli run-perf-collection data/pc-builds-fps.sqlite --max-tasks 1 --delay-seconds 2
```

Expected: tests pass. The smoke test either records one validated success or exits safely with an explicit blocked reason. A blocked result is not bypassed.

- [ ] **Step 6: Commit**

```bash
git add app/perf/collector.py app/cli.py tests/test_perf_collector.py
git commit -m "feat: collect FPS estimates safely"
```

### Task 5: Production model, migration, repository, and importer

**Files:**
- Create: `backend/app/perf/models.py`
- Create: `backend/app/perf/repository.py`
- Create: `backend/app/perf/importer.py`
- Create: `backend/migrations/versions/20260712_0012_game_performance_estimate.py`
- Create: `backend/tests/test_perf_repository.py`
- Create: `backend/tests/test_perf_importer.py`
- Modify: `backend/migrations/env.py`
- Modify: `backend/app/cli.py`

- [ ] **Step 1: Write failing repository and importer tests**

```python
from datetime import datetime, timezone

import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import Session
from sqlalchemy.pool import StaticPool

from app.catalog.seed import CatalogComponent
from app.catalog.repository import seed_hardware_components
from app.db import Base
from app.perf.importer import PerformanceEstimateInput


@pytest.fixture
def session():
    engine = create_engine(
        "sqlite+pysqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(engine)
    with Session(engine) as value:
        seed_hardware_components(
            value,
            [
                CatalogComponent(id="r5-5600", category="cpu", name="R5 5600", brand="AMD", detail_raw="AM4", specs={}),
                CatalogComponent(id="rtx-4060", category="gpu", name="RTX 4060", brand="NVIDIA", detail_raw="8GB", specs={}),
            ],
        )
        yield value


def estimate_input(**overrides):
    payload = {
        "cpu_id": "r5-5600",
        "gpu_id": "rtx-4060",
        "game_id": "cyberpunk-2077",
        "resolution": "1080p",
        "quality": "medium",
        "average_fps": 77,
        "minimum_fps": 66,
        "maximum_fps": 89,
        "bottleneck_type": "cpu",
        "bottleneck_percent": 11,
        "source_url": "https://pc-builds.com/example",
        "source_fetched_at": datetime(2026, 7, 12, tzinfo=timezone.utc),
        "import_batch": "test",
    }
    payload.update(overrides)
    return PerformanceEstimateInput(**payload)


def test_upsert_is_idempotent_and_exact_lookup_is_scoped_by_quality(session) -> None:
    rows = [estimate_input(cpu_id="r5-5600", gpu_id="rtx-4060", game_id="cyberpunk-2077", resolution="1080p")]
    assert upsert_performance_estimates(session, rows) == 1
    assert upsert_performance_estimates(session, rows) == 1

    result = get_performance_estimates(session, "r5-5600", "rtx-4060", ["cyberpunk-2077"], "1080p", "medium")
    assert len(result) == 1
    assert result[0].average_fps == 77


def test_import_rejects_invalid_ranges(tmp_path) -> None:
    path = tmp_path / "bad.json"
    path.write_text(json.dumps({"records": [{"minimum_fps": 90, "average_fps": 80, "maximum_fps": 100}]}))
    with pytest.raises(ValueError):
        read_performance_batch(path)
```

- [ ] **Step 2: Verify RED**

```bash
cd backend
.venv/bin/pytest tests/test_perf_repository.py tests/test_perf_importer.py -q
```

Expected: missing model/repository/importer imports.

- [ ] **Step 3: Add the SQLAlchemy model and Alembic migration**

```python
class GamePerformanceEstimate(Base):
    __tablename__ = "game_performance_estimate"
    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    cpu_id: Mapped[str] = mapped_column(String, ForeignKey("hardware_component.id", ondelete="CASCADE"), index=True)
    gpu_id: Mapped[str] = mapped_column(String, ForeignKey("hardware_component.id", ondelete="CASCADE"), index=True)
    game_id: Mapped[str] = mapped_column(String, index=True)
    resolution: Mapped[str] = mapped_column(String)
    quality: Mapped[str] = mapped_column(String, default="medium")
    average_fps: Mapped[int] = mapped_column(Integer)
    minimum_fps: Mapped[int] = mapped_column(Integer)
    maximum_fps: Mapped[int] = mapped_column(Integer)
    bottleneck_type: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    bottleneck_percent: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    source_url: Mapped[str] = mapped_column(String)
    source_fetched_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    import_batch: Mapped[str] = mapped_column(String, index=True)
    __table_args__ = (UniqueConstraint("cpu_id", "gpu_id", "game_id", "resolution", "quality", name="uq_game_perf_combo"),)
```

Migration `20260712_0012` must revise the existing `20260712_0011` migration and add the unique constraint plus lookup index. Import this model in `migrations/env.py` so metadata-based tests see it.

- [ ] **Step 4: Implement repository and batch validation**

Use one `SELECT ... WHERE cpu_id = ... AND gpu_id = ... AND game_id IN (...) AND resolution = ... AND quality = 'medium'`. Use PostgreSQL/SQLite-compatible query-before-insert upsert logic already used by catalog repositories. Reject records that do not contain valid FPS ordering, target resolutions, medium quality, source URL, and timezone-aware fetch time.

- [ ] **Step 5: Add `import-perf-estimates` CLI**

```bash
cd backend
.venv/bin/python -m app.cli import-perf-estimates data/pc-builds-fps-export.json
```

Expected: `Imported N game performance estimates.`

- [ ] **Step 6: Run tests and commit**

```bash
cd backend
.venv/bin/pytest tests/test_perf_repository.py tests/test_perf_importer.py -q
git add app/perf/models.py app/perf/repository.py app/perf/importer.py migrations/env.py migrations/versions/20260712_0012_game_performance_estimate.py tests/test_perf_repository.py tests/test_perf_importer.py app/cli.py
git commit -m "feat: store imported game performance estimates"
```

### Task 6: Exact backend API responses

**Files:**
- Modify: `backend/app/perf/service.py`
- Modify: `backend/tests/test_perf_api.py`

- [ ] **Step 1: Replace formula expectations with exact-data tests**

Add seeded `GamePerformanceEstimate` rows and assert:

```python
assert body == {
    "status": "ready",
    "average_fps": 77,
    "low_fps": 66,
    "maximum_fps": 89,
    "bottleneck": "cpu",
    "bottleneck_percent": 11,
    "confidence": "medium",
    "advice": "结果为中等画质下的性能估算。",
    "missing_data": [],
    "missing_games": [],
    "source_fetched_at": "2026-07-12T00:00:00Z",
    "game_results": [ANY],
}
```

Import `ANY` from `unittest.mock` in the test module.

Add separate tests for `partial`, `needs_more_data`, and the special request game ID `all-games`, which expands to the approved 15 IDs and reports best/worst/overall results.

- [ ] **Step 2: Verify RED**

```bash
cd backend
.venv/bin/pytest tests/test_perf_api.py -q
```

Expected: current formula response lacks the new fields and exact lookup behavior.

- [ ] **Step 3: Implement the minimal exact lookup service**

Change:

```python
PerfStatus = Literal["ready", "partial", "needs_more_data"]
```

Add `maximum_fps`, `bottleneck_percent`, `missing_games`, and `source_fetched_at` to the response. Add `maximum_fps`, bottleneck fields, and `source_fetched_at` per game. Remove `RESOLUTION_FACTORS`, `GAME_WEIGHTS`, and `_estimate_game`; no numerical fallback remains. Aggregate only returned database rows.

- [ ] **Step 4: Run API tests and commit**

```bash
cd backend
.venv/bin/pytest tests/test_perf_api.py -q
git add app/perf/service.py tests/test_perf_api.py
git commit -m "feat: serve exact FPS lookup results"
```

### Task 7: iOS networking, 15-game scope, and real result states

**Files:**
- Modify: `May/May/Networking/AppAPIClient.swift`
- Modify: `May/May/Models/PerformanceTestFlow.swift`
- Modify: `May/May/Screens/DIYBuildView.swift`
- Modify: `May/MayTests/PerformanceTestFlowRulesTests.swift`

- [ ] **Step 1: Write failing Swift rules for the approved games and response presentation**

```swift
assertEqual(PerformanceGame.samples.count, 15, "Only the approved real games should be collected.")
assertEqual(PerformanceGame.samples.first?.name, "瓦罗兰特", "Game order should match the approved grid.")
assertEqual(PerformanceGame.samples.first(where: { $0.id == "call-of-duty-warzone" })?.name, "COD", "COD should map to Warzone while keeping the approved App label.")

let response = PerformanceEstimatePayload(
    status: .ready,
    averageFPS: 77,
    lowFPS: 66,
    maximumFPS: 89,
    bottleneck: "cpu",
    bottleneckPercent: 11,
    sourceFetchedAt: "2026-07-12T00:00:00Z",
    missingGames: [],
    gameResults: []
)
flow.apply(response)
assertEqual(flow.result?.averageFPS, "77 FPS", "Results must use backend data.")
```

- [ ] **Step 2: Verify RED**

```bash
swiftc May/May/Models/HardwareCatalog.swift May/May/Models/OnboardingProfile.swift May/May/Models/PerformanceTestFlow.swift May/MayTests/PerformanceTestFlowRulesTests.swift -o /tmp/performance-rules
```

Expected: compile failure because the new response/result API is missing.

- [ ] **Step 3: Add API DTOs and request method**

```swift
struct PerformanceEstimateRequestDTO: Encodable {
    let hardware: PerformanceHardwareDTO
    let resolution: String
    let games: [String]
}

struct PerformanceHardwareDTO: Encodable {
    let cpu: String
    let gpu: String
}

struct GamePerformanceResultDTO: Decodable {
    let game: String
    let averageFPS: Int
    let lowFPS: Int
    let maximumFPS: Int
    let bottleneck: String?
    let bottleneckPercent: Int?
    let sourceFetchedAt: String

    var model: GamePerformanceResult {
        GamePerformanceResult(
            gameID: game,
            averageFPS: averageFPS,
            lowFPS: lowFPS,
            maximumFPS: maximumFPS,
            bottleneck: bottleneck,
            bottleneckPercent: bottleneckPercent,
            sourceFetchedAt: sourceFetchedAt
        )
    }
}

struct PerformanceEstimateResponseDTO: Decodable {
    let status: String
    let averageFPS: Int?
    let lowFPS: Int?
    let maximumFPS: Int?
    let bottleneck: String?
    let bottleneckPercent: Int?
    let missingGames: [String]
    let sourceFetchedAt: String?
    let gameResults: [GamePerformanceResultDTO]

    var model: PerformanceEstimatePayload {
        PerformanceEstimatePayload(
            status: PerformanceEstimateStatus(rawValue: status) ?? .needsMoreData,
            averageFPS: averageFPS,
            lowFPS: lowFPS,
            maximumFPS: maximumFPS,
            bottleneck: bottleneck,
            bottleneckPercent: bottleneckPercent,
            sourceFetchedAt: sourceFetchedAt,
            missingGames: missingGames,
            gameResults: gameResults.map(\.model)
        )
    }
}

func estimatePerformance(cpuID: String, gpuID: String, resolution: String, gameIDs: [String]) async throws -> PerformanceEstimateResponseDTO {
    try await request(
        path: "/v1/perf/estimate",
        method: "POST",
        body: PerformanceEstimateRequestDTO(
            hardware: PerformanceHardwareDTO(cpu: cpuID, gpu: gpuID),
            resolution: resolution,
            games: gameIDs
        )
    )
}
```

Use hardware catalog IDs, not display names, in the request.

- [ ] **Step 4: Replace the fixed demo result**

Remove the computed fixed `baseFPS`. Define these model types in `PerformanceTestFlow.swift`:

```swift
enum PerformanceEstimateStatus: String, Equatable {
    case ready
    case partial
    case needsMoreData = "needs_more_data"
}

struct GamePerformanceResult: Equatable {
    let gameID: String
    let averageFPS: Int
    let lowFPS: Int
    let maximumFPS: Int
    let bottleneck: String?
    let bottleneckPercent: Int?
    let sourceFetchedAt: String
}

struct PerformanceEstimatePayload: Equatable {
    let status: PerformanceEstimateStatus
    let averageFPS: Int?
    let lowFPS: Int?
    let maximumFPS: Int?
    let bottleneck: String?
    let bottleneckPercent: Int?
    let sourceFetchedAt: String?
    let missingGames: [String]
    let gameResults: [GamePerformanceResult]
}
```

Use these canonical game IDs in the manifest, database, API, and Swift model: `valorant`, `cs2`, `pubg`, `delta-force`, `teamfight-tactics`, `league-of-legends`, `call-of-duty-warzone`, `cyberpunk-2077`, `red-dead-redemption-2`, `gta-v`, `black-myth-wukong`, `forza-horizon-6`, `elden-ring`, `cities-skylines`, and `minecraft-java-edition`.

Add loading, loaded, partial, empty, and failed states. `PerformanceTestFlow.result` becomes optional and is set only by a decoded backend response. Define the approved 15 games and an `all-games` selection entry separately from those samples. Resolve the stored `HardwareProfile` display names through `HardwareCatalog.cpus` and `HardwareCatalog.gpus` before calling the API; if either exact ID is absent, enter the no-data state without sending a request.

- [ ] **Step 5: Wire async loading into the result transition**

When the user taps “开始测试”, move to the result step, show a progress state, call `estimatePerformance`, then render data or an explicit retry/error card. Disable duplicate requests while loading. The disclosure text must remain visible below results.

- [ ] **Step 6: Run rules and simulator build**

```bash
swiftc May/May/Models/HardwareCatalog.swift May/May/Models/OnboardingProfile.swift May/May/Models/PerformanceTestFlow.swift May/MayTests/PerformanceTestFlowRulesTests.swift -o /tmp/performance-rules && /tmp/performance-rules
xcodebuild -project May/May.xcodeproj -scheme May -destination 'platform=iOS Simulator,name=iPhone 17' -configuration Debug build
```

Expected: `PerformanceTestFlowRulesTests passed` and `** BUILD SUCCEEDED **`.

- [ ] **Step 7: Commit**

```bash
git add May/May/Networking/AppAPIClient.swift May/May/Models/PerformanceTestFlow.swift May/May/Screens/DIYBuildView.swift May/MayTests/PerformanceTestFlowRulesTests.swift
git commit -m "feat: show backend game performance results"
```

### Task 8: Final verification, progress accuracy, and internal collection handoff

**Files:**
- Modify: `backend/progress.json`
- Create: `backend/data/pc-builds-fps-coverage.json`

- [ ] **Step 1: Generate the coverage report**

```bash
cd backend
.venv/bin/python -m app.cli check-perf-manifest data/pc-builds-fps-mappings.json --json data/pc-builds-fps-coverage.json
```

Expected: report totals are exactly 101 CPUs, 77 GPUs, and 15 games, with every row categorized as exact, review, or missing.

- [ ] **Step 2: Run focused and full backend verification**

```bash
cd backend
.venv/bin/pytest tests/test_perf_collector_manifest.py tests/test_perf_collector_parser.py tests/test_perf_collector_store.py tests/test_perf_collector.py tests/test_perf_importer.py tests/test_perf_repository.py tests/test_perf_api.py -q
.venv/bin/pytest
```

Expected: all focused tests and the full suite pass.

- [ ] **Step 3: Run iOS verification again**

```bash
swiftc May/May/Models/HardwareCatalog.swift May/May/Models/OnboardingProfile.swift May/May/Models/PerformanceTestFlow.swift May/MayTests/PerformanceTestFlowRulesTests.swift -o /tmp/performance-rules && /tmp/performance-rules
xcodebuild -project May/May.xcodeproj -scheme May -destination 'platform=iOS Simulator,name=iPhone 17' -configuration Debug build
```

Expected: rules pass and the simulator build succeeds.

- [ ] **Step 4: Update progress without overstating data readiness**

Change the existing “游戏性能测试” item only after verification. Mark the collector/import/API/UI implementation complete, but state the exact mapping coverage and that third-party data remains internal until written authorization. Do not claim the full 116,655 pages were collected unless the SQLite/export reports prove it.

- [ ] **Step 5: Start or resume the internal low-speed run**

```bash
cd backend
.venv/bin/python -m app.cli run-perf-collection data/pc-builds-fps.sqlite --delay-seconds 2
```

This is an operational run, not a deployment step. If it is blocked, preserve the SQLite state and report the exact reason. Do not bypass the block. Do not import or deploy third-party data without written permission.

- [ ] **Step 6: Commit verification metadata**

```bash
git add backend/progress.json backend/data/pc-builds-fps-coverage.json
git commit -m "docs: record FPS data coverage"
```

Expected: the commit contains only verified progress and coverage metadata.

## Final acceptance checklist

- [ ] Manifest totals are 101 CPUs, 77 GPUs, and 15 games.
- [ ] Every mapping is exact, review, or missing; no approximate substitutions exist.
- [ ] One known page parses to 77/66/89, 58/49/66, and 38/32/44.
- [ ] Collector resumes, retries bounded failures, and stops globally on restrictions.
- [ ] Export contains only validated succeeded tasks.
- [ ] Import is idempotent and migration applies cleanly.
- [ ] API returns ready, partial, and needs-more-data without formula fallback.
- [ ] iOS renders loading, results, partial data, no-data, and error states.
- [ ] Disclosure text identifies results as estimates.
- [ ] Full backend tests, Swift rules, and iPhone 17 simulator build pass.
- [ ] No production deployment or third-party data publication occurs without written authorization.
