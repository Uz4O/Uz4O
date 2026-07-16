import Foundation

@main
struct HardwareProfileStoreRulesTests {
    static func main() {
        let suiteName = "HardwareProfileStoreRulesTests"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let store = HardwareProfileStore(defaults: defaults)
        assertEqual(store.load(), .skipped, "A fresh install should begin without a saved computer profile.")

        var profile = HardwareProfile.skipped
        profile.setValue("RTX 5080", for: "显卡")
        profile.setValue("32GB DDR5", for: "内存")
        store.save(profile)

        let restored = store.load()
        assertEqual(restored.gpu, "RTX 5080", "Saved GPU selection should be restored after relaunch.")
        assertEqual(restored.memory, "32GB DDR5", "Saved memory selection should be restored after relaunch.")
        assertEqual(restored.wasSkipped, false, "Selecting a component should mark the profile as recorded.")

        var legacyProfile = HardwareProfile.skipped
        legacyProfile.setValue("ROG STRIX B860-A GAMING WIFI", for: "主板")
        store.save(legacyProfile)
        assertEqual(
            store.load().motherboard,
            "ROG STRIX B860-A GAMING WIFI S吹雪",
            "Saved motherboard names should migrate to the official Chinese catalog name."
        )

        var compatibleProfile = HardwareProfile(
            cpu: "i7-14700",
            gpu: "不知道",
            motherboard: "B760M AORUS ELITE GEN5",
            memory: "不知道",
            storage: "不知道",
            powerSupply: "不知道"
        )
        compatibleProfile.setValue("R7 7800X3D", for: "CPU")
        assertEqual(
            compatibleProfile.motherboard,
            "不知道",
            "Changing CPU should clear a motherboard with an incompatible socket."
        )

        var feedbackProfile = HardwareProfile(
            cpu: "i7-14700",
            gpu: "RTX 4070",
            motherboard: "B760M AORUS ELITE GEN5",
            memory: "不知道",
            storage: "不知道",
            powerSupply: "750W"
        )
        assertEqual(
            feedbackProfile.appliedItemCount,
            4,
            "Applying a saved profile should report how many known components were applied."
        )

        let change = feedbackProfile.updateValue("R7 7800X3D", for: "CPU")
        assertEqual(
            change,
            .motherboardCleared,
            "Changing CPU should report when it clears an incompatible motherboard."
        )

        defaults.removePersistentDomain(forName: suiteName)
        print("HardwareProfileStoreRulesTests passed")
    }

    private static func assertEqual<T: Equatable>(_ actual: T, _ expected: T, _ message: String) {
        guard actual == expected else {
            fatalError("\(message)\nExpected: \(expected)\nActual: \(actual)")
        }
    }
}
