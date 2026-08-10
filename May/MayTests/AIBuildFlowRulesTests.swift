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
            "minimumGenerationDuration: TimeInterval = 14.5",
            "Successful generation should remain visible for the slower loading experience."
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
            "if budgetValue < 6500",
            "Budgets below 6500 yuan should keep memory fixed at 16GB instead of exposing the memory picker."
        )
        assertContains(
            buildViewSource,
            "return budgetValue >= 6500 && budgetValue < 8000",
            "Budgets from 6500 through 7999 yuan should use the constrained capacity choice."
        )
        assertContains(
            buildViewSource,
            "midBudgetCapacityOptions = [\"32GB 内存\", \"1TB 固态\"]",
            "The constrained capacity picker should make 32GB memory and 1TB storage mutually exclusive."
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
            ".frame(width: 90, height: 90)",
            "The central progress badge should stay compact around the percentage."
        )
        assertNotContains(
            buildViewSource,
            ".scaleEffect(isPulsing ? 1.012 : 0.995)",
            "The central progress badge should remain still instead of pulsing."
        )
        assertContains(
            buildViewSource,
            "proxy.size.width * 0.6",
            "The generation stage separators should end around the reference timeline width."
        )
        assertNotContains(
            buildViewSource,
            ".background(.white, in: RoundedRectangle(cornerRadius: 22))",
            "The generation stages should not be presented inside a card."
        )
        assertNotContains(
            buildViewSource,
            "Text(status(for: index))",
            "The generation stages should follow the reference layout without right-side status labels."
        )
        assertContains(
            buildViewSource,
            "isCompact ? 54 : 64",
            "The generation timeline should retain its original readable row height."
        )
        assertContains(
            buildViewSource,
            "HStack(alignment: .top, spacing: 16)",
            "The timeline dots and labels should share the same top alignment."
        )
        assertContains(
            buildViewSource,
            "ZStack(alignment: .top)",
            "The connector line should start from each dot center instead of the row center."
        )
        assertContains(
            buildViewSource,
            ".animation(.smooth(duration: 0.45), value: currentStage)",
            "The active stage dot should use the smoother stage transition."
        )
        assertContains(
            buildViewSource,
            "CGFloat(currentStage) * rowHeight",
            "The active stage dot should move using the fixed row spacing."
        )
        assertNotContains(
            buildViewSource,
            "LiquidStageDot(",
            "The removed liquid deformation should not return to the stage timeline."
        )
        assertContains(
            buildViewSource,
            "while progress < 99",
            "The loading progress should approach 99% before waiting for generation to finish."
        )
        assertContains(
            buildViewSource,
            ".linear(duration: 0.12)",
            "The progress arc should use a longer linear interpolation to avoid visible stepping."
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
        assertNotContains(
            buildViewSource,
            "ForEach(0..<3, id: \\.self) { ring in",
            "The active stage rings should be removed from the transition page."
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
        assertNotContains(
            buildViewSource,
            "GenerationProgressDots(progress: progress)",
            "The removed bottom progress dots should not return to the transition page."
        )
        assertNotContains(
            buildViewSource,
            "Color(red: 0.62, green: 0.64, blue: 0.66)",
            "The removed active stage rings should not leave a gray-ring implementation behind."
        )
        assertNotContains(
            buildViewSource,
            "isFloating",
            "The host image should remain still inside the progress dial."
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

    private static func assertNotContains(_ text: String, _ fragment: String, _ message: String) {
        guard !text.contains(fragment) else {
            fatalError("\(message)\nUnexpected: \(fragment)")
        }
    }
}
