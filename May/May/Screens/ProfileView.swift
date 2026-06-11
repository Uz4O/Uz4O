import SwiftUI

struct ProfileView: View {
    let hardwareProfile: HardwareProfile
    @Binding var selectedTab: AppTab
    let onSelectTab: (AppTab) -> Void
    let onComposePost: () -> Void
    let onOpenBuilds: () -> Void
    let onOpenComputerProfile: () -> Void

    private let accountItems = [
        ProfileItem(title: "我的配置单", icon: "doc.text", subtitle: "查看保存过的方案", isAvailable: true)
    ]

    private let helpItems = [
        ProfileItem(title: "用户协议", icon: "doc.plaintext", subtitle: "使用规则与条款", isAvailable: false),
        ProfileItem(title: "隐私政策", icon: "lock.shield", subtitle: "数据如何被保护", isAvailable: false),
        ProfileItem(title: "意见反馈", icon: "paperplane", subtitle: "告诉我们哪里不好用", isAvailable: false),
        ProfileItem(title: "关于我们", icon: "info.circle", subtitle: "版本与项目介绍", isAvailable: false)
    ]

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    Button(action: onOpenComputerProfile) {
                        HStack(spacing: 18) {
                            MascotAvatar(size: 82)
                            VStack(alignment: .leading, spacing: 7) {
                                Text("AI 装机助手")
                                    .font(.system(size: 22, weight: .bold))
                                    .foregroundStyle(AppTheme.primaryText)
                                Text(profileSummary)
                                    .font(.system(size: 13))
                                    .foregroundStyle(AppTheme.secondaryText)
                                    .lineLimit(3)
                                    .fixedSize(horizontal: false, vertical: true)
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

                    ProfileSection(title: "我的方案", items: accountItems, action: action)
                    ProfileSection(title: "设置与帮助", items: helpItems, action: action)
                }
                .padding(.top, 12)
                .padding(.bottom, 112)
            }

            BottomTabBar(selectedTab: $selectedTab, onSelect: onSelectTab, onComposePost: onComposePost)
        }
        .padding(.horizontal, AppTheme.screenPadding)
        .background(AppTheme.background.ignoresSafeArea())
    }

    private var profileSummary: String {
        let knownSummary = hardwareProfile.knownComponentsSummary
        return knownSummary.isEmpty
            ? "\(hardwareProfile.completionLabel) · 点击开始补充"
            : "\(hardwareProfile.completionLabel) · \(knownSummary)"
    }

    private func action(for title: String) {
        switch title {
        case "我的配置单":
            onOpenBuilds()
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
    let isAvailable: Bool
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
                            if item.isAvailable {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(AppTheme.secondaryText)
                            } else {
                                Text("暂未开放")
                                    .font(.appCaption.weight(.semibold))
                                    .foregroundStyle(AppTheme.secondaryText)
                            }
                        }
                        .padding(.vertical, 15)
                    }
                    .buttonStyle(.plain)
                    .disabled(!item.isAvailable)

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
        onComposePost: {},
        onOpenBuilds: {},
        onOpenComputerProfile: {}
    )
}
