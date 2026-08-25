# Aesthetic AI Build Prototype Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the three image-backed home styles into a complete novice-friendly prototype that collects appearance trade-offs and game experience goals, shows a clearly labeled demo quote, and hands confirmed requirements to a style-aware demo result.

**Architecture:** Add one Foundation-only flow model for styles, restoration tiers, performance choices, deterministic demo pricing, and wizard state. Add one SwiftUI wizard screen and route home style rows into it as a dedicated full-screen flow. Reuse the existing game list, resolution language, shared UI components, and `BuildResultView`; keep the normal AI build flow unchanged.

**Tech Stack:** Swift 5, SwiftUI, existing asset catalog, standalone assertion-based Swift checks, Xcode iPhone 17 simulator build

---

## Prototype Boundary

- Frontend prototype only; do not modify `backend/` or `AppAPIClient.swift`.
- Every quote screen displays `演示估价，仅用于验证流程，不作为购买报价。`.
- Use only 黑武士、海景房、白色极简 because those are the styles with unique existing assets.
- Keep every demo number in `AestheticBuildFlow.swift` so a later API integration replaces data without rewriting views.
- Do not change `AIBuildView` or the normal AI build route.

## File Map

- Create `May/May/Models/AestheticBuildFlow.swift`: prototype data, quote calculation, and state transitions.
- Create `May/MayTests/AestheticBuildFlowRulesTests.swift`: focused model checks.
- Create `May/May/Screens/AestheticBuildView.swift`: four-step wizard.
- Modify `May/May/Screens/HomeView.swift`: replace passive rows with style entries.
- Modify `May/May/ContentView.swift`: full-screen route and flow/result host.
- Modify `May/May/Models/MockData.swift`: style-aware demo result.

### Task 1: Define flow and quote rules

**Files:**
- Create: `May/May/Models/AestheticBuildFlow.swift`
- Create: `May/MayTests/AestheticBuildFlowRulesTests.swift`

- [ ] **Step 1: Write the failing checks**

Create `May/MayTests/AestheticBuildFlowRulesTests.swift`:

```swift
import Foundation

@main
struct AestheticBuildFlowRulesTests {
    static func main() {
        assertEqual(AestheticBuildStyle.featured.map(\.title), ["黑武士", "海景房", "白色极简"], "Only unique styles should ship in the prototype.")

        let panorama = AestheticBuildStyle.featured[1]
        assertEqual(panorama.options.map(\.tier), [.core, .high, .complete], "Restoration choices should be ordered.")

        var flow = AestheticBuildFlow(styleID: panorama.id)
        assertEqual(flow.resolvedResolution, .twoK, "Unknown display should use 2K for the demo quote.")
        assertEqual(flow.quote.total, flow.quote.performanceCore + flow.quote.styleModule, "Total should not double-count style parts.")

        let coreQuote = flow.quote
        flow.selectTier(.complete)
        assertTrue(flow.quote.styleModule.low > coreQuote.styleModule.low, "Complete restoration should cost more than core restoration.")
        assertTrue(flow.quote.aestheticPremium.high <= flow.quote.styleModule.high, "Premium cannot exceed style module cost.")

        flow.setGames([.valorant])
        let lightGameQuote = flow.quote
        flow.setGames([.cyberpunk])
        assertTrue(flow.quote.performanceCore.low > lightGameQuote.performanceCore.low, "Demanding games should raise the estimate.")

        flow.confirmQuote()
        assertTrue(flow.isQuoteConfirmed, "Quote confirmation should be recorded.")
        flow.selectExperience(.highRefresh)
        assertTrue(!flow.isQuoteConfirmed, "Changing requirements should invalidate confirmation.")

        print("AestheticBuildFlowRulesTests passed")
    }

    private static func assertEqual<T: Equatable>(_ actual: T, _ expected: T, _ message: String) {
        guard actual == expected else { fatalError("\(message)\nExpected: \(expected)\nActual: \(actual)") }
    }

    private static func assertTrue(_ value: Bool, _ message: String) {
        guard value else { fatalError(message) }
    }
}
```

- [ ] **Step 2: Run the focused check and verify RED**

```bash
swiftc May/May/Models/HardwareCatalog.swift May/May/Models/OnboardingProfile.swift May/May/Models/PerformanceTestFlow.swift May/May/Models/AestheticBuildFlow.swift May/MayTests/AestheticBuildFlowRulesTests.swift -o /tmp/aesthetic-build-rules
```

Expected: compilation fails because the aesthetic flow types do not exist.

- [ ] **Step 3: Add the minimum model API**

Create `May/May/Models/AestheticBuildFlow.swift` with these types and methods:

```swift
import Foundation

struct AestheticPriceRange: Equatable {
    let low: Int
    let high: Int

    static func + (lhs: Self, rhs: Self) -> Self {
        .init(low: lhs.low + rhs.low, high: lhs.high + rhs.high)
    }

    var label: String { "¥\(low.formatted())–\(high.formatted())" }
    var midpointLabel: String { "约 ¥\(((low + high) / 2).formatted())" }
}

enum AestheticRestorationTier: String, CaseIterable, Identifiable {
    case core, high, complete
    var id: String { rawValue }
    var title: String {
        switch self {
        case .core: "核心还原"
        case .high: "高度还原"
        case .complete: "完整还原"
        }
    }
}

struct AestheticRestorationOption: Equatable, Identifiable {
    var id: AestheticRestorationTier { tier }
    let tier: AestheticRestorationTier
    let fidelity: Int
    let styleCost: AestheticPriceRange
    let premium: AestheticPriceRange
    let keeps: String
    let tradeoff: String
}

struct AestheticBuildStyle: Equatable, Identifiable {
    let id: String
    let title: String
    let summary: String
    let image: String
    let tags: [String]
    let options: [AestheticRestorationOption]

    var startingCostLabel: String { "为颜值花费约 ¥\(options[0].styleCost.low.formatted()) 起" }
    static let featured: [Self] = AestheticDemoCatalog.styles
}

enum AestheticExperience: String, CaseIterable, Identifiable {
    case smooth, highRefresh, competitive
    var id: String { rawValue }
    var title: String {
        switch self {
        case .smooth: "流畅游玩"
        case .highRefresh: "高刷顺滑"
        case .competitive: "电竞竞技"
        }
    }
    var detail: String {
        switch self {
        case .smooth: "约 60 帧"
        case .highRefresh: "约 120–144 帧"
        case .competitive: "200 帧以上"
        }
    }
}

enum AestheticResolutionChoice: String, CaseIterable, Identifiable {
    case unknown, fullHD, twoK, fourK
    var id: String { rawValue }
    var title: String {
        switch self {
        case .unknown: "不知道"
        case .fullHD: "1080P"
        case .twoK: "2K"
        case .fourK: "4K"
        }
    }
    var resolved: PerformanceResolution {
        switch self {
        case .unknown, .twoK: .twoK
        case .fullHD: .fullHD
        case .fourK: .fourK
        }
    }
}

enum AestheticBuildStep: Int, CaseIterable {
    case restoration, games, experience, quote
    var title: String {
        switch self {
        case .restoration: "外观取舍"
        case .games: "常玩游戏"
        case .experience: "体验目标"
        case .quote: "预算预估"
        }
    }
}

struct AestheticBuildQuote: Equatable {
    let performanceCore: AestheticPriceRange
    let styleModule: AestheticPriceRange
    let aestheticPremium: AestheticPriceRange
    let total: AestheticPriceRange
}
```

Add `AestheticBuildFlow` with these stored properties and transitions:

```swift
struct AestheticBuildFlow: Equatable {
    var step: AestheticBuildStep = .restoration
    let styleID: String
    var selectedTier: AestheticRestorationTier = .core
    var selectedGames: [PerformanceGame] = [.cyberpunk]
    var selectedExperience: AestheticExperience = .smooth
    var selectedResolution: AestheticResolutionChoice = .unknown
    private(set) var isQuoteConfirmed = false

    init(styleID: String) {
        self.styleID = AestheticBuildStyle.featured.contains { $0.id == styleID } ? styleID : AestheticBuildStyle.featured[0].id
    }

    var style: AestheticBuildStyle { AestheticBuildStyle.featured.first { $0.id == styleID } ?? AestheticBuildStyle.featured[0] }
    var restoration: AestheticRestorationOption { style.options.first { $0.tier == selectedTier } ?? style.options[0] }
    var resolvedResolution: PerformanceResolution { selectedResolution.resolved }

    var quote: AestheticBuildQuote {
        let performance = basePerformanceCost + demandingGameAdjustment
        return .init(performanceCore: performance, styleModule: restoration.styleCost, aestheticPremium: restoration.premium, total: performance + restoration.styleCost)
    }

    mutating func selectTier(_ value: AestheticRestorationTier) { selectedTier = value; isQuoteConfirmed = false }
    mutating func selectExperience(_ value: AestheticExperience) { selectedExperience = value; isQuoteConfirmed = false }
    mutating func selectResolution(_ value: AestheticResolutionChoice) { selectedResolution = value; isQuoteConfirmed = false }
    mutating func setGames(_ value: [PerformanceGame]) { guard !value.isEmpty else { return }; selectedGames = value; isQuoteConfirmed = false }
    mutating func toggleGame(_ game: PerformanceGame) {
        var games = selectedGames
        if let index = games.firstIndex(of: game) {
            guard games.count > 1 else { return }
            games.remove(at: index)
        } else { games.append(game) }
        setGames(games)
    }
    mutating func goNext() { if let value = AestheticBuildStep(rawValue: step.rawValue + 1) { step = value } }
    mutating func goPrevious() { if let value = AestheticBuildStep(rawValue: step.rawValue - 1) { step = value } }
    mutating func showRestoration() { step = .restoration }
    mutating func showExperience() { step = .experience }
    mutating func confirmQuote() { isQuoteConfirmed = true }
}
```

Add the exact private quote tables:

```swift
private extension AestheticBuildFlow {
    var basePerformanceCost: AestheticPriceRange {
        switch (resolvedResolution, selectedExperience) {
        case (.fullHD, .smooth): .init(low: 3800, high: 4500)
        case (.fullHD, .highRefresh): .init(low: 5000, high: 6000)
        case (.fullHD, .competitive): .init(low: 6200, high: 7500)
        case (.twoK, .smooth): .init(low: 4800, high: 5700)
        case (.twoK, .highRefresh): .init(low: 6500, high: 7800)
        case (.twoK, .competitive): .init(low: 7800, high: 9400)
        case (.fourK, .smooth): .init(low: 7200, high: 8600)
        case (.fourK, .highRefresh): .init(low: 10500, high: 12800)
        case (.fourK, .competitive): .init(low: 13800, high: 17500)
        }
    }

    var demandingGameAdjustment: AestheticPriceRange {
        let ids = Set(selectedGames.map(\.id))
        if ids.contains(where: { ["cyberpunk", "elden-ring", "cod"].contains($0) }) {
            return .init(low: 800, high: 1200)
        }
        if ids.contains(where: { ["pubg", "genshin", "apex"].contains($0) }) {
            return .init(low: 300, high: 600)
        }
        return .init(low: 0, high: 200)
    }
}
```

Add the complete demo catalog. The helper keeps the data compact without adding a production abstraction:

```swift
private enum AestheticDemoCatalog {
    static let styles: [AestheticBuildStyle] = [
        makeStyle(
            id: "blackKnight",
            title: "黑武士",
            summary: "低调冷酷，灯效克制，适合高性能玩家",
            image: "HomeStyleBlackKnight",
            tags: ["暗黑机箱", "克制灯效"],
            signature: "黑色机箱与整体暗色观感",
            highDetail: "统一黑色散热器与主要风扇位",
            completeDetail: "统一散热、风扇和克制灯效",
            costs: [.init(low: 850, high: 1100), .init(low: 1450, high: 1900), .init(low: 2300, high: 3100)],
            premiums: [.init(low: 300, high: 450), .init(low: 850, high: 1250), .init(low: 1650, high: 2350)]
        ),
        makeStyle(
            id: "panorama",
            title: "海景房",
            summary: "通透展示，适合 RGB 与颜值党",
            image: "HomeStylePanorama",
            tags: ["通透设计", "RGB"],
            signature: "海景房机箱与基础灯效",
            highDetail: "造型匹配的散热器与主要风扇位",
            completeDetail: "完整风扇布局、统一灯效与展示感",
            costs: [.init(low: 900, high: 1200), .init(low: 1600, high: 2200), .init(low: 2600, high: 3600)],
            premiums: [.init(low: 350, high: 500), .init(low: 950, high: 1450), .init(low: 1900, high: 2800)]
        ),
        makeStyle(
            id: "whiteMinimal",
            title: "白色极简",
            summary: "干净克制，适合桌搭与工作环境",
            image: "HomeStyleWhiteMinimal",
            tags: ["纯白", "简约"],
            signature: "白色机箱与干净桌搭观感",
            highDetail: "白色散热器与主要可见部件",
            completeDetail: "主要可见部件、风扇和线材统一",
            costs: [.init(low: 800, high: 1050), .init(low: 1400, high: 1850), .init(low: 2200, high: 3000)],
            premiums: [.init(low: 280, high: 420), .init(low: 800, high: 1200), .init(low: 1550, high: 2300)]
        )
    ]

    private static func makeStyle(
        id: String,
        title: String,
        summary: String,
        image: String,
        tags: [String],
        signature: String,
        highDetail: String,
        completeDetail: String,
        costs: [AestheticPriceRange],
        premiums: [AestheticPriceRange]
    ) -> AestheticBuildStyle {
        .init(
            id: id,
            title: title,
            summary: summary,
            image: image,
            tags: tags,
            options: [
                .init(tier: .core, fidelity: 65, styleCost: costs[0], premium: premiums[0], keeps: signature, tradeoff: "使用基础散热和必要风扇"),
                .init(tier: .high, fidelity: 85, styleCost: costs[1], premium: premiums[1], keeps: highDetail, tradeoff: "不补满装饰风扇"),
                .init(tier: .complete, fidelity: 95, styleCost: costs[2], premium: premiums[2], keeps: completeDetail, tradeoff: "保留同风格型号替代空间")
            ]
        )
    }
}
```

- [ ] **Step 4: Run the focused check and verify GREEN**

```bash
swiftc May/May/Models/HardwareCatalog.swift May/May/Models/OnboardingProfile.swift May/May/Models/PerformanceTestFlow.swift May/May/Models/AestheticBuildFlow.swift May/MayTests/AestheticBuildFlowRulesTests.swift -o /tmp/aesthetic-build-rules && /tmp/aesthetic-build-rules
```

Expected: `AestheticBuildFlowRulesTests passed`.

- [ ] **Step 5: Commit**

```bash
git add May/May/Models/AestheticBuildFlow.swift May/MayTests/AestheticBuildFlowRulesTests.swift
git commit -m "feat: define aesthetic build prototype flow"
```

### Task 2: Make home style rows open the flow

**Files:**
- Modify: `May/May/Screens/HomeView.swift`
- Modify: `May/May/ContentView.swift`

- [ ] **Step 1: Replace the private home style model**

Delete `private struct HomeBuildStyle`. Change the home state and section inputs to `AestheticBuildStyle`, using `AestheticBuildStyle.featured`.

Replace `onOpenBuildRecords` with:

```swift
let onOpenAestheticStyle: (String) -> Void
```

Give `HomeBuildStyleSection` separate `onSelect` and `onOpen` callbacks. Chips call `onSelect`; rows call `onOpen`. Remove “查看全部” because it currently leads to unrelated saved builds.

Construct the section as:

```swift
HomeBuildStyleSection(
    styles: AestheticBuildStyle.featured,
    selectedID: selectedBuildStyleID,
    onSelect: { style in
        withAnimation(.easeOut(duration: 0.22)) { selectedBuildStyleID = style.id }
    },
    onOpen: { style in
        selectedBuildStyleID = style.id
        onOpenAestheticStyle(style.id)
    }
)
```

- [ ] **Step 2: Add useful row copy**

Remove the bookmark icon. Show `style.startingCostLabel` beside the title and `按这个风格装机  →` below the summary. Keep the existing image, tags, divider, spacing, and typography otherwise unchanged.

- [ ] **Step 3: Add the full-screen route**

Extend `FullScreenRoute` in `ContentView.swift`:

```swift
case aestheticBuild(styleID: String)
```

Return `"aesthetic-build-\(styleID)"` from `id`. Update the home callback:

```swift
onOpenAestheticStyle: { styleID in
    onPresentFullScreen(.aestheticBuild(styleID: styleID))
}
```

Add the destination:

```swift
case .aestheticBuild(let styleID):
    AestheticBuildFlowView(styleID: styleID, onClose: { presentedFullScreen = nil })
```

- [ ] **Step 4: Add the flow host below `AIBuildFlowView`**

```swift
private struct AestheticBuildFlowView: View {
    let onClose: () -> Void
    @State private var flow: AestheticBuildFlow
    @State private var showsResult = false

    init(styleID: String, onClose: @escaping () -> Void) {
        self.onClose = onClose
        _flow = State(initialValue: AestheticBuildFlow(styleID: styleID))
    }

    var body: some View {
        if showsResult {
            BuildResultView(plan: AppMockData.aestheticSamplePlan(for: flow), onBack: onClose)
        } else {
            AestheticBuildView(flow: $flow, onClose: onClose) {
                showsResult = true
            }
        }
    }
}
```

Update the `HomeView` preview with `onOpenAestheticStyle: { _ in }`.

### Task 3: Build the four-step wizard

**Files:**
- Create: `May/May/Screens/AestheticBuildView.swift`

- [ ] **Step 1: Add the screen shell**

Create `AestheticBuildView` with `@Binding var flow`, `onClose`, and `onGenerate`. Use `ScreenHeader`, `FlowStepIndicator`, a `ScrollView`, and a bottom `PrimaryButton`. The back button closes only from `.restoration`; otherwise it calls `flow.goPrevious()`. The primary button calls `flow.goNext()` until `.quote`, then calls `flow.confirmQuote()` and `onGenerate()`.

```swift
@ViewBuilder
private var stepContent: some View {
    switch flow.step {
    case .restoration: restorationStep
    case .games: gamesStep
    case .experience: experienceStep
    case .quote: quoteStep
    }
}
```

- [ ] **Step 2: Implement restoration selection**

Show `flow.style.image`, title, and summary, followed by one button per `flow.style.options`. Each card displays tier title, `约 N%`, style price range, `保留：...`, and `取舍：...`. Selected cards use a 2-point black stroke; others use the existing border color. Buttons call `flow.selectTier(option.tier)`.

- [ ] **Step 3: Implement game selection**

Render `PerformanceGame.samples` in a two-column `LazyVGrid`. Each 48-point row shows the mark, name, and selected checkmark. Buttons call `flow.toggleGame(game)`. Selected rows are black with white text; unselected rows use `AppTheme.surface`.

- [ ] **Step 4: Implement experience and resolution selection**

Render the three `AestheticExperience` choices as vertical cards with novice-facing title and frame detail. Render `AestheticResolutionChoice.allCases` as capsules. Use `flow.selectExperience` and `flow.selectResolution`, never direct property assignments. When `.unknown` is selected, show `不知道也没关系，演示报价暂按 2K 估算。`.

- [ ] **Step 5: Implement the quote screen**

Display the total as a 32-point heavy value. Below it, show four rows in one `SoftCard`: 性能核心, 外观与散热, 其中颜值溢价, 整机预计. Values come only from `flow.quote`. Add buttons `少为外观花一点` → `flow.showRestoration()` and `游戏性能低一点` → `flow.showExperience()`.

The exact disclaimer must appear directly below the price card:

```swift
Text("演示估价，仅用于验证流程，不作为购买报价。")
    .font(.appCaption)
    .foregroundStyle(AppTheme.warning)
```

- [ ] **Step 6: Keep the UI implementation local**

Place presentation-only helpers such as `RestorationOptionCard`, `GameTargetButton`, and `QuoteRow` as private views in `AestheticBuildView.swift`. Do not add a view-model, coordinator, dependency, or separate component file.

### Task 4: Produce a style-aware demo result

**Files:**
- Modify: `May/May/Models/MockData.swift`

- [ ] **Step 1: Add the result factory**

Add inside `AppMockData`:

```swift
static func aestheticSamplePlan(for flow: AestheticBuildFlow) -> BuildPlan {
    let stylePart = PCPart(
        category: "外观与散热",
        model: "\(flow.style.title) · \(flow.restoration.tier.title)",
        price: flow.quote.styleModule.midpointLabel,
        icon: "fan",
        accent: AppTheme.primaryText,
        reason: flow.restoration.keeps,
        alternative: flow.restoration.tradeoff,
        source: "演示估价"
    )

    return BuildPlan(
        name: "\(flow.style.title)颜值游戏配置",
        budget: flow.quote.total.label,
        totalPrice: flow.quote.total.midpointLabel,
        useCase: "\(flow.resolvedResolution.title) · \(flow.selectedExperience.title) · \(flow.selectedGames.map(\.name).joined(separator: " / "))",
        createdAt: "演示方案",
        parts: Array(parts.prefix(6)) + [stylePart],
        risks: [
            BuildRisk(level: .warning, title: "演示价格", detail: "当前价格只用于验证颜值装机流程，不作为购买报价。"),
            BuildRisk(level: .warning, title: "兼容性待接入", detail: "生产版必须用真实机箱、散热器和风扇数据重新检查空间与散热。")
        ]
    )
}
```

- [ ] **Step 2: Run focused and build verification**

```bash
swiftc May/May/Models/HardwareCatalog.swift May/May/Models/OnboardingProfile.swift May/May/Models/PerformanceTestFlow.swift May/May/Models/AestheticBuildFlow.swift May/MayTests/AestheticBuildFlowRulesTests.swift -o /tmp/aesthetic-build-rules && /tmp/aesthetic-build-rules
xcodebuild -project May/May.xcodeproj -scheme May -destination 'platform=iOS Simulator,name=iPhone 17' -configuration Debug build
```

Expected: the rule test prints its passed message and Xcode ends with `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit the routed prototype**

```bash
git add May/May/Screens/HomeView.swift May/May/ContentView.swift May/May/Screens/AestheticBuildView.swift May/May/Models/MockData.swift
git commit -m "feat: add aesthetic build prototype"
```

### Task 5: Verify the complete interaction

**Files:**
- Modify only when verification exposes a defect: `May/May/Screens/AestheticBuildView.swift`, `May/May/Screens/HomeView.swift`

- [ ] **Step 1: Walk the full path on iPhone 17**

Verify all of these manually:

1. Home shows exactly three styles and no unrelated “查看全部” link.
2. A style row opens the matching style.
3. Each restoration tier changes the quote.
4. At least one game always stays selected.
5. “不知道” visibly uses 2K.
6. Cyberpunk costs more than Valorant with otherwise identical choices.
7. Both adjustment buttons return to the correct step.
8. Confirmation opens a style-aware demo result.
9. Quote and result both disclose demo pricing.
10. Closing returns home, and normal AI build is unchanged.

- [ ] **Step 2: Run final automated checks**

```bash
swiftc May/May/Models/HardwareCatalog.swift May/May/Models/OnboardingProfile.swift May/May/Models/PerformanceTestFlow.swift May/May/Models/AestheticBuildFlow.swift May/MayTests/AestheticBuildFlowRulesTests.swift -o /tmp/aesthetic-build-rules && /tmp/aesthetic-build-rules
xcodebuild -project May/May.xcodeproj -scheme May -destination 'platform=iOS Simulator,name=iPhone 17' -configuration Debug build
git diff --check
```

Expected: focused checks pass, Xcode reports `** BUILD SUCCEEDED **`, and `git diff --check` prints nothing.

- [ ] **Step 3: Commit verification corrections only if needed**

```bash
git add May/May/Screens/AestheticBuildView.swift May/May/Screens/HomeView.swift
git commit -m "fix: polish aesthetic build prototype flow"
```

Skip this commit if manual verification required no code changes.

## Deferred Production Work

After users validate this flow, create a separate production plan for approved case/cooler/fan imports, current price calculation, physical compatibility checks, and replacing the local demo quote/result with API responses.
