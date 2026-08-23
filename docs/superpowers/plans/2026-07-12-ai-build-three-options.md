# AI 装机三方案接入 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 补齐 3000～20000 元真实可行的基底配置，并让 iOS AI 装机一次获取当前预算下可用的二手、全新、混合方案，先看 CPU + GPU 摘要，再进入八大件详情。

**Architecture:** 低价位模板使用独立生成器，复用现有结构化模板、白名单、兼容性和导入链路，避免改写已验证的 7500～20000 元生成器。后端新增无 AI 依赖的 `/v1/build/options` 聚合接口，统一完成游戏分类并原子返回三种采购模式；iOS 通过现有 `AppAPIClient` 请求并将 DTO 映射到现有 `BuildPlan` 详情模型。

**Tech Stack:** Python 3.9+、FastAPI、Pydantic、SQLAlchemy、pytest、Swift 6、SwiftUI、URLSession、Xcode Simulator

---

## File Map

- Create `backend/app/builds/low_budget_catalog.py`: 生成 3000～7000 元当前价格下可行的结构化基底和审核产物。
- Create `backend/tests/test_low_budget_base_builds.py`: 验证低价位档位、采购成色、预算、兼容性和供电。
- Create `backend/data/low-budget-base-build-templates.json`: 可导入数据库的低价位可行模板。
- Create `backend/data/low-budget-base-reference-prices.csv`: 低价位模板涉及的参考价格。
- Create `backend/data/low-budget-base-recommendation-ids.txt`: 低价位推荐硬件 ID。
- Create `backend/data/low-budget-base-audit.json`: 低价位生成审计结果。
- Create `docs/3000-7000-yuan-base-builds.md`: 人工审核用的完整低价位配置表。
- Modify `backend/data/base-build-support-components-2026-07-12.json`: 加入 DDR4 内存等低价平台所需通用硬件。
- Modify `backend/app/builds/service.py`: 增加游戏方向判定和三方案响应模型。
- Modify `backend/app/api/builds.py`: 新增 `/v1/build/options`，复用模板匹配和兼容性检查。
- Modify `backend/tests/test_build_template_matching.py`: 覆盖游戏分类规则。
- Modify `backend/tests/test_build_api.py`: 覆盖三方案接口完整响应和缺失数据错误。
- Modify `backend/tests/test_high_budget_base_builds.py`: 增加高低价合并后的 35 档覆盖断言，保留原 234 套测试。
- Modify `backend/progress.json`: 记录 3000～20000 元真实可行配置和多采购方案接口状态。
- Modify `docs/agents/backend-server-context.md`: 更新模板数量、预算覆盖和接口。
- Modify `May/May/Networking/AppAPIClient.swift`: 增加装机请求、响应 DTO、API 方法和 `BuildPlan` 映射。
- Create `May/May/Screens/BuildOptionsView.swift`: 展示当前预算下可用的二手、全新、混合 CPU + GPU 摘要卡。
- Modify `May/May/Screens/AIBuildView.swift`: 构造请求、显示加载/错误状态并回传真实响应。
- Modify `May/May/ContentView.swift`: 承载三方案与所选详情，移除普通 AI 装机的模拟结果。
- Modify `May/May/Screens/BuildResultView.swift`: 展示接口返回的八大件、优缺点和风险；保持颜值装机模拟流程不变。

### Task 1: Low-Budget Catalog Tests

**Files:**
- Create: `backend/tests/test_low_budget_base_builds.py`
- Test: `backend/tests/test_high_budget_base_builds.py`

- [ ] **Step 1: Write the failing low-budget coverage test**

```python
from app.builds.low_budget_catalog import (
    BUDGET_TIERS,
    REQUIRED_PART_ROLES,
    generate_low_budget_templates,
)


def test_generates_every_low_budget_direction_with_only_feasible_modes() -> None:
    templates = generate_low_budget_templates()

    assert BUDGET_TIERS == list(range(3_000, 7_001, 500))
    assert len({template.id for template in templates}) == len(templates)
    for budget in BUDGET_TIERS:
        assert {
            template.details.direction
            for template in templates
            if template.details.target_budget == budget
        } == {"fps", "aaa", "balanced"}
```

- [ ] **Step 2: Add failing invariant tests**

Assert every template has exactly `REQUIRED_PART_ROLES`, exact part totals, `estimated_total <= target_budget + 200`, the existing `DETAILED_CONDITIONS`, no RTX 40-series GPU in a new slot, CPU/motherboard socket and memory type agreement, and PSU wattage greater than or equal to `minimum_psu_watt(cpu_id, gpu_id)`.

```python
def test_every_low_budget_template_is_complete_and_within_budget() -> None:
    for template in generate_low_budget_templates():
        parts = {part.role: part for part in template.details.parts}
        assert set(parts) == REQUIRED_PART_ROLES
        assert template.estimated_total == sum(part.reference_price for part in parts.values())
        assert template.estimated_total <= template.details.target_budget + 200
```

- [ ] **Step 3: Run the new tests and verify collection fails**

Run: `cd backend && .venv/bin/pytest tests/test_low_budget_base_builds.py -q`

Expected: FAIL during import with `ModuleNotFoundError: app.builds.low_budget_catalog`.

- [ ] **Step 4: Commit the failing tests**

```bash
git add backend/tests/test_low_budget_base_builds.py
git commit -m "test: define low budget build catalog coverage"
```

### Task 2: Low-Budget Catalog Generator and Artifacts

**Files:**
- Create: `backend/app/builds/low_budget_catalog.py`
- Modify: `backend/data/base-build-support-components-2026-07-12.json`
- Create: `backend/data/low-budget-base-build-templates.json`
- Create: `backend/data/low-budget-base-reference-prices.csv`
- Create: `backend/data/low-budget-base-recommendation-ids.txt`
- Create: `backend/data/low-budget-base-audit.json`
- Create: `docs/3000-7000-yuan-base-builds.md`
- Test: `backend/tests/test_low_budget_base_builds.py`

- [ ] **Step 1: Implement the low-budget generator shape**

Define these public constants and functions so the test contract is stable:

```python
BUDGET_TIERS = list(range(3_000, 7_001, 500))
REQUIRED_PART_ROLES = {"cpu", "motherboard", "gpu", "ram", "storage", "psu", "cooler", "case"}


@lru_cache(maxsize=1)
def generate_low_budget_templates() -> list[BuildTemplateInput]:
    templates = []
    for budget in BUDGET_TIERS:
        for direction in ("fps", "aaa", "balanced"):
            for purchase_mode in ("new", "used", "mixed"):
                candidate = _select_candidate(budget, direction, purchase_mode)
                if candidate is not None:
                    templates.append(_build_template(budget, direction, purchase_mode, candidate))
    return templates
```

Use the same purchase conditions as `backend/app/builds/repository.py`. Use the existing CPU, motherboard and GPU whitelist CSV files, the existing user-authored 3000/3500/4000/4500/5000/6500/7000 documents as selection anchors, and add explicit candidates for 5500 and 6000. Keep all generated component IDs inside the maintained whitelist/catalog.

- [ ] **Step 2: Add low-price support parts**

Add only required reusable parts to `base-build-support-components-2026-07-12.json`, including DDR4 8GB×2 3200, 512GB SSD, 550W/650W power supplies, 6-heatpipe coolers and ordinary cases. Every entry must include socket/memory/wattage specs needed by compatibility checks and both used/new source metadata when both conditions are selectable.

- [ ] **Step 3: Implement artifact writers**

Expose `render_low_budget_markdown()` and `write_low_budget_artifacts()` mirroring the existing high-budget artifact contract. Write JSON, Markdown, CSV, recommendation IDs and audit JSON with deterministic ordering. The audit records every skipped budget/direction/mode combination as `over_budget`.

- [ ] **Step 4: Generate artifacts**

Run: `cd backend && .venv/bin/python -m app.builds.low_budget_catalog`

Expected output: `Generated <actual count> templates.`

- [ ] **Step 5: Run low-budget and repository tests**

Run: `cd backend && .venv/bin/pytest tests/test_low_budget_base_builds.py tests/test_build_template_repository.py tests/test_compat_engine.py -q`

Expected: all selected tests PASS.

- [ ] **Step 6: Commit the generator and generated artifacts**

```bash
git add backend/app/builds/low_budget_catalog.py backend/data/base-build-support-components-2026-07-12.json backend/data/low-budget-base-* docs/3000-7000-yuan-base-builds.md backend/tests/test_low_budget_base_builds.py
git commit -m "feat: add complete low budget build catalog"
```

### Task 3: Combined 35-Tier Validation and Import

**Files:**
- Modify: `backend/tests/test_high_budget_base_builds.py`
- Modify: `backend/tests/test_high_budget_base_import.py`
- Modify: `backend/progress.json`
- Modify: `docs/agents/backend-server-context.md`

- [ ] **Step 1: Write a failing combined coverage test**

```python
def test_low_and_high_catalogs_cover_3000_through_20000() -> None:
    templates = generate_low_budget_templates() + generate_high_budget_templates()
    assert len({template.id for template in templates}) == len(templates)
    assert sorted({template.details.target_budget for template in templates}) == list(
        range(3_000, 20_001, 500)
    )
```

- [ ] **Step 2: Add a database import test for both files**

Import low and high template inputs into the same test session with `upsert_build_templates()`, then assert the active row count equals the two generated catalogs and there are no duplicate IDs. Seed every referenced support component and reference price before importing.

- [ ] **Step 3: Run the combined tests**

Run: `cd backend && .venv/bin/pytest tests/test_high_budget_base_builds.py tests/test_high_budget_base_import.py -q`

Expected: PASS with unique templates across all 35 tiers.

- [ ] **Step 4: Update operational documentation**

Update `backend/progress.json` and `docs/agents/backend-server-context.md` from 234/7500～20000 to the verified generated count/3000～20000. Do not change unrelated readiness or release blockers.

- [ ] **Step 5: Commit combined coverage metadata**

```bash
git add backend/tests/test_high_budget_base_builds.py backend/tests/test_high_budget_base_import.py backend/progress.json docs/agents/backend-server-context.md
git commit -m "docs: record complete base build coverage"
```

### Task 4: Game Direction and Atomic Three-Option API

**Files:**
- Modify: `backend/app/builds/service.py`
- Modify: `backend/app/api/builds.py`
- Modify: `backend/tests/test_build_template_matching.py`
- Modify: `backend/tests/test_build_api.py`

- [ ] **Step 1: Write failing direction-classification tests**

```python
@pytest.mark.parametrize(
    ("games", "expected"),
    [
        (["瓦罗兰特", "CS2", "PUBG"], "fps"),
        (["三角洲行动", "黑神话悟空"], "aaa"),
        (["LOL", "我的世界"], "balanced"),
        (["瓦罗兰特", "黑神话悟空"], "balanced"),
        (["什么都玩", "瓦罗兰特"], "balanced"),
        ([], "balanced"),
    ],
)
def test_classify_game_direction(games: list[str], expected: str) -> None:
    assert classify_game_direction(games) == expected
```

- [ ] **Step 2: Implement the exact taxonomy**

Add immutable game sets and `classify_game_direction(games: list[str]) -> Literal["fps", "aaa", "balanced"]`. Return a specialized direction only when all selected known games belong to that one category; return `balanced` for empty, unknown, “什么都玩”, or cross-category selections.

- [ ] **Step 3: Define the options response**

```python
class BuildOptionsResponse(BaseModel):
    direction: Literal["fps", "aaa", "balanced"]
    options: List[BuildGenerationResponse]
    unavailable_modes: List[Literal["new", "used", "mixed"]]
```

The response order is fixed as `used`, `new`, `mixed` so the iOS screen matches the approved order.

- [ ] **Step 4: Write failing API tests**

Seed three templates for one budget/direction and assert one `POST /v1/build/options` request returns exactly three `ready/template` responses with purchase modes `used`, `new`, `mixed`. Add a second test with one mode omitted and assert a successful response containing the available options plus that mode in `unavailable_modes`. Assert HTTP 503 only when no mode exists. Add a cross-category payload and assert `direction == "balanced"`.

- [ ] **Step 5: Implement `/v1/build/options`**

Build three forced `BuildRequest` copies from the incoming request, adding the classified direction and one purchase mode to each copy. Reuse `match_build_template()`, `get_components_by_ids()`, `evaluate_compatibility()` and `template_response()`. Do not invoke the AI provider or rules fallback from this endpoint. Return every valid mode and list missing modes in `unavailable_modes`; raise HTTP 503 only when no valid mode exists.

- [ ] **Step 6: Run focused API tests**

Run: `cd backend && .venv/bin/pytest tests/test_build_template_matching.py tests/test_build_api.py -q`

Expected: all tests PASS; existing `/v1/build/generate` behavior remains unchanged.

- [ ] **Step 7: Commit the backend API**

```bash
git add backend/app/builds/service.py backend/app/api/builds.py backend/tests/test_build_template_matching.py backend/tests/test_build_api.py
git commit -m "feat: return three purchase-mode build options"
```

### Task 5: iOS API Models and Mapping

**Files:**
- Modify: `May/May/Networking/AppAPIClient.swift`
- Modify: `May/May/Models/MockData.swift`

- [ ] **Step 1: Add request and response DTOs**

Add `BuildOptionsRequestDTO`, `BuildOptionsResponseDTO`, `BuildOptionDTO`, `BuildDetailsDTO` and `BuildPartDTO` as `Encodable`/`Decodable` value types. Match backend snake-case fields through the client's existing `.convertFromSnakeCase` decoder and explicit coding keys only where encoding requires them.

```swift
struct BuildOptionsRequestDTO: Encodable {
    let budget: Int
    let useCase: String
    let gameCategories: [String]

    enum CodingKeys: String, CodingKey {
        case budget
        case useCase = "use_case"
        case gameCategories = "game_categories"
    }
}
```

- [ ] **Step 2: Add the API call**

```swift
func buildOptions(_ body: BuildOptionsRequestDTO) async throws -> BuildOptionsResponseDTO {
    try await request(path: "/v1/build/options", method: "POST", body: body)
}
```

- [ ] **Step 3: Add deterministic UI mapping**

Add an initializer or mapping property that converts one `BuildOptionDTO` into `BuildPlan`. Map all eight backend roles to the existing Chinese category labels and SF Symbols. Format prices as `¥ 1234`; map backend risks to warning rows and compatibility success/failure to pass/error rows. Use backend title, target budget, total and direction instead of mock strings.

- [ ] **Step 4: Build the iOS target**

Run: `xcodebuild -project May/May.xcodeproj -scheme May -destination 'platform=iOS Simulator,name=iPhone 17' -configuration Debug build`

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 5: Commit the client contract**

```bash
git add May/May/Networking/AppAPIClient.swift May/May/Models/MockData.swift
git commit -m "feat: add AI build options API client"
```

### Task 6: iOS Generation, Summary Selection, and Detail Flow

**Files:**
- Create: `May/May/Screens/BuildOptionsView.swift`
- Modify: `May/May/Screens/AIBuildView.swift`
- Modify: `May/May/ContentView.swift`
- Modify: `May/May/Screens/BuildResultView.swift`

- [ ] **Step 1: Add generation state to `AIBuildView`**

Change the completion closure to `let onShowResult: (BuildOptionsResponseDTO) -> Void`. Add `isGenerating`, `generationError` and an `AppAPIClient` value. On the final button, call `buildOptions()` in a `Task`, passing `Int(budget)`, `selectedUseCase` and a sorted `selectedGames` array.

Disable repeat submission while loading, change the final button title to “正在生成”, and show a compact retryable error alert without clearing the current selections.

- [ ] **Step 2: Create the summary screen**

`BuildOptionsView` accepts the response, an option-selection closure and a back closure. Render the available un-nested cards in backend order. Each card displays only the purchase-mode label, `CPU + GPU`, formatted total and direction label, plus a chevron button affordance. For unavailable modes, show a compact “当前预算下没有可靠方案，建议提高预算” note instead of an empty card. Use existing `ScreenHeader`, `SoftCard`, typography and colors; no new visual system or dependency.

- [ ] **Step 3: Replace the mock routing state**

Replace `showsResult: Bool` in `AIBuildFlowView` with:

```swift
@State private var optionsResponse: BuildOptionsResponseDTO?
@State private var selectedOption: BuildOptionDTO?
```

Render `AIBuildView`, then `BuildOptionsView`, then `BuildResultView(plan: selectedOption.buildPlan)` according to state. The detail back action returns to the three-option list; closing the full-screen flow remains available from the generation/list level. Do not alter `AestheticBuildFlowView`, which continues using its existing demo plan.

- [ ] **Step 4: Present API advantages, disadvantages and risks**

Extend the real-plan mapping so `BuildResultView` shows backend advantages/disadvantages in concise rows and preserves all backend risk strings. Remove only the ordinary AI build dependency on `AppMockData.samplePlan`; keep previews and unrelated saved/demo plans intact.

- [ ] **Step 5: Cap the AI build budget control**

Change `BudgetSection.maximumBudget` from `50_000` to `20_000` and make the right-hand range label display `¥ 20000`, matching backend coverage.

- [ ] **Step 6: Build and inspect the simulator**

Run the Debug build, launch on iPhone 17 simulator, and verify no overlap at narrow widths. Exercise 3000, 7000, 7500 and 20000 budgets; verify the summary list remains stable while loading text and long CPU/GPU names appear.

- [ ] **Step 7: Commit the connected flow**

```bash
git add May/May/Screens/BuildOptionsView.swift May/May/Screens/AIBuildView.swift May/May/ContentView.swift May/May/Screens/BuildResultView.swift
git commit -m "feat: connect AI build flow to real options"
```

### Task 7: Full Verification and Production Deployment

**Files:**
- Verify: `backend/`
- Verify: `May/May.xcodeproj`
- Modify only if results require it: `backend/progress.json`, `docs/agents/backend-server-context.md`

- [ ] **Step 1: Run the full backend suite**

Run: `cd backend && .venv/bin/pytest -q`

Expected: all tests PASS with no regressions from the current 209-test baseline plus new tests.

- [ ] **Step 2: Run the final iOS build**

Run: `xcodebuild -project May/May.xcodeproj -scheme May -destination 'platform=iOS Simulator,name=iPhone 17' -configuration Debug build`

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Deploy only scoped backend files**

Follow `docs/agents/backend-server-context.md`, not the stale `backend/AGENTS.md` deployment target. Sync only changed backend application/data files to `root@8.152.202.123:/opt/ai-builder-api`, preserving `/opt/ai-builder-api/.env` and unrelated server files. Do not use `backend/scripts/deploy.sh`.

- [ ] **Step 4: Import low-budget catalog on the server**

From `/opt/ai-builder-api`, seed the updated support component file, ingest low-budget reference prices, mark low-budget recommendation IDs without replacing existing recommendations, and import the low-budget template JSON. Then verify Alembic remains at `20260712_0011` unless implementation introduced a migration.

- [ ] **Step 5: Restart and verify the service**

Run `systemctl restart ai-builder-api` and verify `systemctl is-active ai-builder-api` returns `active`. Verify `/v1/catalog/readiness` reports ready and `active_template_count` equals the locally verified high + low generated count.

- [ ] **Step 6: Verify public edge requests**

POST representative requests for 3000, 7000, 7500 and 20000 budgets to `https://api.uzbox.top/v1/build/options`. Assert each response contains direction, all feasible options in `used`, `new`, `mixed` order, `unavailable_modes`, and eight parts plus compatibility data for every returned option.

- [ ] **Step 7: Verify the Release API path in the app**

Run the app against `https://api.uzbox.top`, generate a cross-category selection such as 瓦罗兰特 + 黑神话悟空, confirm the response direction is balanced, open each summary card and inspect the eight-part detail page.

- [ ] **Step 8: Record final evidence**

Update the backend context with the actual test count, generated server template count, service status and public endpoint result. Do not mark unrelated production login/community blockers complete.

- [ ] **Step 9: Commit verification metadata if changed**

```bash
git add backend/progress.json docs/agents/backend-server-context.md
git commit -m "docs: record AI build options deployment"
```
