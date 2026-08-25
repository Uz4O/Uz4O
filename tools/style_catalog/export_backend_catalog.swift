import Foundation

private struct HardwareRecord: Encodable {
    let id: String
    let category: String
    let name: String
    let brand: String
    let detail_raw: String
    let specs: Specs

    struct Specs: Encodable {
        let aesthetic_role: String
        let display_category: String
        let condition: String
        let color: String
        let supports_hot_cpu: Bool
        let aesthetic_styles: [String: String]
    }
}

private struct CatalogEntry {
    let componentID: String
    let role: AestheticBuildPartRole
    let category: String
    let name: String
    let condition: AestheticBuildPartCondition
    let color: String
    let price: Int
    let supportsHotCPU: Bool
    var styles: [String: String]
}

@main
struct AestheticBackendCatalogExporter {
    static func main() throws {
        guard CommandLine.arguments.count == 3 else {
            fatalError("用法：export_backend_catalog <hardware.json> <prices.csv>")
        }

        var entries: [String: CatalogEntry] = [:]
        for style in AestheticBuildStyle.all {
            for color in AestheticStyleColor.allCases {
                collect(
                    style.buildSelection(color: color, selectedAlternativeIDs: [:]),
                    style: style,
                    entries: &entries
                )
                for part in style.overviewParts where !part.usesAICooler {
                    for alternative in part.alternatives {
                        collect(
                            style.buildSelection(
                                color: color,
                                selectedAlternativeIDs: [part.id: alternative.id]
                            ),
                            style: style,
                            entries: &entries
                        )
                    }
                }
            }
        }

        let sorted = entries.values.sorted { $0.componentID < $1.componentID }
        let hardware = sorted.map { entry in
            HardwareRecord(
                id: entry.componentID,
                category: backendCategory(for: entry.role),
                name: entry.name,
                brand: entry.name.split(separator: " ").first.map(String.init) ?? "风格方案",
                detail_raw: "\(displayCategory(for: entry)) · \(entry.condition.rawValue) · \(entry.color)",
                specs: HardwareRecord.Specs(
                    aesthetic_role: entry.role.rawValue,
                    display_category: entry.category,
                    condition: entry.condition.rawValue,
                    color: entry.color,
                    supports_hot_cpu: entry.supportsHotCPU,
                    aesthetic_styles: entry.styles
                )
            )
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let hardwareData = try encoder.encode(hardware)
        try (hardwareData + Data("\n".utf8)).write(
            to: URL(fileURLWithPath: CommandLine.arguments[1]),
            options: .atomic
        )

        var csv = "target_id,reference_price,normal_price_min,normal_price_max,accepted_count,rejected_count,review_reasons\n"
        for entry in sorted {
            csv += "\(entry.componentID),\(entry.price),\(entry.price),\(entry.price),1,0,风格方案人工核实\n"
        }
        try csv.write(
            toFile: CommandLine.arguments[2],
            atomically: true,
            encoding: .utf8
        )
        print("已导出 \(sorted.count) 个正式风格配件 SKU")
    }

    private static func collect(
        _ selection: AestheticBuildSelection,
        style: AestheticBuildStyle,
        entries: inout [String: CatalogEntry]
    ) {
        for part in selection.parts {
            let category = canonicalCategory(
                role: part.role,
                name: part.name,
                fallback: part.category
            )
            if var existing = entries[part.componentID] {
                guard existing.name == part.name,
                      existing.role == part.role,
                      existing.category == category,
                      existing.condition == part.condition,
                      existing.color == selection.color,
                      existing.price == part.referencePrice,
                      existing.supportsHotCPU == part.supportsHotCPU
                else {
                    fatalError("同一 SKU 的资料不一致：\(part.componentID) / \(part.name)")
                }
                existing.styles[style.id] = style.title
                entries[part.componentID] = existing
            } else {
                entries[part.componentID] = CatalogEntry(
                    componentID: part.componentID,
                    role: part.role,
                    category: category,
                    name: part.name,
                    condition: part.condition,
                    color: selection.color,
                    price: part.referencePrice,
                    supportsHotCPU: part.supportsHotCPU,
                    styles: [style.id: style.title]
                )
            }
        }
    }

    private static func backendCategory(for role: AestheticBuildPartRole) -> String {
        switch role {
        case .case: return "case"
        case .cooler: return "cooler"
        case .extra: return "aesthetic_extra"
        }
    }

    private static func canonicalCategory(
        role: AestheticBuildPartRole,
        name: String,
        fallback: String
    ) -> String {
        switch role {
        case .case: return "机箱"
        case .cooler: return "CPU 散热器"
        case .extra:
            if fallback.contains("风扇") { return "风扇套装" }
            if fallback.contains("屏") { return "副屏" }
            if fallback.contains("线") { return "定制线材" }
            if fallback.contains("支架") { return "显卡支架" }
            if name.contains("风扇") { return "风扇套装" }
            if name.contains("屏") { return "副屏" }
            if name.contains("线") { return "定制线材" }
            if name.contains("支架") { return "显卡支架" }
            return fallback
        }
    }

    private static func displayCategory(for entry: CatalogEntry) -> String { entry.category }
}
