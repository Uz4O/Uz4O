import Foundation

enum AppTab: String, CaseIterable {
    case home = "首页"
    case styles = "风格"
    case diy = "DIY"
    case profile = "我的"

    static let bottomNavigationTabs: [AppTab] = [.home, .styles, .diy, .profile]

    func icon(isSelected: Bool) -> String {
        switch self {
        case .home:
            return isSelected ? "house.fill" : "house"
        case .styles:
            return isSelected ? "paintpalette.fill" : "paintpalette"
        case .diy:
            return "wrench.and.screwdriver.fill"
        case .profile:
            return isSelected ? "person.fill" : "person"
        }
    }
}
