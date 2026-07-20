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
        assertEqual(
            AIBuildFlowRules.recommendedDirection(for: ["CS2", "瓦罗兰特"]),
            .fps,
            "FPS-only games should recommend the high-frame-rate direction."
        )
        assertEqual(
            AIBuildFlowRules.recommendedDirection(for: ["瓦罗兰特"]),
            .fps,
            "Valorant alone should recommend an FPS build."
        )
        assertEqual(
            AIBuildFlowRules.recommendedDirection(for: ["黑神话悟空"]),
            .aaa,
            "AAA games should recommend the graphics-first direction."
        )
        assertEqual(
            AIBuildFlowRules.recommendedDirection(for: ["CS2", "黑神话悟空"]),
            .balanced,
            "Mixed game categories should recommend the balanced direction."
        )
        assertContains(
            buildViewSource,
            "minimumGenerationDuration: TimeInterval = 7.0",
            "Successful generation should remain visible long enough to feel intentional."
        )
        assertContains(
            buildViewSource,
            "AIBuildGeneratingView(isComplete: isGenerationComplete)",
            "Submitting the final step should show the dedicated AI generation state."
        )
        assertContains(
            buildViewSource,
            "BuildDirectionRecommendationSheet(",
            "Game direction confirmation should use a prominent modal sheet."
        )
        assertContains(
            buildViewSource,
            ".sheet(item: $directionRecommendation)",
            "The direction sheet should be driven by the current recommendation instead of capturing stale state."
        )
        assertContains(
            contentViewSource,
            ".opacity.combined(with: .scale(scale: 0.985))",
            "Generated options and details should emerge from the completion bloom."
        )
        assertContains(
            buildViewSource,
            "Image(\"PCTower\")",
            "The reference loading design should reuse the existing PC tower asset."
        )
        assertContains(
            buildViewSource,
            "[\"分析需求\", \"检查兼容性\", \"优化配置方案\", \"生成最终结果\"]",
            "The generation dashboard should expose all four reference stages."
        )
        assertContains(
            buildViewSource,
            "transaction.animation = nil",
            "The generation percentage should change directly without a digit transition."
        )
        assertContains(
            buildViewSource,
            "ringRotation = 360",
            "The loading dial should include a slow continuous scanning motion."
        )
        assertContains(
            buildViewSource,
            ".linear(duration: 120)",
            "The outer dial ticks should rotate slowly enough to feel nearly still."
        )
        assertContains(
            buildViewSource,
            ".scaleEffect(isPulsing ? 1.16 : 0.76)",
            "The active stage rings should visibly shrink and expand."
        )
        assertContains(
            buildViewSource,
            "let usesCompactLayout = proxy.size.height < 900",
            "Shorter iPhones should switch the generation dashboard to a compact vertical layout."
        )
        assertContains(
            buildViewSource,
            "usesCompactLayout ? 304 : 342",
            "Compact generation layouts should reduce the dial enough to fit without shrinking text."
        )
        assertContains(
            buildViewSource,
            "isCompact: usesCompactLayout",
            "The stage card should use the same compact-height decision as the dial."
        )
        assertContains(
            buildViewSource,
            "ScrollView(showsIndicators: false)",
            "The generation dashboard should retain scrolling as an accessibility fallback."
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
