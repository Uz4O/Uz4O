import SwiftUI

struct UpgradePlanView: View {
    let onBack: () -> Void

    @State private var budget: Double = 0.45
    @State private var selectedGoal = "2K 游戏"
    @State private var hasResult = false

    private let goals = ["流畅网游", "2K 游戏", "剪辑办公"]

    private var budgetText: String {
        "¥ \(Int(800 + budget * 5200))"
    }

    var body: some View {
        VStack(spacing: 14) {
            ScreenHeader(title: "升级建议", trailingIcon: nil, onBack: onBack)
                .padding(.top, 8)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    UpgradeSummaryCard()

                    SoftCard(radius: 20) {
                        VStack(alignment: .leading, spacing: 16) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("升级目标")
                                    .font(.appHeadline)
                                    .foregroundStyle(AppTheme.primaryText)
                                Text("先按当前电脑短板判断，不盲目整机重配。")
                                    .font(.appCaption)
                                    .foregroundStyle(AppTheme.secondaryText)
                            }

                            UpgradeGoalPicker(options: goals, selected: $selectedGoal)

                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Text("升级预算")
                                        .font(.appSubheadline)
                                        .foregroundStyle(AppTheme.primaryText)
                                    Spacer()
                                    Text(budgetText)
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundStyle(AppTheme.primaryText)
                                }

                                Slider(value: $budget)
                                    .tint(AppTheme.primaryText)
                            }

                            PrimaryButton(title: hasResult ? "重新生成升级方案" : "生成升级方案", icon: "wand.and.stars") {
                                withAnimation(.easeInOut(duration: 0.18)) {
                                    hasResult = true
                                }
                            }
                        }
                        .padding(18)
                    }

                    if hasResult {
                        UpgradeResultSection()
                    } else {
                        UpgradeEmptyHint()
                    }
                }
                .padding(.bottom, 22)
            }
        }
        .padding(.horizontal, AppTheme.screenPadding)
    }
}

private struct UpgradeSummaryCard: View {
    var body: some View {
        SoftCard(radius: 22) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "desktopcomputer")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(AppTheme.primaryText, in: RoundedRectangle(cornerRadius: 16))

                VStack(alignment: .leading, spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("当前旧电脑")
                            .font(.appHeadline)
                            .foregroundStyle(AppTheme.primaryText)
                        Text("i5-10400F / GTX 1660 Super / 16GB DDR4 / 500W")
                            .font(.appCaption)
                            .foregroundStyle(AppTheme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    HStack(spacing: 8) {
                        UpgradeBadge(title: "瓶颈", value: "显卡")
                        UpgradeBadge(title: "可保留", value: "主板内存")
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(18)
        }
    }
}

private struct UpgradeBadge: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(AppTheme.secondaryText)
            Text(value)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(AppTheme.primaryText)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(AppTheme.softSurface, in: RoundedRectangle(cornerRadius: 10))
    }
}

private struct UpgradeGoalPicker: View {
    let options: [String]
    @Binding var selected: String

    var body: some View {
        HStack(spacing: 8) {
            ForEach(options, id: \.self) { option in
                Button {
                    selected = option
                } label: {
                    Text(option)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(selected == option ? .white : AppTheme.primaryText)
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .background(selected == option ? AppTheme.primaryText : AppTheme.softSurface, in: RoundedRectangle(cornerRadius: 11))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct UpgradeEmptyHint: View {
    var body: some View {
        SoftCard(radius: 18) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "lightbulb")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(AppTheme.primaryText)
                    .frame(width: 34, height: 34)
                    .background(AppTheme.softSurface, in: RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 5) {
                    Text("适合不知道该换什么的旧电脑")
                        .font(.appHeadline)
                        .foregroundStyle(AppTheme.primaryText)
                    Text("生成后会按收益排序，告诉你哪些配件先换、哪些还能继续用。")
                        .font(.appBody)
                        .foregroundStyle(AppTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(18)
        }
    }
}

private struct UpgradeResultSection: View {
    private let recommendations = [
        UpgradeRecommendation(rank: "1", title: "先换显卡", detail: "GTX 1660 Super 是 2K 游戏主要瓶颈，升级到 RTX 4060 Ti 或 RX 7700 XT 收益最明显。", cost: "约 ¥ 2600"),
        UpgradeRecommendation(rank: "2", title: "内存暂时保留", detail: "16GB DDR4 还能支撑多数游戏，预算有限时不建议优先升级。", cost: "省 ¥ 350"),
        UpgradeRecommendation(rank: "3", title: "电源看显卡再定", detail: "如果选择 200W 级显卡，建议换一线 650W 金牌，避免满载不稳。", cost: "约 ¥ 450")
    ]

    var body: some View {
        VStack(spacing: 14) {
            SoftCard(radius: 20) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("推荐升级顺序")
                                .font(.appHeadline)
                                .foregroundStyle(AppTheme.primaryText)
                            Text("预计优先升级显卡，整机不用重配。")
                                .font(.appCaption)
                                .foregroundStyle(AppTheme.secondaryText)
                        }

                        Spacer()

                        Text("省钱升级")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 6)
                            .background(AppTheme.success, in: Capsule())
                    }

                    ForEach(recommendations) { item in
                        UpgradeRecommendationRow(item: item)
                    }
                }
                .padding(18)
            }

            PrimaryButton(title: "让 AI 继续细化配件", icon: "sparkles", action: {})
        }
    }
}

private struct UpgradeRecommendation: Identifiable {
    let id = UUID()
    let rank: String
    let title: String
    let detail: String
    let cost: String
}

private struct UpgradeRecommendationRow: View {
    let item: UpgradeRecommendation

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(item.rank)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(AppTheme.primaryText, in: Circle())

            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline) {
                    Text(item.title)
                        .font(.appSubheadline)
                        .foregroundStyle(AppTheme.primaryText)
                    Spacer()
                    Text(item.cost)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(AppTheme.primaryText)
                }

                Text(item.detail)
                    .font(.appCaption)
                    .foregroundStyle(AppTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .background(AppTheme.softSurface, in: RoundedRectangle(cornerRadius: 14))
    }
}

#Preview {
    UpgradePlanView(onBack: {})
}
