import Foundation

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

enum UpgradeGoal: Int, CaseIterable, Identifiable {
    case diagnose = 1
    case gaming
    case everyday
    case productivity

    var id: Int { rawValue }
    var number: String { String(format: "%02d", rawValue) }

    static let selectableCases: [UpgradeGoal] = [.diagnose, .gaming]

    var title: String {
        switch self {
        case .diagnose: return "帮我判断短板"
        case .gaming: return "游戏帧率和画质"
        case .everyday: return "日常卡顿和多任务"
        case .productivity: return "剪辑和渲染效率"
        }
    }

    var compactTitle: String {
        switch self {
        case .diagnose: return "帮我找短板"
        case .gaming: return "游戏性能"
        case .everyday: return "日常卡顿"
        case .productivity: return "剪辑渲染"
        }
    }

    var symbolName: String {
        switch self {
        case .diagnose: return "checkmark.shield"
        case .gaming: return "gamecontroller"
        case .everyday: return "exclamationmark.display"
        case .productivity: return "movieclapper"
        }
    }

    var conditionsTitle: String {
        switch self {
        case .diagnose: return "短板判断条件"
        case .gaming: return "游戏性能目标"
        case .everyday: return "日常体验目标"
        case .productivity: return "生产力性能目标"
        }
    }

    var resultHeadline: String {
        switch self {
        case .diagnose: return "这台电脑，\n先找准真正短板。"
        case .gaming: return "这台电脑，\n先升级显卡。"
        case .everyday: return "这台电脑，\n先补足内存。"
        case .productivity: return "这台电脑，\n先强化处理器。"
        }
    }

    var priorityLabel: String {
        switch self {
        case .diagnose: return "综合短板"
        case .gaming: return "显卡优先"
        case .everyday: return "内存优先"
        case .productivity: return "CPU 优先"
        }
    }
}

enum UpgradeResolution: String, CaseIterable, Identifiable {
    case fullHD = "1080P"
    case twoK = "2K"
    case fourK = "4K"

    var id: String { rawValue }
}

enum UpgradeFrameTarget: Int, CaseIterable, Identifiable {
    case smooth = 60
    case highRefresh = 144
    case esports = 240

    var id: Int { rawValue }
    var title: String { "\(rawValue)" }
}

struct UpgradePlanConfiguration: Equatable {
    var step: UpgradePlanStep
    var hardwareProfile: HardwareProfile
    var goal: UpgradeGoal
    var budget: Int
    var selectedGames: Set<String>
    var resolution: UpgradeResolution
    var frameTarget: UpgradeFrameTarget
    var componentPreference: String

    static let categories = HardwareProfileOptions.categories
    static let games = ["CS2", "PUBG", "无畏契约", "英雄联盟", "永劫无间", "原神", "APEX 英雄", "使命召唤"]
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
            motherboard: "B460M Mortar",
            memory: "16GB DDR4",
            storage: "不知道",
            powerSupply: "550W"
        ),
        goal: .gaming,
        budget: 3000,
        selectedGames: ["CS2", "PUBG", "无畏契约"],
        resolution: .twoK,
        frameTarget: .highRefresh,
        componentPreference: componentPreferences[0]
    )

    var selectedGamesDisplay: String {
        let ordered = Self.games.filter(selectedGames.contains)
        return ordered.isEmpty ? "还没有选择游戏" : ordered.joined(separator: "  /  ")
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
}
