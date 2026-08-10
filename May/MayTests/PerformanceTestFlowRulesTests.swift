import Foundation

@main
struct PerformanceTestFlowRulesTests {
    static func main() {
        assertEqual(
            PerformanceTestStep.allCases.map(\.title),
            ["测试内容", "性能结果"],
            "Performance test should use the requested two-page flow."
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
        var flow = PerformanceTestFlow()
        assertEqual(flow.currentStep, .setup, "Performance test should begin with test setup.")
        assertEqual(flow.hardwareProfile, .skipped, "The setup page must not silently use a demo computer.")
        assertEqual(flow.selectedResolution.title, "2K", "Results should default to 2K.")
        assertEqual(flow.selectedGames, [], "The user should explicitly choose at least one game.")
        assertEqual(flow.canSubmit, false, "Hardware and a game are required before querying results.")
        assertEqual(flow.result, nil, "No fixed demo result should exist before a backend response.")
        assertEqual(
            PerformanceHardwarePercentile.overall(
                cpuID: "r9-9950x3d",
                gpuTimeSpyScore: 47_539
            ),
            100,
            "The strongest supported CPU and GPU combination should reach 100 percent."
        )
        assertEqual(
            PerformanceHardwarePercentile.overall(
                cpuID: "r7-9700x",
                gpuTimeSpyScore: 7_502
            ),
            49,
            "Overall performance should weight CPU and GPU relative scores equally."
        )

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
        flow.toggleGame(.cyberpunk)
        assertEqual(flow.canSubmit, true, "Known CPU, GPU, and one game should enable the result action.")
        assertEqual(
            flow.requestInput,
            PerformanceEstimateInput(cpuID: "i7-14700", gpuID: "rtx-5080", resolution: "2k", gameIDs: ["cyberpunk-2077"]),
            "Requests should resolve exact HardwareCatalog IDs instead of sending display names."
        )

        let request = require(flow.beginRequest(), "A valid catalog profile should create a request context.")
        assertEqual(flow.currentStep, .result, "Starting a test should transition to results immediately.")
        assertEqual(flow.loadState, .loading, "Starting a test should show progress.")

        let response = PerformanceEstimatePayload(
            status: .ready,
            averageFPS: 128,
            gpuTimeSpyScore: 33018,
            missingGames: [],
            gameResults: [
                GamePerformanceResult(
                    gameID: "cyberpunk-2077",
                    averageFPS: 128
                )
            ]
        )
        flow.apply(response, for: request)
        assertEqual(flow.loadState, .loaded, "A ready response should show loaded content.")
        assertEqual(flow.result?.resolution, "2K", "Results must retain the resolution captured when the request began.")
        assertEqual(flow.result?.averageFPS, "128 FPS", "Results must use the backend average FPS.")
        assertEqual(flow.result?.gpuTimeSpyScore, 33018, "Results must retain the selected GPU Time Spy score.")
        assertEqual(flow.result?.gameResults, response.gameResults, "Per-game results must retain average FPS only.")

        flow.selectResolution(.fourK)
        assertEqual(flow.loadState, .idle, "An unseen resolution should begin without a result state.")
        let fourKRequest = require(flow.beginRequest(), "Selecting an unseen resolution should create a request.")
        flow.apply(response, for: fourKRequest)
        assertEqual(flow.result?.resolution, "4K", "The selected resolution should show its own result.")
        flow.selectResolution(.twoK)
        assertEqual(flow.result?.resolution, "2K", "Returning to a queried resolution should reuse its cached result.")
        assertEqual(flow.beginRequest(), nil, "A cached result should not trigger a duplicate request.")

        flow.selectResolution(.fullHD)
        let partialRequest = require(flow.beginRequest(), "A new request should be allowed after completion.")
        flow.apply(
            PerformanceEstimatePayload(
                status: .partial,
                averageFPS: 128,
                gpuTimeSpyScore: 33018,
                missingGames: ["cs2"],
                gameResults: response.gameResults
            ),
            for: partialRequest
        )
        assertEqual(flow.loadState, .partial, "Partial backend data should remain visibly partial.")
        assertEqual(flow.result?.missingGameNames, ["CS2"], "Missing canonical IDs should use App game labels.")

        flow.selectResolution(.fourK)
        flow.hardwareProfile.gpu = "RTX 5090"
        let emptyRequest = require(flow.beginRequest(), "A new request should be allowed after partial results.")
        flow.apply(
            PerformanceEstimatePayload(
                status: .needsMoreData,
                averageFPS: nil,
                gpuTimeSpyScore: 47187,
                missingGames: ["cs2"],
                gameResults: []
            ),
            for: emptyRequest
        )
        assertEqual(flow.loadState, .empty, "A response without reliable rows should show no data.")
        assertEqual(flow.result, nil, "No-data responses must not fabricate result values.")

        var failedFlow = PerformanceTestFlow()
        failedFlow.apply(savedProfile)
        failedFlow.toggleGame(.cyberpunk)
        let failedRequest = require(failedFlow.beginRequest(), "A valid uncached request should start.")
        failedFlow.failRequest("网络连接失败", for: failedRequest)
        assertEqual(failedFlow.loadState, .failed("网络连接失败"), "Request failures should preserve a retry message.")
        assertEqual(failedFlow.beginRequest() == nil, false, "A failed request should be retryable.")

        var raceFlow = PerformanceTestFlow()
        raceFlow.apply(savedProfile)
        raceFlow.toggleGame(.cyberpunk)
        raceFlow.selectResolution(.fourK)
        let staleRequest = require(raceFlow.beginRequest(), "The first request should start.")
        raceFlow.cancelRequest()
        raceFlow.selectResolution(.fullHD)
        let activeRequest = require(raceFlow.beginRequest(), "A replacement request should start.")
        raceFlow.apply(response, for: staleRequest)
        assertEqual(raceFlow.loadState, .loading, "A stale completion must not replace the active loading state.")
        assertEqual(raceFlow.result, nil, "A stale completion must not publish a result.")
        raceFlow.apply(response, for: activeRequest)
        assertEqual(raceFlow.result?.resolution, "1080P", "The active result must use its immutable request snapshot.")

        var allGamesFlow = PerformanceTestFlow()
        allGamesFlow.toggleAllGames()
        assertEqual(allGamesFlow.selectedGamesDisplay, "全部 15 款", "The aggregate selection should report the full approved scope.")
        assertEqual(allGamesFlow.isGameSelected(.valorant), true, "All-games selection should mark each visible game selected.")
        allGamesFlow.toggleAllGames()
        assertEqual(allGamesFlow.selectedGames, [], "Clearing all games should leave the setup action disabled.")

        flow.hardwareProfile.cpu = "不知道"
        assertEqual(flow.requestInput, nil, "Unknown exact hardware should stop before any network request.")

        assertAverageOnlySources()

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

    private static func assertAverageOnlySources() {
        let repository = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let paths = [
            "May/Networking/AppAPIClient.swift",
            "May/Models/PerformanceTestFlow.swift",
            "May/Screens/GamePerformanceView.swift"
        ]
        let forbidden = [
            "lowFPS",
            "maximumFPS",
            "confidence",
            "bottleneck",
            "sourceFetchedAt",
            "smoothness"
        ]
        for path in paths {
            let source = try! String(
                contentsOf: repository.appendingPathComponent(path),
                encoding: .utf8
            )
            for term in forbidden {
                assertEqual(
                    source.contains(term),
                    false,
                    "Performance sources must not expose \(term)."
                )
            }
        }
    }
}
