# 配置结果页精简 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 删除 AI 装机结果中的方案分析、风险提示和无实现价值的次级操作，并同步精简后端模板与 `/v1/build/options` 契约。

**Architecture:** 内部兼容性引擎继续作为安全过滤器，公开的 options 响应只返回方案与八大件详情。高低预算生成器生成精简模板，iOS DTO 和结果模型与新契约同步收窄。

**Tech Stack:** SwiftUI、FastAPI、Pydantic、SQLAlchemy、pytest、xcodebuild

---

### Task 1: 精简后端结果契约

**Files:**
- Modify: `backend/app/builds/service.py`
- Modify: `backend/app/api/builds.py`
- Test: `backend/tests/test_build_template_matching.py`
- Test: `backend/tests/test_build_api.py`

- [ ] **Step 1: 写失败测试**

更新 ready option fixture，断言 `BuildTemplateDetails` 不再需要 `advantages`、`disadvantages`、`risks`，并断言 `/v1/build/options` 响应不包含这些字段或 `compatibility`。

- [ ] **Step 2: 验证失败**

Run: `.venv/bin/pytest tests/test_build_template_matching.py tests/test_build_api.py -q`

Expected: 新的精简契约断言失败。

- [ ] **Step 3: 最小实现**

从 `BuildTemplateDetails` 删除三个文案数组，从 `BuildOptionResponse` 删除 `compatibility`。API 仍使用兼容性结果过滤候选，但最终 response model 不公开该字段。

- [ ] **Step 4: 验证通过**

Run: `.venv/bin/pytest tests/test_build_template_matching.py tests/test_build_api.py -q`

Expected: 全部通过。

### Task 2: 精简并重生成 297 套模板

**Files:**
- Modify: `backend/app/builds/high_budget_catalog.py`
- Modify: `backend/app/builds/low_budget_catalog.py`
- Modify: `backend/data/high-budget-base-build-templates.json`
- Modify: `backend/data/low-budget-base-build-templates.json`
- Modify: `docs/7500-20000-yuan-base-builds.md`
- Modify: `docs/3000-7000-yuan-base-builds.md`
- Test: `backend/tests/test_high_budget_base_builds.py`
- Test: `backend/tests/test_low_budget_base_builds.py`
- Test: `backend/tests/test_high_budget_base_import.py`

- [ ] **Step 1: 写失败测试**

删除对分析/风险数组非空的断言，增加生成模板 JSON 不含三个旧字段的断言，并保留 63、234、297 数量和八大件一致性断言。

- [ ] **Step 2: 验证失败**

Run: `.venv/bin/pytest tests/test_high_budget_base_builds.py tests/test_low_budget_base_builds.py tests/test_high_budget_base_import.py -q`

Expected: 生成器仍输出旧字段，断言失败。

- [ ] **Step 3: 最小实现与制品重生成**

删除两个生成器构造和 Markdown 渲染中的分析/风险逻辑，运行生成器写回两份 JSON 和两份 Markdown。

- [ ] **Step 4: 验证通过**

Run: `.venv/bin/pytest tests/test_high_budget_base_builds.py tests/test_low_budget_base_builds.py tests/test_high_budget_base_import.py -q`

Expected: 模板数量、预算覆盖、八大件和导入一致性全部通过。

### Task 3: 精简 iOS 结果模型与页面

**Files:**
- Modify: `May/May/Networking/AppAPIClient.swift`
- Modify: `May/May/Models/MockData.swift`
- Modify: `May/May/Screens/BuildResultView.swift`

- [ ] **Step 1: 收窄 DTO 和模型**

从 `BuildOptionDTO` 删除 `compatibility`，从 `BuildDetailsDTO` 删除三个文案数组，从 `BuildPlan` 删除对应展示数据，更新所有构造调用。

- [ ] **Step 2: 删除页面元素**

删除“方案分析”“风险提示”和四个 `SecondaryActionButton`，保留“保存配置单”。删除不再使用的私有按钮组件。

- [ ] **Step 3: 编译验证**

Run: `xcodebuild -project May/May.xcodeproj -scheme May -destination 'platform=iOS Simulator,name=iPhone 17' -configuration Debug build`

Expected: `BUILD SUCCEEDED`。

### Task 4: 全量验证与生产同步

**Files:**
- Deploy: `backend/app/builds/service.py`
- Deploy: `backend/app/api/builds.py`
- Deploy: `backend/app/builds/high_budget_catalog.py`
- Deploy: `backend/app/builds/low_budget_catalog.py`
- Deploy: `backend/data/high-budget-base-build-templates.json`
- Deploy: `backend/data/low-budget-base-build-templates.json`

- [ ] **Step 1: 全量验证**

Run: `backend/.venv/bin/pytest`

Run: `xcodebuild` Debug 与 Release iPhone 17 Simulator 构建。

Expected: 后端测试全通过，两个 iOS 构建成功。

- [ ] **Step 2: 生产备份和窄范围同步**

备份 `/opt/ai-builder-api/app` 与 PostgreSQL 数据库，只同步本计划列出的后端代码和模板 JSON。

- [ ] **Step 3: 重导入并重启**

Run: `.venv/bin/python -m app.cli import-build-templates data/low-budget-base-build-templates.json`

Run: `.venv/bin/python -m app.cli import-build-templates data/high-budget-base-build-templates.json`

Run: `systemctl restart ai-builder-api.service`

- [ ] **Step 4: 生产验收**

确认 readiness 为 731 条硬件、27 条价格、297 套模板；抽样 `/v1/build/options` 仍返回三个采购模式和八大件，且 JSON 不含 `advantages`、`disadvantages`、`risks`、`compatibility`。
