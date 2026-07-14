import SwiftUI

struct PCPart: Identifiable {
    let id = UUID()
    let category: String
    let model: String
    let price: String
    let condition: String
    let icon: String
    let accent: Color
}

struct BuildStep: Identifiable {
    let id = UUID()
    let number: String
    let title: String
    let subtitle: String
}

struct BuildPlan: Identifiable {
    let id = UUID()
    let name: String
    let budget: String
    let totalPrice: String
    let useCase: String
    let createdAt: String
    let parts: [PCPart]
}

struct BuildRisk: Identifiable {
    let id = UUID()
    let level: RiskLevel
    let title: String
    let detail: String
}

enum RiskLevel {
    case pass
    case warning
    case error

    var title: String {
        switch self {
        case .pass:
            return "通过"
        case .warning:
            return "提醒"
        case .error:
            return "严重"
        }
    }

    var color: Color {
        switch self {
        case .pass:
            return AppTheme.success
        case .warning:
            return AppTheme.warning
        case .error:
            return AppTheme.error
        }
    }
}

extension BuildOptionDTO {
    func part(for role: BuildPartRoleDTO) -> BuildOptionPartDTO {
        guard let part = details.parts.first(where: { $0.role == role }) else {
            preconditionFailure("Validated build option is missing role: \(role.rawValue)")
        }
        return part
    }

    var referenceTotalText: String {
        formattedBuildPrice(estimatedTotal ?? details.parts.reduce(0) { $0 + $1.referencePrice })
    }

    var buildPlan: BuildPlan {
        return BuildPlan(
            name: title,
            budget: formattedBuildPrice(details.targetBudget),
            totalPrice: referenceTotalText,
            useCase: "\(details.direction.displayName) · \(details.suitableUser)\n\(explanation)",
            createdAt: "参考价日期 \(details.priceDate)",
            parts: BuildPartRoleDTO.allCases.map { part(for: $0).model }
        )
    }
}

extension BuildDirectionDTO {
    var displayName: String {
        switch self {
        case .fps:
            "FPS"
        case .aaa:
            "3A"
        case .balanced:
            "均衡"
        }
    }
}

extension BuildPurchaseModeDTO {
    var displayName: String {
        switch self {
        case .new:
            "全新"
        case .used:
            "二手"
        case .mixed:
            "混合采购"
        }
    }
}

private extension BuildOptionPartDTO {
    var model: PCPart {
        PCPart(
            category: role.displayName,
            model: name,
            price: formattedBuildPrice(referencePrice),
            condition: condition.displayName,
            icon: role.icon,
            accent: role == .cpu ? .blue : AppTheme.primaryText
        )
    }
}

private extension BuildPartRoleDTO {
    var displayName: String {
        switch self {
        case .cpu:
            "CPU"
        case .motherboard:
            "主板"
        case .gpu:
            "显卡"
        case .ram:
            "内存"
        case .storage:
            "硬盘"
        case .psu:
            "电源"
        case .cooler:
            "散热"
        case .case:
            "机箱"
        }
    }

    var icon: String {
        switch self {
        case .cpu:
            "cpu"
        case .motherboard:
            "memorychip"
        case .gpu:
            "display"
        case .ram:
            "rectangle.stack"
        case .storage:
            "externaldrive"
        case .psu:
            "bolt"
        case .cooler:
            "fan"
        case .case:
            "shippingbox"
        }
    }
}

private extension BuildPartConditionDTO {
    var displayName: String {
        switch self {
        case .new:
            "全新"
        case .used:
            "二手"
        }
    }
}

private func formattedBuildPrice(_ value: Int) -> String {
    "¥ \(value.formatted(.number.grouping(.automatic)))"
}

enum AppMockData {
    static let parts = [
        PCPart(category: "CPU", model: "Intel Core i5-14600K", price: "¥ 1499", condition: "全新", icon: "cpu", accent: .blue),
        PCPart(category: "主板", model: "B760M AORUS ELITE", price: "¥ 899", condition: "全新", icon: "memorychip", accent: AppTheme.primaryText),
        PCPart(category: "显卡", model: "RTX 4070 Super 12GB", price: "¥ 4399", condition: "全新", icon: "display", accent: AppTheme.primaryText),
        PCPart(category: "内存", model: "DDR5 6000 32GB", price: "¥ 699", condition: "全新", icon: "rectangle.stack", accent: AppTheme.primaryText),
        PCPart(category: "硬盘", model: "1TB PCIe 4.0 SSD", price: "¥ 459", condition: "全新", icon: "externaldrive", accent: AppTheme.primaryText),
        PCPart(category: "电源", model: "650W 金牌全模组", price: "¥ 499", condition: "全新", icon: "bolt", accent: AppTheme.primaryText),
        PCPart(category: "散热", model: "单塔风冷 6 热管", price: "¥ 159", condition: "全新", icon: "fan", accent: AppTheme.primaryText),
        PCPart(category: "机箱", model: "MATX 白色海景房", price: "¥ 399", condition: "全新", icon: "shippingbox", accent: AppTheme.primaryText)
    ]

    static let guideSteps = [
        BuildStep(number: "01", title: "准备工作", subtitle: "准备工具，了解注意事项"),
        BuildStep(number: "02", title: "安装 CPU", subtitle: "安装处理器到主板"),
        BuildStep(number: "03", title: "安装散热器", subtitle: "安装散热器并涂抹硅脂"),
        BuildStep(number: "04", title: "安装内存", subtitle: "插入内存条"),
        BuildStep(number: "05", title: "安装主板", subtitle: "将主板固定到机箱")
    ]

    static let useCases = ["游戏", "办公", "游戏兼办公"]

    static let samplePlan = BuildPlan(
        name: "2K 游戏均衡配置",
        budget: "8000 档",
        totalPrice: "¥ 8566",
        useCase: "2K 游戏 / 日常剪辑 / 可升级",
        createdAt: "今天 17:20",
        parts: parts
    )

    static func aestheticSamplePlan(for flow: AestheticBuildFlow) -> BuildPlan {
        let stylePart = PCPart(
            category: "外观与散热",
            model: "\(flow.style.title) · \(flow.restoration.tier.title)",
            price: flow.quote.styleModule.midpointLabel,
            condition: "全新",
            icon: "fan",
            accent: AppTheme.primaryText
        )

        return BuildPlan(
            name: "\(flow.style.title)颜值游戏配置",
            budget: flow.quote.total.label,
            totalPrice: flow.quote.total.midpointLabel,
            useCase: "\(flow.resolvedResolution.title) · \(flow.selectedExperience.title) · \(flow.selectedGames.map(\.name).joined(separator: " / "))",
            createdAt: "演示方案",
            parts: Array(parts.prefix(6)) + [stylePart]
        )
    }

    static let savedPlans = [
        samplePlan,
        BuildPlan(name: "5000 办公剪辑配置", budget: "5000 档", totalPrice: "¥ 5188", useCase: "办公 / 轻剪辑", createdAt: "昨天 21:08", parts: parts),
        BuildPlan(name: "万元 4K 游戏配置", budget: "10000+ 档", totalPrice: "¥ 10880", useCase: "4K 游戏 / 直播", createdAt: "5 月 29 日", parts: parts)
    ]

    static let beginnerTopics = [
        "如何确定预算",
        "游戏电脑怎么配",
        "剪辑电脑怎么配"
    ]
}
