import Foundation

@main
struct UpgradePlanConfigurationRulesTests {
    static func main() throws {
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
        assertEqual(configuration.selectedGamesDisplay, "还没有选择游戏", "Upgrade advice should not preselect games for the user.")
        assertEqual(configuration.hasRequiredGameSelection, false, "Gaming upgrades should require at least one selected game.")
        assertEqual(configuration.frameLimit, nil, "Frame limit should be unavailable until the user selects a game.")
        for game in UpgradePlanConfiguration.games {
            configuration.selectedGames = [game]
            for resolution in UpgradeResolution.allCases {
                configuration.resolution = resolution
                assertTrue(
                    configuration.frameLimit != nil,
                    "Every selectable game should have a reference frame limit for \(resolution.rawValue)."
                )
            }
        }
        configuration.selectedGames = []
        configuration.resolution = .twoK

        configuration.goNext()
        assertEqual(configuration.step, .goal, "The second step should collect the upgrade goal and conditions.")
        configuration.goNext()
        assertEqual(configuration.step, .result, "The third step should show the upgrade plan.")
        configuration.goBack()
        assertEqual(configuration.step, .goal, "Back should return to the goal step.")

        configuration.toggleGame("CS2")
        assertEqual(configuration.selectedGames.contains("CS2"), true, "Games should be addable from the multi-select.")
        assertEqual(configuration.hasRequiredGameSelection, true, "Selecting a game should allow generating a gaming upgrade plan.")
        assertEqual(configuration.frameLimit, 215, "CS2 should use the 2K reference limit from the performance-test model.")
        assertEqual(configuration.frameTargetOptions.last, 215, "Frame-target options should stop at the selected game's integer limit.")

        configuration.resolution = .fourK
        configuration.clampFrameTarget()
        assertEqual(configuration.frameLimit, 120, "CS2 should use a different reference limit at 4K.")
        assertEqual(configuration.frameTarget, 120, "The selected frame target should clamp to the new resolution limit.")

        configuration.resolution = .fullHD
        configuration.clampFrameTarget()
        assertEqual(configuration.frameLimit, 500, "Competitive FPS games should allow a 500 FPS target at 1080P.")
        for game in ["无畏契约", "CS2", "PUBG", "三角洲行动", "使命召唤"] {
            configuration.selectedGames = [game]
            assertEqual(configuration.frameLimit, 500, "\(game) should use the shared 1080P FPS-game limit.")
        }
        configuration.selectedGames = ["CS2"]
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

        configuration.goal = .gaming
        configuration.selectedGames = ["CS2"]
        configuration.resolution = .fourK
        configuration.frameTarget = 120
        let request = configuration.apiRequest
        assertEqual(request.current.cpu, "i7-14700", "Upgrade requests should send the catalog CPU ID.")
        assertEqual(request.current.gpu, "rtx-5080", "Upgrade requests should send the catalog GPU ID.")
        assertEqual(request.current.motherboard, "gigabyte-b860-ds3h", "Upgrade requests should send the catalog motherboard ID.")
        assertEqual(request.current.ram, "ram-6000-cl30", "Upgrade requests should send the catalog RAM ID.")
        assertEqual(request.current.storage, "sn850x", "Upgrade requests should send the catalog storage ID.")
        assertEqual(request.current.psu, "psu-corsair-rm750e", "Upgrade requests should send the catalog PSU ID.")
        assertEqual(request.games, ["cs2"], "Upgrade requests should send canonical game IDs.")
        assertEqual(request.resolution, "4k", "Upgrade requests should send the backend resolution value.")
        assertEqual(request.targetFps, 120, "Upgrade requests should send the selected target FPS.")

        let legacyResponseData = Data(
            #"{"status":"no_plan","summary":"当前预算内暂时没有找到比现有配置更合适、且有人工参考价的升级项。","budget":3000,"total_estimated_price":0,"primary_bottleneck":"gpu","missing_fields":[],"steps":[],"notes":["可以提高预算，或先补充更多已人工确认参考价的硬件数据。"]}"#.utf8
        )
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let legacyResponse = try decoder.decode(UpgradePlanResponseDTO.self, from: legacyResponseData)
        assertEqual(legacyResponse.status, "no_plan", "Legacy upgrade responses should still decode.")
        assertEqual(legacyResponse.resolution, "", "A legacy response should not invent a resolution.")
        assertTrue(legacyResponse.gameResults.isEmpty, "Legacy responses should default missing game results to empty.")

        let currentResponseData = Data(
            #"{"status":"ready","summary":"预算内建议升级。","budget":3000,"total_estimated_price":2200,"primary_bottleneck":"gpu","missing_fields":[],"steps":[],"notes":[],"resolution":"1080p","target_fps":500,"target_met":false,"game_results":[{"game":"cs2","before_fps":320,"after_fps":410,"target_fps":500,"met":false}]}"#.utf8
        )
        let currentResponse = try decoder.decode(UpgradePlanResponseDTO.self, from: currentResponseData)
        assertEqual(currentResponse.resolution, "1080p", "Current responses should preserve the backend resolution.")
        assertEqual(currentResponse.targetFps, 500, "Current responses should decode the target FPS.")
        assertEqual(currentResponse.gameResults.first?.afterFps, 410, "Current responses should decode game results.")

        print("UpgradePlanConfigurationRulesTests passed")
    }

    private static func assertEqual<T: Equatable>(_ actual: T, _ expected: T, _ message: String) {
        guard actual == expected else {
            fatalError("\(message)\nExpected: \(expected)\nActual: \(actual)")
        }
    }

    private static func assertTrue(_ value: Bool, _ message: String) {
        guard value else { fatalError(message) }
    }
}
