import Foundation

@main
struct UpgradePlanConfigurationRulesTests {
    static func main() {
        var configuration = UpgradePlanConfiguration.sample

        assertEqual(
            UpgradePlanStep.allCases.map(\.title),
            ["当前电脑", "升级目标", "升级方案"],
            "Upgrade advice should use the optimized three-step flow."
        )
        assertEqual(
            UpgradeGoal.selectableCases.map(\.title),
            ["帮我判断短板", "游戏帧率和画质"],
            "Only diagnosis and gaming should remain as selectable upgrade goals."
        )
        assertEqual(configuration.step, .computer, "Upgrade advice should begin with the current computer.")
        assertEqual(configuration.goal, .gaming, "The preview should begin with the selected gaming direction.")
        assertEqual(configuration.selectedGamesDisplay, "CS2  /  PUBG  /  无畏契约", "Selected games should keep the approved display order.")

        configuration.goNext()
        assertEqual(configuration.step, .goal, "The second step should collect the upgrade goal and conditions.")
        configuration.goNext()
        assertEqual(configuration.step, .result, "The third step should show the upgrade plan.")
        configuration.goBack()
        assertEqual(configuration.step, .goal, "Back should return to the goal step.")

        configuration.toggleGame("CS2")
        assertEqual(configuration.selectedGames.contains("CS2"), false, "Games should be removable from the multi-select.")

        assertEqual(
            UpgradePlanConfiguration.categories.map(\.title),
            ["CPU", "显卡", "主板", "内存", "硬盘", "电源"],
            "Upgrade plan should use the same selectable hardware categories as performance testing."
        )

        configuration.setValue("RTX 4070", for: "显卡")
        configuration.setValue("32GB DDR5", for: "内存")

        assertEqual(configuration.value(for: "显卡"), "RTX 4070", "Selecting a GPU should update the upgrade configuration.")
        assertEqual(configuration.value(for: "内存"), "32GB DDR5", "Selecting memory should update the upgrade configuration.")

        let savedProfile = HardwareProfile(
            cpu: "i7-14700",
            gpu: "RTX 5080",
            motherboard: "B860 DS3H",
            memory: "芝奇/海盗船 DDR5-6000 CL30",
            storage: "Western Digital WD Black SN850X",
            powerSupply: "Corsair RM750e"
        )
        configuration.apply(savedProfile)

        assertEqual(configuration.hardwareProfile, savedProfile, "Upgrade plan should apply the complete saved computer profile.")

        print("UpgradePlanConfigurationRulesTests passed")
    }

    private static func assertEqual<T: Equatable>(_ actual: T, _ expected: T, _ message: String) {
        guard actual == expected else {
            fatalError("\(message)\nExpected: \(expected)\nActual: \(actual)")
        }
    }
}
