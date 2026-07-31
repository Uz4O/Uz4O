import Foundation

@main
struct BuildResultRoutingRulesTests {
    static func main() {
        assertEqual(
            BuildResultReturnTarget.fromConfigTab.destination,
            .profile,
            "Build detail opened from configuration management should return to the profile."
        )

        assertEqual(
            BuildResultReturnTarget.fromAIBuild.destination,
            .home,
            "Build detail opened after AI generation should keep returning to home."
        )

        assertEqual(
            BuildResultReturnTarget.fromConfigAIBuild.destination,
            .profile,
            "AI generation opened from the current computer config section should return to the profile."
        )

        print("BuildResultRoutingRulesTests passed")
    }

    private static func assertEqual<T: Equatable>(_ actual: T, _ expected: T, _ message: String) {
        guard actual == expected else {
            fatalError("\(message)\nExpected: \(expected)\nActual: \(actual)")
        }
    }
}
