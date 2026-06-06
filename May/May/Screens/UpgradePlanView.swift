import SwiftUI

private let upgradeStepCount = 5

struct UpgradePlanView: View {
    let onBack: () -> Void

    @State private var step = 1
    @State private var budget: Double = 3000
    @State private var selectedNeeds: Set<String> = ["提升游戏性能"]
    @State private var selectedGames: Set<String> = ["CS2", "PUBG", "无畏契约"]
    @State private var selectedPart: UpgradeCurrentPart?

    private let designWidth: CGFloat = 328
    private let needs = UpgradeNeed.samples
    private let parts = UpgradeCurrentPart.samples
    private let games = UpgradeGame.samples

    var body: some View {
        VStack(spacing: 0) {
            UpgradeHeader(
                step: step,
                onBack: {
                    if step == 1 {
                        onBack()
                    } else {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            step -= 1
                        }
                    }
                }
            )
            .frame(width: designWidth)
            .padding(.top, 8)

            Group {
                switch step {
                case 1:
                    CurrentConfigStep(parts: parts, selectedPart: $selectedPart)
                case 2:
                    UpgradeBudgetStep(budget: $budget)
                case 3:
                    UpgradeNeedStep(needs: needs, selectedNeeds: $selectedNeeds)
                case 4:
                    GameSelectionStep(games: games, selectedGames: $selectedGames)
                default:
                    UpgradeResultStep()
                }
            }
            .frame(width: designWidth)
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            UpgradeFooter(
                step: step,
                onNext: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        step = min(step + 1, upgradeStepCount)
                    }
                },
                onRegenerate: {},
                onSave: {}
            )
            .frame(width: designWidth)
            .padding(.bottom, 22)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(item: $selectedPart) { part in
            UpgradePartOptionSheet(part: part)
                .presentationDetents([.medium])
        }
    }
}

private struct UpgradeHeader: View {
    let step: Int
    let onBack: () -> Void

    var body: some View {
        VStack(spacing: 22) {
            ZStack {
                Text("升级建议")
                    .font(.appHeadline)
                    .foregroundStyle(AppTheme.primaryText)

                HStack {
                    Button(action: onBack) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(AppTheme.primaryText)
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(.plain)

                    Spacer()
                }
            }

            HStack(spacing: 16) {
                Text("\(step)/\(upgradeStepCount)")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AppTheme.primaryText)
                    .frame(width: 40, alignment: .leading)

                UpgradeProgressDots(step: step)
            }
        }
    }
}

private struct UpgradeProgressDots: View {
    let step: Int

    var body: some View {
        HStack(spacing: 0) {
            ForEach(1...upgradeStepCount, id: \.self) { index in
                Circle()
                    .fill(index <= step ? AppTheme.primaryText : AppTheme.border)
                    .frame(width: 8, height: 8)

                if index < upgradeStepCount {
                    Rectangle()
                        .fill(index < step ? AppTheme.primaryText : AppTheme.border)
                        .frame(height: 1)
                }
            }
        }
    }
}

private struct CurrentConfigStep: View {
    let parts: [UpgradeCurrentPart]
    @Binding var selectedPart: UpgradeCurrentPart?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            UpgradeStepTitle(
                title: "选择当前电脑配置",
                subtitle: "准确填写配置信息，帮助 AI 更精准推荐"
            )

            ScrollView(showsIndicators: false) {
                VStack(spacing: 10) {
                    ForEach(parts) { part in
                        Button {
                            selectedPart = part
                        } label: {
                            UpgradePartRow(part: part)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.bottom, 12)
            }
        }
    }
}

private struct UpgradeBudgetStep: View {
    @Binding var budget: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            UpgradeStepTitle(
                title: "选择升级预算",
                subtitle: "先确定这次愿意投入多少，AI 会优先控制在预算内。"
            )

            UpgradeBudgetSlider(budget: $budget)

            VStack(alignment: .leading, spacing: 12) {
                Text("预算参考")
                    .font(.appSubheadline)
                    .foregroundStyle(AppTheme.primaryText)

                VStack(spacing: 10) {
                    UpgradeBudgetHintRow(title: "小修小补", subtitle: "适合补内存、换散热、加电源余量", range: "¥500-1500")
                    UpgradeBudgetHintRow(title: "核心升级", subtitle: "适合优先换显卡或补齐主要短板", range: "¥1500-5000")
                    UpgradeBudgetHintRow(title: "大幅升级", subtitle: "适合显卡、内存、电源一起升级", range: "¥5000+")
                }
            }

            Spacer(minLength: 0)
        }
    }
}

private struct UpgradeNeedStep: View {
    let needs: [UpgradeNeed]
    @Binding var selectedNeeds: Set<String>

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            UpgradeStepTitle(
                title: "选择升级需求",
                subtitle: "选择这次最想改善的体验，可以多选。"
            )

            SoftCard(radius: 18) {
                HStack(spacing: 12) {
                    Image(systemName: "list.bullet.clipboard")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(AppTheme.primaryText)
                        .frame(width: 34, height: 34)
                        .background(AppTheme.softSurface, in: RoundedRectangle(cornerRadius: 10))

                    VStack(alignment: .leading, spacing: 4) {
                        Text("按优先级选择")
                            .font(.appSubheadline)
                            .foregroundStyle(AppTheme.primaryText)
                        Text("建议 1-3 项")
                            .font(.appCaption)
                            .foregroundStyle(AppTheme.secondaryText)
                    }

                    Spacer()

                    Text("\(selectedNeeds.count) 项")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(AppTheme.primaryText)
                        .padding(.horizontal, 10)
                        .frame(height: 28)
                        .background(AppTheme.softSurface, in: Capsule())
                }
                .padding(14)
            }

            ScrollView(showsIndicators: false) {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    ForEach(needs) { need in
                        UpgradeNeedCard(
                            need: need,
                            isSelected: selectedNeeds.contains(need.title)
                        ) {
                            withAnimation(.spring(response: 0.32, dampingFraction: 0.84)) {
                                toggle(need.title, in: &selectedNeeds)
                            }
                        }
                    }
                }
                .padding(.bottom, 10)
            }
        }
    }
}

private struct GameSelectionStep: View {
    let games: [UpgradeGame]
    @Binding var selectedGames: Set<String>

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            UpgradeStepTitle(
                title: "选择主要玩的游戏",
                subtitle: "选择你常玩的游戏，AI 将参考游戏需求推荐"
            )

            HStack(spacing: 10) {
                Text("搜索游戏名称")
                    .font(.appBody)
                    .foregroundStyle(AppTheme.mutedText)
                Spacer()
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AppTheme.primaryText)
            }
            .padding(.horizontal, 14)
            .frame(height: 44)
            .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.border, lineWidth: 1))

            Text("热门游戏")
                .font(.appSubheadline)
                .foregroundStyle(AppTheme.primaryText)
                .padding(.top, 8)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 9), count: 3), spacing: 10) {
                ForEach(games) { game in
                    UpgradeGameCard(
                        game: game,
                        isSelected: selectedGames.contains(game.name)
                    ) {
                        toggle(game.name, in: &selectedGames)
                    }
                }

                ManualAddGameCard()
            }

            Spacer(minLength: 0)
        }
    }
}

private struct UpgradeResultStep: View {
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text("AI 生成升级建议")
                            .font(.appTitle)
                            .foregroundStyle(AppTheme.primaryText)

                        Text("智能推荐")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(AppTheme.primaryText)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(AppTheme.softSurface, in: Capsule())
                    }

                    Text("基于你的配置和需求生成")
                        .font(.appBody)
                        .foregroundStyle(AppTheme.secondaryText)
                }

                UpgradeOverviewCard()

                Text("推荐升级方案")
                    .font(.appHeadline)
                    .foregroundStyle(AppTheme.primaryText)

                UpgradeRecommendationCard(
                    category: "显卡 (GPU)",
                    current: "当前：NVIDIA GeForce GTX 1660 Super",
                    recommend: "推荐：NVIDIA GeForce RTX 4060",
                    gain: "+65%",
                    price: "¥1899",
                    icon: "display"
                )

                UpgradeRecommendationCard(
                    category: "内存 (RAM)",
                    current: "当前：16GB (8GB x 2) DDR4 2666MHz",
                    recommend: "推荐：32GB (16GB x 2) DDR4 3200MHz",
                    gain: "+25%",
                    price: "¥399",
                    icon: "memorychip"
                )

                UpgradeTotalCard()
            }
            .padding(.bottom, 10)
        }
    }
}

private struct UpgradeFooter: View {
    let step: Int
    let onNext: () -> Void
    let onRegenerate: () -> Void
    let onSave: () -> Void

    var body: some View {
        Group {
            if step < upgradeStepCount {
                PrimaryButton(title: "下一步", icon: nil, action: onNext)
            } else {
                HStack(spacing: 10) {
                    Button(action: onRegenerate) {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.clockwise")
                            Text("重新生成")
                        }
                        .font(.appSubheadline)
                        .foregroundStyle(AppTheme.primaryText)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: AppTheme.controlRadius))
                        .overlay(RoundedRectangle(cornerRadius: AppTheme.controlRadius).stroke(AppTheme.border, lineWidth: 1))
                    }
                    .buttonStyle(.plain)

                    Button(action: onSave) {
                        HStack(spacing: 8) {
                            Image(systemName: "star")
                            Text("保存方案")
                        }
                        .font(.appSubheadline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(AppTheme.primaryButton, in: RoundedRectangle(cornerRadius: AppTheme.controlRadius))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct UpgradeStepTitle: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.appTitle)
                .foregroundStyle(AppTheme.primaryText)

            Text(subtitle)
                .font(.appBody)
                .foregroundStyle(AppTheme.secondaryText)
        }
        .padding(.top, 28)
    }
}

private struct UpgradePartRow: View {
    let part: UpgradeCurrentPart

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: part.icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AppTheme.primaryText)
                .frame(width: 32, height: 32)
                .background(AppTheme.softSurface, in: RoundedRectangle(cornerRadius: 9))

            VStack(alignment: .leading, spacing: 4) {
                Text(part.title)
                    .font(.appSubheadline)
                    .foregroundStyle(AppTheme.primaryText)
                Text(part.value)
                    .font(.appCaption)
                    .foregroundStyle(AppTheme.secondaryText)
                    .lineLimit(1)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(AppTheme.secondaryText)
        }
        .padding(14)
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.border, lineWidth: 1))
    }
}

private struct UpgradeBudgetSlider: View {
    @Binding var budget: Double

    private let minimumBudget: Double = 500
    private let maximumBudget: Double = 12000
    private let budgetStep: Double = 100

    private var valueText: String {
        "¥ \(Int(budget))"
    }

    var body: some View {
        SoftCard(radius: 20) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("升级预算")
                            .font(.appSubheadline)
                            .foregroundStyle(AppTheme.primaryText)
                        Text("可以用加减按钮微调")
                            .font(.appCaption)
                            .foregroundStyle(AppTheme.secondaryText)
                    }

                    Spacer()

                    Text(valueText)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(AppTheme.primaryText)
                }

                HStack {
                    Text("¥ 500")
                    Spacer()
                    Text("¥ 12000")
                }
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AppTheme.secondaryText)

                HStack(spacing: 12) {
                    UpgradeBudgetStepButton(systemName: "minus", isEnabled: budget > minimumBudget) {
                        updateBudget(by: -budgetStep)
                    }

                    Slider(value: $budget, in: minimumBudget...maximumBudget, step: budgetStep)
                        .tint(AppTheme.primaryText)

                    UpgradeBudgetStepButton(systemName: "plus", isEnabled: budget < maximumBudget) {
                        updateBudget(by: budgetStep)
                    }
                }
            }
            .padding(18)
        }
    }

    private func updateBudget(by amount: Double) {
        budget = min(max(budget + amount, minimumBudget), maximumBudget)
    }
}

private struct UpgradeBudgetStepButton: View {
    let systemName: String
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(isEnabled ? AppTheme.primaryText : AppTheme.mutedText)
                .frame(width: 34, height: 34)
                .background(AppTheme.surface, in: Circle())
                .overlay(Circle().stroke(AppTheme.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }
}

private struct UpgradeBudgetHintRow: View {
    let title: String
    let subtitle: String
    let range: String

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.appSubheadline)
                    .foregroundStyle(AppTheme.primaryText)
                Text(subtitle)
                    .font(.appCaption)
                    .foregroundStyle(AppTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            Text(range)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(AppTheme.primaryText)
                .padding(.horizontal, 10)
                .frame(height: 28)
                .background(AppTheme.softSurface, in: Capsule())
        }
        .padding(12)
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.border, lineWidth: 1))
    }
}

private struct UpgradeNeedCard: View {
    let need: UpgradeNeed
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 9) {
                HStack(alignment: .top) {
                    Image(systemName: need.icon)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(isSelected ? .white : AppTheme.primaryText)
                        .frame(width: 30, height: 30)
                        .background(isSelected ? AppTheme.primaryText : AppTheme.softSurface, in: RoundedRectangle(cornerRadius: 9))

                    Spacer()

                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(isSelected ? AppTheme.success : AppTheme.border)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(need.title)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(AppTheme.primaryText)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(need.tagline)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(isSelected ? AppTheme.primaryText : AppTheme.secondaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    Text(need.subtitle)
                        .font(.appCaption)
                        .foregroundStyle(AppTheme.secondaryText)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(11)
            .frame(maxWidth: .infinity, minHeight: 124, alignment: .topLeading)
            .background(isSelected ? AppTheme.softSurface : AppTheme.surface, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(isSelected ? AppTheme.primaryText : AppTheme.border, lineWidth: isSelected ? 1.3 : 1))
            .shadow(color: isSelected ? Color.black.opacity(0.08) : Color.clear, radius: 12, x: 0, y: 7)
        }
        .buttonStyle(.plain)
    }
}

private struct UpgradeGameCard: View {
    let game: UpgradeGame
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack(alignment: .topTrailing) {
                    Text(game.mark)
                        .font(.system(size: game.mark.count > 3 ? 18 : 28, weight: .black))
                        .foregroundStyle(AppTheme.primaryText)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)

                    Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(isSelected ? AppTheme.success : AppTheme.border)
                        .padding(6)
                }

                Text(game.name)
                    .font(.appSubheadline)
                    .foregroundStyle(AppTheme.primaryText)
                    .lineLimit(1)
            }
            .frame(height: 96)
            .background(isSelected ? AppTheme.softSurface : AppTheme.surface, in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(isSelected ? AppTheme.success.opacity(0.55) : AppTheme.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

private struct ManualAddGameCard: View {
    var body: some View {
        VStack(spacing: 7) {
            Image(systemName: "plus.circle")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(AppTheme.secondaryText)
            Text("手动添加")
                .font(.appCaption)
                .foregroundStyle(AppTheme.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 60)
        .background(AppTheme.softSurface, in: RoundedRectangle(cornerRadius: 10))
    }
}

private struct UpgradeOverviewCard: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(LinearGradient(
                    colors: [Color(red: 0.07, green: 0.10, blue: 0.15), Color(red: 0.13, green: 0.16, blue: 0.24)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))

            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("升级总览")
                        .font(.appHeadline)
                        .foregroundStyle(.white)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("性能提升")
                            .font(.appCaption)
                            .foregroundStyle(.white.opacity(0.66))
                        Text("42% ↑")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundStyle(.white)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("预计总花费")
                            .font(.appCaption)
                            .foregroundStyle(.white.opacity(0.66))
                        Text("约 2896 元")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }

                Spacer()

                UpgradeRadarChart()
                    .frame(width: 112, height: 112)
            }
            .padding(16)
        }
        .frame(height: 150)
    }
}

private struct UpgradeRadarChart: View {
    private let labels = ["游戏性能", "生产力", "散热表现", "稳定性", "性价比"]
    private let values: [CGFloat] = [0.86, 0.66, 0.52, 0.72, 0.61]

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            let center = CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)
            let radius = size * 0.34

            ZStack {
                ForEach(1...4, id: \.self) { ring in
                    radarPath(center: center, radius: radius * CGFloat(ring) / 4, values: Array(repeating: 1, count: 5))
                        .stroke(.white.opacity(0.18), lineWidth: 1)
                }

                ForEach(0..<5, id: \.self) { index in
                    Path { path in
                        path.move(to: center)
                        path.addLine(to: point(index: index, total: 5, center: center, radius: radius))
                    }
                    .stroke(.white.opacity(0.14), lineWidth: 1)

                    Text(labels[index])
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(.white.opacity(0.68))
                        .position(point(index: index, total: 5, center: center, radius: radius + 21))
                }

                radarPath(center: center, radius: radius, values: values)
                    .fill(.white.opacity(0.22))

                radarPath(center: center, radius: radius, values: values)
                    .stroke(.white.opacity(0.72), lineWidth: 1.2)
            }
        }
    }

    private func radarPath(center: CGPoint, radius: CGFloat, values: [CGFloat]) -> Path {
        Path { path in
            for index in values.indices {
                let target = point(index: index, total: values.count, center: center, radius: radius * values[index])
                if index == 0 {
                    path.move(to: target)
                } else {
                    path.addLine(to: target)
                }
            }
            path.closeSubpath()
        }
    }

    private func point(index: Int, total: Int, center: CGPoint, radius: CGFloat) -> CGPoint {
        let angle = -CGFloat.pi / 2 + 2 * CGFloat.pi * CGFloat(index) / CGFloat(total)
        return CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
    }
}

private struct UpgradeRecommendationCard: View {
    let category: String
    let current: String
    let recommend: String
    let gain: String
    let price: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                Text(category)
                    .font(.appSubheadline)
                    .foregroundStyle(AppTheme.primaryText)
                Text(current)
                    .font(.appCaption)
                    .foregroundStyle(AppTheme.secondaryText)
                Text(recommend)
                    .font(.appSubheadline)
                    .foregroundStyle(AppTheme.primaryText)
            }

            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(AppTheme.primaryText)
                    .frame(width: 62, height: 34)
                    .background(AppTheme.softSurface, in: RoundedRectangle(cornerRadius: 8))

                Spacer()

                VStack(alignment: .trailing, spacing: 6) {
                    Text(gain)
                        .font(.appCaption)
                        .foregroundStyle(AppTheme.secondaryText)
                    Text("预计：\(price)")
                        .font(.appSubheadline)
                        .foregroundStyle(AppTheme.primaryText)
                }
            }
        }
        .padding(12)
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.border, lineWidth: 1))
    }
}

private struct UpgradeTotalCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("总计预算")
                .font(.appSubheadline)
                .foregroundStyle(AppTheme.primaryText)

            HStack(alignment: .lastTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("预计总花费")
                        .font(.appCaption)
                        .foregroundStyle(AppTheme.secondaryText)
                    Text("价格仅供参考，实际以市场为准")
                        .font(.system(size: 9))
                        .foregroundStyle(AppTheme.mutedText)
                }

                Spacer()

                Text("约 ¥ 2896")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(AppTheme.primaryText)
            }
        }
        .padding(16)
        .background(AppTheme.softSurface, in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct UpgradePartOptionSheet: View {
    let part: UpgradeCurrentPart
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Capsule()
                .fill(AppTheme.border)
                .frame(width: 42, height: 5)
                .frame(maxWidth: .infinity)
                .padding(.top, 10)

            Text("选择\(part.title)")
                .font(.appHeadline)
                .foregroundStyle(AppTheme.primaryText)

            VStack(spacing: 10) {
                ForEach(part.options, id: \.self) { option in
                    Button {
                        dismiss()
                    } label: {
                        HStack {
                            Text(option)
                                .font(.appBody)
                                .foregroundStyle(AppTheme.primaryText)
                            Spacer()
                            if option == part.value {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(AppTheme.success)
                            }
                        }
                        .padding(.horizontal, 14)
                        .frame(height: 44)
                        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(option == part.value ? AppTheme.primaryText : AppTheme.border, lineWidth: option == part.value ? 1.3 : 1))
                    }
                    .buttonStyle(.plain)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 20)
        .background(AppTheme.background)
    }
}

private struct UpgradeCurrentPart: Identifiable {
    let id = UUID()
    let title: String
    let value: String
    let icon: String
    let options: [String]

    static let samples = [
        UpgradeCurrentPart(title: "处理器 (CPU)", value: "Intel Core i5-10400F", icon: "cpu", options: ["不知道", "Intel Core i5-10400F", "Intel Core i7-10700F", "Ryzen 5 5600"]),
        UpgradeCurrentPart(title: "显卡 (GPU)", value: "NVIDIA GeForce GTX 1660 Super", icon: "display", options: ["不知道", "NVIDIA GeForce GTX 1660 Super", "RTX 4060", "RTX 4070 Super"]),
        UpgradeCurrentPart(title: "主板", value: "B460M Mortar", icon: "menucard", options: ["不知道", "B460M Mortar", "B560M", "B760M"]),
        UpgradeCurrentPart(title: "内存 (RAM)", value: "16GB (8GB x 2) DDR4 2666MHz", icon: "memorychip", options: ["不知道", "16GB DDR4", "32GB DDR4", "64GB DDR4"]),
        UpgradeCurrentPart(title: "电源 (PSU)", value: "550W", icon: "bolt", options: ["不知道", "500W", "550W", "650W", "750W"]),
        UpgradeCurrentPart(title: "散热器", value: "原装散热器", icon: "fan", options: ["不知道", "原装散热器", "塔式风冷", "240 水冷"])
    ]
}

private struct UpgradeNeed: Identifiable {
    let id = UUID()
    let title: String
    let tagline: String
    let subtitle: String
    let icon: String

    static let samples = [
        UpgradeNeed(title: "提升游戏性能", tagline: "帧率优先", subtitle: "让热门游戏更稳、更流畅。", icon: "gamecontroller"),
        UpgradeNeed(title: "提升生产力", tagline: "效率优先", subtitle: "剪辑、渲染、建模更顺手。", icon: "scissors"),
        UpgradeNeed(title: "提升整体流畅度", tagline: "日常优先", subtitle: "减少卡顿，打开软件更快。", icon: "speedometer"),
        UpgradeNeed(title: "外观和灯光效果", tagline: "颜值优先", subtitle: "兼顾灯效、整洁和观感。", icon: "sparkles"),
        UpgradeNeed(title: "其他需求", tagline: "自定义", subtitle: "后续按你的补充再细化。", icon: "ellipsis.message")
    ]
}

private struct UpgradeGame: Identifiable {
    let id = UUID()
    let name: String
    let mark: String

    static let samples = [
        UpgradeGame(name: "CS2", mark: "CS"),
        UpgradeGame(name: "PUBG", mark: "PUBG"),
        UpgradeGame(name: "GTA V", mark: "GTA"),
        UpgradeGame(name: "永劫无间", mark: "永"),
        UpgradeGame(name: "原神", mark: "原"),
        UpgradeGame(name: "APEX 英雄", mark: "A"),
        UpgradeGame(name: "英雄联盟", mark: "L"),
        UpgradeGame(name: "使命召唤", mark: "COD"),
        UpgradeGame(name: "无畏契约", mark: "V")
    ]
}

private func toggle(_ value: String, in set: inout Set<String>) {
    if set.contains(value) {
        set.remove(value)
    } else {
        set.insert(value)
    }
}

#Preview {
    UpgradePlanView(onBack: {})
}
