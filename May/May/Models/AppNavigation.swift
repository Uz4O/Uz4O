import Foundation

enum AppTab: String, CaseIterable {
    case home = "首页"
    case diy = "DIY"
    case builds = "配置"
    case profile = "我的"

    static let bottomNavigationTabs: [AppTab] = [.home, .diy, .builds, .profile]

    func icon(isSelected: Bool) -> String {
        switch self {
        case .home:
            return isSelected ? "house.fill" : "house"
        case .builds:
            return isSelected ? "doc.text.fill" : "doc.text"
        case .diy:
            return isSelected ? "wrench.and.screwdriver.fill" : "wrench.and.screwdriver"
        case .profile:
            return isSelected ? "person.fill" : "person"
        }
    }
}
