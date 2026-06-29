import Foundation

@main
struct GuideFlowRulesTests {
    static func main() {
        assertEqual(GuideFlow.componentIntroItems.count, 8, "Guide should keep the eight main hardware parts.")
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

        assertEqual(GuideFlow.guideSections.map(\.id), ["troubleshooting", "faq", "preparation"], "Guide should expose the three requested full-page entries.")
        assertEqual(GuideFlow.guideSections.map(\.title), ["点不亮排查助手", "常见问题答疑解惑", "装机前需准备和了解的事"], "Guide entries should use the requested titles.")
        assertEqual(GuideFlow.guideSections.allSatisfy { !$0.items.isEmpty }, true, "Each guide entry should include readable starter content.")
        assertEqual(GuideFlow.featuredGuideHomeEntry.id, "troubleshooting", "Guide home should feature the no-boot troubleshooting assistant first.")
        assertEqual(GuideFlow.secondaryGuideHomeEntries.map(\.id), ["components", "preparation", "faq"], "Guide home should put the remaining three entries under the featured card.")
        assertEqual(GuideFlow.secondaryGuideHomeEntries.map(\.title), ["电脑八大件展示", "装机前需准备和了解的事", "常见问题答疑解惑"], "Guide home should keep the three lower functions in the reference order.")
        assertEqual(GuideFlow.noBootChecklistScenarios.count, 2, "No-boot assistant should split the two common failure states.")
        assertEqual(
            GuideFlow.noBootChecklistScenarios.map(\.title),
            ["显示器不亮，主机亮着", "显示器和主机都不亮"],
            "No-boot scenarios should match the approved checklist entry choices."
        )
        assertEqual(
            GuideFlow.noBootChecklistScenarios.allSatisfy { $0.subtitle.contains("AI") == false },
            true,
            "No-boot checklist copy should not imply AI involvement."
        )
        assertEqual(
            GuideFlow.noBootChecklistScenarios.map { $0.steps.count },
            [7, 7],
            "Each no-boot scenario should start with seven ordered checklist steps."
        )
        assertEqual(
            GuideFlow.noBootChecklistScenarios[0].steps.first?.title,
            "显示器是否通电",
            "Display-on-host-on path should start with monitor power."
        )
        assertEqual(
            GuideFlow.noBootChecklistScenarios[0].steps.last?.title,
            "查看主板故障灯或蜂鸣提示",
            "Display-on-host-on path should end with board diagnostic indicators."
        )
        assertEqual(
            GuideFlow.noBootChecklistScenarios[1].steps.first?.title,
            "插排和墙插是否有电",
            "All-dark path should start with wall power."
        )
        assertEqual(
            GuideFlow.noBootChecklistScenarios[1].steps.last?.title,
            "最小化启动，排除短路",
            "All-dark path should end with a minimal boot check."
        )

        print("GuideFlowRulesTests passed")
    }

    private static func assertEqual<T: Equatable>(_ actual: T, _ expected: T, _ message: String) {
        guard actual == expected else {
            fatalError("\(message)\nExpected: \(expected)\nActual: \(actual)")
        }
    }
}
