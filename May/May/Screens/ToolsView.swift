import SwiftUI

struct ToolsView: View {
    let onOpenDisplayMatch: () -> Void
    let accessToken: String?

    @State private var comparisonMode: ComparisonMode = .gpu
    @State private var ladderMode: PerformanceLadderCategory = .gpu
    @State private var leftComparisonID: String?
    @State private var rightComparisonID: String?
    @State private var comparisonPickerSide: ComparisonSide?
    @State private var comparisonResult: PerformanceComparisonResponseDTO?
    @State private var comparisonError: String?
    @State private var isComparing = false
    @State private var hasCompared = false
    @State private var isLadderPresented = false
    @State private var isDIYPresented = false
    @State private var importedDIYBuild: BuildOptionDTO?
    @State private var ladderPreviewCache: [PerformanceLadderCategory: [PerformanceLadderItemDTO]] = [:]

    init(onOpenDisplayMatch: @escaping () -> Void, accessToken: String? = nil) {
        self.onOpenDisplayMatch = onOpenDisplayMatch
        self.accessToken = accessToken
    }

    var body: some View {
        GeometryReader { proxy in
            let contentWidth = min(proxy.size.width - 40, 400)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 12) {
                    toolsHeader
                    ladderCard
                    comparisonCard

                    utilityLinksCard
                        .frame(width: contentWidth, height: 125)
                }
                .frame(width: contentWidth, alignment: .leading)
                .padding(.top, 18)
                .padding(.bottom, 112)
                .frame(width: proxy.size.width, alignment: .center)
            }
            .scrollBounceBehavior(.always, axes: .vertical)
            .background(Color.white.ignoresSafeArea())
            .navigationDestination(isPresented: $isLadderPresented) {
                PerformanceLadderView(initialCategory: ladderMode)
            }
            .navigationDestination(isPresented: $isDIYPresented) {
                DIYView(importedBuild: $importedDIYBuild, accessToken: accessToken)
            }
            .task(id: ladderMode) {
                await loadLadderPreview(ladderMode)
            }
        }
    }

    private var toolsHeader: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("装机工具")
                .font(.system(size: 23, weight: .bold))
                .foregroundStyle(.black)
                .offset(y: -5)
            Text("UZBOX TOOLS")
                .font(.system(size: 10, weight: .medium))
                .tracking(4.2)
                .foregroundStyle(Color.black.opacity(0.28))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var comparisonCard: some View {
        ToolPanel {
            if !hasCompared {
                ToolPanelHeader(title: "对比工具") {
                    ToolSegmentedControl(
                        options: ComparisonMode.allCases,
                        selection: $comparisonMode
                    )
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            HStack(spacing: 10) {
                comparisonHardwareButton(id: leftComparisonID, side: .left)

                ZStack {
                    if hasCompared, let result = comparisonResult {
                        VStack(spacing: 3) {
                            Text(result.left.benchmarkScore == result.right.benchmarkScore
                                ? "="
                                : (result.strongerId == result.left.id ? ">" : "<"))
                                .font(.system(size: 42, weight: .heavy, design: .rounded))
                                .contentTransition(.interpolate)
                            Text(String(format: "%.1f%%", result.strongerByPercent))
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .monospacedDigit()
                                .contentTransition(.numericText())
                        }
                        .transition(.scale(scale: 0.7).combined(with: .opacity))
                    } else {
                        Text(isComparing ? "…" : "VS")
                            .font(.system(size: 30, weight: .heavy, design: .rounded))
                            .foregroundStyle(AppTheme.primaryText)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .frame(width: 62)

                comparisonHardwareButton(id: rightComparisonID, side: .right)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, hasCompared ? 34 : 42)

            Button {
                if hasCompared {
                    withAnimation(.easeInOut(duration: 0.32)) {
                        hasCompared = false
                        comparisonResult = nil
                        comparisonError = nil
                    }
                } else {
                    Task { await compareSelections() }
                }
            } label: {
                HStack(spacing: 6) {
                    if isComparing { ProgressView().tint(.white) }
                    Text(hasCompared ? "重新比较  →" : "开始比较  →")
                }
            }
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(.white)
            .frame(width: 160, height: 32)
            .background(Color.black, in: Capsule())
            .frame(maxWidth: .infinity)
            .padding(.top, hasCompared ? 14 : 17)
            .disabled(isComparing || leftComparisonID == nil || rightComparisonID == nil || leftComparisonID == rightComparisonID)

            if let comparisonError {
                Text(comparisonError)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.red.opacity(0.8))
                    .frame(maxWidth: .infinity)
                    .padding(.top, 5)
                    .transition(.opacity)
            }
        }
        .frame(height: 276)
        .animation(.easeInOut(duration: 0.34), value: hasCompared)
        .animation(.easeInOut(duration: 0.26), value: comparisonResult?.strongerByPercent)
        .sheet(item: $comparisonPickerSide) { side in
            HardwarePickerSheet(
                title: comparisonMode == .gpu ? "显卡" : "CPU",
                icon: comparisonMode == .gpu ? "rectangle.3.group" : "cpu",
                filters: HardwareCatalog.filters(for: comparisonMode == .gpu ? "显卡" : "CPU"),
                selectedValue: comparisonSelectionBinding(for: side)
            )
            .presentationDetents([.large])
        }
        .onChange(of: comparisonMode) { _, newMode in
            leftComparisonID = nil
            rightComparisonID = nil
            withAnimation(.easeInOut(duration: 0.28)) {
                hasCompared = false
                comparisonResult = nil
                comparisonError = nil
            }
        }
    }

    private func comparisonHardwareButton(id: String?, side: ComparisonSide) -> some View {
        let item = id.flatMap { selectedID in comparisonItems.first(where: { $0.id == selectedID }) }
        return VStack(spacing: 9) {
            ZStack(alignment: .topLeading) {
                Button {
                    comparisonPickerSide = side
                } label: {
                    if let item {
                        VendorLogo(brand: item.brand)
                    } else {
                        Image(systemName: "plus")
                            .font(.system(size: 21, weight: .regular))
                            .foregroundStyle(AppTheme.secondaryText)
                            .frame(width: 56, height: 56)
                            .background(Color.black.opacity(0.035), in: Circle())
                    }
                }
                .buttonStyle(.plain)
                .contentShape(Circle())
                .disabled(hasCompared || isComparing)

                if item != nil {
                    Button {
                        clearComparisonSelection(for: side)
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 18, height: 18)
                            .background(Color.gray.opacity(0.82), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .offset(x: -8, y: -8)
                    .zIndex(2)
                    .accessibilityLabel("删除已选型号")
                    .disabled(hasCompared || isComparing)
                }
            }

            Button {
                comparisonPickerSide = side
            } label: {
                Text(item?.name ?? (comparisonMode == .gpu ? "选择显卡" : "选择 CPU"))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppTheme.primaryText)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.72)
                    .frame(width: 120)
            }
            .buttonStyle(.plain)
            .disabled(hasCompared || isComparing)
        }
        .frame(width: 120, height: 126)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("选择\(side == .left ? "左侧" : "右侧")\(comparisonMode == .gpu ? "显卡" : "CPU")")
    }

    private var comparisonItems: [HardwareCatalogItem] {
        comparisonMode == .gpu ? HardwareCatalog.gpus : HardwareCatalog.cpus
    }

    private func comparisonSelectionBinding(for side: ComparisonSide) -> Binding<String> {
        Binding(
            get: {
                let id = side == .left ? leftComparisonID : rightComparisonID
                return id.flatMap { selectedID in comparisonItems.first(where: { $0.id == selectedID })?.name } ?? ""
            },
            set: { value in
                guard let id = comparisonItems.first(where: { $0.name == value })?.id else { return }
                if side == .left { leftComparisonID = id } else { rightComparisonID = id }
                comparisonResult = nil
                comparisonError = nil
            }
        )
    }

    private func clearComparisonSelection(for side: ComparisonSide) {
        if side == .left { leftComparisonID = nil } else { rightComparisonID = nil }
        comparisonResult = nil
        comparisonError = nil
    }

    @MainActor
    private func compareSelections() async {
        guard let leftComparisonID, let rightComparisonID, leftComparisonID != rightComparisonID else { return }
        isComparing = true
        comparisonError = nil
        withAnimation(.easeInOut(duration: 0.34)) { hasCompared = true }
        defer { isComparing = false }
        do {
            comparisonResult = try await AppAPIClient().comparePerformance(
                category: comparisonMode == .gpu ? "gpu" : "cpu",
                leftID: leftComparisonID,
                rightID: rightComparisonID
            )
        } catch {
            comparisonError = error.localizedDescription
        }
    }

    private var ladderCard: some View {
        ToolPanel {
            ToolPanelHeader(title: "性能天梯") {
                ToolSegmentedControl(options: PerformanceLadderCategory.allCases, selection: $ladderMode)
            }

            VStack(spacing: 12) {
                ForEach(Array(ladderPreviewItems.prefix(5))) { item in
                    HStack(spacing: 6) {
                        Text("\(item.rank)")
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.white)
                            .frame(width: 19, height: 19)
                            .background(Color.black, in: Circle())

                        Text(item.name)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(AppTheme.primaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                            .frame(width: 100, alignment: .leading)

                        GeometryReader { proxy in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.black.opacity(0.08))
                                Capsule().fill(Color.black)
                                    .frame(
                                        width: proxy.size.width
                                            * CGFloat(min(max(item.relativePercent / 100, 0), 1))
                                    )
                            }
                        }
                        .frame(width: 162, height: 4)

                        Text(String(format: "%.1f%%", item.relativePercent))
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundStyle(AppTheme.secondaryText)
                            .monospacedDigit()
                            .frame(width: 43, alignment: .trailing)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.trailing, 14)
                }
            }
            .padding(.top, 26)

            Button("查看全部  →") {
                isLadderPresented = true
            }
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AppTheme.primaryText)
                .frame(maxWidth: .infinity)
                .padding(.top, 14)
        }
        .frame(height: 278)
    }

    private var ladderPreviewItems: [PerformanceLadderItemDTO] {
        ladderPreviewCache[ladderMode] ?? fallbackLadderPreview(for: ladderMode)
    }

    private func fallbackLadderPreview(
        for category: PerformanceLadderCategory
    ) -> [PerformanceLadderItemDTO] {
        let rows: [(String, String, Double)] = category == .gpu
            ? [
                ("rtx-5090", "RTX 5090", 100),
                ("rtx-5090-d", "RTX 5090 D", 100),
                ("rtx-5090-d-v2", "RTX 5090 D V2", 98.9),
                ("rtx-4090-d", "RTX 4090 D", 72.1),
                ("rtx-5080", "RTX 5080", 69.5),
            ]
            : [
                ("r7-9850x3d", "Ryzen 7 9850X3D", 100),
                ("r9-9900x3d", "Ryzen 9 9900X3D", 99),
                ("r7-9800x3d", "Ryzen 7 9800X3D", 97),
                ("r9-9950x3d", "Ryzen 9 9950X3D", 90),
                ("r9-7900x3d", "Ryzen 9 7900X3D", 83),
            ]
        return rows.enumerated().map { index, row in
            PerformanceLadderItemDTO(
                rank: index + 1,
                id: row.0,
                name: row.1,
                brand: "",
                benchmarkScore: 0,
                relativePercent: row.2
            )
        }
    }

    @MainActor
    private func loadLadderPreview(_ category: PerformanceLadderCategory) async {
        guard ladderPreviewCache[category] == nil else { return }
        guard let response = try? await AppAPIClient().performanceLadder(
            category: category.apiValue
        ) else { return }
        ladderPreviewCache[category] = Array(response.items.prefix(5))
    }

    private var utilityLinksCard: some View {
        HStack(spacing: 0) {
            Button(action: onOpenDisplayMatch) {
                VStack {
                    Spacer(minLength: 0)
                    MonitorGraphic()
                        .frame(maxWidth: .infinity)
                    Spacer(minLength: 4)
                    HStack(spacing: 0) {
                        Text("显卡 × 显示器匹配")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(AppTheme.primaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Spacer(minLength: 6)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 14, weight: .medium))
                    }
                }
            }
            .buttonStyle(.plain)

            Rectangle()
                .fill(Color.black.opacity(0.10))
                .frame(width: 1, height: 76)

            Button {
                isDIYPresented = true
            } label: {
                VStack {
                    Spacer(minLength: 0)
                    DIYEntryGraphic()
                        .frame(maxWidth: .infinity)
                    Spacer(minLength: 4)
                    HStack(spacing: 0) {
                        Text("DIY 装机")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(AppTheme.primaryText)
                        Spacer(minLength: 6)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 14, weight: .medium))
                    }
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 15)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 23))
        .overlay {
            RoundedRectangle(cornerRadius: 23)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.085), radius: 10, y: 5)
    }

    private struct DIYEntryGraphic: View {
        var body: some View {
            Image(systemName: "desktopcomputer")
                .font(.system(size: 34, weight: .regular))
            .foregroundStyle(Color.black)
        }
    }
}

private enum ComparisonMode: String, CaseIterable, Identifiable {
    case gpu = "显卡"
    case cpu = "CPU"

    var id: String { rawValue }
    var title: String { self == .gpu ? "选择显卡" : "选择 CPU" }
}

private enum ComparisonSide: String, Identifiable {
    case left
    case right

    var id: String { rawValue }
}

private struct ToolPanel<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
        }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.horizontal, 16)
            .padding(.vertical, 15)
            .micro3DSurface(
                cornerRadius: 23,
                surfaceColor: Color.white,
                rimColor: Color.black.opacity(0.065),
                borderColor: Color.white.opacity(0.82),
                shadowColor: Color.black.opacity(0.085),
                showsTopHighlight: true
            )
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ToolPanelHeader<Trailing: View>: View {
    let title: String
    let showsMarker: Bool
    let trailing: Trailing

    init(title: String, showsMarker: Bool = true, @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.showsMarker = showsMarker
        self.trailing = trailing()
    }

    var body: some View {
        HStack(spacing: 10) {
            if showsMarker {
                Capsule()
                    .fill(Color.black)
                    .frame(width: 4, height: 16)
            }

            Text(title)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(AppTheme.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .allowsTightening(true)
                .layoutPriority(-1)

            Spacer(minLength: 0)
            trailing
        }
    }
}

private struct ToolSegmentedControl<Option: Hashable & Identifiable & RawRepresentable>: View where Option.RawValue == String {
    let options: [Option]
    @Binding var selection: Option
    @Namespace private var selectionAnimation

    var body: some View {
        HStack(spacing: 2) {
            ForEach(options) { option in
                Button(option.rawValue) {
                    withAnimation(.easeInOut(duration: 0.22)) {
                        selection = option
                    }
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(selection == option ? Color.white : AppTheme.primaryText)
                .frame(width: 64, height: 22)
                .background {
                    if selection == option {
                        Capsule()
                            .fill(Color.black)
                            .matchedGeometryEffect(id: "selected", in: selectionAnimation)
                    }
                }
            }
        }
        .padding(2)
        .background(Color.black.opacity(0.045), in: Capsule())
    }
}

private struct HardwarePlaceholder: View {
    let title: String

    var body: some View {
        VStack(spacing: 13) {
            Image(systemName: "plus")
                .font(.system(size: 21, weight: .regular))
                .frame(width: 56, height: 56)
                .background(Color.black.opacity(0.035), in: Circle())

            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AppTheme.primaryText)
                .lineLimit(1)

            Text("支持 NVIDIA / AMD")
                .font(.system(size: 10, weight: .regular))
                .foregroundStyle(AppTheme.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(width: 120, height: 126)
    }
}

private struct VendorLogo: View {
    let brand: String

    private var normalizedBrand: String {
        brand.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white)
                .overlay(Circle().stroke(Color.black.opacity(0.08), lineWidth: 1))

            if let imageName {
                Image(imageName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 56, height: 56)
                    .clipShape(Circle())
            } else {
                Text(mark)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.primaryText)
                    .minimumScaleFactor(0.55)
            }
        }
        .frame(width: 56, height: 56)
    }

    private var imageName: String? {
        switch normalizedBrand {
        case "nvidia": "VendorNVIDIA"
        case "amd": "VendorAMD"
        case "intel": "VendorIntel"
        default: nil
        }
    }

    private var mark: String {
        switch normalizedBrand {
        case "nvidia": "NVIDIA"
        case "amd": "AMD"
        case "intel": "intel"
        default: brand.isEmpty ? "?" : brand
        }
    }

}

private struct PerformanceComparisonView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var mode: ComparisonMode
    @State private var leftID: String
    @State private var rightID: String
    @State private var result: PerformanceComparisonResponseDTO?
    @State private var isLoading = false
    @State private var errorMessage: String?

    init(initialMode: ComparisonMode) {
        _mode = State(initialValue: initialMode)
        _leftID = State(initialValue: initialMode == .gpu ? "rtx-5090" : "r7-9800x3d")
        _rightID = State(initialValue: initialMode == .gpu ? "rtx-5080" : "i5-12400f")
    }

    private var items: [HardwareCatalogItem] {
        mode == .gpu ? HardwareCatalog.gpus : HardwareCatalog.cpus
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    ToolSegmentedControl(options: ComparisonMode.allCases, selection: $mode)
                        .onChange(of: mode) { _, newMode in
                            leftID = newMode == .gpu ? "rtx-5090" : "r7-9800x3d"
                            rightID = newMode == .gpu ? "rtx-5080" : "i5-12400f"
                            result = nil
                            errorMessage = nil
                        }

                    comparisonPicker(title: "左侧型号", selection: $leftID)
                    comparisonPicker(title: "右侧型号", selection: $rightID)

                    Button {
                        Task { await compare() }
                    } label: {
                        HStack {
                            if isLoading {
                                ProgressView().tint(.white)
                            }
                            Text(isLoading ? "比较中…" : "开始比较")
                        }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                        .background(Color.black, in: Capsule())
                    }
                    .disabled(isLoading || leftID == rightID)

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 13))
                            .foregroundStyle(Color.red.opacity(0.8))
                    }

                    if let result {
                        resultView(result)
                    }
                }
                .padding(20)
            }
            .background(Color.white.ignoresSafeArea())
            .navigationTitle("性能对比")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }

    private func comparisonPicker(title: String, selection: Binding<String>) -> some View {
        Menu {
            ForEach(items) { item in
                Button(item.name) { selection.wrappedValue = item.id }
            }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.secondaryText)
                    Text(items.first(where: { $0.id == selection.wrappedValue })?.name ?? "选择型号")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(AppTheme.primaryText)
                }
                Spacer()
                Image(systemName: "chevron.up.chevron.down")
                    .foregroundStyle(AppTheme.secondaryText)
            }
            .padding(.horizontal, 16)
            .frame(height: 64)
            .background(Color.black.opacity(0.04), in: RoundedRectangle(cornerRadius: 16))
        }
    }

    private func resultView(_ result: PerformanceComparisonResponseDTO) -> some View {
        VStack(spacing: 14) {
            HStack(spacing: 10) {
                scoreCard(result.left, benchmark: result.benchmark)
                Text("VS")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(AppTheme.secondaryText)
                scoreCard(result.right, benchmark: result.benchmark)
            }

            Text(result.summary)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(AppTheme.primaryText)
                .multilineTextAlignment(.center)

            Text(result.benchmark == "time_spy"
                ? "以 RTX 5090 / RTX 5090 D 的 47539 分为 100%"
                : "以 Valorant 双分辨率平均帧数归一化")
                .font(.system(size: 11))
                .foregroundStyle(AppTheme.secondaryText)
        }
        .padding(16)
        .background(Color.black.opacity(0.035), in: RoundedRectangle(cornerRadius: 20))
    }

    private func scoreCard(
        _ hardware: PerformanceComparisonHardwareDTO,
        benchmark: String
    ) -> some View {
        VStack(spacing: 5) {
            Text(hardware.name)
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(String(format: "%.1f%%", hardware.relativePercent))
                .font(.system(size: 24, weight: .bold, design: .rounded))
            Text(benchmark == "time_spy"
                ? "(Int(hardware.benchmarkScore.rounded())) 分"
                : "(Int(hardware.benchmarkScore.rounded())) FPS")
                .font(.system(size: 11))
                .foregroundStyle(AppTheme.secondaryText)
        }
        .frame(maxWidth: .infinity)
    }

    private func compare() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            result = try await AppAPIClient().comparePerformance(
                category: mode == .gpu ? "gpu" : "cpu",
                leftID: leftID,
                rightID: rightID
            )
        } catch {
            result = nil
            errorMessage = error.localizedDescription
        }
    }
}

private struct MonitorGraphic: View {
    var body: some View {
        VStack(spacing: 2) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .stroke(Color.black, lineWidth: 2.2)
                .frame(width: 54, height: 35)
            Rectangle()
                .fill(Color.black)
                .frame(width: 26, height: 2.2)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(Color.black)
                        .frame(width: 2.2, height: 8)
                        .offset(y: 4)
                }
        }
        .foregroundStyle(Color.black)
    }
}

#Preview {
    ToolsView(onOpenDisplayMatch: {})
}
