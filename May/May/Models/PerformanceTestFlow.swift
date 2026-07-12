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
    let lowFPS: Int
    let maximumFPS: Int
    let bottleneck: String?
    let bottleneckPercent: Int?
    let sourceFetchedAt: String
}

struct PerformanceEstimatePayload: Equatable {
    let status: PerformanceEstimateStatus
    let averageFPS: Int?
    let lowFPS: Int?
    let maximumFPS: Int?
    let bottleneck: String?
    let bottleneckPercent: Int?
    let sourceFetchedAt: String?
    let missingGames: [String]
    let gameResults: [GamePerformanceResult]
}

struct PerformanceEstimateInput: Equatable {
    let cpuID: String
    let gpuID: String
    let resolution: String
    let gameIDs: [String]
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
    let lowFPS: String
    let maximumFPS: String
    let smoothness: String
    let bottleneck: String
    let sourceFetchedAt: String
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
        if game == .allGames {
            selectedGames = selectedGames == [.allGames] ? [.cyberpunk] : [.allGames]
        } else if selectedGames.contains(game) {
            if selectedGames.count > 1 {
                selectedGames.removeAll { $0 == game }
            }
        } else {
            selectedGames.removeAll { $0 == .allGames }
            selectedGames.append(game)
        }
    }

    mutating func beginRequest() {
        guard loadState != .loading else { return }
        currentStep = .result
        loadState = .loading
        result = nil
    }

    mutating func apply(_ payload: PerformanceEstimatePayload) {
        guard
            payload.status != .needsMoreData,
            let averageFPS = payload.averageFPS,
            let lowFPS = payload.lowFPS,
            let maximumFPS = payload.maximumFPS,
            let sourceFetchedAt = payload.sourceFetchedAt
        else {
            loadState = .empty
            result = nil
            return
        }

        result = PerformanceTestResult(
            resolution: selectedResolution.title,
            averageFPS: "\(averageFPS) FPS",
            lowFPS: "\(lowFPS) FPS",
            maximumFPS: "\(maximumFPS) FPS",
            smoothness: Self.smoothness(for: averageFPS),
            bottleneck: Self.bottleneckText(payload.bottleneck, percent: payload.bottleneckPercent),
            sourceFetchedAt: sourceFetchedAt,
            missingGameNames: payload.missingGames.map { PerformanceGame.name(for: $0) },
            gameResults: payload.gameResults
        )
        loadState = payload.status == .partial ? .partial : .loaded
    }

    mutating func showNoData() {
        currentStep = .result
        loadState = .empty
        result = nil
    }

    mutating func failRequest(_ message: String) {
        loadState = .failed(message)
        result = nil
    }

    mutating func reset() {
        currentStep = .hardware
        loadState = .idle
        result = nil
    }

    private static func bottleneckText(_ value: String?, percent: Int?) -> String {
        let name: String
        switch value {
        case "cpu": name = "CPU"
        case "gpu": name = "显卡"
        case "balanced": name = "均衡"
        default: name = "暂无明显瓶颈"
        }
        return percent.map { "\(name) \($0)%" } ?? name
    }

    private static func smoothness(for averageFPS: Int) -> String {
        switch averageFPS {
        case 120...: "非常流畅"
        case 60...: "流畅"
        case 30...: "基本流畅"
        default: "不够流畅"
        }
    }
}
