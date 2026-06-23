import SwiftUI

struct ProfileView: View {
    @ObservedObject var session: AppSession
    let hardwareProfile: HardwareProfile
    let onOpenBuilds: () -> Void
    let onOpenComputerProfile: () -> Void
    let onOpenContactComplaint: () -> Void
    let onAccountDeleted: () -> Void

    @State private var presentedLegalDocument: LegalDocument?
    @State private var showsAccountDeletion = false

    private let accountItems = [
        ProfileItem(title: "我的配置单", icon: "doc.text", subtitle: "查看保存过的方案", isAvailable: true)
    ]

    private let helpItems = [
        ProfileItem(title: "用户协议", icon: "doc.plaintext", isAvailable: true),
        ProfileItem(title: "隐私政策", icon: "lock.shield", isAvailable: true),
        ProfileItem(title: "第三方信息共享清单", icon: "square.stack.3d.up", isAvailable: true),
        ProfileItem(title: "社区规范", icon: "person.2", isAvailable: true),
        ProfileItem(title: "联系与投诉", icon: "paperplane", subtitle: LegalContact.email, isAvailable: true)
    ]

    private let destructiveItems = [
        ProfileItem(
            title: "注销账号",
            icon: "person.crop.circle.badge.minus",
            subtitle: "永久删除账号及关联资料",
            isAvailable: true,
            isDestructive: true
        )
    ]

    var body: some View {
        GeometryReader { proxy in
            let contentWidth = AppTheme.responsiveContentWidth(for: proxy.size.width)

            ZStack(alignment: .bottom) {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("我的")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(AppTheme.primaryText)
                            .frame(maxWidth: .infinity)
                            .padding(.bottom, 24)

                        Button(action: onOpenComputerProfile) {
                            HStack(spacing: 18) {
                                MascotAvatar(size: 82)
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("AI 装机助手")
                                        .font(.system(size: 21, weight: .bold))
                                        .foregroundStyle(AppTheme.primaryText)
                                    Text(profileSummary)
                                        .font(.system(size: 12))
                                        .foregroundStyle(AppTheme.secondaryText)
                                        .lineLimit(3)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(AppTheme.secondaryText)
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 18)
                            .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 22))
                            .modifier(AppTheme.cardShadow)
                        }
                        .buttonStyle(.plain)

                        ProfileSection(title: "我的方案", items: accountItems, action: action)
                        ProfileSection(title: "设置与帮助", items: helpItems, action: action)
                        ProfileSection(title: nil, items: destructiveItems, action: action)
                    }
                    .frame(width: contentWidth)
                    .padding(.top, 18)
                    .padding(.bottom, 112)
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(maxWidth: .infinity)
            .background(AppTheme.background.ignoresSafeArea())
        }
        .sheet(item: $presentedLegalDocument) { document in
            NavigationStack {
                LegalDocumentView(document: document)
            }
        }
        .sheet(isPresented: $showsAccountDeletion) {
            AccountDeletionView(session: session, onDeleted: onAccountDeleted)
        }
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
        case "用户协议":
            presentedLegalDocument = .userAgreement
        case "隐私政策":
            presentedLegalDocument = .privacyPolicy
        case "第三方信息共享清单":
            presentedLegalDocument = .thirdPartySharing
        case "社区规范":
            presentedLegalDocument = .communityGuidelines
        case "联系与投诉":
            onOpenContactComplaint()
        case "注销账号":
            showsAccountDeletion = true
        default:
            break
        }
    }
}

private struct ProfileItem: Identifiable {
    var id: String { title }
    let title: String
    let icon: String
    var subtitle: String?
    let isAvailable: Bool
    var isDestructive = false
}

private struct ProfileSection: View {
    let title: String?
    let items: [ProfileItem]
    let action: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let title {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.secondaryText)
                    .padding(.leading, 10)
            }

            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    Button {
                        action(item.title)
                    } label: {
                        HStack(spacing: 16) {
                            Image(systemName: item.icon)
                                .font(.system(size: 21, weight: .medium))
                                .foregroundStyle(item.isDestructive ? .red : AppTheme.primaryText)
                                .frame(width: 32)

                            VStack(alignment: .leading, spacing: 3) {
                                Text(item.title)
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundStyle(item.isDestructive ? .red : AppTheme.primaryText)
                                if let subtitle = item.subtitle {
                                    Text(subtitle)
                                        .font(.system(size: 12))
                                        .foregroundStyle(AppTheme.secondaryText)
                                }
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
                        .padding(.horizontal, 18)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(!item.isAvailable)

                    if index != items.count - 1 {
                        Divider()
                            .padding(.leading, 66)
                            .padding(.trailing, 18)
                    }
                }
            }
            .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 24))
            .modifier(AppTheme.cardShadow)
        }
    }
}

#Preview {
    ProfileView(
        session: AppSession(),
        hardwareProfile: .skipped,
        onOpenBuilds: {},
        onOpenComputerProfile: {},
        onOpenContactComplaint: {},
        onAccountDeleted: {}
    )
}
