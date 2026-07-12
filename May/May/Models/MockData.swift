import SwiftUI

struct PCPart: Identifiable {
    let id = UUID()
    let category: String
    let model: String
    let price: String
    let icon: String
    let accent: Color
    var reason: String = ""
    var alternative: String = ""
    var source: String = "参考价"
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
    let risks: [BuildRisk]
    var advantages: [String] = []
    var disadvantages: [String] = []
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
    func part(for role: BuildPartRoleDTO) -> BuildOptionPartDTO? {
        details.parts.first { $0.role == role }
    }

    var referenceTotalText: String {
        formattedBuildPrice(estimatedTotal ?? details.parts.reduce(0) { $0 + $1.referencePrice })
    }

    var buildPlan: BuildPlan {
        let compatibilityRisks = [
            BuildRisk(
                level: compatibility.compatible ? .pass : .error,
                title: "兼容性结论",
                detail: compatibility.summary
            )
        ] + compatibility.findings.map {
            BuildRisk(level: $0.level.riskLevel, title: $0.title, detail: $0.detail)
        }
        let planRisks = details.risks.map {
            BuildRisk(level: .warning, title: "方案风险", detail: $0)
        }

        return BuildPlan(
            name: title,
            budget: formattedBuildPrice(details.targetBudget),
            totalPrice: referenceTotalText,
            useCase: "\(details.direction.displayName) · \(details.suitableUser)\n\(explanation)",
            createdAt: "参考价日期 \(details.priceDate)",
            parts: BuildPartRoleDTO.allCases.compactMap { part(for: $0)?.model },
            risks: compatibilityRisks + planRisks,
            advantages: details.advantages,
            disadvantages: details.disadvantages
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
            icon: role.icon,
            accent: role == .cpu ? .blue : AppTheme.primaryText,
            reason: "成色：\(condition.displayName) · \(priceSource) · \(priceDate)",
            source: "\(priceSource) · \(priceDate)"
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

private extension BuildCompatibilityLevelDTO {
    var riskLevel: RiskLevel {
        switch self {
        case .pass:
            .pass
        case .warning:
            .warning
        case .error:
            .error
        }
    }
}

private func formattedBuildPrice(_ value: Int) -> String {
    "¥ \(value.formatted(.number.grouping(.automatic)))"
}

enum AppMockData {
    static let parts = [
        PCPart(category: "CPU", model: "Intel Core i5-14600K", price: "¥ 1499", icon: "cpu", accent: .blue, reason: "游戏和生产力都够用，避免 i7 级别预算浪费。", alternative: "Ryzen 5 7500F"),
        PCPart(category: "主板", model: "B760M AORUS ELITE", price: "¥ 899", icon: "memorychip", accent: AppTheme.primaryText, reason: "供电和接口足够，不做过度消费。", alternative: "ROG STRIX B760-G"),
        PCPart(category: "显卡", model: "RTX 4070 Super 12GB", price: "¥ 4399", icon: "display", accent: AppTheme.primaryText, reason: "适合 2K 高画质游戏，功耗和性能平衡。", alternative: "RTX 4060 Ti / RX 7800 XT"),
        PCPart(category: "内存", model: "DDR5 6000 32GB", price: "¥ 699", icon: "rectangle.stack", accent: AppTheme.primaryText, reason: "32GB 更适合剪辑、多任务和长期使用。", alternative: "DDR5 5600 32GB"),
        PCPart(category: "硬盘", model: "1TB PCIe 4.0 SSD", price: "¥ 459", icon: "externaldrive", accent: AppTheme.primaryText, reason: "系统和常用游戏都能放下，后期可加盘。", alternative: "2TB PCIe 4.0 SSD"),
        PCPart(category: "电源", model: "650W 金牌全模组", price: "¥ 499", icon: "bolt", accent: AppTheme.primaryText, reason: "功率有余量，避开虚标杂牌电源。", alternative: "750W 金牌"),
        PCPart(category: "散热", model: "单塔风冷 6 热管", price: "¥ 159", icon: "fan", accent: AppTheme.primaryText, reason: "压制 i5 足够，维护成本低。", alternative: "240 水冷"),
        PCPart(category: "机箱", model: "MATX 白色海景房", price: "¥ 399", icon: "shippingbox", accent: AppTheme.primaryText, reason: "空间够用，兼顾外观和安装难度。", alternative: "静音 MATX 机箱")
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
        parts: parts,
        risks: [
            BuildRisk(level: .warning, title: "价格波动", detail: "显卡价格波动较大，购买前建议再比价。"),
            BuildRisk(level: .pass, title: "兼容性", detail: "CPU、主板、内存、电源和机箱空间匹配。"),
            BuildRisk(level: .pass, title: "升级空间", detail: "后期可升级 2TB SSD 或更高功率电源。")
        ]
    )

    static func aestheticSamplePlan(for flow: AestheticBuildFlow) -> BuildPlan {
        let stylePart = PCPart(
            category: "外观与散热",
            model: "\(flow.style.title) · \(flow.restoration.tier.title)",
            price: flow.quote.styleModule.midpointLabel,
            icon: "fan",
            accent: AppTheme.primaryText,
            reason: flow.restoration.keeps,
            alternative: flow.restoration.tradeoff,
            source: "演示估价"
        )

        return BuildPlan(
            name: "\(flow.style.title)颜值游戏配置",
            budget: flow.quote.total.label,
            totalPrice: flow.quote.total.midpointLabel,
            useCase: "\(flow.resolvedResolution.title) · \(flow.selectedExperience.title) · \(flow.selectedGames.map(\.name).joined(separator: " / "))",
            createdAt: "演示方案",
            parts: Array(parts.prefix(6)) + [stylePart],
            risks: [
                BuildRisk(level: .warning, title: "演示价格", detail: "当前价格只用于验证颜值装机流程，不作为购买报价。"),
                BuildRisk(level: .warning, title: "兼容性待接入", detail: "生产版必须用真实机箱、散热器和风扇数据重新检查空间与散热。")
            ]
        )
    }

    static let savedPlans = [
        samplePlan,
        BuildPlan(name: "5000 办公剪辑配置", budget: "5000 档", totalPrice: "¥ 5188", useCase: "办公 / 轻剪辑", createdAt: "昨天 21:08", parts: parts, risks: samplePlan.risks),
        BuildPlan(name: "万元 4K 游戏配置", budget: "10000+ 档", totalPrice: "¥ 10880", useCase: "4K 游戏 / 直播", createdAt: "5 月 29 日", parts: parts, risks: samplePlan.risks)
    ]

    static let beginnerTopics = [
        "如何确定预算",
        "游戏电脑怎么配",
        "剪辑电脑怎么配"
    ]
}
