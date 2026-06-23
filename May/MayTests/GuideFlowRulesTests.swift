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
        assertEqual(GuideFlow.guideHomeEntries.map(\.id), ["troubleshooting", "components", "preparation", "faq"], "Guide home should arrange four equal entries in the chosen 2x2 order.")
        assertEqual(GuideFlow.guideHomeEntries.map(\.title), ["点不亮排查助手", "电脑八大件展示", "装机前需准备和了解的事", "常见问题答疑解惑"], "Guide home should include the component showcase as a first-class entry.")

        print("GuideFlowRulesTests passed")
    }

    private static func assertEqual<T: Equatable>(_ actual: T, _ expected: T, _ message: String) {
        guard actual == expected else {
            fatalError("\(message)\nExpected: \(expected)\nActual: \(actual)")
        }
    }
}
