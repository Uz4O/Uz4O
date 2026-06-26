# Home Community Preview Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the home screen's card-like "快捷入口" section with a lighter community preview section that shows selected community discussions without adding more entry cards.

**Architecture:** Keep the change scoped to the home screen. Reuse `CommunityPost.featuredFeed` from `May/May/Models/CommunityContent.swift` so the home preview and community tab share the same curated source. Add small private SwiftUI views inside `HomeView.swift` instead of introducing new shared components.

**Tech Stack:** SwiftUI, existing `CommunityPost` model, existing `xcodebuild` iOS simulator build flow.

---

## File Structure

- Modify: `May/May/Screens/HomeView.swift`
  - Remove the current `快捷入口` `VStack` and its three `HomeQuickEntryCard` instances.
  - Add `HomeCommunityPreviewSection` and `HomeCommunityPreviewRow` as private views in the same file.
  - Keep `HomeQuickEntryCard` only if another file uses it; otherwise remove it from `HomeView.swift`.
- Modify: `May/MayTests/CommunityContentRulesTests.swift`
  - Add rules that describe the home community preview content contract.
- Do not modify: `May/May/Models/CommunityContent.swift`
  - It already provides `CommunityPost.featuredFeed` with three curated posts.

## Product Requirements

- Remove the `快捷入口` heading and the three large cards: `硬件检测`, `预算计算`, `装机记录`.
- Replace that area with a non-card-like community preview.
- The preview should use existing community content and route to `onOpenCommunity`.
- The visual shape should be closer to a clean list or feed, not a grid of rounded card buttons.
- The section should not duplicate the main feature selector above it.
- The design should keep the home page calm and less visually fragmented.

## Proposed UI

Section title row:

```text
社区精选                                      更多
```

Rows:

```text
分享一套 5000 元左右的高性价比配置，适合游戏和生产力需求。
装机配置 · 性价比 · 256 回复

最近在纠结这两颗 CPU，主要用途是游戏，求大佬给点建议。
硬件评测 · CPU · 194 回复

实测对比了多款 360 水冷和风冷散热器，数据说话。
硬件评测 · 散热 · 128 回复
```

The rows may use subtle dividers, small metadata text, and a lightweight chevron. Avoid wrapping each item in a large white card.

---

### Task 1: Add Home Preview Content Rules

**Files:**
- Modify: `May/MayTests/CommunityContentRulesTests.swift`

- [ ] **Step 1: Add rule assertions for home preview feed content**

Add these assertions after the existing `CommunityPost.featuredFeed.count` assertion:

```swift
        assertEqual(
            Array(CommunityPost.featuredFeed.prefix(3)).map(\.summary),
            [
                "分享一套 5000 元左右的高性价比配置，适合游戏和生产力需求。",
                "最近在纠结这两颗 CPU，主要用途是游戏，求大佬给点建议。",
                "实测对比了多款 360 水冷和风冷散热器，数据说话。"
            ],
            "Home community preview should reuse the first three curated community summaries."
        )

        assertEqual(
            Array(CommunityPost.featuredFeed.prefix(3)).map { $0.stats.comments },
            [256, 194, 128],
            "Home community preview metadata should expose reply counts from curated posts."
        )
```

- [ ] **Step 2: Run the focused rule test**

Run:

```bash
xcodebuild -project /Users/may/Documents/AI装机/May/May.xcodeproj -scheme May -destination 'generic/platform=iOS Simulator' build
```

Expected: build succeeds. These tests are source-level rule checks in `May/MayTests`; if the project does not compile tests as targets, this command still verifies the app compiles after the planned model usage.

- [ ] **Step 3: Commit the rule update**

```bash
git add /Users/may/Documents/AI装机/May/MayTests/CommunityContentRulesTests.swift
git commit -m "test: document home community preview content"
```

---

### Task 2: Replace Quick Entry Section With Community Preview

**Files:**
- Modify: `May/May/Screens/HomeView.swift`

- [ ] **Step 1: Replace the quick entry block**

In `HomeView.body`, replace this block:

```swift
                    VStack(alignment: .leading, spacing: 14) {
                        Text("快捷入口")
                            .font(.system(size: 20, weight: .heavy))
                            .foregroundStyle(.black)

                        HStack(spacing: 9) {
                            HomeQuickEntryCard(
                                title: "硬件检测",
                                subtitle: "检测电脑硬件状态",
                                icon: "display",
                                action: onOpenConfigReview
                            )

                            HomeQuickEntryCard(
                                title: "预算计算",
                                subtitle: "快速计算装机预算",
                                icon: "list.bullet.rectangle",
                                action: onOpenAI
                            )

                            HomeQuickEntryCard(
                                title: "装机记录",
                                subtitle: "查看历史方案",
                                icon: "camera",
                                action: onOpenBuildRecords
                            )
                        }
                    }
                    .padding(.top, 32)
```

With:

```swift
                    HomeCommunityPreviewSection(
                        posts: Array(CommunityPost.featuredFeed.prefix(3)),
                        onOpenCommunity: onOpenCommunity
                    )
                    .padding(.top, 32)
```

- [ ] **Step 2: Add the community preview section view**

Add this private view below `HomeFeatureSelector` and above `HomeQuickEntryCard`:

```swift
private struct HomeCommunityPreviewSection: View {
    let posts: [CommunityPost]
    let onOpenCommunity: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(alignment: .center) {
                Text("社区精选")
                    .font(.system(size: 20, weight: .heavy))
                    .foregroundStyle(.black)

                Spacer()

                Button(action: onOpenCommunity) {
                    HStack(spacing: 4) {
                        Text("更多")
                        Image(systemName: "chevron.right")
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.black.opacity(0.58))
                }
                .buttonStyle(.plain)
            }

            VStack(spacing: 0) {
                ForEach(Array(posts.enumerated()), id: \.element.id) { index, post in
                    HomeCommunityPreviewRow(post: post, action: onOpenCommunity)

                    if index < posts.count - 1 {
                        Divider()
                            .padding(.leading, 2)
                    }
                }
            }
        }
    }
}
```

- [ ] **Step 3: Add the community preview row view**

Add this private view immediately after `HomeCommunityPreviewSection`:

```swift
private struct HomeCommunityPreviewRow: View {
    let post: CommunityPost
    let action: () -> Void

    private var metadataText: String {
        let tagText = Array(post.tags.prefix(2)).joined(separator: " · ")
        return "\(tagText) · \(post.stats.comments) 回复"
    }

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(post.summary)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppTheme.primaryText)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(metadataText)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(AppTheme.secondaryText)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.black.opacity(0.24))
            }
            .padding(.vertical, 13)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(post.summary)，\(metadataText)")
    }
}
```

- [ ] **Step 4: Remove unused quick entry component if possible**

After replacing the section, search for `HomeQuickEntryCard`:

```bash
rg -n "HomeQuickEntryCard" /Users/may/Documents/AI装机/May/May
```

Expected: only the private struct remains in `HomeView.swift`.

If no call sites remain, delete this entire private struct from `HomeView.swift`:

```swift
private struct HomeQuickEntryCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 23, style: .continuous)
                    .fill(Color.white.opacity(0.88))
                    .shadow(color: Color.black.opacity(0.04), radius: 24, x: 0, y: 14)

                VStack(spacing: 13) {
                    Image(systemName: icon)
                        .font(.system(size: 28, weight: .regular))
                        .foregroundStyle(.black)
                        .frame(width: 48, height: 48)

                    Text(title)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.black)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)

                    Text(subtitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppTheme.secondaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.68)
                }
                .padding(.horizontal, 8)
                .frame(maxWidth: .infinity)
            }
            .frame(height: 150)
        }
        .buttonStyle(.plain)
    }
}
```

- [ ] **Step 5: Verify the app builds**

Run:

```bash
xcodebuild -project /Users/may/Documents/AI装机/May/May.xcodeproj -scheme May -destination 'generic/platform=iOS Simulator' build
```

Expected:

```text
** BUILD SUCCEEDED **
```

- [ ] **Step 6: Commit the home section replacement**

```bash
git add /Users/may/Documents/AI装机/May/May/Screens/HomeView.swift
git commit -m "feat: show community preview on home"
```

---

### Task 3: Manual Visual Acceptance

**Files:**
- No source files should be changed in this task unless the user requests visual tweaks.

- [ ] **Step 1: Run the app in the iPhone simulator**

Open the app from Xcode or run the existing simulator workflow used by this project.

- [ ] **Step 2: Check the home screen hierarchy**

Expected:

```text
AI 装机助手
[hero feature area]
[feature selector]
社区精选
[three lightweight discussion rows]
[bottom tab bar]
```

- [ ] **Step 3: Confirm removed content**

Expected absent text:

```text
快捷入口
硬件检测
预算计算
装机记录
```

- [ ] **Step 4: Confirm interaction**

Tap:

```text
更多
```

Expected: opens the Community tab or community screen through `onOpenCommunity`.

Tap any community preview row.

Expected: opens the Community tab or community screen through `onOpenCommunity`.

- [ ] **Step 5: Commit visual tweak if requested**

If the user asks for spacing or typography changes, keep them in `HomeView.swift` and commit separately:

```bash
git add /Users/may/Documents/AI装机/May/May/Screens/HomeView.swift
git commit -m "style: tune home community preview"
```

---

## Final Verification

Run:

```bash
xcodebuild -project /Users/may/Documents/AI装机/May/May.xcodeproj -scheme May -destination 'generic/platform=iOS Simulator' build
```

Expected:

```text
** BUILD SUCCEEDED **
```

Run:

```bash
rg -n "快捷入口|硬件检测|预算计算|装机记录|HomeQuickEntryCard" /Users/may/Documents/AI装机/May/May/Screens/HomeView.swift
```

Expected: no matches.

Run:

```bash
rg -n "社区精选|HomeCommunityPreviewSection|HomeCommunityPreviewRow" /Users/may/Documents/AI装机/May/May/Screens/HomeView.swift
```

Expected: matches for the new community preview section and row.

## Self-Review

- Spec coverage: The plan removes card-like quick entries and replaces them with a lightweight community preview using existing curated community content.
- Placeholder scan: No placeholders remain; all code snippets and commands are concrete.
- Type consistency: `CommunityPost`, `CommunityStats`, `AppTheme`, and `onOpenCommunity` already exist in the project and are referenced consistently.
