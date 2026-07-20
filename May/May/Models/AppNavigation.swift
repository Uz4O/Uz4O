import Foundation

enum AppTab: String, CaseIterable {
    case home = "首页"
    case styles = "风格"
    case builds = "配置"
    case profile = "我的"

    static let bottomNavigationTabs: [AppTab] = [.home, .styles, .builds, .profile]

    func icon(isSelected: Bool) -> String {
        switch self {
        case .home:
            return isSelected ? "house.fill" : "house"
        case .styles:
            return isSelected ? "paintpalette.fill" : "paintpalette"
        case .builds:
            return isSelected ? "doc.text.fill" : "doc.text"
        case .profile:
            return isSelected ? "person.fill" : "person"
        }
    }
}
