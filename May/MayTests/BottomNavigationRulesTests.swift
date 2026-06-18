import Foundation

@main
struct BottomNavigationRulesTests {
    static func main() {
        assertEqual(
            AppTab.bottomNavigationTabs,
            [.home, .community, .builds, .profile],
            "Bottom navigation should expose the four main destinations without a center compose item."
        )

        assertEqual(
            AppTab.bottomNavigationTabs.count,
            AppTab.allCases.count,
            "Bottom navigation should not reserve an extra middle slot outside the tab model."
        )

        print("BottomNavigationRulesTests passed")
    }

    private static func assertEqual<T: Equatable>(_ actual: T, _ expected: T, _ message: String) {
        guard actual == expected else {
            fatalError("\(message)\nExpected: \(expected)\nActual: \(actual)")
        }
    }
}
