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

enum AIBuildFlowRules {
    static let lowBudgetThreshold = 4000

    static func visibleSteps(budget: Int, ownedParts: Set<AIBuildOwnedPart>) -> [AIBuildStep] {
        usesLowBudgetMode(budget: budget, ownedParts: ownedParts)
            ? [.budget, .scenario]
            : AIBuildStep.allCases
    }

    static func usesLowBudgetMode(budget: Int, ownedParts: Set<AIBuildOwnedPart>) -> Bool {
        budget < lowBudgetThreshold && !ownedParts.contains(where: \.isHighValue)
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
