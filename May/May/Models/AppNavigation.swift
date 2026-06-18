import Foundation

enum AppTab: String, CaseIterable {
    case home = "首页"
    case community = "社区"
    case builds = "配置"
    case profile = "我的"

    static let bottomNavigationTabs: [AppTab] = [.home, .community, .builds, .profile]

    func icon(isSelected: Bool) -> String {
        switch self {
        case .home:
            return isSelected ? "house.fill" : "house"
        case .community:
            return isSelected ? "bubble.left.and.bubble.right.fill" : "bubble.left.and.bubble.right"
        case .builds:
            return isSelected ? "doc.text.fill" : "doc.text"
        case .profile:
            return isSelected ? "person.fill" : "person"
        }
    }
}
