import SwiftUI

struct BuildResultView: View {
    let plan: BuildPlan
    let onBack: () -> Void

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                ScreenHeader(title: "配置方案详情", onBack: onBack)
                    .padding(.top, 8)

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

                SoftCard(radius: 18) {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("风险提示")
                            .font(.appHeadline)
                            .foregroundStyle(AppTheme.primaryText)

                        ForEach(plan.risks) { risk in
                            HStack(alignment: .top, spacing: 10) {
                                Text(risk.level.title)
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 5)
                                    .background(risk.level.color, in: Capsule())

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(risk.title)
                                        .font(.appSubheadline)
                                        .foregroundStyle(AppTheme.primaryText)
                                    Text(risk.detail)
                                        .font(.appCaption)
                                        .foregroundStyle(AppTheme.secondaryText)
                                }
                            }
                        }
                    }
                    .padding(18)
                }

                VStack(spacing: 10) {
                    PrimaryButton(title: "保存配置单", icon: "tray.and.arrow.down", action: {})

                    HStack(spacing: 10) {
                        SecondaryActionButton(title: "复制文本", icon: "doc.on.doc")
                        SecondaryActionButton(title: "分享图片", icon: "square.and.arrow.up")
                    }

                    HStack(spacing: 10) {
                        SecondaryActionButton(title: "重新生成", icon: "arrow.clockwise")
                        SecondaryActionButton(title: "继续优化", icon: "wand.and.stars")
                    }
                }
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

private struct SecondaryActionButton: View {
    let title: String
    let icon: String

    var body: some View {
        Button(action: {}) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                Text(title)
            }
            .font(.appSubheadline)
            .foregroundStyle(AppTheme.primaryText)
            .frame(maxWidth: .infinity)
            .frame(height: 42)
            .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    BuildResultView(plan: AppMockData.samplePlan, onBack: {})
}
