import Foundation

struct OBPage: Equatable {
    let back: String
    let front: String
    let title: String
    let subtitle: String
    let cta: String
}

enum LaunchIntroPage: Int, CaseIterable, Identifiable {
    case build
    case needs
    case review
    case save

    var id: Int { rawValue }

    var content: OBPage {
        Self.pages[rawValue]
    }

    var title: String {
        content.title
    }

    var subtitle: String {
        content.subtitle
    }

    var buttonTitle: String {
        content.cta
    }

    private static let pages = [
        OBPage(back: "ob1_back", front: "ob1_front", title: "AI 装机,从不踩坑。", subtitle: "说出预算和用途,马上生成靠谱配置。", cta: "继续"),
        OBPage(back: "ob2_back", front: "ob2_front", title: "说出需求,配置自动生成。", subtitle: "预算、用途、偏好,一句话交给 AI。", cta: "继续"),
        OBPage(back: "ob3_back", front: "ob3_front", title: "商家清单,一眼排雷。", subtitle: "看懂型号、价格和兼容风险。", cta: "继续"),
        OBPage(back: "ob4_back", front: "ob4_front", title: "保存方案,随时升级。", subtitle: "对比价格变化,下一次换件也不慌。", cta: "开始装机")
    ]
}
