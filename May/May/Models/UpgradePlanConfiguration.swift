import Foundation

struct UpgradeCurrentHardwareDTO: Encodable, Equatable, Hashable {
    let cpu: String?
    let gpu: String?
    let motherboard: String?
    let ram: String?
    let psu: String?
}

struct UpgradePlanRequestDTO: Encodable, Equatable, Hashable {
    let budget: Int
    let current: UpgradeCurrentHardwareDTO
    let need: String
    let games: [String]
    let resolution: String
    let targetFps: Int?

    enum CodingKeys: String, CodingKey {
        case budget, current, need, games, resolution
        case targetFps = "target_fps"
    }
}

struct UpgradeStepDTO: Codable, Equatable, Hashable, Identifiable {
    var id: Int { order }

    let order: Int
    let role: String
    let fromComponentId: String
    let fromName: String
    let toComponentId: String
    let toName: String
    let estimatedPrice: Int
    let expectedGainPercent: Int
    let reason: String
    let bundleId: String
    let bundleTitle: String
    let requiredTogether: Bool
}

struct UpgradeGameResultDTO: Codable, Equatable, Hashable, Identifiable {
    var id: String { game }

    let game: String
    let beforeFps: Int
    let afterFps: Int
    let targetFps: Int
    let met: Bool
}

struct UpgradePlanResponseDTO: Codable, Equatable, Hashable {
    let status: String
    let summary: String
    let budget: Int
    let totalEstimatedPrice: Int
    let primaryBottleneck: String?
    let missingFields: [String]
    let steps: [UpgradeStepDTO]
    let notes: [String]
    let resolution: String
    let targetFps: Int?
    let targetMet: Bool?
    let gameResults: [UpgradeGameResultDTO]
    let direction: String?
    let anchorTemplateId: String?
    let priceDate: String?

    private enum CodingKeys: String, CodingKey {
        case status, summary, budget, totalEstimatedPrice, primaryBottleneck
        case missingFields, steps, notes, resolution, targetFps, targetMet, gameResults
        case direction, anchorTemplateId, priceDate
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = try container.decode(String.self, forKey: .status)
        summary = try container.decode(String.self, forKey: .summary)
        budget = try container.decode(Int.self, forKey: .budget)
        totalEstimatedPrice = try container.decode(Int.self, forKey: .totalEstimatedPrice)
        primaryBottleneck = try container.decodeIfPresent(String.self, forKey: .primaryBottleneck)
        missingFields = try container.decode([String].self, forKey: .missingFields)
        steps = try container.decode([UpgradeStepDTO].self, forKey: .steps)
        notes = try container.decode([String].self, forKey: .notes)
        resolution = try container.decodeIfPresent(String.self, forKey: .resolution) ?? ""
        targetFps = try container.decodeIfPresent(Int.self, forKey: .targetFps)
        targetMet = try container.decodeIfPresent(Bool.self, forKey: .targetMet)
        gameResults = try container.decodeIfPresent(
            [UpgradeGameResultDTO].self,
            forKey: .gameResults
        ) ?? []
        direction = try container.decodeIfPresent(String.self, forKey: .direction)
        anchorTemplateId = try container.decodeIfPresent(String.self, forKey: .anchorTemplateId)
        priceDate = try container.decodeIfPresent(String.self, forKey: .priceDate)
    }
}

struct SaveUpgradePlanRequestDTO: Encodable {
    let title: String
    let plan: UpgradePlanResponseDTO
    let budget: Int
    let totalPrice: Int
    let useCase: String

    enum CodingKeys: String, CodingKey {
        case title, plan, budget
        case totalPrice = "total_price"
        case useCase = "use_case"
    }
}

struct SavedUpgradePlanDTO: Decodable, Hashable, Identifiable {
    let id: String
    let title: String
    let plan: UpgradePlanResponseDTO
    let budget: Int?
    let totalPrice: Int?
    let useCase: String?
    let createdAt: String
    let updatedAt: String
}

enum UpgradePlanStep: Int, CaseIterable {
    case computer = 1
    case goal
    case result

    var title: String {
        switch self {
        case .computer: return "当前电脑"
        case .goal: return "升级目标"
        case .result: return "升级方案"
        }
    }

}

enum UpgradeGoal: Equatable {
    case gaming

    static let selectableCases: [UpgradeGoal] = [.gaming]

    var title: String {
        "游戏帧率和画质"
    }

    var conditionsTitle: String {
        "游戏性能目标"
    }
}

enum UpgradeResolution: String, CaseIterable, Identifiable {
    case fullHD = "1080P"
    case twoK = "2K"
    case fourK = "4K"

    var id: String { rawValue }

    var apiValue: String {
        switch self {
        case .fullHD: return "1080p"
        case .twoK: return "2k"
        case .fourK: return "4k"
        }
    }
}

struct UpgradePlanConfiguration: Equatable {
    var step: UpgradePlanStep
    var hardwareProfile: HardwareProfile
    var goal: UpgradeGoal
    var budget: Int
    var selectedGames: Set<String>
    var resolution: UpgradeResolution
    var frameTarget: Int
    var componentPreference: String

    static let categories = HardwareProfileOptions.categories.filter { $0.title != "硬盘" }
    static let games = [
        "无畏契约", "CS2", "PUBG", "三角洲行动", "云顶之弈",
        "英雄联盟", "使命召唤", "赛博朋克2077", "荒野大镖客2", "GTA5",
        "黑神话悟空", "地平线6", "艾尔登法环", "城市天际线", "我的世界"
    ]
    static let gameIDs = [
        "无畏契约": "valorant",
        "CS2": "cs2",
        "PUBG": "pubg",
        "三角洲行动": "delta-force",
        "云顶之弈": "teamfight-tactics",
        "英雄联盟": "league-of-legends",
        "使命召唤": "call-of-duty-warzone",
        "赛博朋克2077": "cyberpunk-2077",
        "荒野大镖客2": "red-dead-redemption-2",
        "GTA5": "gta-v",
        "黑神话悟空": "black-myth-wukong",
        "地平线6": "forza-horizon-6",
        "艾尔登法环": "elden-ring",
        "城市天际线": "cities-skylines",
        "我的世界": "minecraft-java-edition"
    ]

    // Snapshot of backend/app/perf for R7 9850X3D + RTX 5090 D.
    // 1080P competitive FPS games use the product-defined 500 FPS ceiling.
    private static let referenceFrameLimits: [String: [UpgradeResolution: Int]] = [
        "valorant": [.fullHD: 500, .twoK: 406, .fourK: 325],
        "cs2": [.fullHD: 500, .twoK: 215, .fourK: 120],
        "pubg": [.fullHD: 500, .twoK: 266, .fourK: 212],
        "delta-force": [.fullHD: 500, .twoK: 373, .fourK: 322],
        "teamfight-tactics": [.fullHD: 307, .twoK: 256, .fourK: 184],
        "league-of-legends": [.fullHD: 410, .twoK: 338, .fourK: 246],
        "call-of-duty-warzone": [.fullHD: 500, .twoK: 339, .fourK: 350],
        "cyberpunk-2077": [.fullHD: 173, .twoK: 147, .fourK: 115],
        "red-dead-redemption-2": [.fullHD: 184, .twoK: 155, .fourK: 124],
        "gta-v": [.fullHD: 229, .twoK: 185, .fourK: 129],
        "black-myth-wukong": [.fullHD: 157, .twoK: 132, .fourK: 97],
        "forza-horizon-6": [.fullHD: 235, .twoK: 203, .fourK: 158],
        "elden-ring": [.fullHD: 60, .twoK: 60, .fourK: 60],
        "cities-skylines": [.fullHD: 108, .twoK: 92, .fourK: 67],
        "minecraft-java-edition": [.fullHD: 374, .twoK: 237, .fourK: 124]
    ]
    static let componentPreferences = [
        "保留现有平台 · 只用新件",
        "可更换平台 · 只用新件",
        "保留现有平台 · 新旧均可",
        "可更换平台 · 新旧均可"
    ]

    static let sample = UpgradePlanConfiguration(
        step: .computer,
        hardwareProfile: HardwareProfile(
            cpu: "i5-10400F",
            gpu: "GTX 1660 Super",
            motherboard: "B460 HD3",
            memory: "不知道",
            storage: "不知道",
            powerSupply: "Corsair RM750e"
        ),
        goal: .gaming,
        budget: 3000,
        selectedGames: [],
        resolution: .twoK,
        frameTarget: 144,
        componentPreference: componentPreferences[0]
    )

    var selectedGamesDisplay: String {
        let ordered = Self.games.filter(selectedGames.contains)
        return ordered.isEmpty ? "还没有选择游戏" : ordered.joined(separator: "  /  ")
    }

    var hasRequiredGameSelection: Bool {
        !selectedGames.isEmpty
    }

    var missingRequiredHardwareTitles: [String] {
        [
            ("CPU", Self.catalogID(for: hardwareProfile.cpu, in: HardwareCatalog.cpus)),
            ("显卡", Self.catalogID(for: hardwareProfile.gpu, in: HardwareCatalog.gpus)),
            ("主板", Self.catalogID(for: hardwareProfile.motherboard, in: HardwareCatalog.motherboards)),
            ("内存", Self.catalogID(for: hardwareProfile.memory, in: HardwareCatalog.rams)),
            ("电源", Self.catalogID(for: hardwareProfile.powerSupply, in: HardwareCatalog.powerSupplies)),
        ].compactMap { title, componentID in
            componentID == nil ? title : nil
        }
    }

    var hasRequiredHardwareSelection: Bool {
        missingRequiredHardwareTitles.isEmpty
    }

    var apiRequest: UpgradePlanRequestDTO {
        UpgradePlanRequestDTO(
            budget: budget,
            current: UpgradeCurrentHardwareDTO(
                cpu: Self.catalogID(for: hardwareProfile.cpu, in: HardwareCatalog.cpus),
                gpu: Self.catalogID(for: hardwareProfile.gpu, in: HardwareCatalog.gpus),
                motherboard: Self.catalogID(for: hardwareProfile.motherboard, in: HardwareCatalog.motherboards),
                ram: Self.catalogID(for: hardwareProfile.memory, in: HardwareCatalog.rams),
                psu: Self.catalogID(for: hardwareProfile.powerSupply, in: HardwareCatalog.powerSupplies)
            ),
            need: goal.title,
            games: Self.games.filter(selectedGames.contains).compactMap { Self.gameIDs[$0] },
            resolution: resolution.apiValue,
            targetFps: frameTarget
        )
    }

    var frameLimit: Int? {
        let selectedIDs = selectedGames.compactMap { Self.gameIDs[$0] }
        guard selectedIDs.count == selectedGames.count, !selectedIDs.isEmpty else { return nil }
        return selectedIDs.compactMap { Self.referenceFrameLimits[$0]?[resolution] }.min()
    }

    var frameTargetOptions: [Int] {
        guard let frameLimit else { return [] }
        let commonTargets = [30, 60, 90, 120, 144, 165, 180, 240, 360, 500]
        return Array(Set(commonTargets.filter { $0 <= frameLimit } + [frameTarget, frameLimit]))
            .filter { $0 <= frameLimit }
            .sorted()
    }

    mutating func goNext() {
        guard let next = UpgradePlanStep(rawValue: step.rawValue + 1) else { return }
        step = next
    }

    mutating func goBack() {
        guard let previous = UpgradePlanStep(rawValue: step.rawValue - 1) else { return }
        step = previous
    }

    mutating func toggleGame(_ game: String) {
        if selectedGames.contains(game) {
            selectedGames.remove(game)
        } else {
            selectedGames.insert(game)
        }
        clampFrameTarget()
    }

    mutating func clampFrameTarget() {
        guard let frameLimit else { return }
        frameTarget = min(frameTarget, frameLimit)
    }

    func value(for title: String) -> String {
        hardwareProfile.value(for: title)
    }

    mutating func setValue(_ value: String, for title: String) {
        hardwareProfile.setValue(value, for: title)
    }

    mutating func apply(_ profile: HardwareProfile) {
        hardwareProfile = profile
    }

    private static func catalogID(
        for selectedValue: String,
        in items: [HardwareCatalogItem]
    ) -> String? {
        guard selectedValue != "不知道" else { return nil }
        return items.first { item in
            selectedValue == item.name || selectedValue.hasPrefix("\(item.name) ·")
        }?.id
    }
}
