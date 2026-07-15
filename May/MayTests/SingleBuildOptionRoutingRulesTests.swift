import Foundation

@main
struct SingleBuildOptionRoutingRulesTests {
    static func main() {
        let contentViewSource = try! String(
            contentsOfFile: "May/May/ContentView.swift",
            encoding: .utf8
        )

        assertEqual(
            AIBuildFlowRules.shouldSkipOptionSelection(optionCount: 0),
            false,
            "An empty response must not navigate to a nonexistent detail."
        )
        assertEqual(
            AIBuildFlowRules.shouldSkipOptionSelection(optionCount: 1),
            true,
            "A single option should skip the redundant selection screen."
        )
        assertEqual(
            AIBuildFlowRules.shouldSkipOptionSelection(optionCount: 2),
            false,
            "Multiple options should remain selectable."
        )
        assertContains(
            contentViewSource,
            "selectedOption = shouldSkipOptionSelection(for: response) ? response.options.first : nil",
            "A single returned option should be selected immediately."
        )
        assertContains(
            contentViewSource,
            "if let response, !shouldSkipOptionSelection(for: response)",
            "The option selection screen should only exist for multiple options."
        )
        assertContains(
            contentViewSource,
            "if shouldSkipOptionSelection(for: response)",
            "Returning from a direct result should clear the response and return to the form."
        )

        print("SingleBuildOptionRoutingRulesTests passed")
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
