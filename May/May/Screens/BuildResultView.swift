import SwiftUI

struct BuildResultView: View {
    let plan: BuildPlan
    let onBack: () -> Void

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                ScreenHeader(title: "配置方案详情", onBack: onBack)
                    .padding(.top, 8)

                Text(AIContentDisclosure.text)
                    .font(.appCaption)
                    .foregroundStyle(AppTheme.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)

                SoftCard(radius: 22) {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(plan.name)
                                    .font(.appTitle)
                                    .foregroundStyle(AppTheme.primaryText)
                                Text(plan.useCase)
                                    .font(.appBody)
                                    .foregroundStyle(AppTheme.secondaryText)
                                    .fixedSize(horizontal: false, vertical: true)
                            }

                            Spacer()

                            Image("PCTower")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 86, height: 86)
                        }

                        HStack(spacing: 10) {
                            SummaryBadge(title: "预算", value: plan.budget)
                            SummaryBadge(title: "总价", value: plan.totalPrice)
                        }
                    }
                    .padding(20)
                }

                SoftCard(radius: 18) {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("配件清单")
                            .font(.appHeadline)
                            .foregroundStyle(AppTheme.primaryText)

                        ForEach(plan.parts) { part in
                            DetailedPartRow(part: part)
                            if part.id != plan.parts.last?.id {
                                Divider()
                            }
                        }
                    }
                    .padding(18)
                }

                PrimaryButton(title: "保存配置单", icon: "tray.and.arrow.down", action: {})
                    .padding(.bottom, 22)
            }
            .padding(.horizontal, AppTheme.screenPadding)
        }
    }
}

private struct SummaryBadge: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.appCaption)
                .foregroundStyle(AppTheme.secondaryText)
            Text(value)
                .font(.appSubheadline)
                .foregroundStyle(AppTheme.primaryText)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.softSurface, in: RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    BuildResultView(plan: AppMockData.samplePlan, onBack: {})
}
