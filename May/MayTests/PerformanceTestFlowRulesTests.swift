import Foundation

@main
struct PerformanceTestFlowRulesTests {
    static func main() {
        assertEqual(
            PerformanceTestStep.allCases.map(\.title),
            ["电脑配置", "测试条件", "性能结果"],
            "Performance test should use the requested three-step flow."
        )

        var flow = PerformanceTestFlow()
        assertEqual(flow.currentStep, .hardware, "Performance test should begin with hardware selection.")
        assertEqual(flow.selectedResolution.title, "2K", "Default resolution should match the current result copy.")
        assertEqual(flow.selectedGames.map(\.name), ["赛博朋克 2077"], "Default game should keep one selected test target.")

        flow.goNext()
        assertEqual(flow.currentStep, .conditions, "Next should move from hardware to test conditions.")

        flow.selectedResolution = .fourK
        flow.toggleGame(.valorant)
        flow.goNext()

        assertEqual(flow.currentStep, .result, "Second next should move to results.")
        assertEqual(flow.result.resolution, "4K", "Result should describe the chosen resolution.")
        assertEqual(flow.result.primaryGame, "赛博朋克 2077", "Result should keep the first selected game as the primary target.")
        assertEqual(flow.result.bottleneck, "显卡", "4K testing should prioritize GPU bottleneck guidance.")

        flow.goPrevious()
        assertEqual(flow.currentStep, .conditions, "Back should return from results to conditions.")

        print("PerformanceTestFlowRulesTests passed")
    }

    private static func assertEqual<T: Equatable>(_ actual: T, _ expected: T, _ message: String) {
        guard actual == expected else {
            fatalError("\(message)\nExpected: \(expected)\nActual: \(actual)")
        }
    }
}
