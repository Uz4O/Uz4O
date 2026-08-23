import Foundation

@main
struct BuildResultContentRulesTests {
    static func main() {
        let modelSource = try! String(
            contentsOfFile: "May/May/Models/MockData.swift",
            encoding: .utf8
        )
        let viewSource = try! String(
            contentsOfFile: "May/May/Screens/BuildResultView.swift",
            encoding: .utf8
        )
        let contentViewSource = try! String(
            contentsOfFile: "May/May/ContentView.swift",
            encoding: .utf8
        )
        let diyViewSource = try! String(
            contentsOfFile: "May/May/Screens/DIYView.swift",
            encoding: .utf8
        )

        assertContains(
            modelSource,
            "condition: condition.displayName",
            "API parts should preserve whether each component is new or used."
        )
        assertContains(viewSource, "Text(part.model)", "The component model should be shown directly.")
        assertContains(viewSource, "part.price.replacingOccurrences", "The component price should be shown directly.")
        assertContains(viewSource, "Text(part.condition)", "The new or used condition should be shown directly.")
        assertContains(viewSource, ".foregroundStyle(.black)", "Part symbols should be black.")
        assertContains(viewSource, ".background(Color.white", "Part icon tiles should be white.")
        assertContains(
            modelSource,
            "name: details.direction.resultTitle",
            "The result title should describe the gaming focus without exposing template wording."
        )
        assertContains(
            modelSource,
            "useCase: details.direction.resultSubtitle",
            "The hero should use a short beginner-friendly direction summary."
        )
        assertContains(viewSource, "PerformanceCard(", "The result should show the performance card.")
        assertContains(
            viewSource,
            "AppAPIClient().estimatePerformance(",
            "The result should reuse the existing game-performance API."
        )
        for resolution in [".fullHD", ".twoK", ".fourK"] {
            assertContains(
                viewSource,
                "resolution: \(resolution)",
                "The result should request every displayed resolution."
            )
        }
        for fixedFPS in ["Text(\"168\")", "value: \"240\"", "value: \"96\""] {
            assertNotContains(
                viewSource,
                fixedFPS,
                "Hard-coded FPS must not return to generated build details."
            )
        }
        assertContains(viewSource, "PartsListCard(plan: plan", "The parts should use the reference list card.")
        assertContains(
            viewSource,
            "if let alternative = plan.usedGPUAlternative",
            "All-new NVIDIA results should show a maintained used 40-series alternative when available."
        )
        assertContains(viewSource, "Text(\"显卡替代建议\")", "The alternative should be clearly separated from the configured parts.")
        assertContains(
            viewSource,
            "此建议不改变上方全新配置，也不计入总价",
            "The used-card suggestion must not be mistaken for part of the all-new total."
        )
        assertContains(viewSource, "TotalPriceSection(totalPrice: plan.totalPrice)", "The total should have its own full-width row.")
        assertContains(viewSource, "Text(plan.useCase)", "The header should keep the short plan subtitle.")
        assertContains(viewSource, "Text(\"游戏性能表现\")", "The performance card title should match the reference.")
        assertContains(viewSource, "\"1080P 电竞\"", "The esports performance metric should remain visible.")
        assertContains(viewSource, "\"4K 高画质\"", "The high-quality performance metric should remain visible.")
        assertNotContains(viewSource, "保存配置单", "The removed save-build action should not return.")
        assertContains(viewSource, "title: \"保存为图片\"", "The result should support saving a complete image.")
        assertContains(viewSource, "title: \"进入DIY界面编辑\"", "AI builds should be editable in DIY.")
        assertContains(viewSource, "ImageRenderer(", "The saved image should render the complete result card.")
        assertContains(viewSource, ".frame(maxWidth: 420)", "The result actions should fill phones without growing too wide on larger screens.")
        assertContains(
            contentViewSource,
            "onEditInDIY: { onEditInDIY(selectedOption) }",
            "The selected AI option should be handed to DIY."
        )
        assertContains(
            contentViewSource,
            "DIYView(importedBuild: $diyBuildOption)",
            "The DIY tab should receive the pending AI option."
        )
        assertContains(
            diyViewSource,
            "selectedComponents = importedComponents",
            "DIY should replace its current selection with the imported AI build."
        )
        assertContains(
            diyViewSource,
            "DIYSummaryMetric(title: \"推荐电源瓦数\"",
            "DIY should show the backend-recommended PSU wattage as its main metric."
        )
        assertNotContains(
            diyViewSource,
            "title: \"预计功耗\"",
            "DIY should not present estimated load as PSU purchase guidance."
        )
        assertOrdered(
            viewSource,
            "TotalPriceSection(totalPrice: plan.totalPrice)",
            "title: \"保存为图片\"",
            "The total row must appear above the result actions."
        )
        assertContains(
            viewSource,
            "ForEach(Array(plan.parts.enumerated())",
            "Result parts should reveal in a short staggered sequence."
        )
        assertNotContains(viewSource, "part.reason", "Selection explanations should not appear in the result list.")
        assertNotContains(viewSource, "SoftCard", "The hero and parts list should not use the old card containers.")
        assertNotContains(viewSource, "BuildHeroCard", "The old dark PC hero should not return.")
        assertNotContains(viewSource, "Image(\"PCTower\")", "The old tower artwork should not return.")
        assertNotContains(viewSource, "复制清单", "The removed copy action should not return.")
        assertNotContains(viewSource, "BuildSummaryCard", "The old three-column summary should not return.")
        assertNotContains(viewSource, "AIContentDisclosure", "The extra AI disclosure should not crowd the result page.")
        assertNotContains(viewSource, "价格可能随市场波动", "The extra market-price note should not crowd the result page.")
        assertNotContains(viewSource, "ShareLink", "The removed share control should not return.")
        assertNotContains(viewSource, "info.circle", "The performance card should not show an info icon.")
        assertNotContains(viewSource, "ForEach(0..<48", "The performance gauge should not show radial tick marks.")
        assertNotContains(
            viewSource,
            ".background(Color.black, in: RoundedRectangle(cornerRadius: 10))",
            "Part icon tiles should no longer use a black background."
        )
        assertNotContains(viewSource, "SummaryBadge(title: \"预算\"", "The user's original budget should not be repeated.")
        assertNotContains(
            modelSource,
            "reason: \"成色：",
            "Price source and date should not be packed into result presentation text."
        )

        print("BuildResultContentRulesTests passed")
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

    private static func assertOrdered(
        _ text: String,
        _ first: String,
        _ second: String,
        _ message: String
    ) {
        guard let firstRange = text.range(of: first),
              let secondRange = text.range(of: second),
              firstRange.lowerBound < secondRange.lowerBound
        else {
            fatalError(message)
        }
    }
}
