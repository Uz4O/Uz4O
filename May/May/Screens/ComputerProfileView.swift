import SwiftUI

struct ComputerProfileView: View {
    @Binding var hardwareProfile: HardwareProfile
    let onBack: () -> Void

    @State private var selectedCategory: HardwareOptionCategory?

    var body: some View {
        VStack(spacing: 16) {
            ScreenHeader(title: "我的电脑档案", trailingIcon: nil, onBack: onBack)
                .padding(.top, 8)

            SoftCard(radius: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(hardwareProfile.completionLabel)
                        .font(.appHeadline)
                        .foregroundStyle(AppTheme.primaryText)

                    Text(profileSummary)
                        .font(.appBody)
                        .foregroundStyle(AppTheme.secondaryText)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            SoftCard(radius: 18) {
                VStack(spacing: 0) {
                    ForEach(Array(HardwareProfileOptions.categories.enumerated()), id: \.element.id) { index, category in
                        ComputerProfileRow(
                            title: category.title,
                            value: hardwareProfile.value(for: category.title),
                            icon: category.icon
                        ) {
                            selectedCategory = category
                        }

                        if index != HardwareProfileOptions.categories.count - 1 {
                            Divider().padding(.leading, 42)
                        }
                    }
                }
                .padding(.horizontal, 16)
            }

            Spacer()
        }
        .padding(.horizontal, AppTheme.screenPadding)
        .padding(.bottom, 22)
        .sheet(item: $selectedCategory) { category in
            HardwarePickerSheet(
                title: category.title,
                icon: category.icon,
                filters: filters(for: category),
                contextMessage: contextMessage(for: category),
                selectedValue: binding(for: category.title)
            )
            .presentationDetents([.large])
        }
    }

    private var profileSummary: String {
        hardwareProfile.knownComponentsSummary.isEmpty
            ? "选择你知道的硬件即可，不确定的项目可以稍后补充。"
            : hardwareProfile.knownComponentsSummary
    }

    private func binding(for title: String) -> Binding<String> {
        Binding(
            get: { hardwareProfile.value(for: title) },
            set: { hardwareProfile.setValue($0, for: title) }
        )
    }

    private func filters(for category: HardwareOptionCategory) -> [HardwareCatalogFilter] {
        category.title == "主板"
            ? HardwareCatalog.motherboardFilters(compatibleWithCPU: hardwareProfile.cpu)
            : HardwareCatalog.filters(for: category.title)
    }

    private func contextMessage(for category: HardwareOptionCategory) -> String? {
        guard category.title == "主板", let socket = HardwareCatalog.cpuSocket(for: hardwareProfile.cpu) else { return nil }
        return "已根据 \(hardwareProfile.cpu) 筛选 \(socket) 兼容主板"
    }
}

private struct ComputerProfileRow: View {
    let title: String
    let value: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppTheme.primaryText)
                    .frame(width: 30, height: 30)
                    .background(AppTheme.softSurface, in: RoundedRectangle(cornerRadius: 8))

                Text(title)
                    .font(.appSubheadline)
                    .foregroundStyle(AppTheme.primaryText)

                Spacer()

                Text(value)
                    .font(.appBody)
                    .foregroundStyle(AppTheme.secondaryText)
                    .lineLimit(1)

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(AppTheme.secondaryText)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.vertical, 13)
    }
}

#Preview {
    ComputerProfileView(hardwareProfile: .constant(.skipped), onBack: {})
}
