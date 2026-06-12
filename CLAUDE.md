# CLAUDE.md

## Project Overview

This is a SwiftUI iOS app at `/Users/may/Documents/AI装机`.

The product is an AI PC-building assistant for Chinese users, especially beginners who do not understand PC hardware. The app currently focuses on frontend/product experience. Backend work has not been started yet.

Core product direction:

- Help beginners generate PC build suggestions.
- Help users check whether a quoted PC configuration has obvious problems.
- Help users record their current computer and get upgrade advice.
- Provide a configuration/community area so users can share builds and ask others to review them.

The product should feel like a practical PC decision assistant, not a generic hardware encyclopedia or shopping app.

## Current Tech Stack

- Platform: iOS
- UI: SwiftUI
- Project: `May/May.xcodeproj`
- Scheme: `May`
- Main entry: `May/May/MayApp.swift`
- Root routing: `May/May/ContentView.swift`

There is no backend yet. Most data is local mock/model data.

## Important Product Principles

- The app should prioritize beginners.
- Avoid overly technical explanations unless needed.
- Do not frame the app as a shopping or affiliate product.
- Configuration results should be explainable and easy to share.
- AI should not freely invent hardware models in the future backend design; specific recommendations should come from a maintained recommendation/hardware database.
- Community features should center on configuration review, build sharing, upgrade questions, and avoiding bad configurations, not generic chat.

## Key Files

- `May/May/ContentView.swift`
  - App-level routing and tab/screen switching.

- `May/May/Theme/AppTheme.swift`
  - Shared colors, typography, radii, shadows.

- `May/May/Components/AppComponents.swift`
  - Shared UI components such as buttons, cards, tab bar, rows.

- `May/May/Models/OnboardingProfile.swift`
  - Login-after onboarding state, build preference, home feature ordering.

- `May/May/Models/HardwareProfileStore.swift`
  - Local persistence for the user's current computer profile.

- `May/May/Screens/OnboardingChoiceView.swift`
  - Login-after selection flow.

- `May/May/Screens/HomeView.swift`
  - Home screen and primary feature entry points.

- `May/May/Screens/AIBuildView.swift`
  - AI build flow prototype.

- `May/May/Screens/BuildResultView.swift`
  - Build result display prototype.

- `May/May/Screens/ConfigReviewView.swift`
  - Configuration checking / quote review flow.

- `May/May/Screens/UpgradePlanView.swift`
  - Existing-computer upgrade advice flow.

- `May/May/Screens/DIYBuildView.swift`
  - Currently reused as a game performance test flow.

- `May/May/Screens/CommunityView.swift`
  - Community/configuration sharing screen.

- `May/May/Screens/CommunityComposerView.swift`
  - Community post composer.

- `May/May/Screens/MyBuildsView.swift`
  - Configuration tab, saved builds, and current-computer entry.

- `May/May/Screens/ProfileView.swift`
  - Profile/settings surface.

- `docs/登录后选择界面方案-v1.md`
  - Product spec for the login-after selection flow.

- `design-qa.md`
  - Notes from visual QA against reference screenshots.

## Build and Verification

Use Xcode or XcodeBuildMCP.

Known working defaults:

```text
Project: /Users/may/Documents/AI装机/May/May.xcodeproj
Scheme: May
Simulator: iPhone 17 or iPhone 17 Pro
Platform: iOS Simulator
```

Useful validation:

```bash
xcodebuild -project May/May.xcodeproj -scheme May -destination 'platform=iOS Simulator,name=iPhone 17' -configuration Debug build
```

In this repository, the Xcode project uses file-system-synchronized groups. Do not assume every new Swift file must be manually added to `project.pbxproj` before first verifying with a real build.

`test_sim` may fail because the scheme is not configured for test-without-building. Prefer normal simulator builds and focused Swift tests where available.

## Current Worktree Note

Before making edits, run:

```bash
git status --short --branch
```

This repository often has active uncommitted UI changes. Do not revert user or other-agent changes unless explicitly asked.

## Suggested Workflow for Claude

1. Read this file first.
2. Run `git status --short --branch`.
3. Inspect the exact screen/model files related to the user's request.
4. Preserve existing SwiftUI visual patterns unless the user asks for a redesign.
5. Keep frontend changes scoped and verify with an iOS Simulator build.
6. If changing UI, use simulator screenshots or UI snapshots for visual sanity checks.
7. If asked about backend, answer at the architecture/product level unless the user explicitly asks to implement backend code.

## Suggested Skills

If available, use:

- SwiftUI/iOS UI patterns for screen and component changes.
- Systematic debugging for build failures or broken navigation.
- Verification-before-completion before claiming a change is done.
- Product/brainstorming workflow for feature decisions.

