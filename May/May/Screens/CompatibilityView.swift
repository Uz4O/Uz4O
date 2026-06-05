import SwiftUI

struct CompatibilityView: View {
    let onBack: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            ScreenHeader(title: "兼容性检测", trailingIcon: nil, onBack: onBack)
                .padding(.top, 8)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    CompatibilitySummaryCard()
                    CompatibilityCheckList()
                    CompatibilityPartsList()

                    VStack(spacing: 10) {
                        PrimaryButton(title: "重新检测", icon: "arrow.clockwise", action: {})

                        Button("保存报告") {}
                            .font(.appBody)
                            .foregroundStyle(AppTheme.secondaryText)
                            .buttonStyle(.plain)
                    }
                    .padding(.bottom, 22)
                }
            }
        }
        .padding(.horizontal, AppTheme.screenPadding)
    }
}

private struct CompatibilitySummaryCard: View {
    var body: some View {
        SoftCard(radius: 22) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 16) {
                    ZStack {
                        Image(systemName: "shield")
                            .font(.system(size: 56, weight: .light))
                            .foregroundStyle(AppTheme.border)
                        Image(systemName: "checkmark")
                            .font(.system(size: 27, weight: .bold))
                            .foregroundStyle(AppTheme.success)
                    }
                    .frame(width: 64, height: 70)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("当前配置检测结果")
                            .font(.appCaption)
                            .foregroundStyle(AppTheme.secondaryText)
                        Text("可正常装机")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(AppTheme.success)
                        Text("0 个严重问题，2 个购买前提醒")
                            .font(.appCaption)
                            .foregroundStyle(AppTheme.secondaryText)
                    }

                    Spacer()
                }

                HStack(spacing: 10) {
                    CompatibilityScoreBadge(title: "兼容评分", value: "92")
                    CompatibilityScoreBadge(title: "电源余量", value: "充足")
                    CompatibilityScoreBadge(title: "升级空间", value: "良好")
                }
            }
            .padding(20)
        }
    }
}

private struct CompatibilityScoreBadge: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.appCaption)
                .foregroundStyle(AppTheme.secondaryText)
            Text(value)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(AppTheme.primaryText)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.softSurface, in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct CompatibilityCheckList: View {
    private let checks = [
        BuildRisk(level: .pass, title: "CPU + 主板", detail: "i5-14600K 可搭配 B760M，接口和平台匹配。"),
        BuildRisk(level: .pass, title: "内存 + 主板", detail: "DDR5 6000 与当前主板规格匹配。"),
        BuildRisk(level: .warning, title: "散热压制", detail: "单塔风冷可用，长时间满载建议换更强风冷。"),
        BuildRisk(level: .warning, title: "机箱空间", detail: "购买显卡前需要确认具体型号长度不超过机箱限位。"),
        BuildRisk(level: .pass, title: "电源功率", detail: "650W 金牌对当前配置有合理余量。")
    ]

    var body: some View {
        SoftCard(radius: 18) {
            VStack(alignment: .leading, spacing: 14) {
                Text("兼容关系")
                    .font(.appHeadline)
                    .foregroundStyle(AppTheme.primaryText)

                ForEach(checks) { risk in
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
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
            .padding(18)
        }
    }
}

private struct CompatibilityPartsList: View {
    var body: some View {
        SoftCard(radius: 18) {
            VStack(alignment: .leading, spacing: 18) {
                Text("检测配件")
                    .font(.appHeadline)
                    .foregroundStyle(AppTheme.primaryText)

                ForEach(AppMockData.parts) { part in
                    PartRow(part: part, showsCheckmark: true)
                }
            }
            .padding(18)
        }
    }
}

#Preview {
    CompatibilityView(onBack: {})
}
