import Foundation

@main
struct OnboardingProfileRulesTests {
    static func main() {
        assertEqual(
            OnboardingProfile.skipped.homeFeatureOrder.map(\.title),
            ["游戏性能测试", "配置排雷", "升级建议", "装机指南"],
            "Skipped users should see the default home priority."
        )

        let onboardingProfile = OnboardingProfile()
        assertEqual(
            onboardingProfile.homeFeatureOrder.map(\.title),
            ["游戏性能测试", "配置排雷", "升级建议", "装机指南"],
            "Onboarding should keep the default home priority."
        )

        assertEqual(
            onboardingProfile.homeHeroButtonTitle,
            "开始装机",
            "Hero button copy should stay stable."
        )

        assertEqual(
            onboardingProfile.homeHeroSubtitle,
            "智能推荐最佳配置方案",
            "Hero subtitle should keep the original copy."
        )

        let skippedHardwareProfile = OnboardingProfile(hardwareProfile: .skipped)
        assertEqual(
            skippedHardwareProfile.hardwareProfile.wasSkipped,
            true,
            "Existing computer users can skip hardware profile collection before entering the app."
        )

        let completedHardwareProfile = OnboardingProfile(
            hardwareProfile: HardwareProfile(
                cpu: HardwareProfileOptions.cpu[0],
                gpu: HardwareProfileOptions.gpu[1],
                motherboard: HardwareProfileOptions.motherboard[1],
                memory: HardwareProfileOptions.memory[2],
                storage: HardwareProfileOptions.storage[1],
                powerSupply: HardwareProfileOptions.powerSupply[2]
            )
        )
        assertEqual(
            completedHardwareProfile.hardwareProfile.summary,
            "CPU 不知道 · 显卡 RTX 5090 D · 主板 B860 DS3H · 内存 芝奇/海盗船 DDR5-6000 CL30 · DDR5 · 32GB (16GBx2) · 6000MHz · CL30 · 硬盘 Western Digital WD Black SN850X · 1TB · PCIe 4.0 · 电源 Corsair RM750e · 750W · 80+ Gold",
            "Hardware profile summary should preserve user-entered config before entering the app."
        )

        assertEqual(
            completedHardwareProfile.hardwareProfile.completedComponentCount,
            5,
            "Unknown components should not count toward profile completion."
        )

        assertEqual(
            completedHardwareProfile.hardwareProfile.completionLabel,
            "已填写 5/6",
            "Hardware profile should expose a clear completion label."
        )

        assertEqual(
            completedHardwareProfile.hardwareProfile.knownComponentsSummary,
            "显卡 RTX 5090 D · 主板 B860 DS3H · 内存 芝奇/海盗船 DDR5-6000 CL30 · DDR5 · 32GB (16GBx2) · 6000MHz · CL30 · 硬盘 Western Digital WD Black SN850X · 1TB · PCIe 4.0 · 电源 Corsair RM750e · 750W · 80+ Gold",
            "Profile summaries should omit unknown components."
        )

        assertEqual(
            HardwareProfile.skipped.completionLabel,
            "已填写 0/6",
            "Skipped profiles should clearly show that no components are recorded."
        )

        assertEqual(
            completedHardwareProfile.homeFeatureOrder.map(\.title),
            ["游戏性能测试", "配置排雷", "升级建议", "装机指南"],
            "Hardware selections should not change home functions."
        )

        assertEqual(
            HardwareProfileOptions.categories.map(\.title),
            ["CPU", "显卡", "主板", "内存", "硬盘", "电源"],
            "Hardware profile collection should only ask for component configuration."
        )

        assertEqual(
            HardwareProfileOptions.categories.allSatisfy { $0.options.contains("不知道") },
            true,
            "Every hardware selection category should allow the user to choose unknown."
        )

        assertEqual(
            BuildPreference.aiBuildOptions.map(\.title),
            ["性能优先", "颜值优先", "均衡搭配"],
            "AI build preferences should use the requested order and labels."
        )

        assertEqual(
            BuildPreference.defaultAISelection,
            .balanced,
            "AI build preference should default to balanced."
        )

        print("OnboardingProfileRulesTests passed")
    }

    private static func assertEqual<T: Equatable>(_ actual: T, _ expected: T, _ message: String) {
        guard actual == expected else {
            fatalError("\(message)\nExpected: \(expected)\nActual: \(actual)")
        }
    }
}
