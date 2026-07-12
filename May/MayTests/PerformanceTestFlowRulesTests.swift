import Foundation

@main
struct PerformanceTestFlowRulesTests {
    static func main() {
        assertEqual(
            PerformanceTestStep.allCases.map(\.title),
            ["电脑配置", "测试条件", "性能结果"],
            "Performance test should use the requested three-step flow."
        )
        assertEqual(PerformanceGame.samples.count, 15, "Only the approved real games should be collected.")
        assertEqual(PerformanceGame.samples.first?.name, "瓦罗兰特", "Game order should match the approved grid.")
        assertEqual(
            PerformanceGame.samples.first(where: { $0.id == "call-of-duty-warzone" })?.name,
            "COD",
            "COD should map to Warzone while keeping the approved App label."
        )
        assertEqual(PerformanceGame.allGames.id, "all-games", "All games should be a separate aggregate selection.")
        assertEqual(
            PerformanceGame.samples.contains(PerformanceGame.allGames),
            false,
            "The aggregate selection must not be included in the 15 collected games."
        )
        assertEqual(PerformanceTestFlow.smoothness(for: 29), "不够流畅", "29 FPS should stay below the basic threshold.")
        assertEqual(PerformanceTestFlow.smoothness(for: 30), "基本流畅", "30 FPS should enter the basic threshold.")
        assertEqual(PerformanceTestFlow.smoothness(for: 59), "基本流畅", "59 FPS should stay below the smooth threshold.")
        assertEqual(PerformanceTestFlow.smoothness(for: 60), "流畅", "60 FPS should enter the smooth threshold.")
        assertEqual(PerformanceTestFlow.smoothness(for: 119), "流畅", "119 FPS should stay below the very smooth threshold.")
        assertEqual(PerformanceTestFlow.smoothness(for: 120), "非常流畅", "120 FPS should enter the very smooth threshold.")

        var flow = PerformanceTestFlow()
        assertEqual(flow.currentStep, .hardware, "Performance test should begin with hardware selection.")
        assertEqual(flow.selectedResolution.title, "2K", "Default resolution should match the current result copy.")
        assertEqual(flow.selectedGames.map(\.id), ["cyberpunk-2077"], "Default game should use its canonical backend ID.")
        assertEqual(flow.result, nil, "No fixed demo result should exist before a backend response.")

        let savedProfile = HardwareProfile(
            cpu: "i7-14700",
            gpu: "RTX 5080",
            motherboard: "B860 DS3H",
            memory: "芝奇/海盗船 DDR5-6000 CL30",
            storage: "Western Digital WD Black SN850X",
            powerSupply: "Corsair RM750e"
        )
        flow.apply(savedProfile)
        assertEqual(flow.hardwareProfile, savedProfile, "Performance test should apply the complete saved computer profile.")
        assertEqual(
            flow.requestInput,
            PerformanceEstimateInput(cpuID: "i7-14700", gpuID: "rtx-5080", resolution: "2k", gameIDs: ["cyberpunk-2077"]),
            "Requests should resolve exact HardwareCatalog IDs instead of sending display names."
        )

        flow.goNext()
        assertEqual(flow.currentStep, .conditions, "Next should move from hardware to test conditions.")
        flow.selectedResolution = .fourK
        flow.toggleGame(.valorant)
        let request = require(flow.beginRequest(), "A valid catalog profile should create a request context.")
        assertEqual(flow.currentStep, .result, "Starting a test should transition to results immediately.")
        assertEqual(flow.loadState, .loading, "Starting a test should show progress.")

        let response = PerformanceEstimatePayload(
            status: .ready,
            averageFPS: 77,
            lowFPS: 66,
            maximumFPS: 89,
            bottleneck: "cpu",
            bottleneckPercent: 11,
            sourceFetchedAt: "2026-07-12T00:00:00Z",
            missingGames: [],
            gameResults: [
                GamePerformanceResult(
                    gameID: "cyberpunk-2077",
                    averageFPS: 77,
                    lowFPS: 66,
                    maximumFPS: 89,
                    bottleneck: "cpu",
                    bottleneckPercent: 11,
                    sourceFetchedAt: "2026-07-12T00:00:00Z"
                )
            ]
        )
        flow.selectedResolution = .fullHD
        flow.apply(response, for: request)
        assertEqual(flow.loadState, .loaded, "A ready response should show loaded content.")
        assertEqual(flow.result?.resolution, "4K", "Results must retain the resolution captured when the request began.")
        assertEqual(flow.result?.averageFPS, "77 FPS", "Results must use backend data.")
        assertEqual(flow.result?.lowFPS, "66 FPS", "Low FPS must use backend data.")
        assertEqual(flow.result?.maximumFPS, "89 FPS", "Maximum FPS must use backend data.")
        assertEqual(flow.result?.smoothness, "流畅", "Smoothness should be derived from the backend average FPS.")
        assertEqual(flow.result?.bottleneck, "CPU 11%", "Bottleneck and percentage must use backend data.")
        assertEqual(flow.result?.sourceFetchedAt, "2026-07-12T00:00:00Z", "Freshness must use backend data.")

        let partialRequest = require(flow.beginRequest(), "A new request should be allowed after completion.")
        flow.apply(
            PerformanceEstimatePayload(
                status: .partial,
                averageFPS: 77,
                lowFPS: 66,
                maximumFPS: 89,
                bottleneck: nil,
                bottleneckPercent: nil,
                sourceFetchedAt: "2026-07-12T00:00:00Z",
                missingGames: ["cs2"],
                gameResults: response.gameResults
            ),
            for: partialRequest
        )
        assertEqual(flow.loadState, .partial, "Partial backend data should remain visibly partial.")
        assertEqual(flow.result?.missingGameNames, ["CS2"], "Missing canonical IDs should use App game labels.")

        let emptyRequest = require(flow.beginRequest(), "A new request should be allowed after partial results.")
        flow.apply(
            PerformanceEstimatePayload(
                status: .needsMoreData,
                averageFPS: nil,
                lowFPS: nil,
                maximumFPS: nil,
                bottleneck: nil,
                bottleneckPercent: nil,
                sourceFetchedAt: nil,
                missingGames: ["cs2"],
                gameResults: []
            ),
            for: emptyRequest
        )
        assertEqual(flow.loadState, .empty, "A response without reliable rows should show no data.")
        assertEqual(flow.result, nil, "No-data responses must not fabricate result values.")

        let failedRequest = require(flow.beginRequest(), "A new request should be allowed after no data.")
        flow.failRequest("网络连接失败", for: failedRequest)
        assertEqual(flow.loadState, .failed("网络连接失败"), "Request failures should preserve a retry message.")

        var raceFlow = PerformanceTestFlow()
        raceFlow.selectedResolution = .fourK
        let staleRequest = require(raceFlow.beginRequest(), "The first request should start.")
        raceFlow.cancelRequest()
        raceFlow.selectedResolution = .fullHD
        let activeRequest = require(raceFlow.beginRequest(), "A replacement request should start.")
        raceFlow.apply(response, for: staleRequest)
        assertEqual(raceFlow.loadState, .loading, "A stale completion must not replace the active loading state.")
        assertEqual(raceFlow.result, nil, "A stale completion must not publish a result.")
        raceFlow.selectedResolution = .twoK
        raceFlow.apply(response, for: activeRequest)
        assertEqual(raceFlow.result?.resolution, "1080P", "The active result must use its immutable request snapshot.")

        var allGamesFlow = PerformanceTestFlow()
        allGamesFlow.toggleGame(.allGames)
        assertEqual(allGamesFlow.selectedGamesDisplay, "全部 15 款", "The aggregate selection should report the full approved scope.")

        flow.hardwareProfile.cpu = "不知道"
        assertEqual(flow.requestInput, nil, "Unknown exact hardware should stop before any network request.")

        print("PerformanceTestFlowRulesTests passed")
    }

    private static func assertEqual<T: Equatable>(_ actual: T, _ expected: T, _ message: String) {
        guard actual == expected else {
            fatalError("\(message)\nExpected: \(expected)\nActual: \(actual)")
        }
    }

    private static func require<T>(_ value: T?, _ message: String) -> T {
        guard let value else { fatalError(message) }
        return value
    }
}
