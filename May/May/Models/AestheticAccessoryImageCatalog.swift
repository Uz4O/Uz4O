import Foundation

enum AestheticAccessoryImageCatalog {
    static func imageName(for title: String) -> String? {
        let normalized = title.replacingOccurrences(of: " ", with: "")

        if normalized.contains("LV360") {
            return "AccessoryThermalrightLV360"
        }
        if normalized.contains("N360") {
            return "AccessoryValkyrieN360"
        }
        if normalized.contains("SE360") || normalized.contains("展域") {
            return "AccessoryTryxSE360"
        }
        if normalized.contains("龙王") {
            return "AccessoryROGRyujin4"
        }
        if normalized.contains("隐流") || normalized.contains("HydroShift") {
            return "AccessoryLianLiHydroShift"
        }
        if normalized.contains("LCD") {
            return "AccessoryLianLiTLCD"
        }
        if normalized.contains("积木") || normalized.contains("四代风扇") || normalized.contains("四代") {
            return "AccessoryLianLiSLFan"
        }
        if normalized.contains("ZA360") {
            return "AccessoryJonsboZA360"
        }
        if normalized.contains("ZA120") {
            return "AccessoryJonsboZA120"
        }
        if normalized.contains("棱镜8Pro") {
            return "AccessoryPrism8Pro"
        }
        if normalized.contains("LA300") {
            return "AccessoryTitanLA300"
        }
        if normalized.contains("LG600") {
            return "AccessoryTitanLG600"
        }
        if normalized.contains("大力神") {
            return "AccessoryROGHerculx"
        }

        return nil
    }
}
