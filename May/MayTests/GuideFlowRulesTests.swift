import Foundation

@main
struct GuideFlowRulesTests {
    static func main() {
        assertEqual(GuideFlow.componentIntroItems.count, 8, "Guide should introduce the main hardware parts before assembly.")
        assertEqual(GuideFlow.componentIntroItems.first?.title, "CPU", "Guide should begin the intro with CPU.")
        assertEqual(GuideFlow.componentIntroItems.first?.imageName, "GuidePartCPU", "Guide intro items should point to real image assets.")
        assertEqual(GuideFlow.componentIntroItems.first { $0.id == "cpu" }?.modelName, "desktop-cpu-mobile", "CPU intro should point to its 3D model resource.")
        assertEqual(GuideFlow.componentIntroItems.first { $0.id == "gpu" }?.modelName, "dual-fan-gpu-mobile", "GPU intro should point to its 3D model resource.")
        assertEqual(GuideFlow.componentIntroItems.first { $0.id == "board" }?.modelName, "modern-atx-motherboard-mobile", "Board intro should point to its 3D model resource.")
        assertEqual(GuideFlow.componentIntroItems.first { $0.id == "memory" }?.modelName, "desktop-dimm-ram-mobile", "Memory intro should point to its 3D model resource.")
        assertEqual(GuideFlow.componentIntroItems.first { $0.id == "ssd" }?.modelName, "m2-2280-nvme-ssd-mobile", "SSD intro should point to its 3D model resource.")
        assertEqual(GuideFlow.componentIntroItems.first { $0.id == "psu" }?.modelName, "atx-psu-mobile", "PSU intro should point to its 3D model resource.")
        assertEqual(GuideFlow.componentIntroItems.first { $0.id == "cooler" }?.modelName, "tower-cpu-air-cooler-mobile", "Cooler intro should point to its 3D model resource.")

        for item in GuideFlow.componentIntroItems {
            assertEqual(item.detailPoints.count, 2, "\(item.title) should explain appearance and install position.")
            assertEqual(item.detailPoints.map(\.title), ["外观识别", "安装位置"], "\(item.title) should omit role copy from the intro card.")
        }

        assertEqual(GuideFlow.steps.count, 10, "Guide should expose 10 jumpable steps after removing preparation.")
        assertEqual(GuideFlow.steps.first?.title, "安装 CPU", "Formal assembly should begin with CPU installation.")
        assertEqual(GuideFlow.cpuInstallPhases.count, 5, "CPU guide animation should show five focused AM5 install phases.")
        assertEqual(GuideFlow.cpuInstallPhases.map(\.title), ["摆正主板", "抬起拉杆", "打开压框", "对准三角", "轻放并锁紧"], "CPU guide animation should match the AM5 video install order without a separate plastic cover step.")
        assertEqual(GuideFlow.cpuInstallModelNames, ["modern-atx-motherboard-mobile", "desktop-cpu-mobile"], "CPU install animation should use the real motherboard and CPU 3D model resources.")
        assertEqual(GuideFlow.cpuInstallAnimatedBoardNodeNames, ["MB_CPU_Load_Lever", "MB_CPU_Lever_Handle", "MB_CPU_Metal_Frame_Top", "MB_CPU_Metal_Frame_Bottom", "MB_CPU_Metal_Frame_Left", "MB_CPU_Metal_Frame_Right"], "CPU install animation should animate the motherboard model's own AM5 latch and load-frame nodes.")
        assertEqual(GuideFlow.cpuInstallAnchorName, "cpuSocketInstallAnchor", "CPU install should align the CPU substrate bottom-center baseline to a socket install anchor.")
        assertEqual(GuideFlow.cpuInstallResetScenePhaseIndex, GuideFlow.cpuInstallPhases.count, "CPU install loop should use a hidden scene-only reset phase after the final teaching phase.")
        assertEqual(GuideFlow.memoryInstallPhases.count, 5, "Memory guide animation should show five focused install phases.")
        assertEqual(GuideFlow.memoryInstallPhases.map(\.title), ["打开卡扣", "查看防呆口", "对齐插槽", "安装两条内存", "下压回弹"], "Memory guide animation should separately teach notch alignment, then combine pressing and latch rebound.")
        assertEqual(GuideFlow.memoryInstallModelNames, ["modern-atx-motherboard-mobile", "desktop-cpu-mobile", "desktop-dimm-ram-mobile"], "Memory install animation should keep the CPU installed from the previous step while using real motherboard and DIMM model resources.")
        assertEqual(GuideFlow.memoryInstallAnchorNames, ["dimmSlotA2InstallAnchor", "dimmSlotB2InstallAnchor"], "Memory install should align each DIMM contact-bottom baseline to named slot install anchors.")
        assertEqual(GuideFlow.memoryInstallAnimatedBoardNodeNames, ["MB_RAM_Top_Latch_2", "MB_RAM_Top_Latch_Lever_2", "MB_RAM_Top_Latch_Hook_2", "MB_RAM_Top_Latch_Notch_2", "MB_RAM_Bottom_Latch_2", "MB_RAM_Bottom_Latch_Lever_2", "MB_RAM_Bottom_Latch_Hook_2", "MB_RAM_Bottom_Latch_Notch_2", "MB_RAM_Top_Latch_4", "MB_RAM_Top_Latch_Lever_4", "MB_RAM_Top_Latch_Hook_4", "MB_RAM_Top_Latch_Notch_4", "MB_RAM_Bottom_Latch_4", "MB_RAM_Bottom_Latch_Lever_4", "MB_RAM_Bottom_Latch_Hook_4", "MB_RAM_Bottom_Latch_Notch_4"], "Memory install animation should animate the motherboard model's own RAM latch nodes for slots 2 and 4.")
        assertEqual(GuideFlow.ssdInstallPhases.count, 5, "SSD guide animation should show five focused install phases.")
        assertEqual(GuideFlow.ssdInstallPhases.map(\.title), ["拆下散热片", "对齐缺口", "斜插 SSD", "压平固定", "装回散热片"], "SSD guide animation should teach heatsink removal, notch alignment, angled insertion, screw fixing, and heatsink reinstall.")
        assertEqual(GuideFlow.ssdInstallModelNames, ["modern-atx-motherboard-mobile", "desktop-cpu-mobile", "desktop-dimm-ram-mobile", "m2-2280-nvme-ssd-mobile"], "SSD install animation should keep CPU and memory installed while using real motherboard and M.2 SSD model resources.")
        assertEqual(GuideFlow.ssdInstallAnchorName, "m2SlotInstallAnchor", "SSD install should align the SSD gold-finger baseline to a named M.2 slot install anchor.")
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
