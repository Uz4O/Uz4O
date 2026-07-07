import Foundation

@main
struct AIBuildFlowRulesTests {
    static func main() {
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

        print("AIBuildFlowRulesTests passed")
    }

    private static func assertEqual<T: Equatable>(_ actual: T, _ expected: T, _ message: String) {
        guard actual == expected else {
            fatalError("\(message)\nExpected: \(expected)\nActual: \(actual)")
        }
    }
}
