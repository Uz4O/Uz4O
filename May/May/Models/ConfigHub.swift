import Foundation

enum ConfigHubSection: String, CaseIterable, Identifiable {
    case aiBuilds
    case currentComputer

    var id: String { rawValue }

    static let defaultSelection: ConfigHubSection = .aiBuilds

    var title: String {
        switch self {
        case .aiBuilds:
            return "AI 配置"
        case .currentComputer:
            return "我的配置"
        }
    }

    var subtitle: String {
        switch self {
        case .aiBuilds:
            return "保存过的方案都在这里"
        case .currentComputer:
            return "补充当前电脑，升级建议和配置对比会更准确。"
        }
    }
}

enum ConfigHubListStyle: Equatable {
    case compactList

    var primaryActionTitle: String {
        switch self {
        case .compactList:
            return "查看"
        }
    }

    var showsInlineActionBar: Bool {
        switch self {
        case .compactList:
            return false
        }
    }
}
