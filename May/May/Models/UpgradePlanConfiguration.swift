import Foundation

struct UpgradePlanConfiguration: Equatable {
    var hardwareProfile: HardwareProfile

    static let categories = HardwareProfileOptions.categories

    static let sample = UpgradePlanConfiguration(
        hardwareProfile: HardwareProfile(
            cpu: "i5-10400F",
            gpu: "GTX 1660 Super",
            motherboard: "MAG B560 TORPEDO 鱼雷",
            memory: "16GB DDR4",
            storage: "不知道",
            powerSupply: "550W"
        )
    )

    func value(for title: String) -> String {
        switch title {
        case "CPU":
            return hardwareProfile.cpu
        case "显卡":
            return hardwareProfile.gpu
        case "主板":
            return hardwareProfile.motherboard
        case "内存":
            return hardwareProfile.memory
        case "硬盘":
            return hardwareProfile.storage
        default:
            return hardwareProfile.powerSupply
        }
    }

    mutating func setValue(_ value: String, for title: String) {
        hardwareProfile.setValue(value, for: title)
    }

    mutating func apply(_ profile: HardwareProfile) {
        hardwareProfile = profile
    }
}
