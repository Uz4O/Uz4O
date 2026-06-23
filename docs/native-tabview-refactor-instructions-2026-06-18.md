# 底部导航重构为原生 TabView 指令（给 Codex 执行）

> 目标：把当前手搓的 `BottomTabBar` + `switch selectedScreen` 导航，重构为 SwiftUI 原生 `TabView` + `NavigationStack`。
> 这样在 iOS 26（当前 Xcode 26.5 / SDK 26.5 支持）下，底部栏自动获得官方 **Liquid Glass 质感 + 选中滑动动画**（即 Apple Music 底部栏效果），无需任何手写动画。
> 这是**架构级重构**，不是改样式。请严格按本文件的页面归类来组织，避免改乱现有跳转。

---

## 背景：当前导航结构（已分析）

- 一个 `@State selectedScreen: AppScreen` + 大 `switch` 控制全部画面。
- **4 个主画面**（带底部 tab）：`.home / .community / .builds / .profile`
- **9 个二级页**（无底部栏，有返回）：`.aiBuild / .buildResult / .computerProfile / .upgrade / .configReview / .compatibility / .guide / .diy`
- **2 个入口前画面**：`.login / .onboarding`
- 1 个 sheet：`CommunityComposerView`
- 手搓组件 `BottomTabBar`（`AppComponents.swift`）—— **重构后删除/弃用**。

---

## 目标架构

```
ContentView
└── switch appPhase
    ├── .login      → LoginView           （保持现状，不进 TabView）
    ├── .onboarding → OnboardingChoiceView （保持现状）
    └── .main       → MainTabView          ← 新增，原生 TabView
```

`MainTabView` 用原生 `TabView`：
```swift
TabView(selection: $selectedTab) {
    Tab("首页", systemImage: "house", value: AppTab.home) {
        NavigationStack(path: $homePath) { HomeView(...) .navigationDestination(...) }
    }
    Tab("社区", systemImage: "bubble.left.and.bubble.right", value: AppTab.community) {
        NavigationStack(path: $communityPath) { CommunityView(...) ... }
    }
    Tab("配置", systemImage: "doc.text", value: AppTab.builds) {
        NavigationStack(path: $buildsPath) { MyBuildsView(...) ... }
    }
    Tab("我的", systemImage: "person", value: AppTab.profile) {
        NavigationStack(path: $profilePath) { ProfileView(...) ... }
    }
}
```
> 用 iOS 18+ 的 `Tab(...)` 新 API（SDK 26.5 支持）。iOS 26 下系统自动赋予 Liquid Glass 外观与滑动动画，**不要手写任何选中指示器/动画**。

---

## 二级页归类（混合方式，务必照此实现）

### A. tab 内 push（保留底部栏，用 NavigationStack + navigationDestination）
这些是浏览/延伸类，push 进当前 tab 的栈，底部栏保留：

| 二级页 | 从哪个 tab 进入 | 入口栈 |
|--------|----------------|--------|
| `computerProfile` 电脑档案 | 配置 / 我的 | builds / profile 栈 |
| `upgrade` 升级建议 | 首页 / 配置 | 对应栈 |
| `configReview` 配置排雷 | 首页 | home 栈 |
| `compatibility` 兼容检查 | 首页 | home 栈 |
| `guide` 装机指南 | 首页 | home 栈 |
| `buildResult` 装机结果 | 配置 | builds 栈（也可全屏，见备注） |

实现：定义 `enum Route: Hashable`，每个栈用 `path: [Route]`，点击时 `path.append(.xxx)`，页面里 `.navigationDestination(for: Route.self)` 渲染目标 view。返回用系统返回手势/按钮（移除自定义 onBack 的手动切 screen，改为 `dismiss()` 或 `path.removeLast()`）。

### B. 全屏覆盖（fullScreenCover，沉浸式任务流，不要底部栏）
这些是需要用户专注完成的流程，盖住整个屏幕：

| 二级页 | 触发 | 方式 |
|--------|------|------|
| `aiBuild` AI 一键装机 | 各处"开始装机" | `.fullScreenCover` |
| `diy` 性能测试流程 | 首页/配置 | `.fullScreenCover` |

实现：用 `@State` 布尔/可选枚举驱动 `.fullScreenCover`。流程内部完成后 `dismiss()`。

> **buildResult 备注**：装机结果如果是 AI 装机流程的最后一步，建议跟 `aiBuild` 一起放在 fullScreenCover 流程内（aiBuild → 结果 → 完成关闭）；如果是从"配置"tab 点已保存方案查看，则用 A 类 push。请按调用来源分别处理（代码里 `buildResultReturnTarget` 已经在区分来源，沿用该信息决定）。

---

## 状态迁移要点

1. 把 `selectedScreen: AppScreen` 拆成：
   - `appPhase: {login, onboarding, main}`（顶层阶段）
   - 各 tab 的 `path` 数组（栈内导航）
   - `presentedFullScreen: FullScreenRoute?`（沉浸流程）
2. `selectedTab` 保留，作为 TabView 的 selection。
3. `handleTabSelection`、`openTool`、`openAI` 等手动切 screen 的逻辑，改写为：切 tab / push path / 触发 cover。
4. 现有各 View 的 `onBack` / `onSelectTab` / `onOpenXxx` 回调：
   - `onOpenXxx`（打开二级页）→ 改成 push path 或触发 cover。
   - `onBack` → 改成 `dismiss()`（cover）或 `path.removeLast()`（栈）。
   - `onSelectTab` → 多数可删除（TabView 自己管 tab 切换）；若 View 内有"跳到别的 tab"的需求，改成设置 `selectedTab`。
5. `CommunityComposerView` 的 `.sheet` 保留不变。
6. 数据绑定（`onboardingProfile`、`hardwareProfile` 保存）逻辑保持，放到 `MainTabView` 或上层。

---

## 不要做的事

- ❌ 不要再写任何自定义选中指示器、药丸、拉伸、拖尾、matchedGeometryEffect——**全部交给原生 TabView**。
- ❌ 不要改各业务 View（HomeView/CommunityView 等）的**内部 UI 和配色**，只改它们之间的"导航接线"。
- ❌ 不要动 login/onboarding 的内部逻辑，只把它们纳入 `appPhase` 切换。
- ❌ 不要删除业务 View 文件。

---

## 验收标准

1. iPhone 17 模拟器（iOS 26）编译通过：
   ```bash
   cd /Users/may/Documents/AI装机
   xcodebuild -project May/May.xcodeproj -scheme May \
     -destination 'platform=iOS Simulator,name=iPhone 17' -configuration Debug build
   ```
2. 底部 4 个 tab 切换时，呈现**系统原生的 Liquid Glass 滑动效果**（不再是手写的）。
3. 全部原有跳转可达且能正确返回：
   - 4 个 tab 互切正常。
   - A 类二级页 push 后底部栏保留、可滑动返回。
   - B 类（AI装机、性能测试）全屏打开、完成后正确关闭回到来源。
   - 登录 → 引导 → 主界面 流程正常。
   - 社区发帖 sheet 正常。
4. `BottomTabBar` 及相关手写动画代码已移除或不再被引用。
5. 录屏或连拍 tab 切换，确认是原生效果。

---

## 给 Codex 的一句话
> 按 `docs/native-tabview-refactor-instructions-2026-06-18.md` 把手搓导航重构为原生 TabView + NavigationStack（拿 iOS 26 原生 Liquid Glass），二级页按文件里的 A/B 归类分别用 push 或 fullScreenCover。不改业务页内部 UI。改完用 iPhone 17 模拟器编译并录屏确认原生效果。这是大改动，建议先在一个分支上做。
