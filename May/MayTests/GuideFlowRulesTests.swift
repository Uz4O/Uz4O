import Foundation

@main
struct GuideFlowRulesTests {
    static func main() {
        assertEqual(GuideFlow.steps.count, 11, "Guide should expose 11 jumpable steps.")

        var flow = GuideFlow()
        assertEqual(flow.currentStep.number, 1, "Guide should begin at the first step.")

        flow.goNext()
        assertEqual(flow.currentStep.number, 2, "Next should advance by one step.")

        flow.goPrevious()
        assertEqual(flow.currentStep.number, 1, "Previous should return by one step.")

        flow.goPrevious()
        assertEqual(flow.currentStep.number, 1, "Previous should stop at the first step.")

        flow.jump(to: 8)
        assertEqual(flow.currentStep.number, 9, "Jump should move to the selected step index.")
        assertEqual(flow.progressFraction, 0.8, "Progress fraction should describe the selected step on the full track.")

        flow.jump(to: 99)
        assertEqual(flow.currentStep.number, 9, "Invalid jumps should not change the current step.")

        print("GuideFlowRulesTests passed")
    }

    private static func assertEqual<T: Equatable>(_ actual: T, _ expected: T, _ message: String) {
        guard actual == expected else {
            fatalError("\(message)\nExpected: \(expected)\nActual: \(actual)")
        }
    }
}
