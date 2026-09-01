import Foundation

@main
struct BootTroubleshootingRulesTests {
    static func main() {
        assertEqual(
            BootTroubleshootingCatalog.scenarios.count,
            6,
            "Troubleshooting should cover the six approved beginner-visible symptoms."
        )
        assertEqual(
            BootTroubleshootingCatalog.scenarios.first?.title,
            "完全没反应",
            "The flow should start with the clearest no-power symptom."
        )
        assertTrue(
            BootTroubleshootingCatalog.scenarios.allSatisfy { !$0.choices.isEmpty },
            "Every symptom needs one focused follow-up question."
        )
        assertTrue(
            BootTroubleshootingCatalog.outcomes.allSatisfy { $0.steps.count >= 4 },
            "Every result needs an ordered, useful troubleshooting path."
        )

        let scenarioIDs = BootTroubleshootingCatalog.scenarios.map(\.id)
        let outcomeIDs = BootTroubleshootingCatalog.outcomes.map(\.id)
        assertEqual(Set(scenarioIDs).count, scenarioIDs.count, "Scenario IDs must be unique.")
        assertEqual(Set(outcomeIDs).count, outcomeIDs.count, "Outcome IDs must be unique.")

        for scenario in BootTroubleshootingCatalog.scenarios {
            for choice in scenario.choices {
                assertTrue(
                    BootTroubleshootingCatalog.outcome(id: choice.outcomeID) != nil,
                    "Every choice must resolve locally: \(scenario.id) / \(choice.id)."
                )
            }
        }

        let scenarioCopy = BootTroubleshootingCatalog.scenarios.flatMap { scenario in
            [scenario.title, scenario.subtitle, scenario.question, scenario.questionHint]
                + scenario.choices.map(\.title)
        }
        let outcomeCopy = BootTroubleshootingCatalog.outcomes.flatMap { outcome in
            [outcome.title, outcome.summary]
                + outcome.steps.flatMap { [$0.title, $0.detail, $0.warning ?? ""] }
        }
        let allCopy = ([BootTroubleshootingCatalog.safetyNotice] + scenarioCopy + outcomeCopy)
            .joined(separator: "\n")

        for forbidden in ["用螺丝刀轻触", "尝试主板短接", "打开电源外壳", "回形针测试"] {
            assertTrue(!allCopy.contains(forbidden), "Beginner guidance must not include dangerous action: \(forbidden)")
        }
        assertTrue(!allCopy.contains("AI 诊断"), "The offline flow must not imply AI diagnosis.")
        assertTrue(
            BootTroubleshootingCatalog.safetyNotice.contains("不要拆开电源"),
            "The global safety boundary must explicitly forbid opening the PSU."
        )

        var session = BootTroubleshootingSession()
        assertEqual(session.stage, .symptoms, "A session should start at symptom selection.")
        session.selectScenario("no-display")
        assertEqual(session.selectedScenario?.title, "风扇转，但没有画面", "The selected symptom should be retained.")
        session.beginQuestions()
        assertEqual(session.stage, .question, "Starting should move to one focused question.")
        session.selectChoice("motherboard")
        assertEqual(session.stage, .action, "A valid answer should open the ordered checks.")
        assertEqual(session.outcome?.id, "video-port", "Motherboard video output should start with the port check.")
        assertEqual(session.currentStep?.id, "gpu-video-port", "The safest, highest-value check should be first.")

        let stepCount = require(session.outcome?.steps.count, "The selected result should have steps.")
        for _ in 0..<stepCount {
            session.continueUnresolved()
        }
        assertEqual(session.stage, .unresolved, "Exhausting the checks should show a transparent unresolved result.")
        assertEqual(session.completedStepIDs.count, stepCount, "The unresolved summary should retain every completed check.")

        session.restart()
        session.selectScenario("debug-light")
        session.beginQuestions()
        session.selectChoice("dram")
        session.markResolved()
        assertEqual(session.stage, .resolved, "The user must be able to finish as soon as a check solves the issue.")
        assertEqual(session.completedStepIDs.count, 1, "The resolved result should record the successful check.")

        verifyLocalUIIntegration()

        print("BootTroubleshootingRulesTests passed")
    }

    private static func verifyLocalUIIntegration() {
        let project = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let tools = try! String(
            contentsOf: project.appendingPathComponent("May/Screens/ToolsView.swift"),
            encoding: .utf8
        )
        let screen = try! String(
            contentsOf: project.appendingPathComponent("May/Screens/BootTroubleshootingView.swift"),
            encoding: .utf8
        )

        assertTrue(tools.contains("DIY 装机"), "The tool card should expose DIY build.")
        assertTrue(tools.contains("DIYView(importedBuild:"), "The DIY card should navigate locally.")
        assertTrue(!tools.contains("电脑点不亮"), "The troubleshooting shortcut should be replaced.")
        assertTrue(!tools.contains("装机预算测算"), "The replaced budget shortcut must be removed.")
        assertTrue(screen.contains("电脑现在是什么情况？"), "The symptom screen needs a concise prompt.")
        assertTrue(screen.contains("开机时"), "Startup symptoms should be grouped together.")
        assertTrue(screen.contains("进入 BIOS 后"), "Post-BIOS symptoms should be grouped together.")
        assertTrue(!screen.contains("开始排查"), "Choosing a symptom should start troubleshooting directly.")
        assertTrue(screen.contains("做完了，但还是没有画面") && screen.contains("问题解决了"), "Each check needs beginner-friendly outcomes.")
        assertTrue(screen.contains("BootGuideVideoPorts") && screen.contains("BootGuideMemory"), "Key checks should use real hardware illustrations.")
        assertTrue(screen.contains(".toolbar(.hidden, for: .tabBar)"), "The focused flow should hide the tab bar.")
    }

    private static func assertEqual<T: Equatable>(_ actual: T, _ expected: T, _ message: String) {
        guard actual == expected else {
            fatalError("\(message)\nExpected: \(expected)\nActual: \(actual)")
        }
    }

    private static func assertTrue(_ value: Bool, _ message: String) {
        guard value else { fatalError(message) }
    }

    private static func require<T>(_ value: T?, _ message: String) -> T {
        guard let value else { fatalError(message) }
        return value
    }
}
