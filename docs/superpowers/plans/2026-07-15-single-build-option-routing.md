# 单配置方案直达详情 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 当 AI 装机只返回一套方案时跳过方案选择页直接进入详情，同时保留多方案选择和正确的返回路径。

**Architecture:** `AIBuildFlowRules` 提供纯函数判断，`AIBuildFlowView` 在现有动画状态之上根据方案数量设置 `response` 与 `selectedOption`。选择页只在多方案时创建，详情返回行为也根据相同规则决定目标页面。

**Tech Stack:** Swift、SwiftUI、独立 Swift 规则测试、xcodebuild

---

### Task 1: 增加单方案判断规则

**Files:**
- Modify: `May/May/Models/AIBuildFlow.swift`
- Modify: `May/MayTests/AIBuildFlowRulesTests.swift`

- [ ] **Step 1: 写失败测试**

在 `AIBuildFlowRulesTests` 增加：

```swift
assertEqual(AIBuildFlowRules.shouldSkipOptionSelection(optionCount: 0), false)
assertEqual(AIBuildFlowRules.shouldSkipOptionSelection(optionCount: 1), true)
assertEqual(AIBuildFlowRules.shouldSkipOptionSelection(optionCount: 2), false)
```

- [ ] **Step 2: 验证测试失败**

Run:

```bash
swiftc May/May/Models/HardwareCatalog.swift May/May/Models/OnboardingProfile.swift May/May/Models/AIBuildFlow.swift May/MayTests/AIBuildFlowRulesTests.swift -o /tmp/ai-build-flow-rules && /tmp/ai-build-flow-rules
```

Expected: 编译失败，因为 `shouldSkipOptionSelection` 尚不存在。

- [ ] **Step 3: 实现最小规则**

```swift
static func shouldSkipOptionSelection(optionCount: Int) -> Bool {
    optionCount == 1
}
```

- [ ] **Step 4: 验证规则测试通过**

运行同一命令，Expected: `AIBuildFlowRulesTests passed`。

### Task 2: 接入父级路由状态

**Files:**
- Modify: `May/May/ContentView.swift`
- Modify: `May/MayTests/AIBuildFlowRulesTests.swift`

- [ ] **Step 1: 写路由源代码失败断言**

要求 `ContentView.swift` 包含单方案判断、只在多方案时创建 `BuildOptionsView`，并在单方案详情返回时清空响应。

```swift
assertContains(contentViewSource, "selectedOption = shouldSkipOptionSelection(for: response) ? response.options.first : nil")
assertContains(contentViewSource, "if let response, !shouldSkipOptionSelection(for: response)")
assertContains(contentViewSource, "if shouldSkipOptionSelection(for: response)")
```

- [ ] **Step 2: 验证测试失败**

运行 Task 1 的 Swift 测试命令。Expected: FAIL，缺少新路由代码片段。

- [ ] **Step 3: 实现路由切换**

- 请求完成时始终保存响应；仅当方案数为一时同步选择第一套方案。
- `BuildOptionsView` 仅在方案数不为一时创建。
- 详情返回时，单方案清空 `response` 与 `selectedOption`；多方案只清空 `selectedOption`。
- 继续复用当前 `resultAnimation` 与 `resultTransition`。

- [ ] **Step 4: 验证规则测试通过**

运行 Task 1 的 Swift 测试命令。Expected: `AIBuildFlowRulesTests passed`。

### Task 3: 编译验证

**Files:**
- Verify: `May/May.xcodeproj`

- [ ] **Step 1: Debug 构建**

```bash
xcodebuild -project May/May.xcodeproj -scheme May -destination 'platform=iOS Simulator,name=iPhone 17' -configuration Debug build
```

Expected: `BUILD SUCCEEDED`。

- [ ] **Step 2: Release 构建**

```bash
xcodebuild -project May/May.xcodeproj -scheme May -destination 'platform=iOS Simulator,name=iPhone 17' -configuration Release build
```

Expected: `BUILD SUCCEEDED`。

- [ ] **Step 3: 提交范围核对**

使用 `git diff` 区分本次单方案路由和此前未提交的生成动画修改，不回退任何现有改动。
