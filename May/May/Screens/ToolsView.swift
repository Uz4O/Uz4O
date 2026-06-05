import SwiftUI

struct ToolsView: View {
    @Binding var selectedTab: AppTab
    let onSelectTab: (AppTab) -> Void
    let onOpenCompatibility: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("检测工具")
                    .font(.appTitle)
                    .foregroundStyle(AppTheme.primaryText)
                Spacer()
            }
            .padding(.top, 8)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    ToolIntroGrid(onOpenCompatibility: onOpenCompatibility)
                    ToolsOnlyHint()
                }
                .padding(.bottom, 8)
            }

            Spacer(minLength: 0)

            BottomTabBar(selectedTab: $selectedTab, onSelect: onSelectTab)
        }
        .padding(.horizontal, AppTheme.screenPadding)
        .padding(.bottom, 14)
    }
}

private struct ToolIntroGrid: View {
    let onOpenCompatibility: () -> Void

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
            ToolActionCard(
                title: "兼容性检测",
                subtitle: "检查 CPU、主板、内存、电源和机箱空间",
                icon: "checkmark.shield",
                level: .pass,
                action: onOpenCompatibility
            )

            ToolActionCard(
                title: "电源功耗估算",
                subtitle: "按 CPU 和显卡估算推荐电源瓦数",
                icon: "bolt",
                level: .warning,
                action: {}
            )

            ToolActionCard(
                title: "高 U 低显检测",
                subtitle: "识别 CPU 和显卡预算是否失衡",
                icon: "cpu",
                level: .warning,
                action: {}
            )
        }
    }
}

private struct ToolActionCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let level: RiskLevel
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            SoftCard(radius: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(level.color)
                    Text(title)
                        .font(.appSubheadline)
                        .foregroundStyle(AppTheme.primaryText)
                    Text(subtitle)
                        .font(.appCaption)
                        .foregroundStyle(AppTheme.secondaryText)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
                .padding(14)
                .frame(maxWidth: .infinity, minHeight: 116, alignment: .topLeading)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct ToolsOnlyHint: View {
    var body: some View {
        SoftCard(radius: 18) {
            VStack(alignment: .leading, spacing: 8) {
                Text("配置单诊断已放到主页")
                    .font(.appHeadline)
                    .foregroundStyle(AppTheme.primaryText)
                Text("工具页只保留硬件检测类功能：兼容性、电源功耗和高 U 低显。")
                    .font(.appBody)
                    .foregroundStyle(AppTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(18)
        }
    }
}

#Preview {
    ToolsView(selectedTab: .constant(.tools), onSelectTab: { _ in }, onOpenCompatibility: {})
}
