import Foundation

struct AestheticPriceRange: Equatable {
    let low: Int
    let high: Int

    init(_ low: Int, _ high: Int) {
        self.low = low
        self.high = high
    }

    static func + (lhs: AestheticPriceRange, rhs: AestheticPriceRange) -> AestheticPriceRange {
        AestheticPriceRange(lhs.low + rhs.low, lhs.high + rhs.high)
    }

    var label: String {
        "¥\(low)–\(high)"
    }

    var midpointLabel: String {
        "约 ¥\((low + high) / 2)"
    }
}

enum AestheticRestorationTier: String, CaseIterable, Identifiable {
    case core
    case high
    case complete

    var id: String { rawValue }

    var title: String {
        switch self {
        case .core:
            return "核心还原"
        case .high:
            return "高度还原"
        case .complete:
            return "完整还原"
        }
    }
}

struct AestheticRestorationOption: Equatable, Identifiable {
    var id: AestheticRestorationTier { tier }

    let tier: AestheticRestorationTier
    let fidelity: Int
    let styleCost: AestheticPriceRange
    let premium: AestheticPriceRange
    let keeps: String
    let tradeoff: String
}

struct AestheticBuildStyle: Equatable, Identifiable {
    let id: String
    let title: String
    let summary: String
    let image: String
    let tags: [String]
    let options: [AestheticRestorationOption]

    var startingCostLabel: String {
        "外观方案约 ¥\(options.first?.styleCost.low ?? 0) 起"
    }

    static let featured = AestheticDemoCatalog.styles
}

enum AestheticExperience: String, CaseIterable, Identifiable {
    case smooth
    case highRefresh
    case competitive

    var id: String { rawValue }

    var title: String {
        switch self {
        case .smooth:
            return "流畅游玩"
        case .highRefresh:
            return "高刷顺滑"
        case .competitive:
            return "电竞竞技"
        }
    }

    var detail: String {
        switch self {
        case .smooth:
            return "约 60 帧"
        case .highRefresh:
            return "约 120–144 帧"
        case .competitive:
            return "200 帧以上"
        }
    }
}

enum AestheticResolutionChoice: String, CaseIterable, Identifiable {
    case unknown
    case fullHD
    case twoK
    case fourK

    var id: String { rawValue }

    var title: String {
        switch self {
        case .unknown:
            return "不知道"
        case .fullHD:
            return "1080P"
        case .twoK:
            return "2K"
        case .fourK:
            return "4K"
        }
    }

    var resolved: PerformanceResolution {
        switch self {
        case .unknown, .twoK:
            return .twoK
        case .fullHD:
            return .fullHD
        case .fourK:
            return .fourK
        }
    }
}

enum AestheticBuildStep: Int, CaseIterable {
    case restoration
    case games
    case experience
    case quote

    var title: String {
        switch self {
        case .restoration:
            return "外观取舍"
        case .games:
            return "常玩游戏"
        case .experience:
            return "体验目标"
        case .quote:
            return "预算预估"
        }
    }
}

struct AestheticBuildQuote: Equatable {
    let performanceCore: AestheticPriceRange
    let styleModule: AestheticPriceRange
    let aestheticPremium: AestheticPriceRange
    let total: AestheticPriceRange
}

struct AestheticBuildFlow: Equatable {
    var step: AestheticBuildStep = .restoration
    var styleID: String
    var selectedTier: AestheticRestorationTier = .core
    var selectedGames: [PerformanceGame] = [.cyberpunk]
    var selectedExperience: AestheticExperience = .smooth
    var selectedResolution: AestheticResolutionChoice = .unknown
    private(set) var isQuoteConfirmed = false

    init(styleID: String = AestheticBuildStyle.featured[0].id) {
        self.styleID = AestheticBuildStyle.featured.contains { $0.id == styleID }
            ? styleID
            : AestheticBuildStyle.featured[0].id
    }

    var style: AestheticBuildStyle {
        AestheticBuildStyle.featured.first { $0.id == styleID } ?? AestheticBuildStyle.featured[0]
    }

    var restoration: AestheticRestorationOption {
        style.options.first { $0.tier == selectedTier } ?? style.options[0]
    }

    var resolvedResolution: PerformanceResolution {
        selectedResolution.resolved
    }

    var quote: AestheticBuildQuote {
        let performanceCore = basePerformanceCost + gameAdjustment
        let styleModule = restoration.styleCost

        return AestheticBuildQuote(
            performanceCore: performanceCore,
            styleModule: styleModule,
            aestheticPremium: restoration.premium,
            total: performanceCore + styleModule
        )
    }

    mutating func selectTier(_ tier: AestheticRestorationTier) {
        selectedTier = tier
        isQuoteConfirmed = false
    }

    mutating func selectExperience(_ experience: AestheticExperience) {
        selectedExperience = experience
        isQuoteConfirmed = false
    }

    mutating func selectResolution(_ resolution: AestheticResolutionChoice) {
        selectedResolution = resolution
        isQuoteConfirmed = false
    }

    mutating func setGames(_ games: [PerformanceGame]) {
        guard !games.isEmpty else { return }
        selectedGames = games
        isQuoteConfirmed = false
    }

    mutating func toggleGame(_ game: PerformanceGame) {
        if selectedGames.contains(game) {
            guard selectedGames.count > 1 else { return }
            selectedGames.removeAll { $0 == game }
        } else {
            selectedGames.append(game)
        }
        isQuoteConfirmed = false
    }

    mutating func goNext() {
        guard let next = AestheticBuildStep(rawValue: step.rawValue + 1) else { return }
        step = next
    }

    mutating func goPrevious() {
        guard let previous = AestheticBuildStep(rawValue: step.rawValue - 1) else { return }
        step = previous
    }

    mutating func showRestoration() {
        step = .restoration
    }

    mutating func showExperience() {
        step = .experience
    }

    mutating func confirmQuote() {
        isQuoteConfirmed = true
    }

    private var basePerformanceCost: AestheticPriceRange {
        switch (resolvedResolution, selectedExperience) {
        case (.fullHD, .smooth):
            return AestheticPriceRange(3800, 4500)
        case (.fullHD, .highRefresh):
            return AestheticPriceRange(5000, 6000)
        case (.fullHD, .competitive):
            return AestheticPriceRange(6200, 7500)
        case (.twoK, .smooth):
            return AestheticPriceRange(4800, 5700)
        case (.twoK, .highRefresh):
            return AestheticPriceRange(6500, 7800)
        case (.twoK, .competitive):
            return AestheticPriceRange(7800, 9400)
        case (.fourK, .smooth):
            return AestheticPriceRange(7200, 8600)
        case (.fourK, .highRefresh):
            return AestheticPriceRange(10500, 12800)
        case (.fourK, .competitive):
            return AestheticPriceRange(13800, 17500)
        }
    }

    private var gameAdjustment: AestheticPriceRange {
        selectedGames
            .map { adjustment(for: $0) }
            .max { $0.high < $1.high } ?? AestheticPriceRange(0, 0)
    }

    private func adjustment(for game: PerformanceGame) -> AestheticPriceRange {
        switch game.id {
        case "cyberpunk", "elden-ring", "cod":
            return AestheticPriceRange(800, 1200)
        case "pubg", "genshin", "apex":
            return AestheticPriceRange(300, 600)
        default:
            return AestheticPriceRange(0, 200)
        }
    }
}

enum AestheticDemoCatalog {
    static let styles: [AestheticBuildStyle] = [
        style(
            id: "blackKnight",
            title: "黑武士",
            summary: "低调冷酷，灯效克制，适合高性能玩家",
            image: "HomeStyleBlackKnight",
            tags: ["暗黑机箱", "克制灯效"],
            signature: "黑色机箱与整体暗色观感",
            highDetail: "统一黑色散热器与主要风扇位",
            completeDetail: "统一散热、风扇和克制灯效",
            costs: [AestheticPriceRange(850, 1100), AestheticPriceRange(1450, 1900), AestheticPriceRange(2300, 3100)],
            premiums: [AestheticPriceRange(300, 450), AestheticPriceRange(850, 1250), AestheticPriceRange(1650, 2350)]
        ),
        style(
            id: "panorama",
            title: "海景房",
            summary: "通透展示，适合 RGB 与颜值党",
            image: "HomeStylePanorama",
            tags: ["通透设计", "RGB"],
            signature: "海景房机箱与基础灯效",
            highDetail: "造型匹配的散热器与主要风扇位",
            completeDetail: "完整风扇布局、统一灯效与展示感",
            costs: [AestheticPriceRange(900, 1200), AestheticPriceRange(1600, 2200), AestheticPriceRange(2600, 3600)],
            premiums: [AestheticPriceRange(350, 500), AestheticPriceRange(950, 1450), AestheticPriceRange(1900, 2800)]
        ),
        style(
            id: "whiteMinimal",
            title: "白色极简",
            summary: "干净克制，适合桌搭与工作环境",
            image: "HomeStyleWhiteMinimal",
            tags: ["纯白", "简约"],
            signature: "白色机箱与干净桌搭观感",
            highDetail: "白色散热器与主要可见部件",
            completeDetail: "主要可见部件、风扇和线材统一",
            costs: [AestheticPriceRange(800, 1050), AestheticPriceRange(1400, 1850), AestheticPriceRange(2200, 3000)],
            premiums: [AestheticPriceRange(280, 420), AestheticPriceRange(800, 1200), AestheticPriceRange(1550, 2300)]
        )
    ]

    private static func style(
        id: String,
        title: String,
        summary: String,
        image: String,
        tags: [String],
        signature: String,
        highDetail: String,
        completeDetail: String,
        costs: [AestheticPriceRange],
        premiums: [AestheticPriceRange]
    ) -> AestheticBuildStyle {
        AestheticBuildStyle(
            id: id,
            title: title,
            summary: summary,
            image: image,
            tags: tags,
            options: [
                AestheticRestorationOption(tier: .core, fidelity: 65, styleCost: costs[0], premium: premiums[0], keeps: signature, tradeoff: "使用基础散热和必要风扇"),
                AestheticRestorationOption(tier: .high, fidelity: 85, styleCost: costs[1], premium: premiums[1], keeps: highDetail, tradeoff: "不补满装饰风扇"),
                AestheticRestorationOption(tier: .complete, fidelity: 95, styleCost: costs[2], premium: premiums[2], keeps: completeDetail, tradeoff: "保留同风格型号替代空间")
            ]
        )
    }
}
