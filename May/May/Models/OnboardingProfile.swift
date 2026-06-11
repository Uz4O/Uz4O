import Foundation

enum AppScreen: Hashable {
    case login
    case onboarding
    case home
    case aiBuild
    case community
    case builds
    case profile
    case computerProfile
    case upgrade
    case configReview
    case compatibility
    case guide
    case diy
    case buildResult
}

enum BuildResultReturnTarget: Equatable {
    case fromAIBuild
    case fromConfigTab
    case fromConfigAIBuild

    var destination: AppScreen {
        switch self {
        case .fromAIBuild:
            return .home
        case .fromConfigTab, .fromConfigAIBuild:
            return .builds
        }
    }
}

enum BuildPreference: String, CaseIterable, Identifiable {
    case balanced
    case performance
    case aesthetic

    var id: String { rawValue }

    var title: String {
        switch self {
        case .balanced:
            return "均衡推荐"
        case .performance:
            return "性能优先"
        case .aesthetic:
            return "颜值优先"
        }
    }

    var subtitle: String {
        switch self {
        case .balanced:
            return "性能和外观都照顾一点，适合大多数人"
        case .performance:
            return "同预算优先把钱花在 CPU、显卡、内存和电源上"
        case .aesthetic:
            return "更重视外观，但会帮你避开好看却不值的搭配"
        }
    }

    var icon: String {
        switch self {
        case .balanced:
            return "scale.3d"
        case .performance:
            return "bolt.fill"
        case .aesthetic:
            return "paintpalette.fill"
        }
    }
}

enum HomeFeatureKind: String {
    case aiBuild
    case configReview
    case guide
    case builds
    case upgrade
    case compatibility
    case diy
}

enum ComputerOwnershipChoice {
    case hasComputer
    case noComputer

    var shouldCollectHardwareBeforePreference: Bool {
        self == .hasComputer
    }
}

struct HardwareOptionCategory: Equatable, Identifiable {
    var id: String { title }

    let title: String
    let icon: String
    let options: [String]
}

enum HardwareProfileOptions {
    static let cpu = HardwareCatalog.cpuOptions
    static let gpu = HardwareCatalog.gpuOptions
    static let motherboard = HardwareCatalog.motherboardOptions
    static let memory = HardwareCatalog.memoryOptions
    static let storage = HardwareCatalog.storageOptions
    static let powerSupply = HardwareCatalog.powerSupplyOptions

    static let categories = [
        HardwareOptionCategory(title: "CPU", icon: "cpu", options: cpu),
        HardwareOptionCategory(title: "显卡", icon: "display", options: gpu),
        HardwareOptionCategory(title: "主板", icon: "menucard", options: motherboard),
        HardwareOptionCategory(title: "内存", icon: "rectangle.stack", options: memory),
        HardwareOptionCategory(title: "硬盘", icon: "externaldrive", options: storage),
        HardwareOptionCategory(title: "电源", icon: "bolt", options: powerSupply)
    ]
}

struct HardwareProfile: Codable, Equatable {
    enum Change: Equatable {
        case updated
        case motherboardCleared

        var feedbackMessage: String? {
            switch self {
            case .updated:
                return nil
            case .motherboardCleared:
                return "因接口不兼容，已清除原主板"
            }
        }
    }

    var cpu: String
    var gpu: String
    var motherboard: String
    var memory: String
    var storage: String
    var powerSupply: String
    var wasSkipped: Bool

    init(
        cpu: String,
        gpu: String,
        motherboard: String = "不知道",
        memory: String,
        storage: String,
        powerSupply: String,
        wasSkipped: Bool = false
    ) {
        self.cpu = cpu
        self.gpu = gpu
        self.motherboard = motherboard
        self.memory = memory
        self.storage = storage
        self.powerSupply = powerSupply
        self.wasSkipped = wasSkipped
    }

    static let skipped = HardwareProfile(
        cpu: "不知道",
        gpu: "不知道",
        motherboard: "不知道",
        memory: "不知道",
        storage: "不知道",
        powerSupply: "不知道",
        wasSkipped: true
    )

    var summary: String {
        "CPU \(cpu) · 显卡 \(gpu) · 主板 \(motherboard) · 内存 \(memory) · 硬盘 \(storage) · 电源 \(powerSupply)"
    }

    var completedComponentCount: Int {
        componentValues.filter { $0 != "不知道" }.count
    }

    var appliedItemCount: Int {
        completedComponentCount
    }

    var completionLabel: String {
        "已填写 \(completedComponentCount)/\(HardwareProfileOptions.categories.count)"
    }

    var isComplete: Bool {
        completedComponentCount == HardwareProfileOptions.categories.count
    }

    var knownComponentsSummary: String {
        componentSummaries
            .filter { $0.value != "不知道" }
            .map { "\($0.title) \($0.value)" }
            .joined(separator: " · ")
    }

    func value(for title: String) -> String {
        switch title {
        case "CPU":
            return cpu
        case "显卡":
            return gpu
        case "主板":
            return motherboard
        case "内存":
            return memory
        case "硬盘":
            return storage
        default:
            return powerSupply
        }
    }

    mutating func setValue(_ value: String, for title: String) {
        _ = updateValue(value, for: title)
    }

    @discardableResult
    mutating func updateValue(_ value: String, for title: String) -> Change {
        var change = Change.updated

        switch title {
        case "CPU":
            cpu = value
            if !HardwareCatalog.areCompatible(cpu: value, motherboard: motherboard) {
                motherboard = "不知道"
                change = .motherboardCleared
            }
        case "显卡":
            gpu = value
        case "主板":
            motherboard = value
        case "内存":
            memory = value
        case "硬盘":
            storage = value
        default:
            powerSupply = value
        }

        wasSkipped = false
        return change
    }

    private var componentValues: [String] {
        [cpu, gpu, motherboard, memory, storage, powerSupply]
    }

    private var componentSummaries: [(title: String, value: String)] {
        [
            ("CPU", cpu),
            ("显卡", gpu),
            ("主板", motherboard),
            ("内存", memory),
            ("硬盘", storage),
            ("电源", powerSupply)
        ]
    }
}

struct HomeFeatureDisplay: Equatable {
    let kind: HomeFeatureKind
    let title: String
    let subtitle: String
    let icon: String
}

struct OnboardingProfile: Equatable {
    var preference: BuildPreference
    var hardwareProfile: HardwareProfile

    init(preference: BuildPreference, hardwareProfile: HardwareProfile = .skipped) {
        self.preference = preference
        self.hardwareProfile = hardwareProfile
    }

    static let skipped = OnboardingProfile(preference: .balanced, hardwareProfile: .skipped)

    var preferenceLabel: String {
        preference.title
    }

    var homeHeroSubtitle: String {
        "智能推荐最佳配置方案"
    }

    var homeHeroButtonTitle: String {
        "开始装机"
    }

    var homeFeatureOrder: [HomeFeatureDisplay] {
        [
            .diy,
            .configReview,
            .upgrade,
            .guide
        ]
    }
}

private extension HomeFeatureDisplay {
    static let aiBuild = HomeFeatureDisplay(
        kind: .aiBuild,
        title: "AI 一键装机",
        subtitle: "从预算和用途生成配置建议",
        icon: "sparkles"
    )

    static let diy = HomeFeatureDisplay(
        kind: .diy,
        title: "游戏性能测试",
        subtitle: "测测游戏帧率表现",
        icon: "gamecontroller"
    )

    static let configReview = HomeFeatureDisplay(
        kind: .configReview,
        title: "配置排雷",
        subtitle: "判断配置能不能买",
        icon: "doc.text.magnifyingglass"
    )

    static let guide = HomeFeatureDisplay(
        kind: .guide,
        title: "装机指南",
        subtitle: "按步骤了解装机流程",
        icon: "book.closed"
    )

    static let upgrade = HomeFeatureDisplay(
        kind: .upgrade,
        title: "升级建议",
        subtitle: "按预算给出升级顺序",
        icon: "arrow.up.forward.circle"
    )
}
