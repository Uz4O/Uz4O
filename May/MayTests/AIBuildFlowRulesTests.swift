import Foundation

@main
struct AIBuildFlowRulesTests {
    static func main() {
        let buildViewSource = try! String(
            contentsOfFile: "May/May/Screens/AIBuildView.swift",
            encoding: .utf8
        )
        let contentViewSource = try! String(
            contentsOfFile: "May/May/ContentView.swift",
            encoding: .utf8
        )

        assertEqual(
            AIBuildFlowRules.visibleSteps(budget: 3900, ownedParts: []),
            [.budget, .scenario],
            "Low budget without valuable owned parts should skip purchase and hardware preference pages."
        )
        assertEqual(
            AIBuildFlowRules.visibleSteps(budget: 3000, ownedParts: [.gpu]),
            AIBuildStep.allCases,
            "A valuable owned GPU should keep the full flow even under 4000 yuan."
        )
        assertEqual(
            AIBuildFlowRules.visibleSteps(budget: 3000, ownedParts: [.casePart, .storage]),
            [.budget, .scenario],
            "Low-value owned parts should not bypass low-budget mode."
        )
        assertEqual(
            AIBuildFlowRules.lowBudgetDefaults(useCase: "游戏"),
            AIBuildLowBudgetDefaults(purchasePreference: "部分配件二手", buildPreference: .performance, colorPreference: "颜色不限"),
            "Low-budget gaming should prefer mixed purchase and performance."
        )
        assertEqual(
            AIBuildFlowRules.lowBudgetDefaults(useCase: "办公"),
            AIBuildLowBudgetDefaults(purchasePreference: "全新优先", buildPreference: .balanced, colorPreference: "颜色不限"),
            "Low-budget office builds should stay new-first and balanced."
        )
        assertContains(
            buildViewSource,
            "minimumGenerationDuration: TimeInterval = 2.4",
            "Successful generation should remain visible long enough to feel intentional."
        )
        assertContains(
            buildViewSource,
            "AIBuildGeneratingView()",
            "Submitting the final step should show the dedicated AI generation state."
        )
        assertContains(
            contentViewSource,
            ".combined(with: .scale(scale: 0.96, anchor: .bottom))",
            "Generated options and details should use the richer result transition."
        )
        print("AIBuildFlowRulesTests passed")
    }

    private static func assertEqual<T: Equatable>(_ actual: T, _ expected: T, _ message: String) {
        guard actual == expected else {
            fatalError("\(message)\nExpected: \(expected)\nActual: \(actual)")
        }
    }

    private static func assertContains(_ text: String, _ fragment: String, _ message: String) {
        guard text.contains(fragment) else {
            fatalError("\(message)\nMissing: \(fragment)")
        }
    }
}
