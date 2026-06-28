# No-Boot Checklist Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (- [ ]) syntax for tracking.

**Goal:** Build the non-AI, checklist-style no-boot troubleshooting flow inside the existing installation guide.

**Architecture:** Keep everything as local static guide content. Add checklist scenario data to May/May/Models/GuideFlow.swift, route the troubleshooting entry in May/May/Screens/GuideView.swift to a dedicated checklist flow, and extend the existing assert-based guide test. No backend, model call, or new dependency is needed.

**Tech Stack:** Swift, SwiftUI, existing AppTheme, existing assert-style Swift tests.

---

## File Structure

- Modify: May/May/Models/GuideFlow.swift
  - Add no-boot checklist scenario and step data.
  - Keep existing GuideSection data for current tests and other guide pages.
- Modify: May/May/Screens/GuideView.swift
  - Add routes for checklist home and checklist scenario detail.
  - Add private SwiftUI views for scenario cards and step cards.
- Modify: May/MayTests/GuideFlowRulesTests.swift
  - Assert the two scenarios, their titles, step counts, no-AI copy, and first/last critical checks.

## Task 1: Add checklist data and tests

**Files:**
- Modify: May/May/Models/GuideFlow.swift
- Modify: May/MayTests/GuideFlowRulesTests.swift

- [ ] **Step 1: Write the failing data test**

In May/MayTests/GuideFlowRulesTests.swift, add this block after the existing secondaryGuideHomeEntries assertions:

~~~swift
        assertEqual(GuideFlow.noBootChecklistScenarios.count, 2, "No-boot assistant should split the two common failure states.")
        assertEqual(
            GuideFlow.noBootChecklistScenarios.map(\.title),
            ["显示器不亮，主机亮着", "显示器和主机都不亮"],
            "No-boot scenarios should match the approved checklist entry choices."
        )
        assertEqual(
            GuideFlow.noBootChecklistScenarios.allSatisfy { $0.subtitle.contains("AI") == false },
            true,
            "No-boot checklist copy should not imply AI involvement."
        )
        assertEqual(
            GuideFlow.noBootChecklistScenarios.map { $0.steps.count },
            [7, 7],
            "Each no-boot scenario should start with seven ordered checklist steps."
        )
        assertEqual(
            GuideFlow.noBootChecklistScenarios[0].steps.first?.title,
            "显示器是否通电",
            "Display-on-host-on path should start with monitor power."
        )
        assertEqual(
            GuideFlow.noBootChecklistScenarios[0].steps.last?.title,
            "查看主板故障灯或蜂鸣提示",
            "Display-on-host-on path should end with board diagnostic indicators."
        )
        assertEqual(
            GuideFlow.noBootChecklistScenarios[1].steps.first?.title,
            "插排和墙插是否有电",
            "All-dark path should start with wall power."
        )
        assertEqual(
            GuideFlow.noBootChecklistScenarios[1].steps.last?.title,
            "最小化启动，排除短路",
            "All-dark path should end with a minimal boot check."
        )
~~~

- [ ] **Step 2: Run the focused test and verify it fails**

Run:

~~~bash
swiftc May/May/Models/GuideFlow.swift May/MayTests/GuideFlowRulesTests.swift -o /tmp/GuideFlowRulesTests && /tmp/GuideFlowRulesTests
~~~

Expected: compile failure mentioning type 'GuideFlow' has no member 'noBootChecklistScenarios'.

- [ ] **Step 3: Add the minimal checklist model and static data**

In May/May/Models/GuideFlow.swift, add these structs after GuideHomeEntry:

~~~swift
struct GuideNoBootChecklistScenario: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let symbol: String
    let steps: [GuideNoBootChecklistStep]
}

struct GuideNoBootChecklistStep: Identifiable, Hashable {
    let id: String
    let title: String
    let text: String
    let symbol: String
}
~~~

Then add this static data inside GuideFlow, after secondaryGuideHomeEntries:

~~~swift
    static let noBootChecklistScenarios = [
        GuideNoBootChecklistScenario(
            id: "display-dark-host-on",
            title: "显示器不亮，主机亮着",
            subtitle: "主机有风扇或灯光反应，但屏幕没有画面。",
            symbol: "display",
            steps: [
                GuideNoBootChecklistStep(id: "monitor-power", title: "显示器是否通电", text: "确认显示器电源线插紧，电源指示灯亮起。", symbol: "powerplug"),
                GuideNoBootChecklistStep(id: "monitor-input", title: "显示器输入源是否选对", text: "用显示器按键切到当前视频线对应的 HDMI、DP 或 Type-C 输入。", symbol: "rectangle.connected.to.line.below"),
                GuideNoBootChecklistStep(id: "display-cable", title: "视频线是否插紧", text: "重新插拔显示器和电脑两端的视频线，确认接口没有松动。", symbol: "cable.connector"),
                GuideNoBootChecklistStep(id: "gpu-port", title: "视频线是否插在显卡接口", text: "有独立显卡时，视频线要插显卡接口，不要插主板视频接口。", symbol: "rectangle.stack"),
                GuideNoBootChecklistStep(id: "gpu-power", title: "显卡供电线是否插好", text: "检查显卡 6Pin、8Pin 或 12VHPWR 供电线是否插到底。", symbol: "bolt"),
                GuideNoBootChecklistStep(id: "memory-reseat", title: "内存是否插紧", text: "关机断电后重新插拔内存，优先只留一根插在主板推荐插槽。", symbol: "memorychip"),
                GuideNoBootChecklistStep(id: "debug-light", title: "查看主板故障灯或蜂鸣提示", text: "查看主板 CPU、DRAM、VGA、BOOT 灯，按亮灯位置继续检查对应硬件。", symbol: "lightbulb")
            ]
        ),
        GuideNoBootChecklistScenario(
            id: "all-dark",
            title: "显示器和主机都不亮",
            subtitle: "按下开机键后，主机风扇、灯光和屏幕都没有反应。",
            symbol: "power",
            steps: [
                GuideNoBootChecklistStep(id: "wall-power", title: "插排和墙插是否有电", text: "换一个墙插或用手机充电器确认插排确实有电。", symbol: "poweroutlet.type.b"),
                GuideNoBootChecklistStep(id: "psu-cable", title: "电源线是否插紧", text: "确认电源线两端都插到底，机箱背部接口没有松动。", symbol: "cable.connector"),
                GuideNoBootChecklistStep(id: "psu-switch", title: "电源背部开关是否拨到 I", text: "电源背后的 I/O 开关要拨到 I，O 代表关闭。", symbol: "switch.2"),
                GuideNoBootChecklistStep(id: "front-panel", title: "机箱开机线是否接对", text: "按主板说明书确认 POWER SW 插在正确的前面板针脚上。", symbol: "button.programmable"),
                GuideNoBootChecklistStep(id: "board-power", title: "主板 24Pin 和 CPU 8Pin 是否插紧", text: "确认主板右侧 24Pin 和 CPU 附近 8Pin 供电都插到底。", symbol: "bolt.horizontal"),
                GuideNoBootChecklistStep(id: "short-power", title: "尝试主板短接开机针脚", text: "用螺丝刀轻触 POWER SW 两根针脚，排除机箱开机键问题。", symbol: "screwdriver"),
                GuideNoBootChecklistStep(id: "minimal-boot", title: "最小化启动，排除短路", text: "只保留 CPU、散热器、一根内存、显卡和电源，先确认能否开机。", symbol: "checklist")
            ]
        )
    ]
~~~

- [ ] **Step 4: Run the focused test and verify it passes**

Run:

~~~bash
swiftc May/May/Models/GuideFlow.swift May/MayTests/GuideFlowRulesTests.swift -o /tmp/GuideFlowRulesTests && /tmp/GuideFlowRulesTests
~~~

Expected: GuideFlowRulesTests passed.

- [ ] **Step 5: Commit Task 1**

Run:

~~~bash
git add May/May/Models/GuideFlow.swift May/MayTests/GuideFlowRulesTests.swift
git commit -m "feat: add no-boot checklist data"
~~~

## Task 2: Add the checklist UI flow

**Files:**
- Modify: May/May/Screens/GuideView.swift

- [ ] **Step 1: Extend guide page routing**

In May/May/Screens/GuideView.swift, replace the GuidePage enum with:

~~~swift
private enum GuidePage: Equatable {
    case overview
    case noBootChecklistHome
    case noBootChecklistScenario(GuideNoBootChecklistScenario)
    case componentShowcase
    case components
    case section(GuideSection)
}
~~~

Update headerTitle with these cases:

~~~swift
        case .noBootChecklistHome:
            return "点不亮排查助手"
        case .noBootChecklistScenario(let scenario):
            return scenario.title
~~~

Update currentPage with these cases before .componentShowcase:

~~~swift
        case .noBootChecklistHome:
            NoBootChecklistHomePage(
                contentWidth: contentWidth,
                onOpenScenario: { scenario in
                    page = .noBootChecklistScenario(scenario)
                }
            )
            .transition(.opacity)
        case .noBootChecklistScenario(let scenario):
            NoBootChecklistScenarioPage(scenario: scenario, contentWidth: contentWidth)
                .transition(.opacity)
~~~

Update handleBack() to:

~~~swift
    private func handleBack() {
        switch page {
        case .overview:
            onBack()
        case .noBootChecklistScenario:
            page = .noBootChecklistHome
        default:
            page = .overview
        }
    }
~~~

Update openHomeEntry(_:) to:

~~~swift
    private func openHomeEntry(_ entry: GuideHomeEntry) {
        if entry.id == "troubleshooting" {
            page = .noBootChecklistHome
            return
        }

        if entry.id == "components" {
            page = .componentShowcase
            return
        }

        guard let section = GuideFlow.guideSections.first(where: { $0.id == entry.id }) else {
            return
        }
        page = .section(section)
    }
~~~

- [ ] **Step 2: Add the checklist views**

Add these private views before GuideSectionDetailPage:

~~~swift
private struct NoBootChecklistHomePage: View {
    let contentWidth: CGFloat
    let onOpenScenario: (GuideNoBootChecklistScenario) -> Void

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("先选你看到的情况")
                        .font(.system(size: 26, weight: .black))
                        .foregroundStyle(AppTheme.primaryText)

                    Text("这里不是 AI 诊断，只是按常见故障顺序整理的图文清单。")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppTheme.secondaryText)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(spacing: 12) {
                    ForEach(GuideFlow.noBootChecklistScenarios) { scenario in
                        NoBootScenarioCard(scenario: scenario) {
                            onOpenScenario(scenario)
                        }
                    }
                }
            }
            .frame(width: contentWidth, alignment: .leading)
            .padding(.top, 8)
            .padding(.bottom, 10)
            .frame(maxWidth: .infinity)
        }
    }
}

private struct NoBootScenarioCard: View {
    let scenario: GuideNoBootChecklistScenario
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 13) {
                Image(systemName: scenario.symbol)
                    .font(.system(size: 23, weight: .black))
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(AppTheme.primaryText, in: RoundedRectangle(cornerRadius: 17))

                VStack(alignment: .leading, spacing: 7) {
                    Text(scenario.title)
                        .font(.system(size: 17, weight: .black))
                        .foregroundStyle(AppTheme.primaryText)

                    Text(scenario.subtitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppTheme.secondaryText)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("\(scenario.steps.count) 步清单")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(AppTheme.secondaryText)
                        .padding(.top, 2)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(AppTheme.secondaryText)
                    .padding(.top, 4)
            }
            .padding(16)
            .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 18))
            .overlay {
                RoundedRectangle(cornerRadius: 18)
                    .stroke(AppTheme.border, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(scenario.title)，\(scenario.subtitle)，\(scenario.steps.count) 步清单")
    }
}

private struct NoBootChecklistScenarioPage: View {
    let scenario: GuideNoBootChecklistScenario
    let contentWidth: CGFloat

    @State private var checkedStepIDs: Set<String> = []

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(scenario.title)
                        .font(.system(size: 24, weight: .black))
                        .foregroundStyle(AppTheme.primaryText)

                    Text(scenario.subtitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppTheme.secondaryText)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(18)
                .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 20))
                .overlay {
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(AppTheme.border, lineWidth: 1)
                }

                VStack(spacing: 10) {
                    ForEach(Array(scenario.steps.enumerated()), id: \.element.id) { index, step in
                        NoBootChecklistStepCard(
                            index: index + 1,
                            step: step,
                            isChecked: checkedStepIDs.contains(step.id)
                        ) {
                            if checkedStepIDs.contains(step.id) {
                                checkedStepIDs.remove(step.id)
                            } else {
                                checkedStepIDs.insert(step.id)
                            }
                        }
                    }
                }
            }
            .frame(width: contentWidth, alignment: .leading)
            .padding(.top, 8)
            .padding(.bottom, 10)
            .frame(maxWidth: .infinity)
        }
    }
}

private struct NoBootChecklistStepCard: View {
    let index: Int
    let step: GuideNoBootChecklistStep
    let isChecked: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(alignment: .top, spacing: 12) {
                ZStack(alignment: .bottomTrailing) {
                    Image(systemName: step.symbol)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(AppTheme.primaryText)
                        .frame(width: 42, height: 42)
                        .background(AppTheme.softSurface, in: RoundedRectangle(cornerRadius: 13))

                    Text("\(index)")
                        .font(.system(size: 9, weight: .black))
                        .foregroundStyle(.white)
                        .frame(width: 17, height: 17)
                        .background(AppTheme.primaryText, in: Circle())
                        .offset(x: 4, y: 4)
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text(step.title)
                        .font(.system(size: 15, weight: .black))
                        .foregroundStyle(AppTheme.primaryText)

                    Text(step.text)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppTheme.secondaryText)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(isChecked ? AppTheme.primaryText : AppTheme.secondaryText.opacity(0.55))
            }
            .padding(14)
            .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 16))
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(AppTheme.border, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("第\(index)步，\(step.title)，\(step.text)")
        .accessibilityValue(isChecked ? "已检查" : "未检查")
    }
}
~~~

- [ ] **Step 3: Build the app target enough to catch SwiftUI compile errors**

Run:

~~~bash
xcodebuild -project May/May.xcodeproj -scheme May -destination 'platform=iOS Simulator,name=iPhone 16' -quiet build
~~~

Expected: build succeeds. If the simulator name is unavailable, run this and use one listed iPhone simulator name:

~~~bash
xcrun simctl list devices available | rg 'iPhone .*\('
~~~

- [ ] **Step 4: Re-run the guide data test**

Run:

~~~bash
swiftc May/May/Models/GuideFlow.swift May/MayTests/GuideFlowRulesTests.swift -o /tmp/GuideFlowRulesTests && /tmp/GuideFlowRulesTests
~~~

Expected: GuideFlowRulesTests passed.

- [ ] **Step 5: Commit Task 2**

Run:

~~~bash
git add May/May/Screens/GuideView.swift
git commit -m "feat: add no-boot checklist flow"
~~~

## Final Verification

- [ ] **Step 1: Run the focused guide data test**

Run:

~~~bash
swiftc May/May/Models/GuideFlow.swift May/MayTests/GuideFlowRulesTests.swift -o /tmp/GuideFlowRulesTests && /tmp/GuideFlowRulesTests
~~~

Expected: GuideFlowRulesTests passed.

- [ ] **Step 2: Build the app**

Run:

~~~bash
xcodebuild -project May/May.xcodeproj -scheme May -destination 'platform=iOS Simulator,name=iPhone 16' -quiet build
~~~

Expected: build succeeds.

## Spec Coverage Check

- Two entry choices: Task 1 data and Task 2 checklist home.
- Ordered checklist pages: Task 1 data and Task 2 scenario page.
- Step card with title, illustration symbol, short copy, and checked state: Task 2 step card.
- No AI involvement: Task 1 copy assertion and static local data.
- No backend or model dependency: plan only touches local Swift files.
