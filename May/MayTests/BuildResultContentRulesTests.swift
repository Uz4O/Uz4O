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
        assertNotContains(viewSource, "part.reason", "Selection explanations should not appear in the result list.")
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
