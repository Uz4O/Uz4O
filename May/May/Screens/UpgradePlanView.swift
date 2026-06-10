import SwiftUI

private let upgradeStepCount = 5

struct UpgradePlanView: View {
    let savedHardwareProfile: HardwareProfile
    let onBack: () -> Void

    @State private var step = 1
    @State private var budget: Double = 3000
    @State private var selectedNeed = "提升游戏性能"
    @State private var selectedGames: Set<String> = ["CS2", "PUBG", "无畏契约"]
    @State private var selectedHardwareCategory: HardwareOptionCategory?
    @State private var configuration = UpgradePlanConfiguration.sample

    private let designWidth: CGFloat = 328
    private let needs = UpgradeNeed.samples
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
                    CurrentConfigStep(
                        configuration: $configuration,
                        selectedCategory: $selectedHardwareCategory,
                        savedHardwareProfile: savedHardwareProfile
                    )
                case 2:
                    UpgradeBudgetStep(budget: $budget)
                case 3:
                    GameSelectionStep(games: games, selectedGames: $selectedGames)
                case 4:
                    UpgradeNeedStep(needs: needs, selectedNeed: $selectedNeed)
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
        .sheet(item: $selectedHardwareCategory) { category in
            HardwarePickerSheet(
                title: category.title,
                icon: category.icon,
                filters: filters(for: category),
                contextMessage: contextMessage(for: category),
                selectedValue: binding(for: category.title)
            )
            .presentationDetents([.large])
        }
    }

    private func binding(for title: String) -> Binding<String> {
        Binding(
            get: { configuration.value(for: title) },
            set: { configuration.setValue($0, for: title) }
        )
    }

    private func filters(for category: HardwareOptionCategory) -> [HardwareCatalogFilter] {
        category.title == "主板"
            ? HardwareCatalog.motherboardFilters(compatibleWithCPU: configuration.hardwareProfile.cpu)
            : HardwareCatalog.filters(for: category.title)
    }

    private func contextMessage(for category: HardwareOptionCategory) -> String? {
        let cpu = configuration.hardwareProfile.cpu
        guard category.title == "主板", let socket = HardwareCatalog.cpuSocket(for: cpu) else { return nil }
        return "已根据 \(cpu) 筛选 \(socket) 兼容主板"
    }
}

private struct CurrentConfigStep: View {
    @Binding var configuration: UpgradePlanConfiguration
    @Binding var selectedCategory: HardwareOptionCategory?
    let savedHardwareProfile: HardwareProfile

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            UpgradeConfigIntroCard(
                icon: "desktopcomputer",
                title: "选择当前电脑配置",
                subtitle: "先选你知道的 CPU、显卡、内存和电源，不确定的地方可以选“不知道”。"
            )

            ApplySavedProfileButton(hasSavedProfile: !savedHardwareProfile.wasSkipped) {
                configuration.apply(savedHardwareProfile)
            }

            ScrollView(showsIndicators: false) {
                VStack(spacing: 12) {
                    ForEach(UpgradePlanConfiguration.categories) { category in
                        UpgradeHardwareRow(
                            category: category,
                            selectedValue: configuration.value(for: category.title)
                        ) {
                            selectedCategory = category
                        }
                    }
                }
                .padding(.bottom, 10)
            }
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

private struct UpgradeConfigIntroCard: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        SoftCard(radius: 18) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(AppTheme.primaryText)
                    .frame(width: 52, height: 52)
                    .background(AppTheme.softSurface, in: RoundedRectangle(cornerRadius: 16))

                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.appHeadline)
                        .foregroundStyle(AppTheme.primaryText)
                    Text(subtitle)
                        .font(.appCaption)
                        .foregroundStyle(AppTheme.secondaryText)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(16)
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

                SoftCard(radius: 18) {
                    VStack(spacing: 0) {
                        UpgradeBudgetHintRow(title: "小修小补", subtitle: "适合补内存、换散热、加电源余量", range: "¥500-1500")
                        BudgetHintDivider()
                        UpgradeBudgetHintRow(title: "核心升级", subtitle: "适合优先换显卡或补齐主要短板", range: "¥1500-5000")
                        BudgetHintDivider()
                        UpgradeBudgetHintRow(title: "大幅升级", subtitle: "适合显卡、内存、电源一起升级", range: "¥5000+")
                    }
                }
            }

            Spacer(minLength: 0)
        }
    }
}

private struct UpgradeNeedStep: View {
    let needs: [UpgradeNeed]
    @Binding var selectedNeed: String

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            UpgradeStepTitle(
                title: "选择升级需求",
                subtitle: "选择这次最想改善的体验，AI 会按这个方向安排升级顺序。"
            )

            VStack(alignment: .leading, spacing: 12) {
                Text("主要诉求")
                    .font(.appHeadline)
                    .foregroundStyle(AppTheme.primaryText)

                UpgradeNeedSegmentedPicker(needs: needs, selectedNeed: $selectedNeed)
            }

            if let need = needs.first(where: { $0.title == selectedNeed }) {
                UpgradeNeedSummary(need: need)
            }

            Spacer(minLength: 0)
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
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("AI 生成升级建议")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(AppTheme.primaryText)

                    Text("智能推荐")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(AppTheme.primaryText)
                        .padding(.horizontal, 7)
                        .frame(height: 22)
                        .background(AppTheme.softSurface, in: Capsule())
                }

                UpgradeOverviewCard()

                Text("推荐升级方案")
                    .font(.appHeadline)
                    .foregroundStyle(AppTheme.primaryText)

                UpgradeRecommendationCard(
                    category: "显卡 (GPU)",
                    recommend: "推荐：RTX 4060",
                    note: "优先升级",
                    icon: "display"
                )

                UpgradeRecommendationCard(
                    category: "内存 (RAM)",
                    recommend: "推荐：32GB (16GB x 2) DDR4 3200MHz",
                    note: "可选升级",
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

private struct UpgradeHardwareRow: View {
    let category: HardwareOptionCategory
    let selectedValue: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            SoftCard(radius: 16) {
                HStack(spacing: 12) {
                    Image(systemName: category.icon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppTheme.primaryText)
                        .frame(width: 34, height: 34)
                        .background(AppTheme.softSurface, in: RoundedRectangle(cornerRadius: 10))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(category.title)
                            .font(.appSubheadline)
                            .foregroundStyle(AppTheme.primaryText)
                        Text(selectedValue)
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
            }
        }
        .buttonStyle(.plain)
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
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(AppTheme.primaryText)
                Text(subtitle)
                    .font(.system(size: 10, weight: .regular))
                    .foregroundStyle(AppTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            Text(range)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(AppTheme.primaryText)
                .padding(.horizontal, 11)
                .frame(height: 28)
                .background(AppTheme.softSurface, in: Capsule())
        }
        .padding(.horizontal, 14)
        .frame(height: 72)
    }
}

private struct BudgetHintDivider: View {
    var body: some View {
        Rectangle()
            .fill(AppTheme.border.opacity(0.7))
            .frame(height: 1)
            .padding(.leading, 14)
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
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(isSelected ? AppTheme.primaryText : AppTheme.border, lineWidth: 1.2)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct UpgradeNeedSegmentedPicker: View {
    let needs: [UpgradeNeed]
    @Binding var selectedNeed: String
    @Namespace private var selectionNamespace

    var body: some View {
        HStack(spacing: 0) {
            ForEach(needs) { need in
                Button {
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
                        selectedNeed = need.title
                    }
                } label: {
                    ZStack {
                        if selectedNeed == need.title {
                            Capsule()
                                .fill(AppTheme.surface)
                                .matchedGeometryEffect(id: "upgradeNeedSelection", in: selectionNamespace)
                                .shadow(color: Color.black.opacity(0.10), radius: 18, x: 0, y: 10)
                        }

                        Text(need.title)
                            .font(.system(size: 13, weight: selectedNeed == need.title ? .bold : .semibold))
                            .foregroundStyle(selectedNeed == need.title ? AppTheme.primaryText : AppTheme.secondaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.68)
                            .padding(.horizontal, 5)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(AppTheme.softSurface, in: Capsule())
        .overlay(
            Capsule()
                .stroke(AppTheme.border.opacity(0.75), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 14, x: 0, y: 8)
    }
}

private struct UpgradeNeedSummary: View {
    let need: UpgradeNeed

    var body: some View {
        SoftCard(radius: 18) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 11) {
                    Image(systemName: need.icon)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 34, height: 34)
                        .background(AppTheme.primaryText, in: RoundedRectangle(cornerRadius: 10))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(need.tagline)
                            .font(.appSubheadline)
                            .foregroundStyle(AppTheme.primaryText)
                        Text(need.subtitle)
                            .font(.appCaption)
                            .foregroundStyle(AppTheme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)
                }

                Rectangle()
                    .fill(AppTheme.border.opacity(0.7))
                    .frame(height: 1)

                VStack(alignment: .leading, spacing: 10) {
                    Text("升级侧重点")
                        .font(.appSubheadline)
                        .foregroundStyle(AppTheme.primaryText)

                    ForEach(need.focusItems, id: \.self) { item in
                        HStack(alignment: .top, spacing: 9) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(AppTheme.success)
                                .frame(width: 18, height: 18)
                                .background(AppTheme.success.opacity(0.12), in: Circle())
                                .padding(.top, 1)

                            Text(item)
                                .font(.appCaption)
                                .foregroundStyle(AppTheme.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }

                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "lightbulb")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(AppTheme.primaryText)
                        .frame(width: 22, height: 22)
                        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 7))

                    Text(need.hint)
                        .font(.appCaption)
                        .foregroundStyle(AppTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(11)
                .background(AppTheme.softSurface, in: RoundedRectangle(cornerRadius: 12))
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .transition(.opacity.combined(with: .move(edge: .bottom)))
        .animation(.easeInOut(duration: 0.18), value: need.title)
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
        VStack(alignment: .leading, spacing: 12) {
            Text("升级总览")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)

            HStack(spacing: 10) {
                UpgradeOverviewMetric(title: "提升", value: "42%")
                UpgradeOverviewMetric(title: "预算", value: "¥2896")
                UpgradeOverviewMetric(title: "优先", value: "显卡")
            }
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [Color(red: 0.07, green: 0.10, blue: 0.15), Color(red: 0.13, green: 0.16, blue: 0.24)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 12)
        )
    }
}

private struct UpgradeOverviewMetric: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.white.opacity(0.62))
            Text(value)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 10))
    }
}

private struct UpgradeRecommendationCard: View {
    let category: String
    let recommend: String
    let note: String
    let icon: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(AppTheme.primaryText)
                .frame(width: 38, height: 38)
                .background(AppTheme.softSurface, in: RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 4) {
                Text(category)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.primaryText)
                Text(recommend)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(AppTheme.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }

            Spacer()

            Text(note)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(AppTheme.secondaryText)
        }
        .padding(12)
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.border, lineWidth: 1))
    }
}

private struct UpgradeTotalCard: View {
    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("升级顺序")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.primaryText)
                Text("先处理影响体验最大的短板")
                    .font(.system(size: 9))
                    .foregroundStyle(AppTheme.mutedText)
            }

            Spacer()

            Text("显卡优先")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(AppTheme.primaryText)
        }
        .padding(14)
        .background(AppTheme.softSurface, in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct UpgradeNeed: Identifiable {
    let id = UUID()
    let title: String
    let tagline: String
    let subtitle: String
    let icon: String
    let focusItems: [String]
    let hint: String

    static let samples = [
        UpgradeNeed(
            title: "提升游戏性能",
            tagline: "帧率优先",
            subtitle: "让热门游戏更稳、更流畅，预算优先投入显卡、CPU 和内存。",
            icon: "gamecontroller",
            focusItems: ["当前显卡是否是主要瓶颈", "CPU 是否会拖累游戏帧率", "电源和散热能不能支撑升级"],
            hint: "适合更在意帧率和画质的用户，外观升级会放到性能短板之后。"
        ),
        UpgradeNeed(
            title: "均衡提升",
            tagline: "体验优先",
            subtitle: "同时考虑游戏流畅度、日常响应速度、噪音和后续升级空间。",
            icon: "scale.3d",
            focusItems: ["哪些配件升级收益最高", "内存、硬盘和电源是否需要补齐", "是否保留后续升级空间"],
            hint: "适合不知道先换什么的用户，系统会优先避开只提升单项、整体体验不明显的方案。"
        ),
        UpgradeNeed(
            title: "外观和灯光效果",
            tagline: "颜值优先",
            subtitle: "兼顾机箱、灯效、散热和桌面观感，但避免牺牲关键性能。",
            icon: "sparkles",
            focusItems: ["机箱和散热是否适合展示", "是否需要白色、灯效或海景房风格", "颜值升级会不会压缩核心性能预算"],
            hint: "适合更重视桌面观感的用户，AI 会提醒哪些外观升级不值得优先花钱。"
        )
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
    UpgradePlanView(savedHardwareProfile: .skipped, onBack: {})
}
