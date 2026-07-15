# AI 装机结果页参考图改版 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将动态 AI 装机结果页改为参考图中的黑色方案主视觉和无外层卡片配件清单，同时保留保存功能且不恢复复制功能。

**Architecture:** 继续使用现有 `BuildPlan` 与 `PCPart` 数据，仅在客户端增加游戏方向短说明。`BuildResultView` 内部新增页面私有的主视觉卡与价格提示，避免影响其他页面的共享组件。

**Tech Stack:** Swift、SwiftUI、独立 Swift 规则测试、xcodebuild

---

### Task 1: 锁定参考图结构和动态短说明

**Files:**
- Modify: `May/MayTests/BuildResultContentRulesTests.swift`
- Modify: `May/May/Models/MockData.swift`

- [ ] **Step 1: 写失败测试**

扩展源代码规则测试，要求结果页包含 `BuildHeroCard`、动态 `resultSubtitle`、价格提示和保存按钮，不包含 `SoftCard` 或“复制清单”。

```swift
assertContains(modelSource, "useCase: details.direction.resultSubtitle")
assertContains(viewSource, "BuildHeroCard(plan: plan)")
assertContains(viewSource, "价格可能随市场波动")
assertContains(viewSource, "PrimaryButton(title: \"保存配置单\"")
assertNotContains(viewSource, "SoftCard")
assertNotContains(viewSource, "复制清单")
```

- [ ] **Step 2: 验证测试失败**

Run:

```bash
swiftc -parse-as-library May/MayTests/BuildResultContentRulesTests.swift -o /tmp/build-result-content-rules && /tmp/build-result-content-rules
```

Expected: FAIL，因为当前仍使用 `SoftCard`，且没有 `BuildHeroCard` 或价格提示。

- [ ] **Step 3: 增加方向短说明映射**

为 `BuildDirectionDTO` 增加 `resultSubtitle`：

```swift
var resultSubtitle: String {
    switch self {
    case .fps: "优先保证高帧率游戏体验"
    case .aaa: "优先保证大型游戏画质与流畅度"
    case .balanced: "兼顾高帧率与大型游戏"
    }
}
```

将 `BuildOptionDTO.buildPlan.useCase` 映射为该短说明。

### Task 2: 实现黑色主视觉和无卡片清单

**Files:**
- Modify: `May/May/Screens/BuildResultView.swift`
- Test: `May/MayTests/BuildResultContentRulesTests.swift`

- [ ] **Step 1: 替换方案摘要**

删除现有摘要 `SoftCard` 和 `SummaryBadge`，新增页面私有 `BuildHeroCard`。卡片使用纯黑背景、`PCTower` 图片、白色动态标题、灰色短说明和配置总价，并使用固定宽高比限制图片与文字区域。

- [ ] **Step 2: 移除清单外层卡片**

将配件清单改为普通 `VStack`，保留标题、八大件、分隔线和保存按钮。每行图标底座统一为白色、图标为黑色并增加浅色边框，型号最多两行，价格使用 `fixedSize()` 保持右对齐。

- [ ] **Step 3: 增加价格提示**

在清单下方增加 `info.circle` 图标和“价格可能随市场波动，请以实际购买时为准。”。

- [ ] **Step 4: 验证规则测试通过**

Run:

```bash
swiftc -parse-as-library May/MayTests/BuildResultContentRulesTests.swift -o /tmp/build-result-content-rules && /tmp/build-result-content-rules
```

Expected: `BuildResultContentRulesTests passed`。

### Task 3: 编译和提交

**Files:**
- Verify: `May/May.xcodeproj`

- [ ] **Step 1: 运行 Debug 构建**

```bash
xcodebuild -project May/May.xcodeproj -scheme May -destination 'platform=iOS Simulator,name=iPhone 17' -configuration Debug build
```

Expected: `BUILD SUCCEEDED`。

- [ ] **Step 2: 运行 Release 构建**

```bash
xcodebuild -project May/May.xcodeproj -scheme May -destination 'platform=iOS Simulator,name=iPhone 17' -configuration Release build
```

Expected: `BUILD SUCCEEDED`。

- [ ] **Step 3: 提交并推送**

```bash
git add May/May/Models/MockData.swift May/May/Screens/BuildResultView.swift May/MayTests/BuildResultContentRulesTests.swift
git commit -m "refactor: match build result reference UI"
git push origin codex/native-tabview-refactor
```
