import Foundation

enum AIBuildStep: Int, CaseIterable {
    case budget
    case scenario
    case purchase
    case hardware

    var title: String {
        switch self {
        case .budget:
            return "预算和用途"
        case .scenario:
            return "场景选择"
        case .purchase:
            return "购买和外观"
        case .hardware:
            return "补充偏好"
        }
    }

    var subtitle: String {
        switch self {
        case .budget:
            return "先确定大方向，AI 会按预算控制配置。"
        case .scenario:
            return "告诉 AI 你主要玩哪些游戏。"
        case .purchase:
            return "选择你能接受的购买方式和主机外观。"
        case .hardware:
            return "再补充一个会影响配置取舍的问题。"
        }
    }
}

enum AIBuildOwnedPart: String, CaseIterable, Identifiable {
    case none
    case gpu
    case cpu
    case motherboardBundle
    case memory
    case storage
    case psu
    case casePart

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none:
            return "没有"
        case .gpu:
            return "显卡"
        case .cpu:
            return "CPU"
        case .motherboardBundle:
            return "CPU / 主板套装"
        case .memory:
            return "内存"
        case .storage:
            return "硬盘"
        case .psu:
            return "电源"
        case .casePart:
            return "机箱"
        }
    }

    var isHighValue: Bool {
        switch self {
        case .gpu, .cpu, .motherboardBundle:
            return true
        case .none, .memory, .storage, .psu, .casePart:
            return false
        }
    }
}

struct AIBuildLowBudgetDefaults: Equatable {
    let purchasePreference: String
    let buildPreference: BuildPreference
    let colorPreference: String
}

struct AIBuildPerformanceSelection: Equatable {
    let gameIDs: [String]
    let unavailableGameNames: [String]
}

enum AIBuildDirection: String, CaseIterable, Identifiable {
    case fps
    case aaa
    case balanced

    var id: Self { self }

    var title: String {
        switch self {
        case .fps:
            return "FPS主机"
        case .aaa:
            return "3A主机"
        case .balanced:
            return "全能均衡"
        }
    }

    var recommendation: String {
        switch self {
        case .fps:
            return "这类游戏更依赖 CPU，预算会适当向 CPU 倾斜，优先保证高帧率和低帧稳定性。"
        case .aaa:
            return "这类游戏更依赖显卡，预算会适当向显卡倾斜，优先保证高画质下的流畅度。"
        case .balanced:
            return "你选择的游戏类型比较丰富，预算会在 CPU 和显卡之间保持均衡。"
        }
    }

    var summary: String {
        switch self {
        case .fps:
            return "CPU 优先，适合高帧率竞技游戏"
        case .aaa:
            return "显卡优先，适合高画质大型游戏"
        case .balanced:
            return "CPU 与显卡均衡，适合多种游戏"
        }
    }
}

enum AIBuildFlowRules {
    static let lowBudgetThreshold = 4000
    static let gpuPreferenceMinimumBudget = 8000

    private static let fpsGames: Set<String> = ["瓦罗兰特", "CS2", "PUBG", "永劫无间"]
    private static let balancedGames: Set<String> = ["暗区突围", "NBA2K", "穿越火线"]
    private static let aaaGames: Set<String> = ["三角洲行动", "赛博朋克2077", "荒野大镖客2", "GTA5", "黑神话悟空", "地平线6", "艾尔登法环"]
    private static let performanceGameIDs = [
        "瓦罗兰特": "valorant",
        "CS2": "cs2",
        "PUBG": "pubg",
        "三角洲行动": "delta-force",
        "云顶之弈": "teamfight-tactics",
        "LOL": "league-of-legends",
        "COD": "call-of-duty-warzone",
        "赛博朋克2077": "cyberpunk-2077",
        "荒野大镖客2": "red-dead-redemption-2",
        "GTA5": "gta-v",
        "黑神话悟空": "black-myth-wukong",
        "地平线6": "forza-horizon-6",
        "艾尔登法环": "elden-ring",
        "城市天际线": "cities-skylines",
        "我的世界": "minecraft-java-edition"
    ]
    private static let gamesPendingPerformanceData = ["永劫无间", "暗区突围", "NBA2K", "穿越火线"]

    static func shouldSkipOptionSelection(optionCount: Int) -> Bool {
        optionCount == 1
    }

    static func recommendedDirection(for games: Set<String>) -> AIBuildDirection {
        if games.isEmpty || games.contains("什么都玩") {
            return .balanced
        }
        if games.isSubset(of: fpsGames) {
            return .fps
        }
        if games.isSubset(of: aaaGames) {
            return .aaa
        }
        if games.isSubset(of: balancedGames) {
            return .balanced
        }
        return .balanced
    }

    static func performanceSelection(for games: [String]) -> AIBuildPerformanceSelection {
        if games.contains("什么都玩") {
            return AIBuildPerformanceSelection(
                gameIDs: ["all-games"],
                unavailableGameNames: gamesPendingPerformanceData
            )
        }

        return AIBuildPerformanceSelection(
            gameIDs: games.compactMap { performanceGameIDs[$0] },
            unavailableGameNames: games.filter { performanceGameIDs[$0] == nil }
        )
    }

    static func visibleSteps(budget: Int, ownedParts: Set<AIBuildOwnedPart>) -> [AIBuildStep] {
        usesLowBudgetMode(budget: budget, ownedParts: ownedParts)
            ? [.budget, .scenario]
            : AIBuildStep.allCases
    }

    static func usesLowBudgetMode(budget: Int, ownedParts: Set<AIBuildOwnedPart>) -> Bool {
        budget < lowBudgetThreshold && !ownedParts.contains(where: \.isHighValue)
    }

    static func shouldShowGPUPreference(
        budget: Int,
        useCase: String,
        hasOwnedGPU: Bool
    ) -> Bool {
        budget >= gpuPreferenceMinimumBudget && useCase == "游戏" && !hasOwnedGPU
    }

    static func lowBudgetDefaults(useCase: String) -> AIBuildLowBudgetDefaults {
        if useCase == "办公" {
            return AIBuildLowBudgetDefaults(
                purchasePreference: "全新优先",
                buildPreference: .balanced,
                colorPreference: "颜色不限"
            )
        }
        return AIBuildLowBudgetDefaults(
            purchasePreference: "部分配件二手",
            buildPreference: useCase == "游戏" ? .performance : .balanced,
            colorPreference: "颜色不限"
        )
    }
}

/// Pure paging rules shared by the AI build wizard and its focused tests.
/// Pages are zero-based: budget = 0, games = 1, preferences = 2, capacity = 3.
enum AIBuildPagerRules {
    static let pageCount = 4
    static let defaultThresholdRatio = 0.18
    static let defaultRubberBandFactor = 0.22

    static let gamesPage = 1
    static let preferencesPage = 2

    static func clampedPage(_ page: Int, pageCount: Int = Self.pageCount) -> Int {
        guard pageCount > 0 else { return 0 }
        return min(max(page, 0), pageCount - 1)
    }

    /// Keeps a page-following drag within one page and adds resistance when
    /// pulling beyond the first or last page.
    static func dragOffset(
        translation: Double,
        currentPage: Int,
        pageExtent: Double,
        pageCount: Int = Self.pageCount,
        rubberBandFactor: Double = Self.defaultRubberBandFactor
    ) -> Double {
        guard pageCount > 0, translation.isFinite, pageExtent.isFinite else { return 0 }
        let extent = abs(pageExtent)
        guard extent > 0 else { return 0 }

        let page = clampedPage(currentPage, pageCount: pageCount)
        let clampedTranslation = min(max(translation, -extent), extent)
        let isOutward = (page == 0 && clampedTranslation > 0)
            || (page == pageCount - 1 && clampedTranslation < 0)
        guard isOutward else { return clampedTranslation }

        let factor = min(max(rubberBandFactor, 0), 1)
        return clampedTranslation * factor
    }

    static func dragProgress(
        translation: Double,
        currentPage: Int,
        pageExtent: Double,
        pageCount: Int = Self.pageCount,
        rubberBandFactor: Double = Self.defaultRubberBandFactor
    ) -> Double {
        let extent = abs(pageExtent)
        guard extent > 0, extent.isFinite else { return 0 }
        return dragOffset(
            translation: translation,
            currentPage: currentPage,
            pageExtent: extent,
            pageCount: pageCount,
            rubberBandFactor: rubberBandFactor
        ) / extent
    }

    /// Chooses the adjacent page after release. A negative translation means
    /// an upward swipe (forward); a positive translation means backward.
    static func targetPage(
        currentPage: Int,
        translation: Double,
        pageExtent: Double,
        pageCount: Int = Self.pageCount,
        thresholdRatio: Double = Self.defaultThresholdRatio,
        selectedGameCount: Int? = nil
    ) -> Int {
        let current = clampedPage(currentPage, pageCount: pageCount)
        let extent = abs(pageExtent)
        guard pageCount > 1, translation.isFinite, extent > 0, extent.isFinite else { return current }

        let ratio = min(max(thresholdRatio, 0), 1)
        guard abs(translation) >= extent * ratio, translation != 0 else { return current }

        let direction = translation < 0 ? 1 : -1
        let candidate = clampedPage(current + direction, pageCount: pageCount)
        guard candidate != current else { return current }

        guard let selectedGameCount else { return candidate }
        return canAdvance(
            from: current,
            to: candidate,
            selectedGameCount: selectedGameCount,
            pageCount: pageCount
        ) ? candidate : current
    }

    /// Validates a settled transition. Every transition is exactly one page;
    /// the games page cannot advance to preferences without a game selected.
    static func canAdvance(
        from currentPage: Int,
        to targetPage: Int,
        selectedGameCount: Int,
        pageCount: Int = Self.pageCount
    ) -> Bool {
        guard pageCount > 0,
              currentPage >= 0, currentPage < pageCount,
              targetPage >= 0, targetPage < pageCount,
              abs(targetPage - currentPage) == 1 else {
            return false
        }

        if currentPage == gamesPage,
           targetPage == preferencesPage,
           selectedGameCount <= 0 {
            return false
        }
        return true
    }

    static func canAdvance(
        from currentPage: Int,
        to targetPage: Int,
        selectedGames: [String],
        pageCount: Int = Self.pageCount
    ) -> Bool {
        canAdvance(
            from: currentPage,
            to: targetPage,
            selectedGameCount: selectedGames.count,
            pageCount: pageCount
        )
    }
}
