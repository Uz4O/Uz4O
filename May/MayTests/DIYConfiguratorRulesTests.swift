import Foundation

@main
struct DIYConfiguratorRulesTests {
    static func main() {
        assertEqual(
            DIYConfiguratorLayout.parts.map(\.title),
            ["CPU", "显卡", "主板", "内存", "硬盘", "电源", "散热", "机箱"],
            "DIY builder should preserve the reference design's 4×2 card order."
        )
        assertEqual(
            DIYConfiguratorLayout.parts.filter(\.isSelected).map(\.number),
            ["01", "02", "03"],
            "The static reference state should show only the first three parts as selected."
        )
        print("DIYConfiguratorRulesTests passed")
    }

    private static func assertEqual<T: Equatable>(_ actual: T, _ expected: T, _ message: String) {
        guard actual == expected else {
            fatalError("\(message)\nExpected: \(expected)\nActual: \(actual)")
        }
    }
}
