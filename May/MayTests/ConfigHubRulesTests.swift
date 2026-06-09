import Foundation

@main
struct ConfigHubRulesTests {
    static func main() {
        assertEqual(
            ConfigHubSection.allCases.map(\.title),
            ["AI 配置", "我的配置"],
            "Config tab should separate AI generated builds from the current computer profile."
        )

        assertEqual(
            ConfigHubSection.aiBuilds.subtitle,
            "保存过的方案都在这里",
            "AI builds section should describe saved generated configs."
        )

        assertEqual(
            ConfigHubSection.currentComputer.subtitle,
            "补充当前电脑，升级建议和配置对比会更准确。",
            "Current computer section should describe the user's existing computer."
        )

        assertEqual(
            ConfigHubSection.defaultSelection,
            .aiBuilds,
            "Config tab should open on AI generated configs first."
        )

        assertEqual(
            ConfigHubListStyle.compactList.primaryActionTitle,
            "查看",
            "Compact config rows should keep a single clear primary action."
        )

        assertEqual(
            ConfigHubListStyle.compactList.showsInlineActionBar,
            false,
            "Compact config rows should not render the old multi-button action bar."
        )

        print("ConfigHubRulesTests passed")
    }

    private static func assertEqual<T: Equatable>(_ actual: T, _ expected: T, _ message: String) {
        guard actual == expected else {
            fatalError("\(message)\nExpected: \(expected)\nActual: \(actual)")
        }
    }
}
