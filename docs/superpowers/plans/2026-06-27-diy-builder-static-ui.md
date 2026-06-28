# DIY Builder Static UI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the existing “开始 DIY” CTA open a static SwiftUI builder page that closely reproduces the supplied 4×2 hardware-card design.

**Architecture:** Keep the existing DIY landing page and native DIY tab. Add one presentation-only layout model for the eight fixed card entries, one focused SwiftUI screen, and one boolean navigation state in `MainTabView`; no backend, persistence, selection sheets, calculations, or host-preview image loading are added in this phase.

**Tech Stack:** Swift 5, SwiftUI, SF Symbols, assertion-based Swift rules, Xcode iOS Simulator build.

---

### Task 1: Define and verify the static card order

**Files:**
- Create: `May/May/Models/DIYConfiguratorLayout.swift`
- Create: `May/MayTests/DIYConfiguratorRulesTests.swift`

- [ ] **Step 1: Write the failing layout rule**

Create `DIYConfiguratorRulesTests.swift`:

```swift
import Foundation

@main
struct DIYConfiguratorRulesTests {
    static func main() {
        assertEqual(
            DIYConfiguratorLayout.parts.map(\.title),
            ["CPU", "显卡", "主板", "内存", "硬盘", "电源", "散热", "机箱"],
            "DIY builder should preserve the reference design's 4×2 card order."
        )
        assertEqual(
            DIYConfiguratorLayout.parts.filter(\.isSelected).map(\.number),
            ["01", "02", "03"],
            "The static reference state should show only the first three parts as selected."
        )
        print("DIYConfiguratorRulesTests passed")
    }

    private static func assertEqual<T: Equatable>(_ actual: T, _ expected: T, _ message: String) {
        guard actual == expected else {
            fatalError("\(message)\nExpected: \(expected)\nActual: \(actual)")
        }
    }
}
```

- [ ] **Step 2: Run the test and verify RED**

Run:

```bash
swiftc May/May/Models/DIYConfiguratorLayout.swift May/MayTests/DIYConfiguratorRulesTests.swift -o /tmp/diy-configurator-rules
```

Expected: compilation fails because `DIYConfiguratorLayout.swift` does not exist.

- [ ] **Step 3: Add the minimum presentation model**

Create `DIYConfiguratorLayout.swift`:

```swift
import Foundation

struct DIYConfiguratorPart: Equatable, Identifiable {
    let number: String
    let title: String
    let value: String
    let icon: String
    let isSelected: Bool

    var id: String { number }
}

enum DIYConfiguratorLayout {
    static let parts = [
        DIYConfiguratorPart(number: "01", title: "CPU", value: "Intel i5-14600KF", icon: "cpu", isSelected: true),
        DIYConfiguratorPart(number: "02", title: "显卡", value: "RTX 4070 Super", icon: "rectangle.3.group", isSelected: true),
        DIYConfiguratorPart(number: "03", title: "主板", value: "微星 B760M\nMORTAR", icon: "square.grid.3x3.square", isSelected: true),
        DIYConfiguratorPart(number: "04", title: "内存", value: "待选择", icon: "memorychip", isSelected: false),
        DIYConfiguratorPart(number: "05", title: "硬盘", value: "待选择", icon: "internaldrive", isSelected: false),
        DIYConfiguratorPart(number: "06", title: "电源", value: "待选择", icon: "fan", isSelected: false),
        DIYConfiguratorPart(number: "07", title: "散热", value: "待选择", icon: "fanblades", isSelected: false),
        DIYConfiguratorPart(number: "08", title: "机箱", value: "待选择", icon: "server.rack", isSelected: false)
    ]
}
```

- [ ] **Step 4: Run the rule and verify GREEN**

Run:

```bash
swiftc May/May/Models/DIYConfiguratorLayout.swift May/MayTests/DIYConfiguratorRulesTests.swift -o /tmp/diy-configurator-rules && /tmp/diy-configurator-rules
```

Expected: `DIYConfiguratorRulesTests passed`.

### Task 2: Connect the landing CTA to the new static screen

**Files:**
- Modify: `May/May/Screens/DIYHomeView.swift`
- Modify: `May/May/ContentView.swift`
- Create: `May/May/Screens/DIYConfiguratorView.swift`

- [ ] **Step 1: Expose the landing-page CTA action**

Change the landing view declaration and button action:

```swift
struct DIYHomeView: View {
    let onStartDIY: () -> Void
```

```swift
Button(action: onStartDIY) {
```

Update the preview to `DIYHomeView(onStartDIY: {})`.

- [ ] **Step 2: Add the minimum DIY-tab navigation state**

Add to `MainTabView`:

```swift
@State private var showsDIYConfigurator = false
```

Replace the DIY tab root with:

```swift
NavigationStack {
    DIYHomeView {
        showsDIYConfigurator = true
    }
    .toolbar(.hidden, for: .navigationBar)
    .navigationDestination(isPresented: $showsDIYConfigurator) {
        DIYConfiguratorView()
            .toolbar(.hidden, for: .navigationBar)
    }
}
```

- [ ] **Step 3: Build the static reference hierarchy**

Create `DIYConfiguratorView.swift` with these concrete sections:

```swift
import SwiftUI

struct DIYConfiguratorView: View {
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 4)

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                DIYConfiguratorHeader()
                DIYConfiguratorIntro()
                    .padding(.top, 30)

                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(DIYConfiguratorLayout.parts) { part in
                        DIYPartCard(part: part)
                    }
                }
                .padding(.top, 30)

                DIYRealtimeSummary()
                    .padding(.top, 18)

                HStack(spacing: 12) {
                    DIYStaticActionButton(title: "✦ AI 优化", isPrimary: false)
                    DIYStaticActionButton(title: "查看主机概况", isPrimary: true, showsArrow: true)
                }
                .padding(.top, 16)
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 28)
        }
        .background(Color.white.ignoresSafeArea())
    }
}
```

Add private subviews in the same file:

- `DIYConfiguratorHeader`: 28-point heavy `UzBox` and 22-point bell.
- `DIYConfiguratorIntro`: 13-point gray eyebrow, 38-point heavy title, and 14-point gray subtitle.
- `DIYPartCard`: 214-point tall rounded card, top-right number, 56-point circular icon surface, title/value text, green selected check or dashed plus.
- `DIYRealtimeSummary`: rounded bordered card with “实时检测” and four equal metrics: `¥ 7997`, `428W`, `完全兼容`, `预算内`.
- `DIYStaticActionButton`: 46-point capsule; outline for AI optimization and black fill for host overview; both use empty actions because this phase is static.

- [ ] **Step 4: Build and inspect on the reference-size simulator**

Run:

```bash
xcodebuild -project May/May.xcodeproj -scheme May -destination 'platform=iOS Simulator,name=iPhone 17' -configuration Debug build
```

Expected: `** BUILD SUCCEEDED **`.

Launch on iPhone 17 Pro Max, tap DIY then “开始 DIY”, and compare with `/Users/may/Downloads/ChatGPT_Image_2026年6月27日_22_24_17.png`. Adjust only the new screen’s font sizes, card dimensions, spacing, and summary/action heights.

- [ ] **Step 5: Re-run final checks**

Run:

```bash
swiftc May/May/Models/DIYConfiguratorLayout.swift May/MayTests/DIYConfiguratorRulesTests.swift -o /tmp/diy-configurator-rules && /tmp/diy-configurator-rules
xcodebuild -project May/May.xcodeproj -scheme May -destination 'platform=iOS Simulator,name=iPhone 17' -configuration Debug build
```

Expected: the rule prints `passed` and the build ends with `** BUILD SUCCEEDED **`.
