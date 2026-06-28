import Foundation

@main
struct LaunchIntroRulesTests {
    static func main() {
        assertEqual(LaunchIntroPage.allCases.count, 4, "Launch intro should contain the four approved pages.")
        assertEqual(LaunchIntroPage.allCases.map(\.title), [
            "AI 装机,从不踩坑。",
            "说出需求,配置自动生成。",
            "商家清单,一眼排雷。",
            "保存方案,随时升级。"
        ], "Launch intro titles should match the approved black-and-white onboarding set.")
        assertEqual(LaunchIntroPage.allCases.last?.buttonTitle, "开始装机", "Final launch intro CTA should enter the app.")
        assertEqual(
            LaunchIntroPage.allCases.map(\.buttonTitle),
            ["继续", "继续", "继续", "开始装机"],
            "Launch intro CTA copy should match the approved image set."
        )

        print("LaunchIntroRulesTests passed")
    }

    private static func assertEqual<T: Equatable>(_ actual: T, _ expected: T, _ message: String) {
        guard actual == expected else {
            fatalError("\(message)\nExpected: \(expected)\nActual: \(actual)")
        }
    }
}
