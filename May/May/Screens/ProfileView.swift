import SwiftUI

struct ProfileView: View {
    @Binding var selectedTab: AppTab
    let onSelectTab: (AppTab) -> Void
    let onOpenBuilds: () -> Void

    private let items = [
        ("我的配置单", "doc.text", "查看保存过的方案"),
        ("我的反馈", "bubble.left.and.bubble.right", "查看和补充反馈"),
        ("公益说明", "heart", "无广告、不卖货、只帮你避坑"),
        ("价格透明说明", "tag", "参考价来自公开信息"),
        ("用户协议", "doc.plaintext", "使用规则"),
        ("隐私政策", "lock.shield", "数据如何被保护"),
        ("意见反馈", "paperplane", "告诉我们哪里不好用"),
        ("关于我们", "info.circle", "项目定位与版本信息")
    ]

    var body: some View {
        VStack(spacing: 16) {
            SoftCard(radius: 22) {
                HStack(spacing: 14) {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 46))
                        .foregroundStyle(AppTheme.primaryText)

                    VStack(alignment: .leading, spacing: 5) {
                        Text("AI 装机助手")
                            .font(.appHeadline)
                            .foregroundStyle(AppTheme.primaryText)
                        Text("登录后可保存配置单和反馈")
                            .font(.appBody)
                            .foregroundStyle(AppTheme.secondaryText)
                    }

                    Spacer()
                }
                .padding(18)
            }
            .padding(.top, 8)

            SoftCard(radius: 18) {
                VStack(spacing: 0) {
                    ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                        Button(action: item.0 == "我的配置单" ? onOpenBuilds : {}) {
                            HStack(spacing: 12) {
                                Image(systemName: item.1)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(AppTheme.primaryText)
                                    .frame(width: 28, height: 28)
                                    .background(AppTheme.softSurface, in: RoundedRectangle(cornerRadius: 8))

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(item.0)
                                        .font(.appSubheadline)
                                        .foregroundStyle(AppTheme.primaryText)
                                    Text(item.2)
                                        .font(.appCaption)
                                        .foregroundStyle(AppTheme.secondaryText)
                                }

                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(AppTheme.secondaryText)
                            }
                            .padding(.vertical, 13)
                        }
                        .buttonStyle(.plain)

                        if index != items.count - 1 {
                            Divider().padding(.leading, 40)
                        }
                    }
                }
                .padding(.horizontal, 16)
            }

            Spacer(minLength: 0)

            BottomTabBar(selectedTab: $selectedTab, onSelect: onSelectTab)
        }
        .padding(.horizontal, AppTheme.screenPadding)
        .padding(.bottom, 14)
    }
}

#Preview {
    ProfileView(selectedTab: .constant(.profile), onSelectTab: { _ in }, onOpenBuilds: {})
}
