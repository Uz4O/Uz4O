import SwiftUI

enum PerformanceLadderCategory: String, CaseIterable, Hashable, Identifiable {
    case gpu = "显卡"
    case cpu = "CPU"

    var id: String { rawValue }
    var apiValue: String { self == .gpu ? "gpu" : "cpu" }
}

struct PerformanceLadderView: View {
    @State private var category: PerformanceLadderCategory
    @State private var responses: [PerformanceLadderCategory: PerformanceLadderResponseDTO] = [:]
    @State private var loadingCategory: PerformanceLadderCategory?
    @State private var errorMessage: String?
    @State private var searchText = ""
    @State private var selectedBrand: String?
    @Namespace private var categorySelectionAnimation

    init(initialCategory: PerformanceLadderCategory) {
        _category = State(initialValue: initialCategory)
    }

    private var response: PerformanceLadderResponseDTO? {
        responses[category]
    }

    private var visibleItems: [PerformanceLadderItemDTO] {
        guard let items = response?.items else { return [] }
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return items.filter {
            (selectedBrand == nil || $0.brand == selectedBrand)
                && (query.isEmpty
                    || $0.name.localizedCaseInsensitiveContains(query)
                    || $0.brand.localizedCaseInsensitiveContains(query))
        }
    }

    private var availableBrands: [String] {
        guard let items = response?.items else { return [] }
        let presentBrands = Set(items.map(\.brand))
        let preferredOrder = category == .gpu ? ["NVIDIA", "AMD", "Intel"] : ["AMD", "Intel"]
        return preferredOrder.filter(presentBrands.contains)
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 0) {
                header

                if loadingCategory == category, response == nil {
                    ProgressView("正在加载排行…")
                        .font(.system(size: 13))
                        .frame(maxWidth: .infinity)
                        .padding(.top, 90)
                } else if let errorMessage, response == nil {
                    errorState(errorMessage)
                } else if visibleItems.isEmpty {
                    Text(response?.items.isEmpty == true ? "暂无排行数据" : "没有符合筛选条件的型号")
                        .font(.system(size: 14))
                        .foregroundStyle(AppTheme.secondaryText)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 90)
                } else {
                    rankingHeader
                    ForEach(visibleItems) { item in
                        rankingRow(item)
                    }
                    dataNote
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 36)
        }
        .background(Color.white.ignoresSafeArea())
        .navigationTitle("性能天梯")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .searchable(text: $searchText, prompt: "搜索型号")
        .task(id: category) {
            searchText = ""
            await load(category)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 5) {
                Text("HARDWARE RANKING")
                    .font(.system(size: 10, weight: .medium))
                    .tracking(3.2)
                    .foregroundStyle(Color.black.opacity(0.28))
                Text(category == .gpu ? "按 Time Spy 综合性能排序" : "按游戏性能排序")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppTheme.primaryText)
            }

            HStack(spacing: 3) {
                ForEach(PerformanceLadderCategory.allCases) { option in
                    Button {
                        guard category != option else { return }
                        withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
                            category = option
                            selectedBrand = nil
                            searchText = ""
                        }
                    } label: {
                        ZStack {
                            if category == option {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(Color.black)
                                    .matchedGeometryEffect(
                                        id: "categorySelection",
                                        in: categorySelectionAnimation
                                    )
                            }
                            Text(option.rawValue)
                                .foregroundStyle(category == option ? Color.white : AppTheme.primaryText)
                        }
                    }
                    .font(.system(size: 13, weight: .medium))
                    .frame(maxWidth: .infinity)
                    .frame(height: 38)
                }
            }
            .padding(3)
            .background(Color.black.opacity(0.045), in: RoundedRectangle(cornerRadius: 13, style: .continuous))

            if !availableBrands.isEmpty {
                HStack(spacing: 18) {
                    brandFilterButton(nil)
                    ForEach(availableBrands, id: \.self) { brand in
                        brandFilterButton(brand)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(.top, 16)
        .padding(.bottom, 14)
    }

    private var rankingHeader: some View {
        HStack {
            Text("综合性能")
            Spacer()
            if let response {
                Text("共 \(visibleItems.count) 款 · \(response.referenceName) = 100%")
            }
        }
        .font(.system(size: 11))
        .foregroundStyle(AppTheme.secondaryText)
        .padding(.vertical, 10)
    }

    private func rankingRow(_ item: PerformanceLadderItemDTO) -> some View {
        HStack(spacing: 12) {
            Text("\(item.rank)")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(item.rank <= 3 ? Color.white : AppTheme.secondaryText)
                .frame(width: 28, height: 28)
                .background(item.rank <= 3 ? Color.black : Color.clear, in: Circle())

            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .firstTextBaseline, spacing: 7) {
                    Text(item.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppTheme.primaryText)
                        .lineLimit(1)
                    Spacer(minLength: 4)
                }

                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.black.opacity(0.07))
                        Capsule().fill(Color.black)
                            .frame(
                                width: proxy.size.width
                                    * CGFloat(min(max(item.relativePercent / 100, 0), 1))
                            )
                    }
                }
                .frame(height: 4)
            }

            Text(String(format: "%.1f%%", item.relativePercent))
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(AppTheme.primaryText)
                .monospacedDigit()
                .frame(width: 52, alignment: .trailing)
        }
        .frame(minHeight: 62)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.black.opacity(0.055))
                .frame(height: 0.5)
                .padding(.leading, 40)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("第 \(item.rank) 名，\(item.name)，相对性能 \(String(format: "%.1f", item.relativePercent)) 百分比")
    }

    private func brandFilterButton(_ brand: String?) -> some View {
        let isSelected = selectedBrand == brand
        return Button {
            withAnimation(.easeInOut(duration: 0.18)) {
                selectedBrand = brand
            }
        } label: {
            Text(brand ?? "全部")
                .font(.system(size: 11, weight: isSelected ? .semibold : .medium))
                .foregroundStyle(isSelected ? AppTheme.primaryText : AppTheme.secondaryText)
                .padding(.horizontal, 2)
                .padding(.vertical, 6)
                .overlay(alignment: .bottom) {
                    Capsule()
                        .fill(Color.black)
                        .frame(width: isSelected ? 18 : 0, height: 2)
                }
        }
        .buttonStyle(.plain)
    }

    private var dataNote: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "info.circle")
                .font(.system(size: 12))
                .padding(.top, 2)
            Text(category == .gpu
                ? "RTX 5090 与 RTX 5090 D 按已确认的 100% / 99.6% 展示；其他型号按现有 Time Spy 分数换算。"
                : "CPU 排名采用 truebottleneck 游戏性能榜单数据；不同游戏和设置下的表现会有差异。")
                .font(.system(size: 11))
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(AppTheme.secondaryText)
        .padding(.top, 16)
    }

    private func errorState(_ message: String) -> some View {
        VStack(spacing: 14) {
            Text(message)
                .font(.system(size: 13))
                .foregroundStyle(AppTheme.secondaryText)
                .multilineTextAlignment(.center)
            Button("重新加载") {
                Task { await load(category, force: true) }
            }
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .frame(height: 36)
            .background(Color.black, in: Capsule())
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }

    @MainActor
    private func load(_ requestedCategory: PerformanceLadderCategory, force: Bool = false) async {
        if responses[requestedCategory] != nil, !force { return }
        loadingCategory = requestedCategory
        errorMessage = nil
        defer {
            if loadingCategory == requestedCategory {
                loadingCategory = nil
            }
        }
        do {
            responses[requestedCategory] = try await AppAPIClient().performanceLadder(
                category: requestedCategory.apiValue
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    NavigationStack {
        PerformanceLadderView(initialCategory: .gpu)
    }
}
