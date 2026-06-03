import SwiftUI

struct MyBuildsView: View {
    @Binding var selectedTab: AppTab
    let onSelectTab: (AppTab) -> Void
    let onOpenPlan: () -> Void
    let onCreate: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("我的配置单")
                    .font(.appTitle)
                    .foregroundStyle(AppTheme.primaryText)
                Spacer()
                Button(action: onCreate) {
                    Image(systemName: "plus")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(AppTheme.primaryText)
                }
            }
            .padding(.top, 8)

            if AppMockData.savedPlans.isEmpty {
                EmptyBuildState(onCreate: onCreate)
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 12) {
                        ForEach(AppMockData.savedPlans) { plan in
                            SavedPlanCard(plan: plan, onOpen: onOpenPlan)
                        }
                    }
                    .padding(.bottom, 8)
                }
            }

            Spacer(minLength: 0)

            BottomTabBar(selectedTab: $selectedTab, onSelect: onSelectTab)
        }
        .padding(.horizontal, AppTheme.screenPadding)
        .padding(.bottom, 14)
    }
}

private struct EmptyBuildState: View {
    let onCreate: () -> Void

    var body: some View {
        SoftCard(radius: 22) {
            VStack(spacing: 14) {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(AppTheme.secondaryText)
                Text("当前没有配置单")
                    .font(.appHeadline)
                    .foregroundStyle(AppTheme.primaryText)
                Text("生成完配置后，可以在这里回来查看、复制和继续优化。")
                    .font(.appBody)
                    .foregroundStyle(AppTheme.secondaryText)
                    .multilineTextAlignment(.center)
                PrimaryButton(title: "创建第一张配置单", icon: "sparkles", action: onCreate)
            }
            .padding(24)
        }
    }
}

private struct SavedPlanCard: View {
    let plan: BuildPlan
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            SoftCard(radius: 18) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(plan.name)
                                .font(.appHeadline)
                                .foregroundStyle(AppTheme.primaryText)
                            Text("\(plan.budget) · \(plan.useCase)")
                                .font(.appCaption)
                                .foregroundStyle(AppTheme.secondaryText)
                        }
                        Spacer()
                        Text(plan.totalPrice)
                            .font(.appSubheadline)
                            .foregroundStyle(AppTheme.primaryText)
                    }

                    HStack {
                        Text(plan.createdAt)
                            .font(.appCaption)
                            .foregroundStyle(AppTheme.secondaryText)
                        Spacer()
                        ForEach(["重命名", "复制", "分享", "删除"], id: \.self) { item in
                            Text(item)
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(item == "删除" ? AppTheme.error : AppTheme.secondaryText)
                        }
                    }
                }
                .padding(16)
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    MyBuildsView(selectedTab: .constant(.builds), onSelectTab: { _ in }, onOpenPlan: {}, onCreate: {})
}
