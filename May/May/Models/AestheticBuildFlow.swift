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
        if id == "asusAP202" {
            return color == .black
                ? "StyleASUSAP202Black"
                : "StyleASUSAP202White"
        }
        if id == "hyteY70" {
            return color == .black
                ? "StyleHYTEY70Black"
                : "StyleHYTEY70White"
        }
        if id == "aocShockingBow" {
            return color == .black
                ? "StyleAOCShockingBowBlack"
                : "StyleAOCShockingBowWhite"
        }
        if id == "bo400cg" {
            return color == .black
                ? "StyleJonsboBO400CGBlack"
                : "StyleJonsboBO400CGWhite"
        }
        if id == "visionMin" {
            return color == .black
                ? "StyleLianLiVisionMinBlack"
                : "StyleLianLiVisionMinWhite"
        }
        if id == "hangjiaS960" {
            return color == .black
                ? "StyleHangjiaS960Black"
                : "StyleHangjiaS960White"
        }
        if id == "lianliV150INF" {
            return color == .black
                ? "StyleLianLiV150INFBlack"
                : "StyleLianLiV150INFWhite"
        }
        if id == "jonsboTK1" {
            return color == .black
                ? "StyleJonsboTK1Black"
                : "StyleJonsboTK1White"
        }
        if id == "jonsboD33Wood" {
            return color == .black
                ? "StyleJonsboD33WoodBlack"
                : "StyleJonsboD33WoodWhite"
        }
        if id == "jonsboD34" {
            return color == .black
                ? "StyleJonsboD34Black"
                : "StyleJonsboD34White"
        }
        if id == "aigoXuanYingG20" {
            return color == .black
                ? "StyleAigoXuanYingG20Black"
                : "StyleAigoXuanYingG20White"
        }
        if id == "valkyrieVK3" {
            return color == .black
                ? "StyleValkyrieVK3Black"
                : "StyleValkyrieVK3White"
        }
        if id == "lianliO11EVORGB" {
            return color == .black
                ? "StyleLianLiO11EVORGBBlack"
                : "StyleLianLiO11EVORGBWhite"
        }
        if id == "phanteksEvolvS2" {
            return color == .black
                ? "StylePhanteksEvolvS2Black"
                : "StylePhanteksEvolvS2White"
        }
        if id == "phanteksEvolvX2Matrix" {
            return color == .black
                ? "StylePhanteksEvolvX2MatrixBlack"
                : "StylePhanteksEvolvX2MatrixWhite"
        }
        if id == "jonsboTK4" {
            return color == .black
                ? "StyleJonsboTK4Black"
                : "StyleJonsboTK4White"
        }
        if id == "xingcanChenAir" {
            return color == .black
                ? "StyleAigoXingcanChenAirBlack"
                : "StyleAigoXingcanChenAirWhite"
        }
        if id == "phanteksNV7" {
            return color == .black
                ? "StylePhanteksNV7Black"
                : "StylePhanteksNV7White"
        }
        if id == "lianliO11DMiniV2" {
            return color == .black
                ? "StyleLianLiO11DMiniV2Black"
                : "StyleLianLiO11DMiniV2White"
        }
        if id == "asusTUF502Ammo" {
            return color == .black
                ? "StyleASUSTUF502AmmoBlack"
                : "StyleASUSTUF502AmmoWhite"
        }
        if id == "rogGR801" {
            return color == .black
                ? "StyleROGGR801Black"
                : "StyleROGGR801White"
        }
        if id == "msiVIXTA300R" {
            return color == .black
                ? "StyleMSIVIXTA300RBlack"
                : "StyleMSIVIXTA300RWhite"
        }
        if id == "hangjiaS960V2" {
            return color == .black
                ? "StyleHangjiaS960V2Black"
                : "StyleHangjiaS960V2White"
        }
        if id == "hangjiaGX750C" {
            return color == .black
                ? "StyleHangjiaGX750CBlack"
                : "StyleHangjiaGX750CWhite"
        }
        if id == "coolermasterMF400Mesh" {
            return color == .black
                ? "StyleCoolerMasterMF400MeshBlack"
                : "StyleCoolerMasterMF400MeshWhite"
        }
        if id == "sugonCiyuanCangPX" {
            return color == .black
                ? "StyleSugonCiyuanCangPXBlack"
                : "StyleSugonCiyuanCangPXWhite"
        }
        if id == "titanStarship" {
            return color == .black
                ? "StyleTitanStarshipBlack"
                : "StyleTitanStarshipWhite"
        }
        if id == "fangtangC34Pro" {
            return color == .black
                ? "StyleFangtangC34ProBlack"
                : "StyleFangtangC34ProWhite"
        }
        if id == "cougarV235" {
            return color == .black
                ? "StyleCougarV235Black"
                : "StyleCougarV235White"
        }

        return AestheticGeneratedCatalog.image(for: id, color: color) ?? image
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

    static let all = AestheticDemoCatalog.styles + AestheticGeneratedCatalog.styles
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
    case performanceBudget
    case games
    case experience
    case quote

    var title: String {
        switch self {
        case .performanceBudget:
            return "预算和用途"
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
    static let minimumPerformanceBudget = 4000
    static let maximumPerformanceBudget = 30000

    var step: AestheticBuildStep = .performanceBudget
    let styleID: String
    private let lockedAppearanceCost: Int?
    var selectedTier: AestheticRestorationTier = .core
    var performanceBudget: Int = 8000
    var selectedUseCase = "游戏"
    var hasOwnedGPU = false
    var ownedGPUModel = ""
    var selectedGames: [PerformanceGame] = [.cyberpunk]
    var selectedExperience: AestheticExperience = .smooth
    var selectedResolution: AestheticResolutionChoice = .unknown
    private(set) var isQuoteConfirmed = false

    init(styleID: String = AestheticBuildStyle.featured[0].id, appearanceCost: Int? = nil) {
        self.styleID = AestheticBuildStyle.all.contains { $0.id == styleID }
            ? styleID
            : AestheticBuildStyle.all[0].id
        self.lockedAppearanceCost = appearanceCost
    }

    var style: AestheticBuildStyle {
        AestheticBuildStyle.all.first { $0.id == styleID } ?? AestheticBuildStyle.all[0]
    }

    var restoration: AestheticRestorationOption {
        style.options.first { $0.tier == selectedTier } ?? style.options[0]
    }

    var appearanceCost: Int {
        lockedAppearanceCost ?? style.overviewTotal(for: .black)
    }

    var resolvedResolution: PerformanceResolution {
        selectedResolution.resolved
    }

    var quote: AestheticBuildQuote {
        let performanceCore = lockedAppearanceCost == nil
            ? basePerformanceCost + gameAdjustment
            : AestheticPriceRange(performanceBudget, performanceBudget)
        let styleModule = lockedAppearanceCost.map { AestheticPriceRange($0, $0) } ?? restoration.styleCost

        return AestheticBuildQuote(
            performanceCore: performanceCore,
            styleModule: styleModule,
            aestheticPremium: lockedAppearanceCost == nil
                ? restoration.premium
                : AestheticPriceRange(0, 0),
            total: performanceCore + styleModule
        )
    }

    mutating func setPerformanceBudget(_ budget: Int) {
        performanceBudget = min(
            max(budget, Self.minimumPerformanceBudget),
            Self.maximumPerformanceBudget
        )
        isQuoteConfirmed = false
    }

    mutating func selectUseCase(_ useCase: String) {
        guard AppMockData.useCases.contains(useCase) else { return }
        selectedUseCase = useCase
        isQuoteConfirmed = false
    }

    mutating func setHasOwnedGPU(_ hasOwnedGPU: Bool) {
        self.hasOwnedGPU = hasOwnedGPU
        if !hasOwnedGPU {
            ownedGPUModel = ""
        }
        isQuoteConfirmed = false
    }

    mutating func setOwnedGPUModel(_ model: String) {
        ownedGPUModel = model
        isQuoteConfirmed = false
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
        if styleID == "asusAP202" {
            return asusAP202Parts
        }
        if styleID == "hyteY70" {
            return hyteY70Parts
        }
        if styleID == "aocShockingBow" {
            return aocShockingBowParts
        }
        if styleID == "bo400cg" {
            return bo400CGParts
        }
        if styleID == "visionMin" {
            return visionMinParts
        }
        if styleID == "hangjiaS960" {
            return hangjiaS960Parts
        }
        if styleID == "lianliV150INF" {
            return lianliV150INFParts
        }
        if styleID == "jonsboTK1" {
            return jonsboTK1Parts
        }
        if styleID == "jonsboD33Wood" {
            return jonsboD33WoodParts
        }
        if styleID == "jonsboD34" {
            return jonsboD34Parts
        }
        if styleID == "aigoXuanYingG20" {
            return aigoXuanYingG20Parts
        }
        if styleID == "valkyrieVK3" {
            return valkyrieVK3Parts
        }
        if styleID == "lianliO11EVORGB" {
            return lianliO11EVORGBParts
        }
        if styleID == "phanteksEvolvS2" {
            return phanteksEvolvS2Parts
        }
        if styleID == "phanteksEvolvX2Matrix" {
            return phanteksEvolvX2MatrixParts
        }
        if styleID == "jonsboTK4" {
            return jonsboTK4Parts
        }
        if styleID == "xingcanChenAir" {
            return xingcanChenAirParts
        }
        if styleID == "phanteksNV7" {
            return phanteksNV7Parts
        }
        if styleID == "lianliO11DMiniV2" {
            return lianliO11DMiniV2Parts
        }
        if styleID == "asusTUF502Ammo" {
            return asusTUF502AmmoParts
        }
        if styleID == "rogGR801" {
            return rogGR801Parts
        }
        if styleID == "msiVIXTA300R" {
            return msiVIXTA300RParts
        }
        if styleID == "hangjiaS960V2" {
            return hangjiaS960V2Parts
        }
        if styleID == "hangjiaGX750C" {
            return hangjiaGX750CParts
        }
        if styleID == "coolermasterMF400Mesh" {
            return coolermasterMF400MeshParts
        }
        if styleID == "sugonCiyuanCangPX" {
            return sugonCiyuanCangPXParts
        }
        if styleID == "titanStarship" {
            return titanStarshipParts
        }
        if styleID == "fangtangC34Pro" {
            return fangtangC34ProParts
        }
        if let generatedParts = AestheticGeneratedCatalog.parts(for: styleID) {
            return generatedParts
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

    private static let asusAP202Parts = [
        part("asus-ap202", "机箱", "华硕灵光岛 AP202", 599, [], whitePrice: 649),
        part("asus-ap202", "一体式水冷", "联立隐流 1 代", 499, [
            alternative("联立隐流 2 代", 1599, "同系列现有型号平替"),
            alternative("展域 SE360", 1799, "现有 360 水冷平替"),
            alternative("ROG 龙王 4 代水冷颜值版", 2599, "现有 360 水冷平替"),
            alternative("利民 LV360", 899, "现有 360 水冷平替"),
            alternative("瓦尔基里 N360", 950, "现有 360 水冷平替")
        ]),
        part("asus-ap202", "风扇套装", "乔思伯 ZA360 2 把 + ZA240 1 把 + ZA120 1 把", 499, [
            alternative("联立 4 代积木 LED 风扇 4 把", 800, "现有灯效风扇平替"),
            alternative("丛林豹星际积木 V4 无屏 × 4", 120, "无屏灯效风扇平替"),
            alternative("棱镜 8 Pro × 4", 40, "4 把 × 9.9 元，按现有参考价格取整")
        ])
    ]

    private static let hyteY70Parts = [
        part("hyte-y70", "机箱", "HYTE Y70 TOUCH", 3799, [
            alternative("HYTE Y70 TOUCH（二手）", 1700, "原型号二手，成色以实际为准")
        ]),
        part("hyte-y70", "一体式水冷", "ROG 龙王 4 代水冷颜值版", 2599, [
            alternative("展域 SE360（全新）", 1799, "常规全新参考价格"),
            alternative("展域 SE360（闲鱼全新）", 1499, "闲鱼供货商全新价格"),
            alternative("展域 SE360（二手）", 1000, "原型号二手参考价格"),
            alternative("利民 LV360", 899, "外观相近的全新平替")
        ], whitePrice: 2699),
        part("hyte-y70", "LCD 风扇", "联立 4 代积木 LCD 风扇 4 把", 1465, [
            alternative("丛林豹星际积木 V4 LCD × 4", 796, "带屏风扇 4 把 × 199 元")
        ]),
        part("hyte-y70", "LED 风扇", "联立 4 代积木 LED 风扇 3 把", 600, [
            alternative("丛林豹星际积木 V4 无屏 × 3", 90, "无屏风扇 3 把 × 30 元")
        ])
    ]

    private static let aocShockingBowParts = [
        part("aoc-shocking-bow", "机箱", "AOC CG455B", 299, [
            alternative("AOC CG455B（二手）", 150, "原型号二手，成色以实际为准")
        ], whitePrice: 309),
        part("aoc-shocking-bow", "风扇套装", "棱镜 8 Pro × 10", 99, [
            alternative("丛林豹星际积木 V4 无屏 × 10", 300, "无屏风扇 10 把 × 30 元"),
            alternative("联立 4 代积木 LED 风扇 × 10", 2000, "沿用现有 LED 风扇价格")
        ]),
        part("aoc-shocking-bow", "一体式水冷", "钛坦 LA300", 499, [
            alternative("利民 LV360", 899, "现有水冷型号平替"),
            alternative("瓦尔基里 N360", 950, "现有水冷型号平替"),
            alternative("展域 SE360", 1799, "现有水冷型号平替"),
            alternative("联立隐流 1 代", 499, "现有水冷型号平替"),
            alternative("联立隐流 2 代", 1599, "现有水冷型号平替"),
            alternative("ROG 龙王 4 代水冷颜值版", 2599, "现有水冷型号平替")
        ])
    ]

    private static let bo400CGParts = [
        part("bo400cg", "机箱", "乔思伯 BO400CG", 1599, []),
        part("bo400cg", "风扇套装", "ZA360 风扇 3 把 + ZA120 风扇 1 把", 499, [
            alternative("海中神 ZA 风扇组合", 165, "ZA360 3 把 × 50 元 + ZA120 1 把 × 15 元")
        ]),
        part("bo400cg", "一体式水冷", "ROG 龙王 4 代水冷颜值版", 2599, [
            alternative("展域 SE360（全新）", 1799, "常规全新参考价格"),
            alternative("展域 SE360（闲鱼全新）", 1499, "闲鱼供货商全新价格"),
            alternative("展域 SE360（二手）", 1000, "原型号二手参考价格"),
            alternative("利民 LV360", 899, "外观相近的全新平替")
        ], whitePrice: 2699)
    ]

    private static let visionMinParts = [
        part("vision-min", "机箱", "联力 VISION MIN", 549, []),
        part("vision-min", "一体式水冷", "联立隐流 1 代", 499, [
            alternative("利民 LV360", 900, "沿用 VISION COMPACT 水冷平替"),
            alternative("瓦尔基里 N360", 950, "沿用 VISION COMPACT 水冷平替"),
            alternative("展域 SE360（二手）", 1000, "沿用 VISION COMPACT 水冷平替"),
            alternative("展域 SE360（全新供货）", 1499, "沿用 VISION COMPACT 水冷平替"),
            alternative("展域 SE360（全新）", 1799, "沿用现有水冷价格")
        ]),
        part("vision-min", "副屏", "图灵智显 8.8 寸副屏", 340, [
            alternative("图灵智显 8.8 寸副屏（二手）", 200, "沿用 VISION COMPACT 副屏平替")
        ]),
        part("vision-min", "风扇套装", "联立 LCD 积木风扇 4 把 + LED 积木风扇 3 把", 3000, [
            alternative("丛林豹星际积木 V4 套装", 886, "带屏 4 把 × 199 元 + 无屏 3 把 × 30 元")
        ])
    ]

    private static let hangjiaS960Parts = [
        part("hangjia-s960", "机箱", "航嘉 S960", 159, [], whitePrice: 169),
        part("hangjia-s960", "散热器", "任意风冷或水冷（按选择计价）", 499, []),
        part("hangjia-s960", "风扇套装", "棱镜 8 Pro × 9", 89, [])
    ]

    private static let lianliV150INFParts = [
        part("lianli-v150-inf", "机箱", "联力 V150INF", 549, []),
        part("lianli-v150-inf", "一体式水冷", "联立隐流 1 代", 499, []),
        part("lianli-v150-inf", "风扇套装", "棱镜 8 Pro × 6", 59, [])
    ]

    private static let jonsboTK1Parts = [
        part("jonsbo-tk1", "机箱", "乔思伯 TK-1", 579, []),
        part("jonsbo-tk1", "一体式水冷", "任意水冷（按选择计价）", 499, []),
        part("jonsbo-tk1", "风扇套装", "棱镜 8 Pro × 4", 40, [])
    ]

    private static let jonsboD33WoodParts = [
        part("jonsbo-d33-wood", "机箱", "乔思伯 D33 WOOD", 499, []),
        part("jonsbo-d33-wood", "风扇套装", "乔思伯 ZA360 × 2 + ZA240 × 1 + ZA120 × 1", 499, []),
        part("jonsbo-d33-wood", "一体式水冷", "乔思伯 TX-360", 699, [])
    ]

    private static let jonsboD34Parts = [
        part("jonsbo-d34", "机箱", "乔思伯 D34", 399, [], whitePrice: 459),
        part("jonsbo-d34", "一体式水冷", "钛坦 LG600 240 水冷", 599, []),
        part("jonsbo-d34", "风扇套装", "乔思伯 ZA240 × 2 + ZA120 × 1", 253, [])
    ]

    private static let aigoXuanYingG20Parts = [
        part("aigo-xuan-ying-g20", "机箱", "爱国者 炫影 G20", 189, []),
        part("aigo-xuan-ying-g20", "风扇套装", "棱镜 8 Pro × 8", 79, [])
    ]

    private static let valkyrieVK3Parts = [
        part("valkyrie-vk3", "机箱", "瓦尔基里 VK3", 399, [])
    ]

    private static let lianliO11EVORGBParts = [
        part("lianli-o11-evo-rgb", "机箱", "联力 O11 EVO RGB", 1299, []),
        part("lianli-o11-evo-rgb", "一体式水冷", "展域 SE360", 1799, []),
        part("lianli-o11-evo-rgb", "风扇套装", "联力积木一代风扇 10 把 × 169 元", 1690, [])
    ]

    private static let phanteksEvolvS2Parts = [
        part("phanteks-evolv-s2", "机箱", "追风者 EVOLV S2", 549, []),
        part("phanteks-evolv-s2", "风扇套装", "联力积木四代风扇 7 把（按 200 元/把估算）", 1400, [])
    ]

    private static let phanteksEvolvX2MatrixParts = [
        part("phanteks-evolv-x2-matrix", "机箱", "追风者 EVOLV X2 MATRIX", 549, []),
        part("phanteks-evolv-x2-matrix", "风扇套装", "联力积木四代风扇 7 把（按 200 元/把估算）", 1400, [])
    ]

    private static let jonsboTK4Parts = [
        part("jonsbo-tk4", "机箱", "乔思伯 TK4", 849, []),
        part("jonsbo-tk4", "一体式水冷", "乔思伯 TX-360", 699, []),
        part("jonsbo-tk4", "风扇套装", "乔思伯 ZA360 × 3 + ZA240 × 1", 686, [])
    ]

    private static let xingcanChenAirParts = [
        part("xingcan-chen-air", "机箱", "爱国者 星璨辰 Air", 399, []),
        part("xingcan-chen-air", "风扇套装", "魔方 U360 × 3 + 魔方 U120 × 1", 566, [])
    ]

    private static let phanteksNV7Parts = [
        part("phanteks-nv7", "机箱", "追风者 NV7", 1299, []),
        part("phanteks-nv7", "副屏", "图灵智显 8.8 寸副屏", 340, []),
        part("phanteks-nv7", "风扇套装", "棱镜 8 Pro × 12", 119, []),
        part("phanteks-nv7", "一体式水冷", "钛坦 LG600", 699, [])
    ]

    private static let lianliO11DMiniV2Parts = [
        part("lianli-o11d-mini-v2", "机箱", "联力 O11D MINI V2", 549, [], whitePrice: 599),
        part("lianli-o11d-mini-v2", "风扇套装", "棱镜 8 Pro × 9", 89, []),
        part("lianli-o11d-mini-v2", "一体式水冷", "联力隐流 1 代", 499, [])
    ]

    private static let asusTUF502AmmoParts = [
        part("asus-tuf-502-ammo", "机箱", "华硕 TUF 502 弹药库", 899, []),
        part("asus-tuf-502-ammo", "风扇套装", "联力积木一代风扇 10 把 × 169 元", 1690, []),
        part("asus-tuf-502-ammo", "一体式水冷", "钛坦 LG600", 699, [])
    ]

    private static let rogGR801Parts = [
        part("rog-gr801", "机箱", "ROG GR801 幻世神", 1699, []),
        part("rog-gr801", "一体式水冷", "ROG 龙王 4 代水冷", 2599, [], whitePrice: 2699),
        part("rog-gr801", "LCD 风扇", "联力 4 代积木 LCD 风扇 × 5", 1832, []),
        part("rog-gr801", "LED 风扇", "联力 4 代积木 LED 风扇 × 7", 1400, [])
    ]

    private static let msiVIXTA300RParts = [
        part("msi-vixta-300r", "机箱", "微星 MPG VIXTA 300R", 569, [], whitePrice: 659),
        part("msi-vixta-300r", "风扇套装", "棱镜 8 Pro × 9", 89, []),
        part("msi-vixta-300r", "一体式水冷", "超频三 巨浪 360 ARGB", 399, [])
    ]

    private static let hangjiaS960V2Parts = [
        part("hangjia-s960-v2", "机箱", "航嘉 S960 V2", 169, [], whitePrice: 159),
        part("hangjia-s960-v2", "风扇套装", "棱镜 8 Pro × 9", 89, [])
    ]

    private static let hangjiaGX750CParts = [
        part("hangjia-gx750c", "机箱", "航嘉 GX750C 挑战者", 259, []),
        part("hangjia-gx750c", "风扇套装", "棱镜 8 Pro × 10", 99, [])
    ]

    private static let coolermasterMF400MeshParts = [
        part("coolermaster-mf400-mesh", "机箱", "酷冷至尊 MF400 Mesh", 699, []),
        part("coolermaster-mf400-mesh", "散热器", "酷冷至尊挑战者 V4", 169, []),
        part("coolermaster-mf400-mesh", "风扇套装", "棱镜 8 Pro × 4", 40, [])
    ]

    private static let sugonCiyuanCangPXParts = [
        part("sugon-ciyuan-cang-px", "机箱", "鑫谷次元仓 PX", 299, []),
        part("sugon-ciyuan-cang-px", "一体式水冷", "鑫谷冰智 360", 399, []),
        part("sugon-ciyuan-cang-px", "风扇套装", "魔方 U360 × 3 + 魔方 U120 × 1", 566, [])
    ]

    private static let titanStarshipParts = [
        part("titan-starship", "机箱", "钛坦星舟", 658, []),
        part("titan-starship", "一体式水冷", "钛坦幻世 360", 1599, []),
        part("titan-starship", "风扇套装", "棱镜 8 Pro × 9", 89, [])
    ]

    private static let fangtangC34ProParts = [
        part("fangtang-c34pro", "机箱", "酷方 C34PRO", 899, []),
        part("fangtang-c34pro", "风扇套装", "棱镜 8 Pro × 7", 69, []),
        part("fangtang-c34pro", "一体式水冷", "钛坦 LG600", 699, [])
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
        ),
        style(
            id: "asusAP202",
            title: "华硕灵光岛 AP202",
            summary: "悬浮灯带与双面玻璃结合的紧凑展示方案",
            image: "StyleASUSAP202Black",
            tags: ["悬浮灯带", "紧凑海景房"],
            signature: "保留灵光岛 AP202 机箱和基础灯效结构",
            highDetail: "保留隐流水冷与四风扇布局",
            completeDetail: "完整保留 AP202、隐流水冷和 ZA 风扇组合",
            costs: [AestheticPriceRange(low: 1138, high: 1250), AestheticPriceRange(low: 1350, high: 1500), AestheticPriceRange(low: 1597, high: 1647)],
            premiums: [AestheticPriceRange(low: 180, high: 260), AestheticPriceRange(low: 360, high: 480), AestheticPriceRange(low: 520, high: 680)]
        ),
        style(
            id: "hyteY70",
            title: "HYTE Y70 鱼缸机箱",
            summary: "纵向触控副屏与七把积木风扇组成的沉浸式展示方案",
            image: "StyleHYTEY70Black",
            tags: ["触控副屏", "鱼缸机箱"],
            signature: "保留 HYTE Y70 TOUCH 机箱与正面触控屏",
            highDetail: "保留龙王水冷和 LCD 风扇展示效果",
            completeDetail: "完整保留 Y70 TOUCH、龙王水冷与七把积木风扇",
            costs: [AestheticPriceRange(low: 3485, high: 4000), AestheticPriceRange(low: 6000, high: 7000), AestheticPriceRange(low: 8463, high: 8563)],
            premiums: [AestheticPriceRange(low: 850, high: 1100), AestheticPriceRange(low: 1600, high: 2100), AestheticPriceRange(low: 2500, high: 3200)]
        ),
        style(
            id: "aocShockingBow",
            title: "AOC 震天弓",
            summary: "超宽鱼缸机箱与十把灯效风扇组成的沉浸式展示方案",
            image: "StyleAOCShockingBowBlack",
            tags: ["超宽鱼缸", "十把风扇"],
            signature: "保留 AOC CG455B 机箱与基础灯效布局",
            highDetail: "保留钛坦水冷和十把棱镜风扇",
            completeDetail: "完整保留震天弓机箱、LA300 与十把风扇",
            costs: [AestheticPriceRange(low: 748, high: 900), AestheticPriceRange(low: 1000, high: 1150), AestheticPriceRange(low: 1297, high: 1307)],
            premiums: [AestheticPriceRange(low: 120, high: 180), AestheticPriceRange(low: 280, high: 380), AestheticPriceRange(low: 500, high: 700)]
        ),
        style(
            id: "bo400cg",
            title: "乔思伯 BO400CG",
            summary: "四面圆角铝框与环形灯效风扇组成的高端展示方案",
            image: "StyleJonsboBO400CGBlack",
            tags: ["圆角铝框", "环形灯效"],
            signature: "保留 BO400CG 机箱和基础灯效布局",
            highDetail: "保留龙王水冷与 ZA 风扇组合",
            completeDetail: "完整保留 BO400CG、龙王水冷和四风扇布局",
            costs: [AestheticPriceRange(low: 2663, high: 3000), AestheticPriceRange(low: 3800, high: 4200), AestheticPriceRange(low: 4697, high: 4797)],
            premiums: [AestheticPriceRange(low: 400, high: 550), AestheticPriceRange(low: 1000, high: 1400), AestheticPriceRange(low: 1900, high: 2400)]
        ),
        style(
            id: "visionMin",
            title: "联立 Vison Min",
            summary: "紧凑双面玻璃机箱与屏显风扇组成的小型展示方案",
            image: "StyleLianLiVisionMinBlack",
            tags: ["紧凑海景房", "LCD 风扇"],
            signature: "保留 Vison Min 机箱和核心展示结构",
            highDetail: "保留副屏、隐流水冷和七把灯效风扇",
            completeDetail: "完整保留 Vison Min、四把 LCD 风扇、三把 LED 风扇与副屏",
            costs: [AestheticPriceRange(low: 2134, high: 2500), AestheticPriceRange(low: 3200, high: 3600), AestheticPriceRange(low: 4388, high: 4388)],
            premiums: [AestheticPriceRange(low: 300, high: 450), AestheticPriceRange(low: 900, high: 1300), AestheticPriceRange(low: 1800, high: 2400)]
        ),
        style(
            id: "hangjiaS960",
            title: "航嘉 S960",
            summary: "高性价比双面玻璃机箱与九把灯效风扇组合",
            image: "StyleHangjiaS960Black",
            tags: ["高性价比", "九把风扇"],
            signature: "保留 S960 机箱和基础风扇布局",
            highDetail: "保留九把棱镜风扇和可选散热器",
            completeDetail: "完整保留 S960、九把棱镜风扇与自选散热器",
            costs: [AestheticPriceRange(low: 747, high: 757), AestheticPriceRange(low: 747, high: 757), AestheticPriceRange(low: 747, high: 757)],
            premiums: [AestheticPriceRange(low: 120, high: 180), AestheticPriceRange(low: 220, high: 320), AestheticPriceRange(low: 350, high: 500)]
        ),
        style(
            id: "lianliV150INF",
            title: "联力 V150INF",
            summary: "前置双风扇与紧凑海景房结构组成的垂直展示方案",
            image: "StyleLianLiV150INFBlack",
            tags: ["紧凑机箱", "双前置风扇"],
            signature: "保留 V150INF 机箱和基础灯效",
            highDetail: "保留隐流水冷与六把棱镜风扇",
            completeDetail: "完整保留 V150INF、隐流水冷和六把风扇",
            costs: [AestheticPriceRange(low: 1107, high: 1107), AestheticPriceRange(low: 1107, high: 1107), AestheticPriceRange(low: 1107, high: 1107)],
            premiums: [AestheticPriceRange(low: 180, high: 260), AestheticPriceRange(low: 360, high: 480), AestheticPriceRange(low: 520, high: 700)]
        ),
        style(
            id: "jonsboTK1",
            title: "乔思伯 TK-1",
            summary: "紧凑竖置结构与底部灯效风扇组成的小型展示方案",
            image: "StyleJonsboTK1Black",
            tags: ["紧凑机箱", "底部风扇"],
            signature: "保留 TK-1 机箱和底部风扇布局",
            highDetail: "保留四把棱镜风扇与自选水冷",
            completeDetail: "完整保留 TK-1、四把棱镜风扇和水冷",
            costs: [AestheticPriceRange(low: 1118, high: 1118), AestheticPriceRange(low: 1118, high: 1118), AestheticPriceRange(low: 1118, high: 1118)],
            premiums: [AestheticPriceRange(low: 160, high: 240), AestheticPriceRange(low: 300, high: 420), AestheticPriceRange(low: 500, high: 700)]
        ),
        style(
            id: "jonsboD33Wood",
            title: "乔思伯 D33 WOOD",
            summary: "木纹前面板与横向展示结构结合的温润海景房方案",
            image: "StyleJonsboD33WoodBlack",
            tags: ["木纹面板", "横向展示"],
            signature: "保留 D33 WOOD 机箱和木纹前面板",
            highDetail: "保留 ZA 风扇组合与 TX-360 水冷",
            completeDetail: "完整保留 D33 WOOD、四把 ZA 风扇和 TX-360",
            costs: [AestheticPriceRange(low: 1697, high: 1697), AestheticPriceRange(low: 1697, high: 1697), AestheticPriceRange(low: 1697, high: 1697)],
            premiums: [AestheticPriceRange(low: 220, high: 320), AestheticPriceRange(low: 420, high: 600), AestheticPriceRange(low: 700, high: 950)]
        ),
        style(
            id: "jonsboD34",
            title: "乔思伯 D34",
            summary: "双面玻璃机箱与侧面屏显、灯效风扇组合的展示方案",
            image: "StyleJonsboD34Black",
            tags: ["乔思伯", "屏显机箱"],
            signature: "保留 D34 机箱和基础灯效布局",
            highDetail: "保留钛坦 LG600 240 水冷与 ZA 风扇组合",
            completeDetail: "完整保留 D34、LG600 240 水冷和两把 ZA240、一把 ZA120",
            costs: [AestheticPriceRange(low: 1251, high: 1311), AestheticPriceRange(low: 1251, high: 1311), AestheticPriceRange(low: 1251, high: 1311)],
            premiums: [AestheticPriceRange(low: 0, high: 0), AestheticPriceRange(low: 0, high: 0), AestheticPriceRange(low: 0, high: 0)]
        ),
        style(
            id: "aigoXuanYingG20",
            title: "爱国者 炫影 G20",
            summary: "双面玻璃与八把灯效风扇组成的高性价比海景房方案",
            image: "StyleAigoXuanYingG20Black",
            tags: ["海景房", "八把风扇"],
            signature: "保留炫影 G20 机箱和基础风扇布局",
            highDetail: "保留八把棱镜 8 Pro 风扇",
            completeDetail: "完整保留炫影 G20 与八把棱镜 8 Pro 风扇",
            costs: [AestheticPriceRange(low: 268, high: 268), AestheticPriceRange(low: 268, high: 268), AestheticPriceRange(low: 268, high: 268)],
            premiums: [AestheticPriceRange(low: 80, high: 120), AestheticPriceRange(low: 160, high: 240), AestheticPriceRange(low: 260, high: 380)]
        ),
        style(
            id: "valkyrieVK3",
            title: "瓦尔基里 VK3",
            summary: "大体积海景房机箱与底部屏幕组成的旗舰展示方案",
            image: "StyleValkyrieVK3Black",
            tags: ["海景房", "底部屏幕"],
            signature: "保留 VK3 机箱和整体展示结构",
            highDetail: "保留 VK3 的底部屏幕与通透玻璃结构",
            completeDetail: "完整保留 VK3 机箱及其展示结构",
            costs: [AestheticPriceRange(low: 399, high: 399), AestheticPriceRange(low: 399, high: 399), AestheticPriceRange(low: 399, high: 399)],
            premiums: [AestheticPriceRange(low: 100, high: 160), AestheticPriceRange(low: 220, high: 320), AestheticPriceRange(low: 360, high: 520)]
        ),
        style(
            id: "lianliO11EVORGB",
            title: "联力 O11 EVO RGB",
            summary: "双面玻璃海景房与十把积木风扇组成的高亮展示方案",
            image: "StyleLianLiO11EVORGBBlack",
            tags: ["海景房", "十把风扇"],
            signature: "保留 O11 EVO RGB 机箱和基础灯效布局",
            highDetail: "保留展域 SE360 水冷与十把积木风扇",
            completeDetail: "完整保留 O11 EVO RGB、展域 SE360 和十把联力积木一代风扇",
            costs: [AestheticPriceRange(low: 4788, high: 4788), AestheticPriceRange(low: 4788, high: 4788), AestheticPriceRange(low: 4788, high: 4788)],
            premiums: [AestheticPriceRange(low: 0, high: 0), AestheticPriceRange(low: 0, high: 0), AestheticPriceRange(low: 0, high: 0)]
        ),
        style(
            id: "phanteksEvolvS2",
            title: "追风者 EVOLV S2",
            summary: "顶部与底部风扇布局结合双面玻璃的简洁海景房方案",
            image: "StylePhanteksEvolvS2Black",
            tags: ["海景房", "七把风扇"],
            signature: "保留 EVOLV S2 机箱和基础风扇布局",
            highDetail: "保留七把联力积木四代风扇",
            completeDetail: "完整保留 EVOLV S2 和七把联力积木四代风扇",
            costs: [AestheticPriceRange(low: 1949, high: 1949), AestheticPriceRange(low: 1949, high: 1949), AestheticPriceRange(low: 1949, high: 1949)],
            premiums: [AestheticPriceRange(low: 0, high: 0), AestheticPriceRange(low: 0, high: 0), AestheticPriceRange(low: 0, high: 0)]
        ),
        style(
            id: "phanteksEvolvX2Matrix",
            title: "追风者 EVOLV X2 MATRIX",
            summary: "矩阵屏显与双面玻璃结合的高辨识度海景房方案",
            image: "StylePhanteksEvolvX2MatrixBlack",
            tags: ["海景房", "矩阵屏显"],
            signature: "保留 EVOLV X2 MATRIX 机箱和矩阵屏显结构",
            highDetail: "保留七把联力积木四代风扇",
            completeDetail: "完整保留 EVOLV X2 MATRIX 和七把联力积木四代风扇",
            costs: [AestheticPriceRange(low: 1949, high: 1949), AestheticPriceRange(low: 1949, high: 1949), AestheticPriceRange(low: 1949, high: 1949)],
            premiums: [AestheticPriceRange(low: 0, high: 0), AestheticPriceRange(low: 0, high: 0), AestheticPriceRange(low: 0, high: 0)]
        ),
        style(
            id: "jonsboTK4",
            title: "乔思伯 TK4",
            summary: "双面玻璃机箱与侧面风扇墙组成的高亮展示方案",
            image: "StyleJonsboTK4Black",
            tags: ["海景房", "侧面风扇墙"],
            signature: "保留 TK4 机箱和基础风扇布局",
            highDetail: "保留 TX-360 水冷与 ZA 风扇组合",
            completeDetail: "完整保留 TK4、TX-360 和四把 ZA 风扇",
            costs: [AestheticPriceRange(low: 2234, high: 2234), AestheticPriceRange(low: 2234, high: 2234), AestheticPriceRange(low: 2234, high: 2234)],
            premiums: [AestheticPriceRange(low: 0, high: 0), AestheticPriceRange(low: 0, high: 0), AestheticPriceRange(low: 0, high: 0)]
        ),
        style(
            id: "xingcanChenAir",
            title: "爱国者 星璨辰 Air",
            summary: "紧凑海景房机箱与魔方风扇组合的轻量展示方案",
            image: "StyleAigoXingcanChenAirBlack",
            tags: ["海景房", "魔方风扇"],
            signature: "保留星璨辰 Air 机箱和基础风扇布局",
            highDetail: "保留三把 U360 与一把 U120 风扇",
            completeDetail: "完整保留星璨辰 Air 和四把魔方风扇",
            costs: [AestheticPriceRange(low: 965, high: 965), AestheticPriceRange(low: 965, high: 965), AestheticPriceRange(low: 965, high: 965)],
            premiums: [AestheticPriceRange(low: 0, high: 0), AestheticPriceRange(low: 0, high: 0), AestheticPriceRange(low: 0, high: 0)]
        ),
        style(
            id: "phanteksNV7",
            title: "追风者 NV7",
            summary: "大体积海景房与副屏、十二把风扇组成的旗舰展示方案",
            image: "StylePhanteksNV7Black",
            tags: ["旗舰海景房", "副屏展示"],
            signature: "保留 NV7 机箱和基础风扇布局",
            highDetail: "保留 8.8 寸副屏、LG600 水冷和十二把风扇",
            completeDetail: "完整保留 NV7、图灵副屏、LG600 与十二把棱镜风扇",
            costs: [AestheticPriceRange(low: 2457, high: 2457), AestheticPriceRange(low: 2457, high: 2457), AestheticPriceRange(low: 2457, high: 2457)],
            premiums: [AestheticPriceRange(low: 0, high: 0), AestheticPriceRange(low: 0, high: 0), AestheticPriceRange(low: 0, high: 0)]
        ),
        style(
            id: "lianliO11DMiniV2",
            title: "联力 O11D MINI V2",
            summary: "紧凑双面玻璃机箱与九把灯效风扇组成的高亮展示方案",
            image: "StyleLianLiO11DMiniV2Black",
            tags: ["紧凑海景房", "九把风扇"],
            signature: "保留 O11D MINI V2 机箱和基础风扇布局",
            highDetail: "保留隐流一代水冷与九把棱镜风扇",
            completeDetail: "完整保留 O11D MINI V2、隐流一代和九把棱镜 8 Pro",
            costs: [AestheticPriceRange(low: 1137, high: 1187), AestheticPriceRange(low: 1137, high: 1187), AestheticPriceRange(low: 1137, high: 1187)],
            premiums: [AestheticPriceRange(low: 0, high: 0), AestheticPriceRange(low: 0, high: 0), AestheticPriceRange(low: 0, high: 0)]
        ),
        style(
            id: "asusTUF502Ammo",
            title: "华硕 TUF 502 弹药库",
            summary: "模块化机箱与十把积木风扇组成的高辨识度展示方案",
            image: "StyleASUSTUF502AmmoBlack",
            tags: ["模块化机箱", "十把风扇"],
            signature: "保留 TUF 502 弹药库机箱和基础风扇布局",
            highDetail: "保留十把联力积木一代风扇和 LG600 水冷",
            completeDetail: "完整保留 TUF 502 弹药库、十把风扇和 LG600",
            costs: [AestheticPriceRange(low: 3288, high: 3288), AestheticPriceRange(low: 3288, high: 3288), AestheticPriceRange(low: 3288, high: 3288)],
            premiums: [AestheticPriceRange(low: 0, high: 0), AestheticPriceRange(low: 0, high: 0), AestheticPriceRange(low: 0, high: 0)]
        ),
        style(
            id: "rogGR801",
            title: "ROG GR801 幻世神",
            summary: "旗舰级 ROG 机箱与 LCD、LED 积木风扇组成的展示方案",
            image: "StyleROGGR801Black",
            tags: ["ROG", "旗舰海景房"],
            signature: "保留 GR801 幻世神机箱和基础灯效布局",
            highDetail: "保留龙王四代水冷与 LCD 风扇展示效果",
            completeDetail: "完整保留 GR801、龙王四代水冷、五把 LCD 和七把 LED 风扇",
            costs: [AestheticPriceRange(low: 7530, high: 7630), AestheticPriceRange(low: 7530, high: 7630), AestheticPriceRange(low: 7530, high: 7630)],
            premiums: [AestheticPriceRange(low: 0, high: 0), AestheticPriceRange(low: 0, high: 0), AestheticPriceRange(low: 0, high: 0)]
        ),
        style(
            id: "msiVIXTA300R",
            title: "微星 MPG VIXTA 300R",
            summary: "微星海景房机箱与九把灯效风扇组成的高性价比展示方案",
            image: "StyleMSIVIXTA300RBlack",
            tags: ["微星", "九把风扇"],
            signature: "保留 VIXTA 300R 机箱和基础风扇布局",
            highDetail: "保留九把棱镜 8 Pro 风扇与巨浪 360 水冷",
            completeDetail: "完整保留 VIXTA 300R、九把棱镜 8 Pro 风扇和巨浪 360 ARGB",
            costs: [AestheticPriceRange(low: 1057, high: 1147), AestheticPriceRange(low: 1057, high: 1147), AestheticPriceRange(low: 1057, high: 1147)],
            premiums: [AestheticPriceRange(low: 0, high: 0), AestheticPriceRange(low: 0, high: 0), AestheticPriceRange(low: 0, high: 0)]
        ),
        style(
            id: "hangjiaS960V2",
            title: "航嘉 S960 V2",
            summary: "航嘉海景房机箱与九把灯效风扇组成的紧凑展示方案",
            image: "StyleHangjiaS960V2Black",
            tags: ["航嘉", "九把风扇"],
            signature: "保留 S960 V2 机箱和基础风扇布局",
            highDetail: "保留九把棱镜 8 Pro 风扇",
            completeDetail: "完整保留 S960 V2 与九把棱镜 8 Pro 风扇",
            costs: [AestheticPriceRange(low: 248, high: 258), AestheticPriceRange(low: 248, high: 258), AestheticPriceRange(low: 248, high: 258)],
            premiums: [AestheticPriceRange(low: 0, high: 0), AestheticPriceRange(low: 0, high: 0), AestheticPriceRange(low: 0, high: 0)]
        ),
        style(
            id: "hangjiaGX750C",
            title: "航嘉 GX750C 挑战者",
            summary: "前置网孔机箱与十把灯效风扇组成的高性价比方案",
            image: "StyleHangjiaGX750CBlack",
            tags: ["航嘉", "十把风扇"],
            signature: "保留 GX750C 挑战者机箱和基础风扇布局",
            highDetail: "保留十把棱镜 8 Pro 风扇",
            completeDetail: "完整保留 GX750C 挑战者与十把棱镜 8 Pro 风扇",
            costs: [AestheticPriceRange(low: 358, high: 358), AestheticPriceRange(low: 358, high: 358), AestheticPriceRange(low: 358, high: 358)],
            premiums: [AestheticPriceRange(low: 0, high: 0), AestheticPriceRange(low: 0, high: 0), AestheticPriceRange(low: 0, high: 0)]
        ),
        style(
            id: "coolermasterMF400Mesh",
            title: "酷冷至尊 MF400 Mesh",
            summary: "紧凑网孔机箱与挑战者 V4 散热器组成的桌面展示方案",
            image: "StyleCoolerMasterMF400MeshBlack",
            tags: ["酷冷至尊", "紧凑机箱"],
            signature: "保留 MF400 Mesh 机箱和基础风扇布局",
            highDetail: "保留挑战者 V4 散热器与四把棱镜 8 Pro 风扇",
            completeDetail: "完整保留 MF400 Mesh、挑战者 V4 和四把棱镜 8 Pro 风扇",
            costs: [AestheticPriceRange(low: 908, high: 908), AestheticPriceRange(low: 908, high: 908), AestheticPriceRange(low: 908, high: 908)],
            premiums: [AestheticPriceRange(low: 0, high: 0), AestheticPriceRange(low: 0, high: 0), AestheticPriceRange(low: 0, high: 0)]
        ),
        style(
            id: "sugonCiyuanCangPX",
            title: "鑫谷次元仓 PX",
            summary: "带前置屏幕的次元仓机箱与魔方风扇组成的展示方案",
            image: "StyleSugonCiyuanCangPXBlack",
            tags: ["鑫谷", "前置屏幕"],
            signature: "保留次元仓 PX 机箱和基础灯效布局",
            highDetail: "保留冰智 360 水冷与魔方风扇组合",
            completeDetail: "完整保留次元仓 PX、冰智 360、三把 U360 和一把 U120",
            costs: [AestheticPriceRange(low: 1264, high: 1264), AestheticPriceRange(low: 1264, high: 1264), AestheticPriceRange(low: 1264, high: 1264)],
            premiums: [AestheticPriceRange(low: 0, high: 0), AestheticPriceRange(low: 0, high: 0), AestheticPriceRange(low: 0, high: 0)]
        ),
        style(
            id: "titanStarship",
            title: "钛坦星舟",
            summary: "双面玻璃机箱与幻世水冷、九把灯效风扇组成的展示方案",
            image: "StyleTitanStarshipBlack",
            tags: ["钛坦", "九把风扇"],
            signature: "保留星舟机箱和基础风扇布局",
            highDetail: "保留幻世 360 水冷与九把棱镜 8 Pro 风扇",
            completeDetail: "完整保留星舟、幻世 360 和九把棱镜 8 Pro 风扇",
            costs: [AestheticPriceRange(low: 2346, high: 2346), AestheticPriceRange(low: 2346, high: 2346), AestheticPriceRange(low: 2346, high: 2346)],
            premiums: [AestheticPriceRange(low: 0, high: 0), AestheticPriceRange(low: 0, high: 0), AestheticPriceRange(low: 0, high: 0)]
        ),
        style(
            id: "fangtangC34Pro",
            title: "方糖机械大师 酷方 C34PRO",
            summary: "机械风格机箱与七把灯效风扇组成的高辨识度展示方案",
            image: "StyleFangtangC34ProBlack",
            tags: ["方糖机械大师", "七把风扇"],
            signature: "保留酷方 C34PRO 机箱和基础风扇布局",
            highDetail: "保留钛坦 LG600 水冷与七把棱镜 8 Pro 风扇",
            completeDetail: "完整保留酷方 C34PRO、LG600 和七把棱镜 8 Pro 风扇",
            costs: [AestheticPriceRange(low: 1667, high: 1667), AestheticPriceRange(low: 1667, high: 1667), AestheticPriceRange(low: 1667, high: 1667)],
            premiums: [AestheticPriceRange(low: 0, high: 0), AestheticPriceRange(low: 0, high: 0), AestheticPriceRange(low: 0, high: 0)]
        ),
        style(
            id: "cougarV235",
            title: "骨伽凌空V235",
            summary: "双面玻璃机箱与九把灯效风扇、360 水冷组成的海景房方案",
            image: "StyleCougarV235Black",
            tags: ["海景房", "九把风扇"],
            signature: "保留骨伽凌空 V235 机箱和基础风扇布局",
            highDetail: "保留九把棱镜 8 Pro 风扇与 PV360 水冷",
            completeDetail: "完整保留凌空 V235、九把棱镜 8 Pro 风扇和 PV360 水冷",
            costs: [AestheticPriceRange(low: 1037, high: 1037), AestheticPriceRange(low: 1037, high: 1037), AestheticPriceRange(low: 1037, high: 1037)],
            premiums: [AestheticPriceRange(low: 0, high: 0), AestheticPriceRange(low: 0, high: 0), AestheticPriceRange(low: 0, high: 0)]
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
