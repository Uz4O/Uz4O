# AI Build Preference Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove the onboarding preference page and add the three-option build preference selector to step 3 of the AI build flow.

**Architecture:** `BuildPreference` becomes a single-purpose AI build option model with explicit display order and a balanced default. `OnboardingProfile` retains only the hardware profile, while `OnboardingChoiceView` ends directly from the no-computer and hardware paths. `AIBuildView` owns the per-build preference as local state and renders it with the existing generic liquid segmented picker.

**Tech Stack:** Swift, SwiftUI, existing standalone Swift rule tests, Xcode simulator build

---

## File Map

- `May/May/Models/OnboardingProfile.swift`: define AI build preference order/default and remove the obsolete onboarding preference state.
- `May/MayTests/OnboardingProfileRulesTests.swift`: specify the new profile shape and AI preference contract.
- `May/May/Screens/OnboardingChoiceView.swift`: reduce onboarding to ownership and optional hardware collection.
- `May/May/ContentView.swift`: construct the simplified onboarding profile.
- `May/May/Screens/AIBuildView.swift`: render and retain the per-build preference selection.

### Task 1: Define The New Preference And Profile Contracts

**Files:**
- Modify: `May/MayTests/OnboardingProfileRulesTests.swift`
- Modify: `May/May/Models/OnboardingProfile.swift`
- Modify: `May/May/ContentView.swift`

- [ ] **Step 1: Write the failing rule assertions**

Replace preference-specific onboarding assertions with these contracts:

```swift
assertEqual(
    BuildPreference.aiBuildOptions.map(\.title),
    ["性能优先", "颜值优先", "均衡搭配"],
    "AI build preferences should use the requested order and labels."
)

assertEqual(
    BuildPreference.defaultAISelection,
    .balanced,
    "AI build preference should default to balanced."
)

let completedProfile = OnboardingProfile(
    hardwareProfile: HardwareProfile(
        cpu: HardwareProfileOptions.cpu[0],
        gpu: HardwareProfileOptions.gpu[1],
        motherboard: HardwareProfileOptions.motherboard[1],
        memory: HardwareProfileOptions.memory[2],
        storage: HardwareProfileOptions.storage[1],
        powerSupply: HardwareProfileOptions.powerSupply[2]
    )
)
```

Remove assertions for `preferenceLabel` and `shouldCollectHardwareBeforePreference` because those APIs must no longer exist.

- [ ] **Step 2: Run the focused rule test and verify RED**

Run:

```bash
swiftc May/May/Models/HardwareCatalog.swift May/May/Models/OnboardingProfile.swift May/MayTests/OnboardingProfileRulesTests.swift -o /tmp/onboarding-profile-rules && /tmp/onboarding-profile-rules
```

Expected: FAIL for the missing new preference/profile API, not a syntax error.

- [ ] **Step 3: Implement the minimal model changes**

Change `BuildPreference` to the AI-only contract:

```swift
enum BuildPreference: String, CaseIterable, Identifiable {
    case balanced
    case performance
    case aesthetic

    static let aiBuildOptions: [BuildPreference] = [.performance, .aesthetic, .balanced]
    static let defaultAISelection: BuildPreference = .balanced

    var id: String { rawValue }

    var title: String {
        switch self {
        case .balanced: return "均衡搭配"
        case .performance: return "性能优先"
        case .aesthetic: return "颜值优先"
        }
    }
}
```

Remove the no-longer-used preference subtitles/icons and `ComputerOwnershipChoice`. Simplify `OnboardingProfile`:

```swift
struct OnboardingProfile: Equatable {
    var hardwareProfile: HardwareProfile

    init(hardwareProfile: HardwareProfile = .skipped) {
        self.hardwareProfile = hardwareProfile
    }

    static let skipped = OnboardingProfile()
}
```

Update `ContentView.init()` to construct `OnboardingProfile(hardwareProfile: savedHardwareProfile)`.

- [ ] **Step 4: Run the focused rule test and verify GREEN**

Run:

```bash
swiftc May/May/Models/HardwareCatalog.swift May/May/Models/OnboardingProfile.swift May/MayTests/OnboardingProfileRulesTests.swift -o /tmp/onboarding-profile-rules && /tmp/onboarding-profile-rules
```

Expected: `OnboardingProfileRulesTests passed`.

### Task 2: Remove The Onboarding Preference Page

**Files:**
- Modify: `May/May/Screens/OnboardingChoiceView.swift`

- [ ] **Step 1: Make the onboarding flow use only two states**

Remove `selectedPreference`, `computerOwnership`, the `.preference` case, the third progress pill, and `PreferenceStep`.

Use direct completion actions:

```swift
onNoComputer: {
    hardwareProfile = .skipped
    onFinish(.skipped)
}

onSkip: {
    hardwareProfile = .skipped
    onFinish(.skipped)
}

onFinish: {
    hardwareProfile = savedHardwareProfile()
    onFinish(OnboardingProfile(hardwareProfile: hardwareProfile))
}
```

Change the no-computer subtitle to `直接进入 App，之后仍可在「我的」页面补充电脑配置。` and the hardware button title to `保存并进入 App`.

- [ ] **Step 2: Build and verify the reduced flow compiles**

Run:

```bash
xcodebuild -project May/May.xcodeproj -scheme May -destination 'platform=iOS Simulator,name=iPhone 17' -configuration Debug build
```

Expected: `BUILD SUCCEEDED` with no references to the deleted preference step or ownership routing helper.

### Task 3: Add The AI Build Preference Selector

**Files:**
- Modify: `May/May/Screens/AIBuildView.swift`

- [ ] **Step 1: Add per-build preference state**

Add this state next to the existing purchase preference:

```swift
@State private var selectedBuildPreference = BuildPreference.defaultAISelection
```

- [ ] **Step 2: Render the selector in the purchase step**

Insert this group after “购买偏好” and before “主机颜色偏好”:

```swift
VStack(alignment: .leading, spacing: 8) {
    Text("装机偏好")
        .font(.appSubheadline)
        .foregroundStyle(AppTheme.primaryText)

    LiquidGlassSegmentedPicker(
        options: BuildPreference.aiBuildOptions,
        selection: $selectedBuildPreference,
        title: \.title
    )
}
```

- [ ] **Step 3: Run final verification**

Run:

```bash
swiftc May/May/Models/HardwareCatalog.swift May/May/Models/OnboardingProfile.swift May/MayTests/OnboardingProfileRulesTests.swift -o /tmp/onboarding-profile-rules && /tmp/onboarding-profile-rules
xcodebuild -project May/May.xcodeproj -scheme May -destination 'platform=iOS Simulator,name=iPhone 17' -configuration Debug build
git diff --check
```

Expected: rule test passes, `BUILD SUCCEEDED`, and `git diff --check` produces no output.
