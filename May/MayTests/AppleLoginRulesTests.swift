import Foundation

@main
struct AppleLoginRulesTests {
    static func main() throws {
        let source = try String(
            contentsOfFile: "May/May/Screens/LoginView.swift",
            encoding: .utf8
        )

        assertContains(
            source,
            "appleAuthorizationErrorMessage(error)",
            "Apple authorization failures should use an actionable message."
        )
        assertContains(
            source,
            "targetEnvironment(simulator)",
            "Simulator Apple login failures should explain that a real device is required."
        )
        assertContains(
            source,
            "真实 iPhone 或 TestFlight 测试",
            "Simulator failures need a concrete next step."
        )

        print("AppleLoginRulesTests passed")
    }

    private static func assertContains(_ text: String, _ expectedFragment: String, _ message: String) {
        guard text.contains(expectedFragment) else {
            fatalError("\(message)\nMissing: \(expectedFragment)")
        }
    }
}
