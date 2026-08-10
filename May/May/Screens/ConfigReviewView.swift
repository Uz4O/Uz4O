import SwiftUI
import PhotosUI
import UIKit

private enum ConfigReviewState {
    case landing
    case manualEntry
    case loading
    case result(ConfigReviewResponseDTO)
    case error(String)
}

enum ConfigReviewPartCategory: String, CaseIterable, Identifiable {
    case cpu
    case motherboard
    case gpu
    case memory
    case storage
    case powerSupply

    var id: String { rawValue }

    var title: String {
        switch self {
        case .cpu: "CPU"
        case .motherboard: "主板"
        case .gpu: "显卡"
        case .memory: "内存"
        case .storage: "硬盘"
        case .powerSupply: "电源"
        }
    }

    var icon: String {
        switch self {
        case .cpu: "cpu"
        case .motherboard: "rectangle.3.group"
        case .gpu: "display"
        case .memory: "memorychip"
        case .storage: "internaldrive"
        case .powerSupply: "bolt"
        }
    }

    func filters(selectedCPU: String) -> [HardwareCatalogFilter] {
        if self == .motherboard, !selectedCPU.isEmpty {
            return HardwareCatalog.motherboardFilters(compatibleWithCPU: selectedCPU)
        }
        return HardwareCatalog.filters(for: title)
    }
}

struct ConfigReviewDraft {
    private var models = Dictionary(
        uniqueKeysWithValues: ConfigReviewPartCategory.allCases.map { ($0, "") }
    )
    private var prices = Dictionary(
        uniqueKeysWithValues: ConfigReviewPartCategory.allCases.map { ($0, "") }
    )

    var completedPartCount: Int {
        ConfigReviewPartCategory.allCases.filter {
            !model(for: $0).isEmpty && priceValue(for: $0) != nil
        }.count
    }

    var canSubmit: Bool {
        completedPartCount >= 2
    }

    var totalPrice: Int {
        ConfigReviewPartCategory.allCases.compactMap(priceValue(for:)).reduce(0, +)
    }

    var sourceText: String {
        var lines = ["配置单（用户手动填写）"]

        for category in ConfigReviewPartCategory.allCases {
            let model = model(for: category)
            guard !model.isEmpty else { continue }

            if let price = priceValue(for: category) {
                lines.append("\(category.title)：\(model)，价格 \(price) 元")
            } else {
                lines.append("\(category.title)：\(model)")
            }
        }

        if totalPrice > 0 {
            lines.append("商家报价：\(totalPrice) 元")
        }

        return lines.joined(separator: "\n")
    }

    func model(for category: ConfigReviewPartCategory) -> String {
        models[category, default: ""]
    }

    func price(for category: ConfigReviewPartCategory) -> String {
        prices[category, default: ""]
    }

    mutating func setModel(_ value: String, for category: ConfigReviewPartCategory) {
        models[category] = value
    }

    mutating func setPrice(_ value: String, for category: ConfigReviewPartCategory) {
        prices[category] = value.filter(\.isNumber)
    }

    private func priceValue(for category: ConfigReviewPartCategory) -> Int? {
        let value = price(for: category)
        guard !value.isEmpty, let price = Int(value), price > 0 else { return nil }
        return price
    }
}

struct ConfigReviewView: View {
    let onBack: () -> Void

    @State private var selectedImageItem: PhotosPickerItem?
    @State private var state: ConfigReviewState = .landing
    @State private var draft = ConfigReviewDraft()
    @State private var requestID = UUID()

    var body: some View {
        Group {
            switch state {
            case .landing:
                ConfigReviewLandingView(
                    selectedImageItem: $selectedImageItem,
                    onBack: onBack,
                    onManualEntry: { state = .manualEntry }
                )
            case .manualEntry:
                ConfigReviewManualEntryView(
                    draft: $draft,
                    onBack: { state = .landing },
                    onSubmit: startManualReview
                )
            case .loading:
                ConfigReviewLoadingView(onBack: cancelReview)
            case .result(let result):
                ConfigReviewResultView(
                    result: result,
                    onBack: { state = .landing }
                )
            case .error(let message):
                ConfigReviewErrorView(
                    message: message,
                    onBack: { state = .landing }
                )
            }
        }
        .background(Color.white.ignoresSafeArea())
        .onChange(of: selectedImageItem) { _, item in
            guard let item else { return }
            startImageReview(item)
        }
    }

    private func startManualReview() {
        startTextReview(draft.sourceText)
    }

    private func startTextReview(_ text: String) {
        let activeRequestID = UUID()
        requestID = activeRequestID
        state = .loading

        Task {
            do {
                let result = try await AppAPIClient().analyzeConfigReviewText(text)
                guard requestID == activeRequestID else { return }
                state = .result(result)
            } catch {
                guard requestID == activeRequestID else { return }
                state = .error(error.localizedDescription)
            }
        }
    }

    private func startImageReview(_ item: PhotosPickerItem) {
        let activeRequestID = UUID()
        requestID = activeRequestID
        state = .loading

        Task {
            defer { selectedImageItem = nil }

            do {
                guard let data = try await item.loadTransferable(type: Data.self) else {
                    guard requestID == activeRequestID else { return }
                    state = .error("没有读取到图片内容")
                    return
                }

                let result = try await AppAPIClient().analyzeConfigReviewImage(imageData: data)
                guard requestID == activeRequestID else { return }
                state = .result(result)
            } catch {
                guard requestID == activeRequestID else { return }
                state = .error(error.localizedDescription)
            }
        }
    }

    private func cancelReview() {
        requestID = UUID()
        state = .landing
    }
}

private struct ConfigReviewLandingView: View {
    @Binding var selectedImageItem: PhotosPickerItem?
    let onBack: () -> Void
    let onManualEntry: () -> Void

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                ConfigReviewLandingTopBar(onBack: onBack)

                VStack(alignment: .leading, spacing: 8) {
                    Text("配置排雷")
                        .font(.system(size: 42, weight: .black))
                        .foregroundStyle(.black)

                    Text("商家配置先别急着买，帮你看懂型号、价格和搭配风险")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(ConfigReviewPalette.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 18)

                ConfigReviewNumberedSection(number: "01") {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("上传配置单")
                            .font(.system(size: 28, weight: .black))
                            .foregroundStyle(.black)

                        Text("支持截图、照片和聊天记录")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(ConfigReviewPalette.secondary)

                        Text("配置截图  ·  报价单照片  ·  聊天记录")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(ConfigReviewPalette.muted)

                        PhotosPicker(selection: $selectedImageItem, matching: .images) {
                            ConfigReviewPrimaryActionLabel(title: "选择图片")
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 4)
                    }
                }
                .padding(.top, 34)

                Divider()
                    .overlay(ConfigReviewPalette.divider)
                    .padding(.top, 28)

                ConfigReviewNumberedSection(number: "02") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("填写配置")
                            .font(.system(size: 28, weight: .black))
                            .foregroundStyle(.black)

                        Text("逐项选择配件型号，并填写商家报价")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(ConfigReviewPalette.secondary)

                        ConfigReviewEntryPreview(onOpen: onManualEntry)
                            .padding(.top, 4)

                        Button(action: onManualEntry) {
                            ConfigReviewSecondaryActionLabel(title: "填写配置")
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 4)
                    }
                }
                .padding(.top, 26)

                Color.clear
                    .frame(height: 24)
            }
            .padding(.horizontal, 28)
        }
    }
}

private struct ConfigReviewLandingTopBar: View {
    let onBack: () -> Void

    var body: some View {
        HStack {
            ConfigReviewBackButton(action: onBack)
            Spacer()
        }
        .padding(.top, 8)
    }
}

private struct ConfigReviewNumberedSection<Content: View>: View {
    let number: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .firstTextBaseline, spacing: 16) {
                Text(number)
                    .font(.system(size: 32, weight: .bold))
                Text("/")
                    .font(.system(size: 27, weight: .medium))
            }
            .foregroundStyle(ConfigReviewPalette.number)

            content()
        }
    }
}

private struct ConfigReviewEntryPreview: View {
    let onOpen: () -> Void

    private let rows = [
        ("cpu", "CPU / 主板", "选择型号"),
        ("display", "显卡 / 内存", "选择型号"),
        ("bolt", "电源 / 商家总价", "填写价格")
    ]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                Button(action: onOpen) {
                    HStack(spacing: 14) {
                        Image(systemName: row.0)
                            .font(.system(size: 17, weight: .semibold))
                            .frame(width: 28)

                        Text(row.1)
                            .font(.system(size: 15, weight: .bold))

                        Spacer()

                        Text(row.2)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(ConfigReviewPalette.muted)

                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(ConfigReviewPalette.muted)
                    }
                    .foregroundStyle(.black)
                    .frame(height: 48)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if index < rows.count - 1 {
                    Divider().overlay(ConfigReviewPalette.divider)
                }
            }
        }
    }
}

private struct ConfigReviewPrimaryActionLabel: View {
    let title: String

    var body: some View {
        HStack(spacing: 18) {
            Text(title)
            Image(systemName: "arrow.right")
        }
        .font(.system(size: 16, weight: .bold))
        .foregroundStyle(.white)
        .frame(width: 226, height: 52)
        .background(Color.black, in: RoundedRectangle(cornerRadius: 13))
    }
}

private struct ConfigReviewSecondaryActionLabel: View {
    let title: String

    var body: some View {
        HStack(spacing: 18) {
            Text(title)
            Image(systemName: "arrow.right")
        }
        .font(.system(size: 16, weight: .bold))
        .foregroundStyle(.black)
        .frame(width: 226, height: 52)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 13))
        .overlay(
            RoundedRectangle(cornerRadius: 13)
                .stroke(Color.black, lineWidth: 1.3)
        )
    }
}

private struct ConfigReviewManualEntryView: View {
    @Binding var draft: ConfigReviewDraft
    let onBack: () -> Void
    let onSubmit: () -> Void

    @State private var selectedCategory: ConfigReviewPartCategory?

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    ConfigReviewBackButton(action: onBack)
                    Spacer()
                    Text("填写配置")
                        .font(.system(size: 17, weight: .bold))
                    Spacer()
                    Color.clear.frame(width: 32, height: 32)
                }
                .padding(.top, 8)

                Text("填写配置")
                    .font(.system(size: 40, weight: .black))
                    .foregroundStyle(.black)
                    .padding(.top, 32)

                Text("选择配件型号，再填写商家给出的单项价格")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(ConfigReviewPalette.secondary)
                    .padding(.top, 8)

                VStack(spacing: 0) {
                    ForEach(ConfigReviewPartCategory.allCases) { category in
                        ConfigReviewPartInputRow(
                            category: category,
                            model: draft.model(for: category),
                            price: priceBinding(for: category),
                            onSelectModel: { selectedCategory = category }
                        )

                        if category != ConfigReviewPartCategory.allCases.last {
                            Divider().overlay(ConfigReviewPalette.divider)
                        }
                    }
                }
                .padding(.top, 28)

                Text("至少完成 2 项配件的型号与价格，即可开始排雷")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(ConfigReviewPalette.muted)
                    .padding(.top, 18)
                    .padding(.bottom, 120)
            }
            .padding(.horizontal, 28)
        }
        .safeAreaInset(edge: .bottom) {
            ConfigReviewManualSubmitBar(
                completedCount: draft.completedPartCount,
                totalPrice: draft.totalPrice,
                isEnabled: draft.canSubmit,
                onSubmit: onSubmit
            )
        }
        .sheet(item: $selectedCategory) { category in
            ConfigReviewHardwarePicker(
                category: category,
                filters: category.filters(selectedCPU: draft.model(for: .cpu)),
                selectedValue: modelBinding(for: category)
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
    }

    private func modelBinding(for category: ConfigReviewPartCategory) -> Binding<String> {
        Binding(
            get: { draft.model(for: category) },
            set: { draft.setModel($0, for: category) }
        )
    }

    private func priceBinding(for category: ConfigReviewPartCategory) -> Binding<String> {
        Binding(
            get: { draft.price(for: category) },
            set: { draft.setPrice($0, for: category) }
        )
    }
}

private struct ConfigReviewPartInputRow: View {
    let category: ConfigReviewPartCategory
    let model: String
    @Binding var price: String
    let onSelectModel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: category.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 28)

                Text(category.title)
                    .font(.system(size: 16, weight: .bold))

                Spacer()
            }

            HStack(spacing: 12) {
                Button(action: onSelectModel) {
                    HStack(spacing: 8) {
                        Text(model.isEmpty ? "选择型号" : model)
                            .font(.system(size: 14, weight: model.isEmpty ? .medium : .semibold))
                            .foregroundStyle(model.isEmpty ? ConfigReviewPalette.muted : .black)
                            .lineLimit(1)

                        Spacer(minLength: 4)

                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(ConfigReviewPalette.muted)
                    }
                    .padding(.horizontal, 12)
                    .frame(height: 42)
                    .background(ConfigReviewPalette.surface, in: RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)

                HStack(spacing: 4) {
                    Text("¥")
                        .foregroundStyle(ConfigReviewPalette.secondary)
                    TextField("价格", text: $price)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                }
                .font(.system(size: 14, weight: .semibold))
                .padding(.horizontal, 12)
                .frame(width: 112, height: 42)
                .background(ConfigReviewPalette.surface, in: RoundedRectangle(cornerRadius: 10))
            }
        }
        .foregroundStyle(.black)
        .padding(.vertical, 18)
    }
}

private struct ConfigReviewManualSubmitBar: View {
    let completedCount: Int
    let totalPrice: Int
    let isEnabled: Bool
    let onSubmit: () -> Void

    var body: some View {
        HStack(spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text("已填写 \(completedCount) 项")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(ConfigReviewPalette.secondary)

                Text(totalPrice > 0 ? "¥\(totalPrice.formatted())" : "等待填写")
                    .font(.system(size: 25, weight: .black))
                    .foregroundStyle(.black)
            }

            Spacer()

            Button(action: onSubmit) {
                HStack(spacing: 14) {
                    Text("开始排雷")
                    Image(systemName: "arrow.right")
                }
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 176, height: 54)
                .background(Color.black, in: RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
            .disabled(!isEnabled)
            .opacity(isEnabled ? 1 : 0.28)
        }
        .padding(.horizontal, 28)
        .padding(.top, 16)
        .padding(.bottom, 10)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            Divider().overlay(ConfigReviewPalette.divider)
        }
    }
}

private struct ConfigReviewHardwarePicker: View {
    let category: ConfigReviewPartCategory
    let filters: [HardwareCatalogFilter]
    @Binding var selectedValue: String

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    private var allItems: [HardwareCatalogItem] {
        var seen = Set<String>()
        return filters
            .flatMap(\.groups)
            .flatMap(\.items)
            .filter { seen.insert($0.id).inserted }
    }

    private var visibleItems: [HardwareCatalogItem] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return allItems }

        return allItems.filter {
            $0.name.localizedCaseInsensitiveContains(query)
                || $0.brand.localizedCaseInsensitiveContains(query)
                || $0.detail.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("选择\(category.title)")
                .font(.system(size: 30, weight: .black))
                .foregroundStyle(.black)
                .padding(.top, 8)

            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(ConfigReviewPalette.secondary)

                TextField("搜索型号", text: $searchText)
                    .font(.system(size: 15, weight: .medium))
            }
            .padding(.horizontal, 14)
            .frame(height: 44)
            .background(ConfigReviewPalette.surface, in: RoundedRectangle(cornerRadius: 11))

            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    ForEach(visibleItems) { item in
                        Button {
                            selectedValue = item.name
                            dismiss()
                        } label: {
                            HStack(spacing: 14) {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(item.name)
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundStyle(.black)
                                    Text(item.detail)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(ConfigReviewPalette.secondary)
                                        .lineLimit(2)
                                }

                                Spacer()

                                Image(systemName: selectedValue == item.name ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(selectedValue == item.name ? .black : ConfigReviewPalette.number)
                            }
                            .padding(.vertical, 15)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        Divider().overlay(ConfigReviewPalette.divider)
                    }

                    if visibleItems.isEmpty {
                        Text("没有找到匹配型号")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(ConfigReviewPalette.secondary)
                            .frame(maxWidth: .infinity, minHeight: 160)
                    }
                }
            }
        }
        .padding(.horizontal, 24)
        .background(Color.white)
    }
}

private struct ConfigReviewLoadingView: View {
    let onBack: () -> Void

    @State private var progress = 0.18

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    ConfigReviewBackButton(action: onBack)
                    Spacer()
                    Text("配置排雷")
                        .font(.system(size: 17, weight: .bold))
                    Spacer()
                    Color.clear.frame(width: 32, height: 32)
                }
                .padding(.top, 8)

                Text("正在检查这套配置")
                    .font(.system(size: 40, weight: .black))
                    .foregroundStyle(.black)
                    .padding(.top, 32)

                Text("通常需要 10–20 秒，请稍等一下")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(ConfigReviewPalette.secondary)
                    .padding(.top, 8)

                HStack(alignment: .center, spacing: 4) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .lastTextBaseline, spacing: 6) {
                            Text("\(Int(progress * 100))")
                                .font(.system(size: 52, weight: .bold))
                                .foregroundStyle(ConfigReviewPalette.number)
                            Text("/ 100")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(ConfigReviewPalette.number)
                        }

                        Text("正在核对型号与价格")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(ConfigReviewPalette.secondary)
                    }
                    .frame(width: 126, alignment: .leading)

                    Image("HomeHeroConfigReviewBoard")
                        .resizable()
                        .scaledToFit()
                        .saturation(0)
                        .contrast(1.08)
                        .frame(maxWidth: .infinity)
                        .frame(height: 260)
                }
                .padding(.top, 18)

                Text("检查进度")
                    .font(.system(size: 24, weight: .black))
                    .foregroundStyle(.black)
                    .padding(.top, 18)

                VStack(spacing: 0) {
                    ConfigReviewProgressRow(number: "01", title: "读取配件型号", status: .completed)
                    ConfigReviewProgressRow(number: "02", title: "检查兼容性", status: progress > 0.36 ? .completed : .waiting)
                    ConfigReviewProgressRow(number: "03", title: "分析性能与预算", status: progress > 0.58 ? .active : .waiting)
                    ConfigReviewProgressRow(number: "04", title: "整理购买建议", status: .waiting, showsDivider: false)
                }
                .padding(.top, 10)

                Text("分析期间可以保持当前页面")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(ConfigReviewPalette.muted)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 24)
                    .padding(.bottom, 24)
            }
            .padding(.horizontal, 28)
        }
        .task {
            withAnimation(.linear(duration: 9)) {
                progress = 0.82
            }
        }
    }
}

private enum ConfigReviewProgressStatus {
    case completed
    case active
    case waiting

    var title: String {
        switch self {
        case .completed: "已完成"
        case .active: "进行中"
        case .waiting: "等待中"
        }
    }
}

private struct ConfigReviewProgressRow: View {
    let number: String
    let title: String
    let status: ConfigReviewProgressStatus
    var showsDivider = true

    var body: some View {
        HStack(spacing: 20) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(number)
                    .font(.system(size: 27, weight: .bold))
                Text("/")
                    .font(.system(size: 21, weight: .medium))
            }
            .foregroundStyle(ConfigReviewPalette.number)
            .frame(width: 82, alignment: .leading)

            Text(title)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.black)

            Spacer()

            VStack(spacing: 6) {
                ConfigReviewProgressIcon(status: status)
                Text(status.title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(ConfigReviewPalette.secondary)
            }
        }
        .frame(minHeight: 76)
        .overlay(alignment: .bottom) {
            if showsDivider {
                Divider().overlay(ConfigReviewPalette.divider)
            }
        }
    }
}

private struct ConfigReviewProgressIcon: View {
    let status: ConfigReviewProgressStatus

    var body: some View {
        switch status {
        case .completed:
            Image(systemName: "checkmark")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(Color.black, in: Circle())
        case .active:
            ProgressView()
                .tint(.black)
                .frame(width: 28, height: 28)
        case .waiting:
            Circle()
                .stroke(ConfigReviewPalette.number, lineWidth: 2)
                .frame(width: 28, height: 28)
        }
    }
}

private struct ConfigReviewResultView: View {
    let result: ConfigReviewResponseDTO
    let onBack: () -> Void

    @State private var showsCopiedMessage = false

    private var riskLevel: RiskLevel {
        RiskLevel(reviewLevel: result.riskLevel)
    }

    private var conclusionTitle: String {
        switch riskLevel {
        case .pass: "这套配置可以买"
        case .error: "建议先别买"
        case .warning: "建议修改后再买"
        }
    }

    private var priceDifference: Int? {
        guard let sellerPrice = result.sellerPrice,
              let referenceTotal = result.referenceTotal
        else { return nil }
        return max(0, sellerPrice - referenceTotal)
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    ConfigReviewBackButton(action: onBack)
                    Spacer()
                    Text("排雷报告")
                        .font(.system(size: 17, weight: .bold))
                    Spacer()
                    ShareLink(item: result.replyText) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.black)
                            .frame(width: 32, height: 32)
                    }
                }
                .padding(.top, 8)

                Text("综合结论")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(ConfigReviewPalette.secondary)
                    .padding(.top, 34)

                Text(conclusionTitle)
                    .font(.system(size: 38, weight: .black))
                    .foregroundStyle(.black)
                    .padding(.top, 10)

                Text(result.summary)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(ConfigReviewPalette.secondary)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 12)

                ConfigReviewResultMetrics(
                    riskLevel: riskLevel,
                    priceDifference: priceDifference,
                    findingCount: result.findings.count
                )
                .padding(.top, 28)

                Text(result.findings.isEmpty ? "检查结果" : "先处理这 \(result.findings.count) 个问题")
                    .font(.system(size: 25, weight: .black))
                    .foregroundStyle(.black)
                    .padding(.top, 42)

                VStack(spacing: 0) {
                    ForEach(Array(result.findings.enumerated()), id: \.element.id) { index, finding in
                        ConfigReviewFindingRow(index: index + 1, finding: finding)
                    }

                    if result.findings.isEmpty {
                        HStack(spacing: 12) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 30, height: 30)
                                .background(Color.black, in: Circle())
                            Text("未发现明显配置风险")
                                .font(.system(size: 16, weight: .bold))
                        }
                        .padding(.vertical, 24)
                    }
                }
                .padding(.top, 12)

                HStack(spacing: 14) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 28, height: 28)
                        .background(Color.black, in: Circle())

                    Text("已完成兼容性、搭配与价格检查")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.black)
                }
                .padding(.top, 22)
                .padding(.bottom, 130)
            }
            .padding(.horizontal, 28)
        }
        .safeAreaInset(edge: .bottom) {
            ConfigReviewResultActionBar(
                findingCount: result.findings.count,
                onCopy: copyReply
            )
        }
        .overlay(alignment: .top) {
            if showsCopiedMessage {
                Text("已复制给商家的回复")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .frame(height: 38)
                    .background(Color.black, in: Capsule())
                    .padding(.top, 14)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }

    private func copyReply() {
        UIPasteboard.general.string = result.replyText
        withAnimation(.easeOut(duration: 0.2)) {
            showsCopiedMessage = true
        }

        Task {
            try? await Task.sleep(for: .seconds(1.5))
            withAnimation(.easeOut(duration: 0.2)) {
                showsCopiedMessage = false
            }
        }
    }
}

private struct ConfigReviewResultMetrics: View {
    let riskLevel: RiskLevel
    let priceDifference: Int?
    let findingCount: Int

    private var compatibilityTitle: String {
        riskLevel == .error ? "需调整" : "通过"
    }

    private var budgetTitle: String {
        guard let priceDifference else { return "待确认" }
        return priceDifference > 0 ? "偏高 ¥\(priceDifference)" : "正常"
    }

    var body: some View {
        HStack(spacing: 0) {
            ConfigReviewMetric(title: "兼容性", value: compatibilityTitle)
            Divider().frame(height: 42).overlay(ConfigReviewPalette.divider)
            ConfigReviewMetric(title: "预算", value: budgetTitle)
            Divider().frame(height: 42).overlay(ConfigReviewPalette.divider)
            ConfigReviewMetric(title: "风险项", value: "\(findingCount) 个")
        }
    }
}

private struct ConfigReviewMetric: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(ConfigReviewPalette.secondary)
            Text(value)
                .font(.system(size: 20, weight: .black))
                .foregroundStyle(.black)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
    }
}

private struct ConfigReviewFindingRow: View {
    let index: Int
    let finding: ConfigReviewFindingDTO

    var body: some View {
        HStack(alignment: .top, spacing: 18) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(String(format: "%02d", index))
                    .font(.system(size: 28, weight: .bold))
                Text("/")
                    .font(.system(size: 21, weight: .medium))
            }
            .foregroundStyle(ConfigReviewPalette.number)
            .frame(width: 82, alignment: .leading)

            VStack(alignment: .leading, spacing: 8) {
                Text(finding.title)
                    .font(.system(size: 17, weight: .black))
                    .foregroundStyle(.black)
                Text(finding.detail)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(ConfigReviewPalette.secondary)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 20)
        .overlay(alignment: .bottom) {
            Divider().overlay(ConfigReviewPalette.divider)
        }
    }
}

private struct ConfigReviewResultActionBar: View {
    let findingCount: Int
    let onCopy: () -> Void

    var body: some View {
        HStack(spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text("已为你整理好回复话术")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(ConfigReviewPalette.secondary)
                Text("\(findingCount) 个修改建议")
                    .font(.system(size: 22, weight: .black))
                    .foregroundStyle(.black)
            }

            Spacer()

            Button(action: onCopy) {
                HStack(spacing: 14) {
                    Text("复制给商家")
                    Image(systemName: "arrow.right")
                }
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 174, height: 54)
                .background(Color.black, in: RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
        .padding(.top, 15)
        .padding(.bottom, 10)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            Divider().overlay(ConfigReviewPalette.divider)
        }
    }
}

private struct ConfigReviewErrorView: View {
    let message: String
    let onBack: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ConfigReviewBackButton(action: onBack)
                .padding(.top, 8)

            Text("没有完成排雷")
                .font(.system(size: 38, weight: .black))
                .foregroundStyle(.black)
                .padding(.top, 44)

            Text(message)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(ConfigReviewPalette.secondary)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 14)

            Button(action: onBack) {
                ConfigReviewPrimaryActionLabel(title: "重新选择")
            }
            .buttonStyle(.plain)
            .padding(.top, 30)

            Spacer()
        }
        .padding(.horizontal, 28)
    }
}

private struct ConfigReviewBackButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.left")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.black)
                .frame(width: 32, height: 32)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("返回")
    }
}

private enum ConfigReviewPalette {
    static let secondary = Color(white: 0.42)
    static let muted = Color(white: 0.58)
    static let number = Color(white: 0.72)
    static let divider = Color(white: 0.86)
    static let surface = Color(white: 0.96)
}

private extension RiskLevel {
    init(reviewLevel: String) {
        switch reviewLevel {
        case "pass": self = .pass
        case "error": self = .error
        default: self = .warning
        }
    }
}

#Preview {
    ConfigReviewView(onBack: {})
}
