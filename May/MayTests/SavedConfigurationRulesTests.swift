import Foundation

@main
struct SavedConfigurationRulesTests {
    static func main() throws {
        let plan = SavedConfigurationPlanDTO(
            version: 1,
            kind: .ai,
            name: "高帧率游戏配置",
            budget: "¥ 8,000",
            totalPrice: "¥ 8,166",
            useCase: "优先保证高帧率游戏体验",
            createdAt: "参考价日期 2026-08-25",
            parts: [
                SavedConfigurationPartDTO(
                    category: "CPU",
                    model: "Intel Core i5-14600K",
                    price: "¥ 1,499",
                    condition: "全新"
                )
            ],
            usedGPUAlternative: nil,
            cpuPlatformAlternative: SavedConfigurationCPUPlatformAlternativeDTO(
                replacementParts: [
                    SavedConfigurationCPUPlatformReplacementDTO(
                        componentID: "i5-14600kf",
                        category: "CPU",
                        model: "i5-14600KF",
                        referencePrice: 1499,
                        condition: "全新"
                    )
                ],
                priceDifference: 899,
                performanceGainPercent: 40
            ),
            performanceContext: SavedConfigurationPerformanceContextDTO(
                cpuID: "i5-14600k",
                gpuID: "rtx-5070",
                gameIDs: ["cs2"],
                unavailableGameNames: []
            )
        )

        assertEqual(plan.numericBudget, 8000, "Cloud saves should retain a numeric budget.")
        assertEqual(plan.numericTotalPrice, 8166, "Cloud saves should retain a numeric total price.")

        let encodedPlan = try JSONEncoder().encode(plan)
        let decodedPlan = try JSONDecoder().decode(SavedConfigurationPlanDTO.self, from: encodedPlan)
        assertEqual(decodedPlan, plan, "Saved configuration snapshots must round-trip without losing parts.")

        let request = SaveConfigurationRequestDTO(
            title: plan.name,
            plan: plan,
            budget: plan.numericBudget,
            totalPrice: plan.numericTotalPrice,
            useCase: plan.kind.useCase
        )
        let requestObject = try JSONSerialization.jsonObject(with: JSONEncoder().encode(request)) as! [String: Any]
        assertEqual(requestObject["use_case"] as? String, "AI装机", "Saved builds must use a filterable cloud kind.")
        assertEqual(requestObject["total_price"] as? Int, 8166, "Saved builds must send the backend total_price contract.")

        let myBuildsSource = try String(contentsOfFile: "May/May/Screens/MyBuildsView.swift", encoding: .utf8)
        let contentSource = try String(contentsOfFile: "May/May/ContentView.swift", encoding: .utf8)
        let diySource = try String(contentsOfFile: "May/May/Screens/DIYView.swift", encoding: .utf8)
        assertNotContains(myBuildsSource, "AppMockData.savedPlans", "My builds must never show demo configurations.")
        assertContains(myBuildsSource, "deleteSavedBuild", "Every cloud configuration must have a delete path.")
        assertContains(contentSource, "case savedBuild(SavedConfigurationDTO)", "Opening a row must carry the exact selected build.")
        assertContains(contentSource, "DIYBuildStore.clear()", "Account deletion must clear legacy local DIY data.")
        assertContains(diySource, "SavedConfigurationPlanDTO(kind: .diy", "DIY saves must use the cloud configuration contract.")

        print("SavedConfigurationRulesTests passed")
    }

    private static func assertEqual<T: Equatable>(_ actual: T, _ expected: T, _ message: String) {
        guard actual == expected else {
            fatalError("\(message)\nExpected: \(expected)\nActual: \(actual)")
        }
    }

    private static func assertContains(_ text: String, _ fragment: String, _ message: String) {
        guard text.contains(fragment) else {
            fatalError("\(message)\nMissing: \(fragment)")
        }
    }

    private static func assertNotContains(_ text: String, _ fragment: String, _ message: String) {
        guard !text.contains(fragment) else {
            fatalError("\(message)\nUnexpected: \(fragment)")
        }
    }
}
