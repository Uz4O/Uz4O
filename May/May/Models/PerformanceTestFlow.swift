import Foundation

enum PerformanceTestStep: Int, CaseIterable {
    case hardware
    case conditions
    case result

    var title: String {
        switch self {
        case .hardware: "电脑配置"
        case .conditions: "测试条件"
        case .result: "性能结果"
        }
    }
}

enum PerformanceResolution: String, CaseIterable, Identifiable {
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
        samples.first(where: { $0.id == id })?.name ?? id
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
    let resolutionTitle: String
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
    let missingGameNames: [String]
    let gameResults: [GamePerformanceResult]
}

struct PerformanceTestFlow: Equatable {
    var currentStep: PerformanceTestStep = .hardware
    var hardwareProfile: HardwareProfile = HardwareProfile(
        cpu: "i5-14600K",
        gpu: "RTX 4070",
        motherboard: "B760M AORUS ELITE GEN5",
        memory: "16GB",
        storage: "Western Digital WD Black SN850X · 1TB · PCIe 4.0",
        powerSupply: "Corsair RM750e · 750W · 80+ Gold"
    )
    var selectedResolution: PerformanceResolution = .twoK
    var selectedGames: [PerformanceGame] = [.cyberpunk]
    private(set) var loadState: PerformanceLoadState = .idle
    private(set) var result: PerformanceTestResult?
    private var requestGeneration = 0
    private var activeRequestToken: Int?

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

    mutating func toggleGame(_ game: PerformanceGame) {
        if selectedGames.contains(game) {
            if selectedGames.count > 1 {
                selectedGames.removeAll { $0 == game }
            }
        } else {
            selectedGames.append(game)
        }
    }

    mutating func beginRequest() -> PerformanceRequestContext? {
        guard loadState != .loading else { return nil }
        currentStep = .result
        result = nil
        guard let input = requestInput else {
            activeRequestToken = nil
            loadState = .empty
            return nil
        }

        requestGeneration += 1
        activeRequestToken = requestGeneration
        loadState = .loading
        return PerformanceRequestContext(
            token: requestGeneration,
            input: input,
            resolutionTitle: selectedResolution.title
        )
    }

    mutating func apply(_ payload: PerformanceEstimatePayload, for request: PerformanceRequestContext) {
        guard activeRequestToken == request.token else { return }
        activeRequestToken = nil
        guard
            payload.status != .needsMoreData,
            let averageFPS = payload.averageFPS
        else {
            loadState = .empty
            result = nil
            return
        }

        result = PerformanceTestResult(
            resolution: request.resolutionTitle,
            averageFPS: "\(averageFPS) FPS",
            missingGameNames: payload.missingGames.map { PerformanceGame.name(for: $0) },
            gameResults: payload.gameResults
        )
        loadState = payload.status == .partial ? .partial : .loaded
    }

    mutating func failRequest(_ message: String, for request: PerformanceRequestContext) {
        guard activeRequestToken == request.token else { return }
        activeRequestToken = nil
        loadState = .failed(message)
        result = nil
    }

    mutating func cancelRequest() {
        activeRequestToken = nil
        if loadState == .loading {
            loadState = .idle
            result = nil
        }
    }

    mutating func reset() {
        cancelRequest()
        currentStep = .hardware
        loadState = .idle
        result = nil
    }

}
