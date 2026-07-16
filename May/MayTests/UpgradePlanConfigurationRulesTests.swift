import Foundation

@main
struct UpgradePlanConfigurationRulesTests {
    static func main() {
        var configuration = UpgradePlanConfiguration.sample

        assertEqual(
            UpgradePlanConfiguration.categories.map(\.title),
            ["CPU", "显卡", "主板", "内存", "硬盘", "电源"],
            "Upgrade plan should use the same selectable hardware categories as performance testing."
        )
        assertEqual(
            HardwareCatalog.motherboardOptions.contains(configuration.hardwareProfile.motherboard),
            true,
            "Upgrade plan sample should use the shared motherboard catalog."
        )
        assertEqual(
            HardwareCatalog.areCompatible(
                cpu: configuration.hardwareProfile.cpu,
                motherboard: configuration.hardwareProfile.motherboard
            ),
            true,
            "Upgrade plan sample CPU and motherboard should be compatible."
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
