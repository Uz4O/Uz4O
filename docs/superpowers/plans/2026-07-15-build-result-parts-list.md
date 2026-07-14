# AI 装机结果页配置清单精简 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将 AI 装机结果页的配件清单精简为以配件型号和价格为视觉重点、以全新或二手为辅助信息的紧凑列表。

**Architecture:** `PCPart` 直接携带成色展示值，API DTO 映射时写入“全新”或“二手”。`BuildResultView` 使用页面私有的紧凑配件行，避免影响兼容性检测页面继续使用的通用 `PartRow`。

**Tech Stack:** Swift、SwiftUI、独立 Swift 规则测试、xcodebuild

---

### Task 1: 收窄结果页配件展示数据

**Files:**
- Modify: `May/May/Models/MockData.swift`
- Create: `May/MayTests/BuildResultContentRulesTests.swift`

- [ ] **Step 1: 写失败测试**

创建源代码规则测试，读取 `MockData.swift` 和 `BuildResultView.swift`，断言真实 API 配件映射包含 `condition: condition.displayName`，结果页直接展示 `part.model`、`part.price`、`part.condition`，且不再展示 `part.reason`。

```swift
let modelSource = try! String(contentsOfFile: "May/May/Models/MockData.swift", encoding: .utf8)
let viewSource = try! String(contentsOfFile: "May/May/Screens/BuildResultView.swift", encoding: .utf8)
assertContains(modelSource, "condition: condition.displayName")
assertContains(viewSource, "Text(part.model)")
assertContains(viewSource, "Text(part.price)")
assertContains(viewSource, "Text(part.condition)")
assertNotContains(viewSource, "part.reason")
```

- [ ] **Step 2: 验证测试失败**

Run:

```bash
swiftc -parse-as-library May/MayTests/BuildResultContentRulesTests.swift -o /tmp/build-result-content-rules && /tmp/build-result-content-rules
```

Expected: FAIL，因为 `PCPart` 尚无 `condition` 映射，结果页也尚未直接展示三个重点字段。

- [ ] **Step 3: 最小化配件展示模型**

将 `PCPart` 的展示字段调整为：

```swift
struct PCPart: Identifiable {
    let id = UUID()
    let category: String
    let model: String
    let price: String
    let condition: String
    let icon: String
    let accent: Color
}
```

真实 DTO 映射写入 `condition.displayName`，演示配置统一写入“全新”。删除不再使用的 `reason`、`alternative` 和 `source` 构造参数。

### Task 2: 实现紧凑双层配件行

**Files:**
- Modify: `May/May/Screens/BuildResultView.swift`
- Modify: `May/May/Components/AppComponents.swift`
- Test: `May/MayTests/BuildResultContentRulesTests.swift`

- [ ] **Step 1: 替换结果页配件行**

在 `BuildResultView.swift` 内新增页面私有 `ResultPartRow`：左侧图标，中间上层为类别和成色小标签、下层为醒目的型号，右侧为加粗价格。将 `DetailedPartRow` 替换为 `ResultPartRow`，并减少清单内部间距。

- [ ] **Step 2: 删除失去调用方的旧组件**

从 `AppComponents.swift` 删除 `DetailedPartRow`，保留兼容性检测继续使用的 `PartRow`。

- [ ] **Step 3: 验证规则测试通过**

Run:

```bash
swiftc -parse-as-library May/MayTests/BuildResultContentRulesTests.swift -o /tmp/build-result-content-rules && /tmp/build-result-content-rules
```

Expected: `BuildResultContentRulesTests passed`。

- [ ] **Step 4: 验证 iOS 构建**

Run:

```bash
xcodebuild -project May/May.xcodeproj -scheme May -destination 'platform=iOS Simulator,name=iPhone 17' -configuration Debug build
```

Expected: `BUILD SUCCEEDED`。

- [ ] **Step 5: 提交改动**

```bash
git add May/May/Models/MockData.swift May/May/Screens/BuildResultView.swift May/May/Components/AppComponents.swift May/MayTests/BuildResultContentRulesTests.swift
git commit -m "refactor: focus build result parts list"
```

### Task 3: 精简结果摘要

**Files:**
- Modify: `May/May/Models/MockData.swift`
- Modify: `May/May/Screens/BuildResultView.swift`
- Test: `May/MayTests/BuildResultContentRulesTests.swift`

- [ ] **Step 1: 将后端模板标题映射为简短游戏方向标题**

FPS、3A 和均衡方向分别显示“高帧率游戏配置”“大型游戏配置”和“均衡游戏配置”，不展示预算档位、“基底配置”或生成逻辑。

- [ ] **Step 2: 只展示配置总价**

删除结果摘要中的用途说明和用户原始预算，只保留全宽的“配置总价”。

- [ ] **Step 3: 运行规则测试和 iOS 构建**

Run:

```bash
swiftc -parse-as-library May/MayTests/BuildResultContentRulesTests.swift -o /tmp/build-result-content-rules && /tmp/build-result-content-rules
xcodebuild -project May/May.xcodeproj -scheme May -destination 'platform=iOS Simulator,name=iPhone 17' -configuration Debug build
```

Expected: 规则测试通过并且 iOS 构建成功。
