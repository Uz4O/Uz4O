import SwiftUI
import Photos
import UIKit

struct DIYView: View {
    private let components = DIYComponent.all
    private let apiClient = AppAPIClient()

    @State private var selectedComponents: [String: CatalogComponentDTO] = [:]
    @State private var catalogComponents: [CatalogComponentDTO] = []
    @State private var catalogPrices: [String: CatalogPriceDTO] = [:]
    @State private var activeSlotID: String?
    @State private var pickerSearchText = ""
    @State private var loadError: String?
    @State private var loadedCategories: Set<String> = []
    @State private var loadingCategories: Set<String> = []
    @State private var feedbackMessage = ""
    @State private var showsFeedback = false

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        header

                        Text("我的装机方案")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(DIYTheme.primary)
                            .padding(.leading, 4)
                            .padding(.top, 22)
                            .padding(.bottom, 12)

                        summaryCard
                            .padding(.bottom, 24)

                        HStack(alignment: .bottom) {
                            Text("八大件配置")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(DIYTheme.primary)
                            Spacer()
                            if let loadError {
                                Text(loadError)
                                    .font(.system(size: 11))
                                    .foregroundStyle(.red)
                                    .lineLimit(1)
                            }
                        }
                        .padding(.leading, 4)
                        .padding(.bottom, 14)

                        LazyVGrid(
                            columns: [
                                GridItem(.flexible(), spacing: 12),
                                GridItem(.flexible(), spacing: 12)
                            ],
                            spacing: 12
                        ) {
                            ForEach(components) { component in
                                DIYComponentCard(
                                    component: component,
                                    selected: selectedComponents[component.id],
                                    price: selectedComponents[component.id].flatMap { catalogPrices[$0.id]?.referencePrice },
                                    action: {
                                        openPicker(for: component)
                                    }
                                )
                            }
                        }

                        actionBar
                            .padding(.top, 22)

                    }
                    .frame(width: max(proxy.size.width - 52, 0), alignment: .leading)
                    .padding(.bottom, 110)
                    .frame(maxWidth: .infinity)
                }
                .background(DIYTheme.background.ignoresSafeArea())

                if let activeSlotID,
                   let slot = components.first(where: { $0.id == activeSlotID }) {
                    Color.black.opacity(0.28)
                        .ignoresSafeArea()
                        .contentShape(Rectangle())
                        .onTapGesture { self.activeSlotID = nil }

                    DIYComponentPicker(
                        slot: slot,
                        components: compatibleComponents(for: slot),
                        prices: catalogPrices,
                        searchText: $pickerSearchText,
                        onSelect: { component in
                            select(component, for: slot)
                        },
                        onDismiss: { self.activeSlotID = nil }
                    )
                    .id(slot.id)
                    .frame(
                        width: min(max(proxy.size.width - 32, 280), 430),
                        height: min(max(proxy.size.height - 120, 420), 620)
                    )
                    .transition(.scale(scale: 0.96).combined(with: .opacity))
                    .zIndex(1)
                }
            }
            .animation(.easeOut(duration: 0.18), value: activeSlotID)
        }
        .task { await loadCatalog() }
        .alert("DIY", isPresented: $showsFeedback) {
            Button("好的", role: .cancel) {}
        } message: {
            Text(feedbackMessage)
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            Text("UzBox")
                .font(.system(size: 25, weight: .heavy))
                .foregroundStyle(.black)
            Spacer()
            Image(systemName: "bell")
                .font(.system(size: 19, weight: .medium))
                .foregroundStyle(.black)
        }
        .padding(.horizontal, 4)
    }

    private var summaryCard: some View {
        HStack(spacing: 0) {
            DIYSummaryMetric(title: "预计总价", value: totalPrice > 0 ? "¥ \(totalPrice)" : "待选择", icon: "info.circle", iconColor: DIYTheme.secondary)
            Divider().frame(height: 62)
            DIYSummaryMetric(title: "已选择", value: "\(selectedComponents.count)", progress: Double(selectedComponents.count) / Double(components.count))
            Divider().frame(height: 62)
            DIYSummaryMetric(title: "预计功耗", value: estimatedPower.map { "\($0)W" } ?? "待选择", icon: "bolt.fill", iconColor: DIYTheme.secondary)
        }
        .frame(height: 94)
        .background(DIYTheme.surface, in: RoundedRectangle(cornerRadius: 22))
        .shadow(color: .black.opacity(0.04), radius: 14, y: 5)
    }

    private var totalPrice: Int {
        selectedComponents.values.reduce(0) { total, component in
            total + (catalogPrices[component.id]?.referencePrice ?? 0)
        }
    }

    private var estimatedPower: Int? {
        let cpuPower = selectedComponents["cpu"].flatMap { power(for: $0) }
        let gpuPower = selectedComponents["gpu"].flatMap { power(for: $0) }
        guard cpuPower != nil || gpuPower != nil else { return nil }
        return (cpuPower ?? 0) + (gpuPower ?? 0) + 100
    }

    private var actionBar: some View {
        HStack(spacing: 12) {
            Button(action: saveConfigurationImage) {
                Label("保存图片", systemImage: "photo")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(DIYTheme.primary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background(DIYTheme.surface, in: RoundedRectangle(cornerRadius: 15))
                    .overlay {
                        RoundedRectangle(cornerRadius: 15)
                            .stroke(DIYTheme.border, lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)

            Button(action: saveToMyBuilds) {
                Label("保存到我的配置单", systemImage: "bookmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background(DIYTheme.primary, in: RoundedRectangle(cornerRadius: 15))
            }
            .buttonStyle(.plain)
        }
    }

    private func power(for component: CatalogComponentDTO) -> Int? {
        if let exact = integerValue(component.specs["tdp"]) {
            return exact
        }
        if let source = integerValue(component.specs["source_tdp"]) {
            return source
        }
        if case let .object(sourceSpecs)? = component.specs["source_specs"],
           let source = integerValue(sourceSpecs["tdp"]) {
            return source
        }

        let text = "\(component.brand) \(component.name)"
            .uppercased()
            .filter { $0.isLetter || $0.isNumber }

        let known: [(String, Int)]
        if component.category == "cpu" {
            known = [
                ("285K", 250), ("265K", 250), ("245K", 159),
                ("14900", 253), ("14700", 253), ("13900", 253),
                ("13700", 253), ("12900", 241), ("12700", 190),
                ("14600", 181), ("13600", 181), ("12600", 150), ("12400", 117),
                ("9850X3D", 120), ("9800X3D", 120), ("7800X3D", 120),
                ("9700X", 120), ("9600X", 105), ("7500F", 88),
                ("5600X", 65), ("5600", 65)
            ]
        } else if component.category == "gpu" {
            known = [
                ("5090", 575), ("5080", 360), ("5070TI", 300), ("5070", 250),
                ("5060TI", 180), ("5060", 145), ("4090", 450), ("4080", 320),
                ("4070TI", 285), ("4070SUPER", 220), ("4070", 200),
                ("4060TI", 160), ("4060", 115), ("3090", 350), ("3080TI", 350),
                ("3080", 320), ("3070TI", 290), ("3070", 220), ("3060TI", 200),
                ("3060", 170), ("9070XT", 304), ("9070", 220), ("9060XT", 200),
                ("7900XTX", 355), ("7900XT", 315), ("7800XT", 263),
                ("7700XT", 245), ("7600XT", 190), ("7600", 165), ("6750", 250),
                ("6700", 230), ("6600", 132), ("A770", 225), ("A580", 185)
            ]
        } else {
            return nil
        }

        return known.first { text.contains($0.0) }?.1
    }

    private func integerValue(_ value: CatalogJSONValue?) -> Int? {
        switch value {
        case .number(let value):
            return Int(value)
        case .string(let value):
            return Int(value.filter { $0.isNumber })
        default:
            return nil
        }
    }

    private func saveToMyBuilds() {
        let parts = components.compactMap { slot -> DIYStoredPart? in
            guard let selected = selectedComponents[slot.id] else { return nil }
            return DIYStoredPart(
                category: slot.title,
                name: selected.name,
                brand: selected.brand,
                price: catalogPrices[selected.id]?.referencePrice
            )
        }
        guard !parts.isEmpty else {
            presentFeedback("请先选择至少一个配件")
            return
        }

        DIYBuildStore.save(
            DIYStoredBuild(
                id: UUID(),
                createdAt: Date(),
                totalPrice: totalPrice,
                estimatedPower: estimatedPower,
                parts: parts
            )
        )
        presentFeedback("已保存到“我的配置单”")
    }

    @MainActor
    private func saveConfigurationImage() {
        guard !selectedComponents.isEmpty else {
            presentFeedback("请先选择至少一个配件")
            return
        }

        let parts = components.compactMap { slot -> DIYStoredPart? in
            guard let selected = selectedComponents[slot.id] else { return nil }
            return DIYStoredPart(
                category: slot.title,
                name: selected.name,
                brand: selected.brand,
                price: catalogPrices[selected.id]?.referencePrice
            )
        }
        var renderer = ImageRenderer(
            content: DIYShareCard(
                parts: parts,
                totalPrice: totalPrice,
                estimatedPower: estimatedPower
            )
            .frame(width: 900)
        )
        renderer.scale = 2
        guard let image = renderer.uiImage else {
            presentFeedback("图片生成失败，请重试")
            return
        }

        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else {
                Task { @MainActor in presentFeedback("没有相册保存权限") }
                return
            }
            UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
            Task { @MainActor in presentFeedback("配置图片已保存到相册") }
        }
    }

    private func presentFeedback(_ message: String) {
        feedbackMessage = message
        showsFeedback = true
    }

    private func compatibleComponents(for slot: DIYComponent) -> [CatalogComponentDTO] {
        guard slot.id == "cpu" || slot.id == "motherboard" else {
            return catalogComponents.filter { $0.category == slot.backendCategory }
        }

        let otherID = slot.id == "cpu" ? "motherboard" : "cpu"
        guard let other = selectedComponents[otherID] else {
            return catalogComponents.filter { $0.category == slot.backendCategory }
        }

        return catalogComponents.filter { candidate in
            if slot.id == "cpu" {
                return candidate.category == "cpu" && areCompatible(cpu: candidate, motherboard: other)
            }
            return candidate.category == "motherboard" && areCompatible(cpu: other, motherboard: candidate)
        }
    }

    private func select(_ component: CatalogComponentDTO, for slot: DIYComponent) {
        selectedComponents[slot.id] = component

        if slot.id == "cpu",
           let motherboard = selectedComponents["motherboard"],
           !areCompatible(cpu: component, motherboard: motherboard) {
            selectedComponents["motherboard"] = nil
        }

        if slot.id == "motherboard",
           let cpu = selectedComponents["cpu"],
           !areCompatible(cpu: cpu, motherboard: component) {
            selectedComponents["cpu"] = nil
        }

        activeSlotID = nil
    }

    private func areCompatible(cpu: CatalogComponentDTO, motherboard: CatalogComponentDTO) -> Bool {
        guard let cpuSocket = socket(for: cpu),
              let motherboardSocket = socket(for: motherboard) else {
            return true
        }
        return normalizedSocket(cpuSocket) == normalizedSocket(motherboardSocket)
    }

    private func socket(for component: CatalogComponentDTO) -> String? {
        if let value = component.specs["socket"], let socket = stringValue(value) {
            return socket
        }
        if let value = component.specs["source_socket"], let socket = stringValue(value) {
            return socket
        }
        if case let .object(sourceSpecs)? = component.specs["source_specs"],
           let value = sourceSpecs["socket"],
           let socket = stringValue(value) {
            return socket
        }
        return nil
    }

    private func stringValue(_ value: CatalogJSONValue) -> String? {
        switch value {
        case .string(let value): return value
        case .number(let value): return String(value)
        default: return nil
        }
    }

    private func normalizedSocket(_ value: String) -> String {
        value.uppercased().filter { $0.isLetter || $0.isNumber }
    }

    @MainActor
    private func loadCatalog() async {
        guard catalogComponents.isEmpty else { return }

        if let cached = DIYCatalogCache.load() {
            apply(cached)
            Task { await refreshCatalog() }
        }
    }

    @MainActor
    private func openPicker(for slot: DIYComponent) {
        pickerSearchText = ""
        activeSlotID = slot.id
        guard !loadedCategories.contains(slot.backendCategory),
              !loadingCategories.contains(slot.backendCategory) else { return }

        loadingCategories.insert(slot.backendCategory)
        Task { await loadCategory(slot.backendCategory) }
    }

    @MainActor
    private func loadCategory(_ category: String) async {
        defer { loadingCategories.remove(category) }

        do {
            let components = try await apiClient.diyComponents(category: category)
            let prices: [String: CatalogPriceDTO]
            if catalogPrices.isEmpty {
                prices = try await apiClient.diyPrices()
            } else {
                prices = catalogPrices
            }
            catalogComponents = mergeComponents(catalogComponents, with: components)
            catalogPrices = prices
            loadedCategories.insert(category)
            DIYCatalogCache.save(DIYCatalogSnapshot(components: catalogComponents, prices: catalogPrices))
            loadError = nil
        } catch {
            loadError = error.localizedDescription
        }

    }

    private func refreshCatalog() async {
        do {
            let snapshot = try await apiClient.diyCatalog()
            DIYCatalogCache.save(snapshot)
            await MainActor.run { apply(snapshot) }
        } catch {
            // Cached data remains usable when a background refresh fails.
        }
    }

    @MainActor
    private func apply(_ snapshot: DIYCatalogSnapshot) {
        catalogComponents = snapshot.components
        catalogPrices = snapshot.prices
        loadedCategories = Set(snapshot.components.map(\.category))
        loadError = nil
    }

    private func mergeComponents(_ existing: [CatalogComponentDTO], with additions: [CatalogComponentDTO]) -> [CatalogComponentDTO] {
        var byID = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })
        additions.forEach { byID[$0.id] = $0 }
        return Array(byID.values)
    }
}

private struct DIYSummaryMetric: View {
    let title: String
    let value: String
    var icon: String?
    var progress: Double?
    var iconColor: Color = DIYTheme.primary

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 5) {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(iconColor)
                }
            }
            .foregroundStyle(DIYTheme.secondary)

            HStack(spacing: 4) {
                Text(value)
                    .foregroundStyle(DIYTheme.primary)
                if title == "已选择" {
                    Text("/8")
                        .foregroundStyle(DIYTheme.secondary)
                }
            }
            .font(.system(size: 20, weight: .bold))
            .lineLimit(1)
            .minimumScaleFactor(0.7)

            if let progress {
                Capsule()
                    .fill(DIYTheme.border)
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(.black)
                            .frame(width: 78 * min(max(progress, 0), 1))
                    }
                    .frame(width: 78, height: 5)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
    }
}

private struct DIYComponentCard: View {
    let component: DIYComponent
    let selected: CatalogComponentDTO?
    let price: Int?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                HStack(spacing: 8) {
                    DIYHardwareIcon(component: component)
                        .scaleEffect(0.82)
                        .frame(width: 44, height: 44)
                        .background(AppTheme.softSurface, in: Circle())

                    VStack(alignment: .leading, spacing: 6) {
                        Text(component.title)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(DIYTheme.primary)
                        Text(selected.map { "\($0.brand) \($0.name)" } ?? "点击选择配件")
                            .font(.system(size: 12, weight: .regular))
                            .foregroundStyle(DIYTheme.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                        if let price {
                            Text("¥\(price)")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(DIYTheme.primary)
                        }
                    }
                }
                .padding(.trailing, 28)

                Image(systemName: selected == nil ? "plus.circle" : "checkmark.circle.fill")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(selected == nil ? DIYTheme.primary : .black)
                    .padding(.trailing, 5)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 10)
            .frame(height: selected == nil ? 94 : 104, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DIYTheme.surface, in: RoundedRectangle(cornerRadius: 19))
            .shadow(color: .black.opacity(0.04), radius: 14, y: 5)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(component.title)，\(selected?.name ?? "未选择")")
    }
}

private struct DIYPartRow: View {
    let component: DIYComponent
    let selected: CatalogComponentDTO?
    let price: Int?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 18) {
                DIYHardwareIcon(component: component)
                    .frame(width: 34, height: 34)

                Text(component.title)
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(DIYTheme.primary)

                Spacer(minLength: 8)

                if let selected {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(selected.brand) \(selected.name)")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(DIYTheme.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                        if let price {
                            Text("¥\(price)")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(DIYTheme.secondary)
                        }
                    }
                } else {
                    Text("选择型号")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(DIYTheme.secondary)
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(DIYTheme.secondary)
            }
            .frame(height: 58)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(component.title)，\(selected?.name ?? "未选择")")
    }
}

private struct DIYStat: View {
    let title: String
    let value: String
    var info = false

    var body: some View {
        VStack(spacing: 9) {
            HStack(spacing: 6) {
                Text(title)
                if info {
                    Image(systemName: "info.circle")
                        .font(.system(size: 14, weight: .medium))
                }
            }
            .font(.system(size: 14, weight: .regular))
            .foregroundStyle(DIYTheme.secondary)
            Text(value)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(DIYTheme.primary)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct DIYComponentPicker: View {
    let slot: DIYComponent
    let components: [CatalogComponentDTO]
    let prices: [String: CatalogPriceDTO]
    @Binding var searchText: String
    let onSelect: (CatalogComponentDTO) -> Void
    let onDismiss: () -> Void
    @State private var vendorFilter = "全部"
    @State private var seriesFilter = "全部"

    private var availableComponents: [CatalogComponentDTO] {
        components.filter { $0.category == slot.backendCategory && prices[$0.id] != nil }
    }

    private var vendorFilters: [String] {
        ["全部"] + uniqueSorted(availableComponents.map(\.brand))
    }

    private var seriesFilters: [String] {
        let available = availableComponents
        let activeVendor = vendorFilters.contains(vendorFilter) ? vendorFilter : "全部"
        let source = activeVendor == "全部" ? available : available.filter { $0.brand == activeVendor }
        let familyMap = slot.id == "motherboard" ? motherboardFamilies(for: available) : [:]
        let values = source.compactMap { seriesLabel($0, motherboardFamilies: familyMap) }
        return ["全部"] + uniqueSorted(values)
    }

    private var filteredComponents: [CatalogComponentDTO] {
        let available = availableComponents
        let activeVendor = vendorFilters.contains(vendorFilter) ? vendorFilter : "全部"
        let activeSeries = seriesFilters.contains(seriesFilter) ? seriesFilter : "全部"
        let familyMap = slot.id == "motherboard" ? motherboardFamilies(for: available) : [:]

        return available
            .filter { component in
                let vendorMatches = activeVendor == "全部" || component.brand == activeVendor
                let seriesMatches = activeSeries == "全部" || seriesLabel(component, motherboardFamilies: familyMap) == activeSeries
                return vendorMatches && seriesMatches
            }
            .filter { component in
                let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !query.isEmpty else { return true }
                return "\(component.brand) \(component.name)".localizedCaseInsensitiveContains(query)
            }
            .sorted {
                let lhs = "\($0.brand) \($0.name)"
                let rhs = "\($1.brand) \($1.name)"
                return lhs.localizedCaseInsensitiveCompare(rhs) == .orderedAscending
            }
    }

    private func seriesLabel(_ component: CatalogComponentDTO, motherboardFamilies: [String: String]) -> String? {
        switch slot.id {
        case "cpu": return cpuSeries(component.name)
        case "gpu": return gpuSeries(component.name)
        case "motherboard": return motherboardFamilies[component.id]
        default: return nil
        }
    }

    private func motherboardFamilies(for available: [CatalogComponentDTO]) -> [String: String] {
        var result: [String: String] = [:]
        for component in available {
            if let chipset = chipsetValue(for: component),
               let family = chipsetFamily(from: chipset) {
                result[component.id] = family
            }
        }

        let knownFamilies = result.values.sorted { $0.count > $1.count }
        for component in available where result[component.id] == nil {
            let text = component.name.uppercased()
            if let family = knownFamilies.first(where: { text.contains($0) }) {
                result[component.id] = family
            }
        }
        return result
    }

    private func cpuSeries(_ name: String) -> String? {
        let text = name.uppercased()
        if text.contains("ULTRA") { return "酷睿 Ultra" }
        if text.contains("RYZEN") || text.contains("锐龙") {
            for tier in ["9", "7", "5", "3"] {
                if text.contains("RYZEN\(tier)") || text.contains("RYZEN \(tier)") || text.contains("锐龙\(tier)") || text.contains("锐龙 \(tier)") {
                    return "锐龙\(tier)"
                }
            }
            return "锐龙"
        }
        guard let digits = numberRuns(in: text).first(where: { $0.count >= 4 }) ?? numberRuns(in: text).last else { return nil }
        let generation: String
        generation = digits.count >= 5 ? String(digits.prefix(2)) : String(digits.prefix(1))
        return "\(generation)代酷睿"
    }

    private func gpuSeries(_ name: String) -> String? {
        let text = name.uppercased().replacingOccurrences(of: " ", with: "")
        for family in ["RTX", "GTX", "RX"] {
            guard let range = text.range(of: family) else { continue }
            let suffix = text[range.upperBound...]
            let remaining = suffix.drop(while: { !$0.isNumber })
            let number = remaining.prefix { $0.isNumber }
            guard number.count >= 2 else { continue }
            if family == "RX" {
                return "RX\(number.first.map { String($0) } ?? "")000系"
            }
            return "\(family)\(number.prefix(2))系"
        }
        if text.contains("ARC") { return "Arc 系列" }
        return nil
    }

    private func numberRuns(in text: String) -> [String] {
        var runs: [String] = []
        var current = ""
        for character in text {
            if character.isNumber {
                current.append(character)
            } else if !current.isEmpty {
                runs.append(current)
                current = ""
            }
        }
        if !current.isEmpty { runs.append(current) }
        return runs
    }

    private func chipsetValue(for component: CatalogComponentDTO) -> String? {
        if let value = component.specs["chipset"], let chipset = stringValue(value) {
            return chipset
        }
        if let value = component.specs["source_chipset"], let chipset = stringValue(value) {
            return chipset
        }
        if case let .object(sourceSpecs)? = component.specs["source_specs"],
           let value = sourceSpecs["chipset"],
           let chipset = stringValue(value) {
            return chipset
        }
        return nil
    }

    private func chipsetFamily(from value: String) -> String? {
        let characters = Array(value.uppercased())
        guard characters.count >= 4 else { return nil }
        for index in 0...(characters.count - 4) {
            guard "ABHXZ".contains(characters[index]) else { continue }
            let digits = characters[(index + 1)...(index + 3)]
            guard digits.allSatisfy(\.isNumber) else { continue }
            return String(characters[index...index + 3])
        }
        return nil
    }

    private func stringValue(_ value: CatalogJSONValue) -> String? {
        if case let .string(value) = value { return value }
        return nil
    }

    private func uniqueSorted(_ values: [String]) -> [String] {
        Array(Set(values)).sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    var body: some View {
        let visibleComponents = filteredComponents

        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text("选择\(slot.title)")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(DIYTheme.primary)
                    Text("分类 · \(slot.title) · \(visibleComponents.count) 个有价型号")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(DIYTheme.secondary)
                }

                Spacer()

                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(DIYTheme.primary)
                        .frame(width: 30, height: 30)
                        .background(DIYTheme.background, in: Circle())
                }
                .buttonStyle(.plain)
            }

            TextField("搜索品牌或型号", text: $searchText)
                .textFieldStyle(.roundedBorder)

            if vendorFilters.count > 1 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(vendorFilters, id: \.self) { filter in
                            Button {
                                vendorFilter = filter
                                seriesFilter = "全部"
                            } label: {
                                Text(filter)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(vendorFilter == filter ? .white : DIYTheme.primary)
                                    .padding(.horizontal, 13)
                                    .padding(.vertical, 8)
                                    .background(
                                        vendorFilter == filter ? DIYTheme.primary : DIYTheme.background,
                                        in: Capsule()
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            if seriesFilters.count > 1 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(seriesFilters, id: \.self) { filter in
                            Button {
                                seriesFilter = filter
                            } label: {
                                Text(filter)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(seriesFilter == filter ? .white : DIYTheme.primary)
                                    .padding(.horizontal, 13)
                                    .padding(.vertical, 8)
                                    .background(
                                        seriesFilter == filter ? DIYTheme.primary : DIYTheme.background,
                                        in: Capsule()
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            if visibleComponents.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "shippingbox")
                        .font(.system(size: 28))
                        .foregroundStyle(DIYTheme.secondary)
                    Text(components.isEmpty ? "目录加载中，请稍后重试" : "没有匹配的有价型号")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(DIYTheme.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 8) {
                        ForEach(visibleComponents) { component in
                            Button {
                                onSelect(component)
                            } label: {
                                HStack(spacing: 10) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(component.name)
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundStyle(DIYTheme.primary)
                                            .lineLimit(2)
                                        Text(component.brand)
                                            .font(.system(size: 12))
                                            .foregroundStyle(DIYTheme.secondary)
                                    }

                                    Spacer(minLength: 8)

                                    Text("¥\(prices[component.id]?.referencePrice ?? 0)")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(DIYTheme.primary)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 11)
                                .background(DIYTheme.background, in: RoundedRectangle(cornerRadius: 12))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .padding(18)
        .background(DIYTheme.surface, in: RoundedRectangle(cornerRadius: 24))
        .shadow(color: .black.opacity(0.2), radius: 28, y: 12)
    }
}

private struct DIYShareCard: View {
    let parts: [DIYStoredPart]
    let totalPrice: Int
    let estimatedPower: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("UzBox DIY 配置单")
                .font(.system(size: 36, weight: .heavy))
                .foregroundStyle(.black)

            Text("自定义电脑硬件方案")
                .font(.system(size: 18, weight: .regular))
                .foregroundStyle(.gray)
                .padding(.top, 8)

            HStack(spacing: 0) {
                summary(title: "预计总价", value: totalPrice > 0 ? "¥\(totalPrice)" : "待选择")
                Divider().frame(height: 68)
                summary(title: "预计功耗", value: estimatedPower.map { "\($0)W" } ?? "待选择")
            }
            .padding(.vertical, 28)

            Divider()

            ForEach(Array(parts.enumerated()), id: \.offset) { _, part in
                HStack(spacing: 18) {
                    Text(part.category)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.black)
                        .frame(width: 120, alignment: .leading)

                    VStack(alignment: .leading, spacing: 5) {
                        Text(part.name)
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(.black)
                            .lineLimit(2)
                        Text(part.brand)
                            .font(.system(size: 16))
                            .foregroundStyle(.gray)
                    }

                    Spacer()

                    if let price = part.price {
                        Text("¥\(price)")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(.black)
                    }
                }
                .padding(.vertical, 18)
                Divider()
            }
        }
        .padding(42)
        .background(Color.white)
    }

    private func summary(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(.gray)
            Text(value)
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(.black)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct DIYHardwareIcon: View {
    let component: DIYComponent

    @ViewBuilder
    var body: some View {
        switch component.id {
        case "gpu":
            ZStack {
                RoundedRectangle(cornerRadius: 3).fill(.black).frame(width: 44, height: 27)
                HStack(spacing: 4) {
                    Circle().fill(.white).frame(width: 10, height: 10)
                    Circle().fill(.white).frame(width: 10, height: 10)
                }
                Rectangle().fill(.black).frame(width: 4, height: 18).offset(x: -24)
            }
        case "motherboard":
            ZStack {
                RoundedRectangle(cornerRadius: 2).fill(.black).frame(width: 33, height: 43)
                VStack(spacing: 4) {
                    Rectangle().fill(.white).frame(width: 18, height: 4)
                    Rectangle().fill(.white).frame(width: 10, height: 9)
                    Rectangle().fill(.white).frame(width: 19, height: 4)
                }
            }
        case "cooler", "power":
            ZStack {
                RoundedRectangle(cornerRadius: 3).fill(.black).frame(width: 39, height: 39)
                Image(systemName: "fanblades").font(.system(size: 23, weight: .medium)).foregroundStyle(.white)
            }
        case "case":
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2).stroke(.black, lineWidth: 3).frame(width: 27, height: 43)
                Rectangle().stroke(.black, lineWidth: 3).frame(width: 13, height: 35).offset(x: 15)
                Rectangle().fill(.black).frame(width: 10, height: 3).offset(x: 5, y: -13)
            }
        default:
            Image(systemName: component.icon)
                .font(.system(size: 25, weight: .medium))
                .foregroundStyle(.black)
        }
    }
}

private enum DIYTheme {
    static let background = Color(red: 0.969, green: 0.965, blue: 0.969)
    static let surface = Color.white
    static let primary = Color(red: 0.08, green: 0.08, blue: 0.08)
    static let secondary = Color(red: 0.35, green: 0.35, blue: 0.35)
    static let border = Color(red: 0.88, green: 0.89, blue: 0.91)
}

private struct DIYComponent: Identifiable {
    let id: String
    let title: String
    let backendCategory: String
    let icon: String

    static let all = [
        DIYComponent(id: "cpu", title: "CPU", backendCategory: "cpu", icon: "cpu"),
        DIYComponent(id: "gpu", title: "显卡", backendCategory: "gpu", icon: "display"),
        DIYComponent(id: "motherboard", title: "主板", backendCategory: "motherboard", icon: "rectangle.split.3x3"),
        DIYComponent(id: "cooler", title: "散热器", backendCategory: "cooler", icon: "fanblades"),
        DIYComponent(id: "memory", title: "内存", backendCategory: "ram", icon: "memorychip"),
        DIYComponent(id: "storage", title: "固态硬盘", backendCategory: "storage", icon: "externaldrive"),
        DIYComponent(id: "power", title: "电源", backendCategory: "psu", icon: "bolt.fill"),
        DIYComponent(id: "case", title: "机箱", backendCategory: "case", icon: "shippingbox")
    ]
}

#Preview {
    DIYView()
}
