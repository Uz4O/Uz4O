import SwiftUI

struct BuildOptionsView: View {
    let response: BuildOptionsResponseDTO
    let onBack: () -> Void
    let onSelect: (BuildOptionDTO) -> Void

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                ScreenHeader(title: "选择配置方案", trailingIcon: nil, onBack: onBack)
                    .padding(.top, 8)

                VStack(alignment: .leading, spacing: 5) {
                    Text("可选方案")
                        .font(.appTitle)
                        .foregroundStyle(AppTheme.primaryText)
                    Text("配置方向：\(response.direction.displayName)")
                        .font(.appBody)
                        .foregroundStyle(AppTheme.secondaryText)
                }
                .padding(.horizontal, 4)

                ForEach(response.options) { option in
                    BuildOptionCard(option: option) {
                        onSelect(option)
                    }
                }

                if !response.unavailableModes.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(response.unavailableModes, id: \.rawValue) { mode in
                            HStack(alignment: .top, spacing: 9) {
                                Image(systemName: "info.circle")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(AppTheme.secondaryText)
                                    .frame(width: 18)

                                Text("当前预算下没有可靠的\(mode.displayName)方案，建议提高预算")
                                    .font(.appCaption)
                                    .foregroundStyle(AppTheme.secondaryText)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(AppTheme.softSurface, in: RoundedRectangle(cornerRadius: AppTheme.controlRadius))
                        }
                    }
                }
            }
            .padding(.horizontal, AppTheme.screenPadding)
            .padding(.bottom, 24)
        }
    }
}

private struct BuildOptionCard: View {
    let option: BuildOptionDTO
    let onSelect: () -> Void

    private var cpuName: String {
        option.part(for: .cpu).name
    }

    private var gpuName: String {
        option.part(for: .gpu).name
    }

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 13) {
                    HStack(spacing: 10) {
                        Text("\(option.details.purchaseMode.displayName)方案")
                            .font(.appHeadline)
                            .foregroundStyle(AppTheme.primaryText)

                        Text(option.details.direction.displayName)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(AppTheme.primaryText)
                            .padding(.horizontal, 8)
                            .frame(height: 24)
                            .background(AppTheme.softSurface, in: Capsule())

                        Spacer(minLength: 0)
                    }

                    ComponentNameRow(label: "CPU", name: cpuName)
                    ComponentNameRow(label: "显卡", name: gpuName)

                    HStack(alignment: .firstTextBaseline) {
                        Text("参考总价")
                            .font(.appCaption)
                            .foregroundStyle(AppTheme.secondaryText)
                        Spacer()
                        Text(option.referenceTotalText)
                            .font(.appSubheadline)
                            .foregroundStyle(AppTheme.primaryText)
                            .monospacedDigit()
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(AppTheme.mutedText)
                    .frame(width: 18)
            }
            .padding(18)
            .frame(maxWidth: .infinity, minHeight: 176, alignment: .leading)
            .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 18))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(AppTheme.border, lineWidth: 1)
            )
            .modifier(AppTheme.cardShadow)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint("查看方案详情")
    }
}

private struct ComponentNameRow: View {
    let label: String
    let name: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text(label)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(AppTheme.secondaryText)
                .frame(width: 32, alignment: .leading)

            Text(name)
                .font(.appBody.weight(.semibold))
                .foregroundStyle(AppTheme.primaryText)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, minHeight: 32, alignment: .topLeading)
                .layoutPriority(1)
        }
    }
}
