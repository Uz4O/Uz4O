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

        assertContains(
            modelSource,
            "condition: condition.displayName",
            "API parts should preserve whether each component is new or used."
        )
        assertContains(viewSource, "Text(part.model)", "The component model should be shown directly.")
        assertContains(viewSource, "Text(part.price)", "The component price should be shown directly.")
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
        assertContains(viewSource, "BuildHeroCard(plan: plan)", "The result should use the reference hero layout.")
        assertContains(viewSource, "Image(\"PCTower\")", "The hero should reuse the existing PC image.")
        assertContains(viewSource, "Text(plan.useCase)", "The hero should show the short direction summary.")
        assertContains(viewSource, "价格可能随市场波动", "The result should explain that prices can change.")
        assertContains(viewSource, "PrimaryButton(title: \"保存配置单\"", "Saving the build should remain available.")
        assertNotContains(viewSource, "part.reason", "Selection explanations should not appear in the result list.")
        assertNotContains(viewSource, "SoftCard", "The hero and parts list should not use the old card containers.")
        assertNotContains(viewSource, "复制清单", "The removed copy action should not return.")
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
}
