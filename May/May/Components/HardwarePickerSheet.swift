import SwiftUI

struct HardwarePickerSheet: View {
    let title: String
    let icon: String
    private let contextMessage: String?
    private let filters: [HardwareCatalogFilter]
    @Binding var selectedValue: String

    @Environment(\.dismiss) private var dismiss
    @State private var selectedFilterTitle: String
    @State private var selectedGroupTitle: String
    @State private var searchText = ""

    init(
        title: String,
        icon: String,
        filters: [HardwareCatalogFilter],
        contextMessage: String? = nil,
        fallbackOptions: [String] = [],
        selectedValue: Binding<String>
    ) {
        self.title = title
        self.icon = icon
        self.contextMessage = contextMessage
        self.filters = filters.isEmpty
            ? [
                HardwareCatalogFilter(
                    title: "全部",
                    groups: [
                        HardwareCatalogGroup(
                            title: title,
                            items: fallbackOptions.map { HardwareCatalogItem(id: $0, name: $0, brand: title, detail: "手动选项") }
                        )
                    ]
                )
            ]
            : filters
        self._selectedValue = selectedValue
        self._selectedFilterTitle = State(initialValue: self.filters.first?.title ?? "全部")
        self._selectedGroupTitle = State(initialValue: self.filters.first?.groups.first?.title ?? "")
    }

    private var activeFilter: HardwareCatalogFilter? {
        filters.first { $0.title == selectedFilterTitle } ?? filters.first
    }

    private var activeGroup: HardwareCatalogGroup? {
        activeFilter?.groups.first { $0.title == selectedGroupTitle } ?? activeFilter?.groups.first
    }

    private var visibleItems: [HardwareCatalogItem] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let items = activeGroup?.items ?? []

        guard !query.isEmpty else { return items }

        return items.filter {
            $0.name.localizedCaseInsensitiveContains(query)
                || $0.detail.localizedCaseInsensitiveContains(query)
                || $0.brand.localizedCaseInsensitiveContains(query)
        }
    }

    private var hidesItemDetail: Bool {
        title == "CPU" || title == "处理器 (CPU)" || title == "显卡" || title == "显卡 (GPU)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Capsule()
                .fill(AppTheme.border)
                .frame(width: 42, height: 5)
                .frame(maxWidth: .infinity)
                .padding(.top, 10)

            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppTheme.primaryText)
                    .frame(width: 32, height: 32)
                    .background(AppTheme.softSurface, in: RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 2) {
                    Text("选择\(title)")
                        .font(.appHeadline)
                        .foregroundStyle(AppTheme.primaryText)
                    Text("按分类筛选，或直接搜索型号")
                        .font(.appCaption)
                        .foregroundStyle(AppTheme.secondaryText)
                }

                Spacer()
            }

            if let contextMessage {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.shield")
                        .font(.system(size: 13, weight: .semibold))
                    Text(contextMessage)
                        .font(.appCaption)
                }
                .foregroundStyle(AppTheme.secondaryText)
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: 36)
                .background(AppTheme.softSurface, in: RoundedRectangle(cornerRadius: 11))
            }

            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.secondaryText)

                TextField("搜索型号", text: $searchText)
                    .font(.appBody)
                    .textInputAutocapitalization(.never)

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(AppTheme.secondaryText)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("清除搜索")
                }
            }
            .padding(.horizontal, 14)
            .frame(height: 40)
            .background(AppTheme.softSurface, in: RoundedRectangle(cornerRadius: 12))

            if filters.count > 1 || (activeFilter?.groups.count ?? 0) > 1 {
                VStack(spacing: 0) {
                    if filters.count > 1 {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(filters) { filter in
                                    Button {
                                        selectedFilterTitle = filter.title
                                        selectedGroupTitle = filter.groups.first?.title ?? ""
                                    } label: {
                                        Text(filter.title)
                                            .font(.system(size: 13, weight: selectedFilterTitle == filter.title ? .bold : .semibold))
                                            .foregroundStyle(selectedFilterTitle == filter.title ? .white : Color.black.opacity(0.48))
                                            .padding(.horizontal, 11)
                                            .frame(height: 34)
                                            .background(selectedFilterTitle == filter.title ? Color.black : Color.clear, in: RoundedRectangle(cornerRadius: 8))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .frame(height: 42)
                    }

                    if filters.count > 1, (activeFilter?.groups.count ?? 0) > 1 {
                        Rectangle()
                            .fill(Color.black.opacity(0.10))
                            .frame(height: 1)
                    }

                    if let groups = activeFilter?.groups, groups.count > 1 {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(groups) { group in
                                    Button {
                                        selectedGroupTitle = group.title
                                    } label: {
                                        Text(group.title)
                                            .font(.system(size: 13, weight: selectedGroupTitle == group.title ? .bold : .semibold))
                                            .foregroundStyle(selectedGroupTitle == group.title ? .white : Color.black.opacity(0.48))
                                            .padding(.horizontal, 11)
                                            .frame(height: 34)
                                            .background(selectedGroupTitle == group.title ? Color.black : Color.clear, in: RoundedRectangle(cornerRadius: 8))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .frame(height: 42)
                    }

                    Rectangle()
                        .fill(Color.black.opacity(0.14))
                        .frame(height: 1)
                }
            }

            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 0, pinnedViews: []) {
                    ForEach(visibleItems) { item in
                        Button {
                            selectedValue = item.name
                            dismiss()
                        } label: {
                            HardwarePickerRow(
                                item: item,
                                isSelected: selectedValue == item.name,
                                showsDetail: !hidesItemDetail
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    if visibleItems.isEmpty {
                        Text("没有找到匹配型号")
                            .font(.appBody)
                            .foregroundStyle(AppTheme.secondaryText)
                            .frame(maxWidth: .infinity, minHeight: 120)
                    }
                }
                .padding(.bottom, 16)
            }
        }
        .padding(.horizontal, 20)
        .background(AppTheme.surface)
        .presentationBackground(AppTheme.surface)
    }
}

private struct HardwarePickerRow: View {
    let item: HardwareCatalogItem
    let isSelected: Bool
    let showsDetail: Bool

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.appBody.weight(.semibold))
                    .foregroundStyle(AppTheme.primaryText)
                    .lineLimit(2)

                if showsDetail {
                    Text(item.detail)
                        .font(.appCaption)
                        .foregroundStyle(AppTheme.secondaryText)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer()

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AppTheme.primaryText)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .frame(minHeight: 52)
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: 10)
                    .fill(AppTheme.softSurface)
                    .overlay {
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(AppTheme.border, lineWidth: 1)
                    }
            }
        }
        .overlay(alignment: .bottom) {
            if !isSelected {
                Rectangle()
                    .fill(Color.black.opacity(0.14))
                    .frame(height: 1)
                    .padding(.leading, 14)
            }
        }
    }
}
