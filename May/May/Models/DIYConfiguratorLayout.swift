import Foundation

struct DIYConfiguratorPart: Equatable, Identifiable {
    let number: String
    let title: String
    let value: String
    let icon: String
    let isSelected: Bool

    var id: String { number }
}

enum DIYConfiguratorLayout {
    static let parts = [
        DIYConfiguratorPart(number: "01", title: "CPU", value: "Intel i5-14600KF", icon: "cpu", isSelected: true),
        DIYConfiguratorPart(number: "02", title: "显卡", value: "RTX 4070 Super", icon: "rectangle.3.group", isSelected: true),
        DIYConfiguratorPart(number: "03", title: "主板", value: "微星 B760M\nMORTAR", icon: "square.grid.3x3.square", isSelected: true),
        DIYConfiguratorPart(number: "04", title: "内存", value: "待选择", icon: "memorychip", isSelected: false),
        DIYConfiguratorPart(number: "05", title: "硬盘", value: "待选择", icon: "internaldrive", isSelected: false),
        DIYConfiguratorPart(number: "06", title: "电源", value: "待选择", icon: "fan", isSelected: false),
        DIYConfiguratorPart(number: "07", title: "散热", value: "待选择", icon: "fanblades", isSelected: false),
        DIYConfiguratorPart(number: "08", title: "机箱", value: "待选择", icon: "server.rack", isSelected: false)
    ]
}
