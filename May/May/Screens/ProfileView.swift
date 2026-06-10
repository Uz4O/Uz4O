import SwiftUI

struct ProfileView: View {
    let hardwareProfile: HardwareProfile
    @Binding var selectedTab: AppTab
    let onSelectTab: (AppTab) -> Void
    let onOpenBuilds: () -> Void
    let onOpenComputerProfile: () -> Void

    private let accountItems = [
        ProfileItem(title: "我的配置单", icon: "doc.text", subtitle: "查看保存过的方案"),
        ProfileItem(title: "我的电脑档案", icon: "desktopcomputer", subtitle: "查看或补充当前电脑配置")
    ]

    private let helpItems = [
        ProfileItem(title: "用户协议", icon: "doc.plaintext", subtitle: "使用规则与条款"),
        ProfileItem(title: "隐私政策", icon: "lock.shield", subtitle: "数据如何被保护"),
        ProfileItem(title: "意见反馈", icon: "paperplane", subtitle: "告诉我们哪里不好用"),
        ProfileItem(title: "关于我们", icon: "info.circle", subtitle: "版本与项目介绍")
    ]

    var body: some View {
        VStack(spacing: 14) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    Button(action: onOpenComputerProfile) {
                        HStack(spacing: 18) {
                            MascotAvatar(size: 82)
                            VStack(alignment: .leading, spacing: 7) {
                                Text("AI 装机助手")
                                    .font(.system(size: 22, weight: .bold))
                                    .foregroundStyle(AppTheme.primaryText)
                                Text(hardwareProfile.wasSkipped ? "可在这里补充电脑档案" : hardwareProfile.summary)
                                    .font(.system(size: 13))
                                    .foregroundStyle(AppTheme.secondaryText)
                                    .lineLimit(2)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(AppTheme.secondaryText)
                        }
                        .padding(20)
                        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 24))
                        .modifier(AppTheme.cardShadow)
                    }
                    .buttonStyle(.plain)

                    ProfileSection(title: "我的方案与档案", items: accountItems, action: action)
                    ProfileSection(title: "设置与帮助", items: helpItems, action: action)
                }
                .padding(.top, 12)
                .padding(.bottom, 4)
            }

            BottomTabBar(selectedTab: $selectedTab, onSelect: onSelectTab)
        }
        .padding(.horizontal, AppTheme.screenPadding)
        .padding(.bottom, 14)
    }

    private func action(for title: String) {
        switch title {
        case "我的配置单":
            onOpenBuilds()
        case "我的电脑档案":
            onOpenComputerProfile()
        default:
            break
        }
    }
}

private struct ProfileItem: Identifiable {
    var id: String { title }
    let title: String
    let icon: String
    let subtitle: String
}

private struct ProfileSection: View {
    let title: String
    let items: [ProfileItem]
    let action: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppTheme.secondaryText)
                .padding(.leading, 10)

            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    Button {
                        action(item.title)
                    } label: {
                        HStack(spacing: 16) {
                            Image(systemName: item.icon)
                                .font(.system(size: 21, weight: .medium))
                                .foregroundStyle(AppTheme.primaryText)
                                .frame(width: 32)

                            VStack(alignment: .leading, spacing: 3) {
                                Text(item.title)
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(AppTheme.primaryText)
                                Text(item.subtitle)
                                    .font(.system(size: 12))
                                    .foregroundStyle(AppTheme.secondaryText)
                            }

                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(AppTheme.secondaryText)
                        }
                        .padding(.vertical, 15)
                    }
                    .buttonStyle(.plain)

                    if index != items.count - 1 {
                        Divider().padding(.leading, 48)
                    }
                }
            }
            .padding(.horizontal, 18)
            .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 24))
            .modifier(AppTheme.cardShadow)
        }
    }
}

#Preview {
    ProfileView(
        hardwareProfile: .skipped,
        selectedTab: .constant(.profile),
        onSelectTab: { _ in },
        onOpenBuilds: {},
        onOpenComputerProfile: {}
    )
}
