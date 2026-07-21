import Foundation

struct AestheticPriceRange: Equatable {
    let low: Int
    let high: Int

    init(low: Int, high: Int) {
        self.low = low
        self.high = high
    }

    init(_ low: Int, _ high: Int) {
        self.init(low: low, high: high)
    }

    static func + (lhs: AestheticPriceRange, rhs: AestheticPriceRange) -> AestheticPriceRange {
        AestheticPriceRange(low: lhs.low + rhs.low, high: lhs.high + rhs.high)
    }

    var label: String {
        "¥\(low.formatted())–\(high.formatted())"
    }

    var midpointLabel: String {
        "约 ¥\(((low + high) / 2).formatted())"
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
        "外观方案约 ¥\(minimumOverviewCost.formatted()) 起"
    }

    var minimumOverviewCost: Int {
        overviewParts.reduce(0) { total, part in
            let lowestAlternative = part.alternatives.map(\.price).min() ?? part.price
            return total + min(part.price, lowestAlternative)
        }
    }

    var overviewParts: [AestheticStylePart] {
        AestheticOverviewCatalog.parts(for: id)
    }

    func heroImage(for color: AestheticStyleColor) -> String {
        if id == "blackKnight" {
            return color == .black
                ? "StyleLianLiVisionCompactBlack"
                : "StyleLianLiVisionCompactWhite"
        }
        if id == "panorama" {
            return color == .black
                ? "StyleROGGR701Black"
                : "StyleROGGR701White"
        }
        if id == "whiteMinimal" {
            return color == .black
                ? "StyleUnknownPlayerPhantomWingBlack"
                : "StyleUnknownPlayerPhantomWingWhite"
        }
        if id == "bo400" {
            return color == .black
                ? "StyleJonsboBO400Black"
                : "StyleJonsboBO400White"
        }
        if id == "xingcanChen" {
            return color == .black
                ? "StyleAigoXingcanChenBlack"
                : "StyleAigoXingcanChenWhite"
        }

        return image
    }

    func heroScale(for color: AestheticStyleColor) -> Double {
        switch (id, color) {
        case ("blackKnight", .black): return 1.05
        case ("panorama", .black): return 0.98
        case ("xingcanChen", .black): return 0.99
        default: return 1
        }
    }

    func overviewTotal(for color: AestheticStyleColor) -> Int {
        if id == "blackKnight" {
            return color == .black ? 6520 : 6580
        }
        if id == "panorama" {
            return color == .black ? 8496 : 8596
        }
        if id == "whiteMinimal" {
            return 3637
        }
        if id == "bo400" {
            return color == .black ? 4497 : 4597
        }
        if id == "xingcanChen" {
            return 1884
        }

        return overviewParts.reduce(0) { $0 + $1.originalPrice(for: color) }
    }

    static let all = AestheticDemoCatalog.styles
    static let featured = Array(all.prefix(3))
}

enum AestheticStyleColor: String, CaseIterable, Identifiable {
    case black
    case white

    var id: String { rawValue }
    var title: String { self == .black ? "黑色" : "白色" }
}

struct AestheticStyleAlternative: Equatable, Identifiable {
    let id: String
    let name: String
    let price: Int
    let detail: String
}

struct AestheticStylePart: Equatable, Identifiable {
    let id: String
    let name: String
    let detail: String
    let price: Int
    let whitePrice: Int?
    let alternatives: [AestheticStyleAlternative]

    func originalPrice(for color: AestheticStyleColor) -> Int {
        color == .white ? whitePrice ?? price : price
    }
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
    let styleID: String
    var selectedTier: AestheticRestorationTier = .core
    var selectedGames: [PerformanceGame] = [.cyberpunk]
    var selectedExperience: AestheticExperience = .smooth
    var selectedResolution: AestheticResolutionChoice = .unknown
    private(set) var isQuoteConfirmed = false

    init(styleID: String = AestheticBuildStyle.featured[0].id) {
        self.styleID = AestheticBuildStyle.all.contains { $0.id == styleID }
            ? styleID
            : AestheticBuildStyle.all[0].id
    }

    var style: AestheticBuildStyle {
        AestheticBuildStyle.all.first { $0.id == styleID } ?? AestheticBuildStyle.all[0]
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
            return AestheticPriceRange(low: 3800, high: 4500)
        case (.fullHD, .highRefresh):
            return AestheticPriceRange(low: 5000, high: 6000)
        case (.fullHD, .competitive):
            return AestheticPriceRange(low: 6200, high: 7500)
        case (.twoK, .smooth):
            return AestheticPriceRange(low: 4800, high: 5700)
        case (.twoK, .highRefresh):
            return AestheticPriceRange(low: 6500, high: 7800)
        case (.twoK, .competitive):
            return AestheticPriceRange(low: 7800, high: 9400)
        case (.fourK, .smooth):
            return AestheticPriceRange(low: 7200, high: 8600)
        case (.fourK, .highRefresh):
            return AestheticPriceRange(low: 10500, high: 12800)
        case (.fourK, .competitive):
            return AestheticPriceRange(low: 13800, high: 17500)
        }
    }

    private var gameAdjustment: AestheticPriceRange {
        selectedGames
            .map { adjustment(for: $0) }
            .max { $0.high < $1.high } ?? AestheticPriceRange(low: 0, high: 0)
    }

    private func adjustment(for game: PerformanceGame) -> AestheticPriceRange {
        switch game.id {
        case "cyberpunk", "elden-ring", "cod":
            return AestheticPriceRange(low: 800, high: 1200)
        case "pubg", "genshin", "apex":
            return AestheticPriceRange(low: 300, high: 600)
        default:
            return AestheticPriceRange(low: 0, high: 200)
        }
    }
}

private enum AestheticOverviewCatalog {
    static func parts(for styleID: String) -> [AestheticStylePart] {
        if styleID == "blackKnight" {
            return visionCompactParts
        }
        if styleID == "panorama" {
            return rogGR701Parts
        }
        if styleID == "whiteMinimal" {
            return phantomWingParts
        }
        if styleID == "bo400" {
            return jonsboBO400Parts
        }
        if styleID == "xingcanChen" {
            return xingcanChenParts
        }

        let prefix: String
        let caseName: String

        switch styleID {
        case "panorama":
            prefix = "panorama"
            caseName = "海景房"
        case "whiteMinimal":
            prefix = "white"
            caseName = "白色极简"
        default:
            prefix = "black"
            caseName = "黑武士"
        }

        return [
            part(prefix, "机箱", "\(caseName)展示机箱", 899, [
                alternative("标准版机箱", 699, "保留通透侧板")
            ]),
            part(prefix, "一体式水冷", "360mm 外观匹配水冷", 699, [
                alternative("240mm 一体式水冷", 499, "散热规模更紧凑")
            ]),
            part(prefix, "风扇套装", "统一灯效风扇 3 把", 399, [
                alternative("基础风扇套装", 249, "减少灯效与装饰数量")
            ]),
            part(prefix, "定制线材", "配色电源延长线", 299, [
                alternative("通用线材", 99, "使用标准黑色线材")
            ]),
            part(prefix, "显卡支架", "与机箱配色一致", 159, [
                alternative("通用显卡支架", 79, "保留支撑功能")
            ])
        ]
    }

    private static let visionCompactParts = [
        part("vision", "机箱", "联立 VISION COMPACT", 679, [
            alternative("联立 VISION COMPACT（二手）", 450, "原型号二手，成色以实际为准")
        ], whitePrice: 739),
        part("vision", "一体式水冷", "展域 SE360", 1799, [
            alternative("利民 LV360", 900, "外观一致平替，暂未发现二手"),
            alternative("瓦尔基里 N360", 950, "外观一致平替，暂未发现二手"),
            alternative("展域 SE360（二手）", 1000, "原型号二手，参考价格"),
            alternative("展域 SE360（全新供货）", 1499, "闲鱼供货商全新价格")
        ]),
        part("vision", "副屏", "图灵智显 8.8 寸副屏", 340, [
            alternative("图灵智显 8.8 寸副屏（二手）", 200, "当前仅提供二手平替")
        ]),
        part("vision", "风扇套装", "联立四代风扇 8 把 + 无线发射器", 3000, [
            alternative("丛林豹星际积木 V4 套装", 1085, "带屏 5 把 × 199 元 + 无屏 3 把 × 30 元")
        ]),
        part("vision", "霓虹线", "联立 4 代霓虹线", 700, [
            alternative("外置霓虹线", 100, "外置安装平替")
        ])
    ]

    private static let rogGR701Parts = [
        part("rog-gr701", "机箱", "ROG GR701 创世神", 3599, [
            alternative("ROG GR701 创世神（二手）", 1700, "原型号二手，参考价格"),
            alternative("ROG GR701 创世神（闲鱼全新）", 2300, "闲鱼全新参考价格")
        ]),
        part("rog-gr701", "一体式水冷", "ROG 龙王 4 代水冷颜值版", 2599, [
            alternative("展域 SE360（全新）", 1799, "常规全新参考价格"),
            alternative("展域 SE360（闲鱼全新）", 1499, "闲鱼供货商全新价格"),
            alternative("展域 SE360（二手）", 1000, "原型号二手参考价格"),
            alternative("利民 LV360", 899, "外观相近的全新平替")
        ], whitePrice: 2699),
        part("rog-gr701", "LCD 风扇", "联立 4 代积木 LCD 风扇 3 把", 1099, [
            alternative("丛林豹星际积木 V4 LCD × 3", 597, "带屏风扇 3 把 × 199 元")
        ]),
        part("rog-gr701", "LED 风扇", "联立 4 代积木 LED 风扇 4 把", 800, [
            alternative("丛林豹星际积木 V4 无屏 × 4", 120, "无屏风扇 4 把 × 30 元")
        ]),
        part("rog-gr701", "显卡支架", "ROG 大力神支架", 399, [
            alternative("ROG 大力神支架（二手）", 160, "原型号二手参考价格"),
            alternative("ROG 大力神支架（闲鱼全新）", 229, "闲鱼全新参考价格")
        ])
    ]

    private static let phantomWingParts = [
        part("phantom-wing", "机箱", "未知玩家 幻翼", 699, []),
        part("phantom-wing", "风扇与控制器", "联立一代积木风扇 6 把 + 无线发射器", 1339, [
            alternative("棱镜 8 Pro × 6", 59, "6 把 × 9.9 元 = 59.4 元；无需联立发射器")
        ]),
        part("phantom-wing", "一体式水冷", "联立隐流 2 代", 1599, [
            alternative("联立隐流 1 代", 499, "同系列上一代平替"),
            alternative("利民 LV360", 899, "外观相近的全新平替")
        ])
    ]

    private static let jonsboBO400Parts = [
        part("bo400", "机箱", "乔思伯 BO400", 1399, [
            alternative("乔思伯 X400", 599, "同品牌低价机箱平替")
        ]),
        part("bo400", "风扇套装", "ZA360 风扇 3 把 + ZA120 风扇 1 把", 499, [
            alternative("海中神 ZA 风扇组合", 165, "ZA360 3 把 × 50 元 + ZA120 1 把 × 15 元")
        ]),
        part("bo400", "一体式水冷", "ROG 龙王 4 代水冷颜值版", 2599, [
            alternative("展域 SE360（全新）", 1799, "常规全新参考价格"),
            alternative("展域 SE360（闲鱼全新）", 1499, "闲鱼供货商全新价格"),
            alternative("展域 SE360（二手）", 1000, "原型号二手参考价格"),
            alternative("利民 LV360", 899, "外观相近的全新平替")
        ], whitePrice: 2699)
    ]

    private static let xingcanChenParts = [
        part("xingcan-chen", "机箱", "爱国者 星璨辰", 699, []),
        part("xingcan-chen", "一体式水冷", "联立隐流 1 代", 499, []),
        part("xingcan-chen", "风扇套装", "乔思伯 ZA360 3 把 + ZA240 1 把", 686, [
            alternative("海中神 ZA 风扇组合", 165, "沿用 BO400 平替：ZA360 3 把 + ZA120 1 把")
        ])
    ]

    private static func part(
        _ prefix: String,
        _ name: String,
        _ detail: String,
        _ price: Int,
        _ alternatives: [AestheticStyleAlternative],
        whitePrice: Int? = nil
    ) -> AestheticStylePart {
        AestheticStylePart(
            id: "\(prefix)-\(name)",
            name: name,
            detail: detail,
            price: price,
            whitePrice: whitePrice,
            alternatives: alternatives
        )
    }

    private static func alternative(
        _ name: String,
        _ price: Int,
        _ detail: String
    ) -> AestheticStyleAlternative {
        AestheticStyleAlternative(
            id: name,
            name: name,
            price: price,
            detail: detail
        )
    }
}

private enum AestheticDemoCatalog {
    static let styles: [AestheticBuildStyle] = [
        style(
            id: "blackKnight",
            title: "联立 VISION COMPACT",
            summary: "双面玻璃展示、屏显风扇与副屏组成的高完整度海景房方案",
            image: "StyleLianLiVisionCompactBlack",
            tags: ["海景房", "屏显风扇"],
            signature: "保留 VISION COMPACT 机箱和主要展示结构",
            highDetail: "保留副屏、灯效风扇和整体黑白配色",
            completeDetail: "完整保留水冷、屏显风扇、副屏与霓虹线",
            costs: [AestheticPriceRange(low: 850, high: 1100), AestheticPriceRange(low: 1450, high: 1900), AestheticPriceRange(low: 2300, high: 3100)],
            premiums: [AestheticPriceRange(low: 300, high: 450), AestheticPriceRange(low: 850, high: 1250), AestheticPriceRange(low: 1650, high: 2350)]
        ),
        style(
            id: "panorama",
            title: "ROG 创世神 701",
            summary: "ROG 全家桶风格与屏显风扇结合的大型旗舰展示方案",
            image: "StyleROGGR701Black",
            tags: ["ROG", "旗舰展示"],
            signature: "保留 GR701 创世神机箱和 ROG 视觉结构",
            highDetail: "保留龙王水冷、屏显风扇和大力神支架",
            completeDetail: "完整保留 ROG 水冷、联立风扇与支架组合",
            costs: [AestheticPriceRange(low: 900, high: 1200), AestheticPriceRange(low: 1600, high: 2200), AestheticPriceRange(low: 2600, high: 3600)],
            premiums: [AestheticPriceRange(low: 350, high: 500), AestheticPriceRange(low: 950, high: 1450), AestheticPriceRange(low: 1900, high: 2800)]
        ),
        style(
            id: "whiteMinimal",
            title: "未知玩家 幻翼",
            summary: "翼展式玻璃顶盖与垂直副屏构成的高辨识度展示方案",
            image: "StyleUnknownPlayerPhantomWingBlack",
            tags: ["翼展顶盖", "垂直副屏"],
            signature: "保留幻翼机箱和翼展式顶部结构",
            highDetail: "保留联立风扇、水冷与整体灯效",
            completeDetail: "完整保留 6 把风扇、发射器和隐流水冷",
            costs: [AestheticPriceRange(low: 800, high: 1050), AestheticPriceRange(low: 1400, high: 1850), AestheticPriceRange(low: 2200, high: 3000)],
            premiums: [AestheticPriceRange(low: 280, high: 420), AestheticPriceRange(low: 800, high: 1200), AestheticPriceRange(low: 1550, high: 2300)]
        ),
        style(
            id: "bo400",
            title: "乔思伯 BO400",
            summary: "圆角铝框与双面玻璃组成的简洁高端展示方案",
            image: "StyleJonsboBO400Black",
            tags: ["圆角铝框", "双面玻璃"],
            signature: "保留 BO400 机箱和基础灯效布局",
            highDetail: "保留龙王水冷与 ZA 风扇组合",
            completeDetail: "完整保留 BO400、龙王水冷和四风扇布局",
            costs: [AestheticPriceRange(low: 1663, high: 2000), AestheticPriceRange(low: 3000, high: 3600), AestheticPriceRange(low: 4497, high: 4597)],
            premiums: [AestheticPriceRange(low: 300, high: 500), AestheticPriceRange(low: 1000, high: 1400), AestheticPriceRange(low: 1900, high: 2400)]
        ),
        style(
            id: "xingcanChen",
            title: "星璨辰",
            summary: "四面通透结构与整齐灯带风扇组成的简洁海景房方案",
            image: "StyleAigoXingcanChenBlack",
            tags: ["四面通透", "灯带风扇"],
            signature: "保留星璨辰机箱和基础灯效",
            highDetail: "保留隐流水冷与 ZA 风扇布局",
            completeDetail: "完整保留机箱、水冷和四风扇组合",
            costs: [AestheticPriceRange(low: 1363, high: 1500), AestheticPriceRange(low: 1600, high: 1750), AestheticPriceRange(low: 1884, high: 1884)],
            premiums: [AestheticPriceRange(low: 200, high: 300), AestheticPriceRange(low: 450, high: 600), AestheticPriceRange(low: 650, high: 800)]
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
