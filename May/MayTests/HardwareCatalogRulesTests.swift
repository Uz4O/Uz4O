import Foundation

@main
struct HardwareCatalogRulesTests {
    static func main() {
        assertEqual(
            HardwareCatalog.cpuOptions.prefix(4).map(\.self),
            ["不知道", "i9-14900KS", "i9-14900KF", "i9-14900K"],
            "CPU options should come from the expanded local hardware catalog."
        )

        assertEqual(
            HardwareCatalog.gpuOptions.contains("RTX 4060"),
            true,
            "GPU options should include chip model names."
        )

        assertEqual(
            HardwareCatalog.gpuOptions.contains("GeForce RTX 4060"),
            false,
            "GPU options should drop marketing prefixes."
        )

        assertEqual(
            HardwareCatalog.gpuOptions.contains { $0.contains("华硕") || $0.contains("微星") || $0.contains("技嘉") },
            false,
            "GPU options should not include board partner brands."
        )

        assertEqual(
            HardwareCatalog.allOptionLabels.contains { $0.contains("¥") || $0.localizedCaseInsensitiveContains("price") },
            false,
            "Hardware options should not expose prices."
        )

        assertEqual(
            HardwareProfileOptions.categories.first { $0.title == "主板" }?.options.contains("B760M AORUS ELITE GEN5"),
            true,
            "Hardware profile collection should include expanded motherboard options."
        )

        assertEqual(
            HardwareCatalog.motherboardOptions.contains("ROG STRIX B860-A GAMING WIFI S吹雪"),
            true,
            "Every motherboard picker should use the official Chinese product name."
        )

        assertEqual(
            HardwareCatalog.filters(for: "CPU").map(\.title),
            ["Intel", "AMD"],
            "CPU picker should use the source category logic and filter by brand."
        )

        assertEqual(
            HardwareCatalog.filters(for: "CPU").first { $0.title == "Intel" }?.groups.map(\.title).prefix(3).map(\.self),
            ["14代酷睿", "酷睿 Ultra", "13代酷睿"],
            "CPU picker should use short generation labels after choosing a brand."
        )

        assertEqual(
            HardwareCatalog.filters(for: "显卡").first { $0.title == "NVIDIA" }?.groups.contains { $0.title == "RTX 40 系列" },
            true,
            "GPU picker should group NVIDIA chip models by series."
        )

        assertEqual(
            HardwareCatalog.filters(for: "显卡").first { $0.title == "NVIDIA" }?.groups.flatMap(\.items).contains { $0.name.contains("华硕") || $0.name.contains("微星") || $0.name.contains("技嘉") },
            false,
            "GPU picker groups should not reintroduce board partner brands."
        )

        assertEqual(
            HardwareCatalog.filters(for: "主板").map(\.title),
            ["Intel", "AMD"],
            "Motherboard picker should filter by platform instead of board partner brand."
        )

        assertEqual(
            HardwareCatalog.filters(for: "主板").first { $0.title == "Intel" }?.groups.contains { $0.title == "B760" },
            true,
            "Motherboard picker should group options by chipset."
        )

        let intelMotherboardFilters = HardwareCatalog.motherboardFilters(compatibleWithCPU: "i7-14700")
        assertEqual(
            intelMotherboardFilters.isEmpty,
            false,
            "Compatible LGA1700 motherboard filters should not be empty."
        )
        assertEqual(
            intelMotherboardFilters.flatMap(\.groups).flatMap(\.items).allSatisfy { $0.detail.contains("LGA1700") },
            true,
            "LGA1700 CPUs should only show LGA1700 motherboards."
        )

        let amdMotherboardFilters = HardwareCatalog.motherboardFilters(compatibleWithCPU: "R7 7800X3D")
        assertEqual(
            amdMotherboardFilters.isEmpty,
            false,
            "Compatible AM5 motherboard filters should not be empty."
        )
        assertEqual(
            amdMotherboardFilters.flatMap(\.groups).flatMap(\.items).allSatisfy { $0.detail.contains("AM5") },
            true,
            "AM5 CPUs should only show AM5 motherboards."
        )

        assertEqual(
            HardwareCatalog.motherboardFilters(compatibleWithCPU: "不知道"),
            HardwareCatalog.filters(for: "主板"),
            "Unknown CPUs should keep the complete motherboard catalog."
        )

        assertEqual(
            HardwareCatalog.areCompatible(cpu: "i7-14700", motherboard: "B760M AORUS ELITE GEN5"),
            true,
            "Matching CPU and motherboard sockets should be compatible."
        )

        assertEqual(
            HardwareCatalog.areCompatible(cpu: "R7 7800X3D", motherboard: "B760M AORUS ELITE GEN5"),
            false,
            "Different CPU and motherboard sockets should be incompatible."
        )

        print("HardwareCatalogRulesTests passed")
    }

    private static func assertEqual<T: Equatable>(_ actual: T, _ expected: T, _ message: String) {
        guard actual == expected else {
            fatalError("\(message)\nExpected: \(expected)\nActual: \(actual)")
        }
    }
}
