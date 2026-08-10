import Foundation

enum PerformanceTestStep: Int, CaseIterable {
    case setup
    case result

    var title: String {
        switch self {
        case .setup: "测试内容"
        case .result: "性能结果"
        }
    }
}

enum PerformanceResolution: String, CaseIterable, Identifiable, Hashable {
    case fullHD
    case twoK
    case fourK

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fullHD: "1080P"
        case .twoK: "2K"
        case .fourK: "4K"
        }
    }

    var apiValue: String {
        switch self {
        case .fullHD: "1080p"
        case .twoK: "2k"
        case .fourK: "4k"
        }
    }

    var subtitle: String {
        switch self {
        case .fullHD: "主流高刷显示器"
        case .twoK: "画质和帧率平衡"
        case .fourK: "更吃显卡性能"
        }
    }
}

struct PerformanceGame: Equatable, Identifiable {
    let id: String
    let name: String
    let mark: String

    static let allGames = PerformanceGame(id: "all-games", name: "什么都玩", mark: "全部")
    static let valorant = PerformanceGame(id: "valorant", name: "瓦罗兰特", mark: "V")
    static let cyberpunk = PerformanceGame(id: "cyberpunk-2077", name: "赛博朋克2077", mark: "2077")

    static let samples = [
        valorant,
        PerformanceGame(id: "cs2", name: "CS2", mark: "CS"),
        PerformanceGame(id: "pubg", name: "PUBG", mark: "PUBG"),
        PerformanceGame(id: "delta-force", name: "三角洲行动", mark: "三角洲"),
        PerformanceGame(id: "teamfight-tactics", name: "云顶之弈", mark: "云顶"),
        PerformanceGame(id: "league-of-legends", name: "LOL", mark: "LOL"),
        PerformanceGame(id: "call-of-duty-warzone", name: "COD", mark: "COD"),
        cyberpunk,
        PerformanceGame(id: "red-dead-redemption-2", name: "荒野大镖客2", mark: "RDR2"),
        PerformanceGame(id: "gta-v", name: "GTA5", mark: "GTA"),
        PerformanceGame(id: "black-myth-wukong", name: "黑神话悟空", mark: "悟空"),
        PerformanceGame(id: "forza-horizon-6", name: "地平线6", mark: "FH6"),
        PerformanceGame(id: "elden-ring", name: "艾尔登法环", mark: "环"),
        PerformanceGame(id: "cities-skylines", name: "城市天际线", mark: "城市"),
        PerformanceGame(id: "minecraft-java-edition", name: "我的世界", mark: "MC")
    ]

    static func name(for id: String) -> String {
        ([allGames] + samples).first(where: { $0.id == id })?.name ?? id
    }
}

enum PerformanceEstimateStatus: String, Equatable {
    case ready
    case partial
    case needsMoreData = "needs_more_data"
}

struct GamePerformanceResult: Equatable {
    let gameID: String
    let averageFPS: Int
}

struct PerformanceEstimatePayload: Equatable {
    let status: PerformanceEstimateStatus
    let averageFPS: Int?
    let gpuTimeSpyScore: Int?
    let missingGames: [String]
    let gameResults: [GamePerformanceResult]
}

struct PerformanceEstimateInput: Equatable {
    let cpuID: String
    let gpuID: String
    let resolution: String
    let gameIDs: [String]
}

struct PerformanceRequestContext: Equatable {
    let token: Int
    let input: PerformanceEstimateInput
    let resolution: PerformanceResolution
    let resolutionTitle: String
}

enum PerformanceHardwarePercentile {
    private static let strongestGPUTimeSpyScore = 47_539

    static func overall(cpuID: String, gpuTimeSpyScore: Int) -> Int? {
        guard
            let cpuScore = cpuPerformanceScore(cpuID),
            let strongestCPUScore = HardwareCatalog.cpus
                .compactMap({ cpuPerformanceScore($0.id) })
                .max()
        else { return nil }

        let cpuRatio = min(max(Double(cpuScore) / Double(strongestCPUScore), 0), 1)
        let gpuRatio = min(
            max(Double(gpuTimeSpyScore) / Double(strongestGPUTimeSpyScore), 0),
            1
        )
        return Int((((cpuRatio + gpuRatio) / 2) * 100).rounded())
    }

    private static func cpuPerformanceScore(_ cpuID: String) -> Int? {
        let components = cpuID.lowercased().split(separator: "-").map(String.init)
        guard components.count >= 2 else { return nil }

        let family = components[0]
        let modelText = components[1]
        guard let model = leadingNumber(in: modelText) else { return nil }

        if family.hasPrefix("u"), let tier = Int(family.dropFirst()) {
            let base = [5: 82, 7: 92, 9: 100][tier]
            guard let base else { return nil }
            let suffixBonus = modelText.hasSuffix("k") ? 4 : 0
            return base + suffixBonus + max((model - 235) / 10, 0)
        }

        if family.hasPrefix("i"), let tier = Int(family.dropFirst()) {
            let base = [3: 36, 5: 64, 7: 76, 9: 90][tier]
            guard let base else { return nil }
            let generation = model / 1_000
            let generationBonus = max(generation - 10, 0) * 4
            let suffixBonus = modelText.hasSuffix("k")
                || modelText.hasSuffix("kf")
                || modelText.hasSuffix("ks")
                ? 4
                : 0
            let fPenalty = modelText.hasSuffix("f") ? -1 : 0
            return base + generationBonus + suffixBonus + fPenalty
        }

        if family.hasPrefix("r"), let tier = Int(family.dropFirst()) {
            let base = [5: 56, 7: 74, 9: 88][tier]
            guard let base else { return nil }
            let series = model / 1_000
            let seriesBonus = max(series - 5, 0) * 5
            let xBonus = modelText.contains("x") ? 4 : 0
            let x3DBonus = modelText.contains("x3d") ? 7 : 0
            return base + seriesBonus + xBonus + x3DBonus
        }

        return nil
    }

    private static func leadingNumber(in value: String) -> Int? {
        Int(value.prefix(while: { $0.isNumber }))
    }
}

enum PerformanceLoadState: Equatable {
    case idle
    case loading
    case loaded
    case partial
    case empty
    case failed(String)
}

struct PerformanceTestResult: Equatable {
    let resolution: String
    let averageFPS: String
    let gpuTimeSpyScore: Int?
    let missingGameNames: [String]
    let gameResults: [GamePerformanceResult]
}

private struct CachedPerformanceState: Equatable {
    var input: PerformanceEstimateInput?
    var loadState: PerformanceLoadState = .idle
    var result: PerformanceTestResult?
}

struct PerformanceTestFlow: Equatable {
    var currentStep: PerformanceTestStep = .setup
    var hardwareProfile: HardwareProfile = .skipped
    var selectedResolution: PerformanceResolution = .twoK
    var selectedGames: [PerformanceGame] = []
    private var cachedStates: [PerformanceResolution: CachedPerformanceState] = [:]
    private var requestGeneration = 0
    private var activeRequestToken: Int?
    private var activeRequestResolution: PerformanceResolution?

    var loadState: PerformanceLoadState {
        cachedStates[selectedResolution]?.loadState ?? .idle
    }

    var result: PerformanceTestResult? {
        cachedStates[selectedResolution]?.result
    }

    var requestInput: PerformanceEstimateInput? {
        guard
            let cpuID = HardwareCatalog.cpus.first(where: { $0.name == hardwareProfile.cpu })?.id,
            let gpuID = HardwareCatalog.gpus.first(where: { $0.name == hardwareProfile.gpu })?.id
        else { return nil }

        return PerformanceEstimateInput(
            cpuID: cpuID,
            gpuID: gpuID,
            resolution: selectedResolution.apiValue,
            gameIDs: selectedGames.map(\.id)
        )
    }

    var selectedGamesDisplay: String {
        areAllGamesSelected ? "全部 \(PerformanceGame.samples.count) 款" : "\(selectedGames.count) 款"
    }

    var selectedGameCount: Int {
        areAllGamesSelected ? PerformanceGame.samples.count : selectedGames.count
    }

    var areAllGamesSelected: Bool {
        selectedGames == [.allGames]
            || PerformanceGame.samples.allSatisfy { selectedGames.contains($0) }
    }

    var canSubmit: Bool {
        !selectedGames.isEmpty && requestInput != nil
    }

    mutating func goNext() {
        guard let next = PerformanceTestStep(rawValue: currentStep.rawValue + 1) else { return }
        currentStep = next
    }

    mutating func goPrevious() {
        guard let previous = PerformanceTestStep(rawValue: currentStep.rawValue - 1) else { return }
        currentStep = previous
    }

    mutating func apply(_ profile: HardwareProfile) {
        hardwareProfile = profile
    }

    mutating func applySavedHardwareIfNeeded(_ profile: HardwareProfile) {
        guard
            hardwareProfile.cpu == "不知道",
            hardwareProfile.gpu == "不知道",
            profile.cpu != "不知道",
            profile.gpu != "不知道"
        else { return }
        hardwareProfile.cpu = profile.cpu
        hardwareProfile.gpu = profile.gpu
    }

    func isGameSelected(_ game: PerformanceGame) -> Bool {
        areAllGamesSelected || selectedGames.contains(game)
    }

    mutating func toggleGame(_ game: PerformanceGame) {
        if areAllGamesSelected {
            selectedGames = PerformanceGame.samples.filter { $0 != game }
        } else if selectedGames.contains(game) {
            selectedGames.removeAll { $0 == game }
        } else {
            selectedGames.append(game)
        }
    }

    mutating func toggleAllGames() {
        selectedGames = areAllGamesSelected ? [] : [.allGames]
    }

    mutating func selectResolution(_ resolution: PerformanceResolution) {
        selectedResolution = resolution
    }

    mutating func beginRequest(advanceToResult: Bool = true) -> PerformanceRequestContext? {
        if advanceToResult {
            currentStep = .result
        }
        guard let input = requestInput else {
            activeRequestToken = nil
            activeRequestResolution = nil
            cachedStates[selectedResolution] = CachedPerformanceState(loadState: .empty)
            return nil
        }

        let existingState = cachedStates[selectedResolution]
        if existingState?.input == input {
            switch existingState?.loadState {
            case .loading, .loaded, .partial, .empty:
                return nil
            case .idle, .failed, .none:
                break
            }
        }

        requestGeneration += 1
        activeRequestToken = requestGeneration
        activeRequestResolution = selectedResolution
        cachedStates[selectedResolution] = CachedPerformanceState(
            input: input,
            loadState: .loading,
            result: nil
        )
        return PerformanceRequestContext(
            token: requestGeneration,
            input: input,
            resolution: selectedResolution,
            resolutionTitle: selectedResolution.title
        )
    }

    mutating func apply(_ payload: PerformanceEstimatePayload, for request: PerformanceRequestContext) {
        guard activeRequestToken == request.token else { return }
        activeRequestToken = nil
        activeRequestResolution = nil
        guard
            payload.status != .needsMoreData,
            let averageFPS = payload.averageFPS
        else {
            cachedStates[request.resolution] = CachedPerformanceState(
                input: request.input,
                loadState: .empty,
                result: nil
            )
            return
        }

        cachedStates[request.resolution] = CachedPerformanceState(
            input: request.input,
            loadState: payload.status == .partial ? .partial : .loaded,
            result: PerformanceTestResult(
                resolution: request.resolutionTitle,
                averageFPS: "\(averageFPS) FPS",
                gpuTimeSpyScore: payload.gpuTimeSpyScore,
                missingGameNames: payload.missingGames.map { PerformanceGame.name(for: $0) },
                gameResults: payload.gameResults
            )
        )
    }

    mutating func failRequest(_ message: String, for request: PerformanceRequestContext) {
        guard activeRequestToken == request.token else { return }
        activeRequestToken = nil
        activeRequestResolution = nil
        cachedStates[request.resolution] = CachedPerformanceState(
            input: request.input,
            loadState: .failed(message),
            result: nil
        )
    }

    mutating func cancelRequest() {
        if
            let resolution = activeRequestResolution,
            cachedStates[resolution]?.loadState == .loading
        {
            cachedStates[resolution]?.loadState = .idle
            cachedStates[resolution]?.result = nil
        }
        activeRequestToken = nil
        activeRequestResolution = nil
    }

    mutating func reset() {
        cancelRequest()
        currentStep = .setup
        cachedStates = [:]
    }

}
