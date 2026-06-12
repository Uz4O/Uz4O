import Foundation

@main
struct GuideFlowRulesTests {
    static func main() {
        assertEqual(GuideFlow.componentIntroItems.count, 8, "Guide should introduce the main hardware parts before assembly.")
        assertEqual(GuideFlow.componentIntroItems.first?.title, "CPU", "Guide should begin the intro with CPU.")
        assertEqual(GuideFlow.componentIntroItems.first?.imageName, "GuidePartCPU", "Guide intro items should point to real image assets.")

        for item in GuideFlow.componentIntroItems {
            assertEqual(item.detailPoints.count, 2, "\(item.title) should explain appearance and install position.")
            assertEqual(item.detailPoints.map(\.title), ["外观识别", "安装位置"], "\(item.title) should omit role copy from the intro card.")
        }

        assertEqual(GuideFlow.steps.count, 10, "Guide should expose 10 jumpable steps after removing preparation.")
        assertEqual(GuideFlow.steps.first?.title, "安装 CPU", "Formal assembly should begin with CPU installation.")
        assertEqual(GuideFlow.cpuInstallPhases.count, 4, "CPU guide animation should show four focused install phases.")
        assertEqual(GuideFlow.cpuInstallPhases.map(\.title), ["打开扣具", "对准三角", "轻放 CPU", "压回扣具"], "CPU guide animation should match the video install order.")
        assertEqual(GuideFlow.memoryInstallPhases.count, 5, "Memory guide animation should show five focused install phases.")
        assertEqual(GuideFlow.memoryInstallPhases.map(\.title), ["打开卡扣", "查看防呆口", "对齐插槽", "安装两条内存", "下压回弹"], "Memory guide animation should separately teach notch alignment, then combine pressing and latch rebound.")
        assertEqual(GuideFlow.ssdInstallPhases.count, 5, "SSD guide animation should show five focused install phases.")
        assertEqual(GuideFlow.ssdInstallPhases.map(\.title), ["拆下散热片", "对齐缺口", "斜插 SSD", "压平固定", "装回散热片"], "SSD guide animation should teach heatsink removal, notch alignment, angled insertion, screw fixing, and heatsink reinstall.")
        assertEqual(GuideFlow.steps[1].action.contains("2/4 槽位"), true, "Memory install copy should say to prefer slots 2 and 4.")

        var flow = GuideFlow()
        assertEqual(flow.isShowingComponentIntro, true, "Guide should begin with the component intro page.")

        flow.startAssembly()
        assertEqual(flow.isShowingComponentIntro, false, "Starting assembly should leave the component intro page.")
        assertEqual(flow.currentStep.number, 1, "Guide should begin at the first step.")

        flow.goNext()
        assertEqual(flow.currentStep.number, 2, "Next should advance by one step.")

        flow.goPrevious()
        assertEqual(flow.currentStep.number, 1, "Previous should return by one step.")

        flow.goPrevious()
        assertEqual(flow.currentStep.number, 1, "Previous should stop at the first step.")

        flow.jump(to: 8)
        assertEqual(flow.currentStep.number, 9, "Jump should move to the selected step index.")
        assertEqual(flow.progressFraction, 8.0 / 9.0, "Progress fraction should describe the selected step on the full track.")

        flow.jump(to: 99)
        assertEqual(flow.currentStep.number, 9, "Invalid jumps should not change the current step.")

        flow.showComponentIntro()
        assertEqual(flow.isShowingComponentIntro, true, "Back from assembly should return to the component intro page first.")
        assertEqual(flow.currentStep.number, 1, "Back from assembly should reset assembly to the first step.")

        flow.startAssembly()
        assertEqual(flow.isShowingComponentIntro, false, "Guide should allow restarting assembly after returning to the intro.")

        flow.showComponentIntro()
        assertEqual(flow.isShowingComponentIntro, true, "Guide should allow returning to the component intro page.")
        assertEqual(flow.currentStep.number, 1, "Returning to the intro should reset assembly to the first step.")

        print("GuideFlowRulesTests passed")
    }

    private static func assertEqual<T: Equatable>(_ actual: T, _ expected: T, _ message: String) {
        guard actual == expected else {
            fatalError("\(message)\nExpected: \(expected)\nActual: \(actual)")
        }
    }
}
