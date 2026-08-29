import Foundation

enum AppTab: String, CaseIterable {
    case home = "首页"
    case styles = "装机风格"
    case diy = "装机工具"
    case profile = "个人中心"

    static let bottomNavigationTabs: [AppTab] = [.home, .styles, .diy, .profile]

    func icon(isSelected: Bool) -> String {
        switch self {
        case .home:
            return isSelected ? "house.fill" : "house"
        case .styles:
            return isSelected ? "square.grid.2x2.fill" : "square.grid.2x2"
        case .diy:
            return isSelected ? "briefcase.fill" : "briefcase"
        case .profile:
            return isSelected ? "person.fill" : "person"
        }
    }
}
