import SwiftUI

struct AIBuildView: View {
    @State private var currentStep: AIBuildStep = .budget
    @State private var isChangingStep = false
    @State private var budget: Double = 6850
    @State private var selectedUseCase = "游戏"
    @State private var selectedGames: Set<String> = []
    @State private var selectedOfficeApps: Set<String> = []
    @State private var usesNoGpuBuild = false
    @State private var needsWirelessNetwork = false
    @State private var selectedBuildPreference = BuildPreference.defaultAISelection
    @State private var chassisColorPreference = "曜石黑"
    @State private var upgradePreference = "当前体验优先"
    @State private var selectedMemorySize = "16GB"
    @State private var selectedStorageSize = "1TB"
    @State private var selectedAestheticStyleID = AestheticBuildStyle.featured[0].id

    let onBack: () -> Void
    let onShowResult: () -> Void

    private let gameOptions = [
        "瓦罗兰特", "CS2", "PUBG", "三角洲行动", "云顶之弈", "LOL",
        "逃离塔科夫", "COD", "赛博朋克2077", "荒野大镖客2", "GTA5",
        "黑神话悟空", "穿越火线", "APEX英雄", "地平线6", "艾尔登法环",
        "城市天际线", "我的世界"
    ]
    private let gameIcons = [
        "瓦罗兰特": "scope",
        "CS2": "target",
        "PUBG": "figure.run",
        "三角洲行动": "map",
        "云顶之弈": "checkerboard.shield",
        "LOL": "shield",
        "逃离塔科夫": "backpack",
        "COD": "crosshair",
        "赛博朋克2077": "sparkles",
        "荒野大镖客2": "mountain.2",
        "GTA5": "car",
        "黑神话悟空": "flame",
        "穿越火线": "plus.viewfinder",
        "APEX英雄": "bolt",
        "地平线6": "steeringwheel",
        "艾尔登法环": "circle.hexagongrid",
        "城市天际线": "building.2",
        "我的世界": "cube"
    ]
    private let officeAppOptions = ["Office", "WPS", "Photoshop", "Premiere", "AutoCAD", "Blender"]
    private let memorySizeOptions = ["16GB", "32GB", "64GB"]
    private let storageSizeOptions = ["512GB", "1TB", "2TB", "4TB"]

    private var availableMemorySizeOptions: [String] {
        let budgetValue = Int(budget)
        if budgetValue < 5000 {
            return ["16GB"]
        }
        if budgetValue < 15000 {
            return ["16GB", "32GB"]
        }
        return memorySizeOptions
    }

    private var availableStorageSizeOptions: [String] {
        let budgetValue = Int(budget)
        if budgetValue < 4000 {
            return ["512GB"]
        }
        if budgetValue < 8000 {
            return ["512GB", "1TB"]
        }
        if budgetValue < 15000 {
            return ["512GB", "1TB", "2TB"]
        }
        return storageSizeOptions
    }

    private var visibleSteps: [AIBuildStep] {
        AIBuildFlowRules.visibleSteps(
            budget: Int(budget),
            ownedParts: []
        )
    }

    private var nextStep: AIBuildStep? {
        guard let index = visibleSteps.firstIndex(of: currentStep) else {
            return visibleSteps.first
        }
        let nextIndex = index + 1
        return nextIndex < visibleSteps.count ? visibleSteps[nextIndex] : nil
    }

    private var previousStep: AIBuildStep? {
        guard let index = visibleSteps.firstIndex(of: currentStep), index > 0 else {
            return nil
        }
        return visibleSteps[index - 1]
    }

    private var usesLowBudgetMode: Bool {
        AIBuildFlowRules.usesLowBudgetMode(
            budget: Int(budget),
            ownedParts: []
        )
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    ScreenHeader(title: "AI 写配置", trailingIcon: nil, onBack: onBack)
                        .padding(.top, 8)

                    StepProgressHeader(currentStep: currentStep, steps: visibleSteps)

                    SoftCard(radius: 22) {
                        VStack(alignment: .leading, spacing: 18) {
                            StepTitle(step: currentStep)

                            stepContent
                        }
                        .padding(22)
                    }
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
                }
                .padding(.horizontal, AppTheme.screenPadding)
                .padding(.bottom, 92)
            }

            WizardBottomBar(
                canGoBack: previousStep != nil,
                primaryTitle: nextStep == nil ? "生成配置方案" : "下一步",
                primaryIcon: nextStep == nil ? "sparkles" : "arrow.right",
                onBack: goToPreviousStep,
                onPrimary: handlePrimaryAction
            )
            .padding(.horizontal, AppTheme.screenPadding)
            .padding(.bottom, 18)
        }
        .animation(.easeInOut(duration: 0.18), value: currentStep)
        .onAppear(perform: clampCapacitySelections)
        .onChange(of: budget) { _, _ in
            clampCapacitySelections()
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        switch currentStep {
        case .budget:
            BudgetSection(budget: $budget)
            PreferenceSegmentGroup(title: "主要用途", options: AppMockData.useCases, selected: $selectedUseCase)
            Toggle(isOn: $usesNoGpuBuild) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("无显卡方案")
                        .font(.appSubheadline)
                        .foregroundStyle(AppTheme.primaryText)
                    Text("是否自备显卡")
                        .font(.appCaption)
                        .foregroundStyle(AppTheme.secondaryText)
                }
            }
            .tint(AppTheme.primaryText)

        case .scenario:
            ScenarioSelectionSection(
                useCase: selectedUseCase,
                gameOptions: gameOptions,
                gameIcons: gameIcons,
                officeAppOptions: officeAppOptions,
                selectedGames: $selectedGames,
                selectedOfficeApps: $selectedOfficeApps
            )

        case .purchase:
            Toggle(isOn: $needsWirelessNetwork) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("无线网络")
                        .font(.appSubheadline)
                        .foregroundStyle(AppTheme.primaryText)
                    Text("房间没有墙上网口时建议打开")
                        .font(.appCaption)
                        .foregroundStyle(AppTheme.secondaryText)
                }
            }
            .tint(AppTheme.primaryText)
            VStack(alignment: .leading, spacing: 8) {
                Text("装机偏好")
                    .font(.appSubheadline)
                    .foregroundStyle(AppTheme.primaryText)

                LiquidGlassSegmentedPicker(
                    options: BuildPreference.aiBuildOptions,
                    selection: $selectedBuildPreference,
                    title: \.title
                )
            }
            PreferenceSegmentGroup(
                title: "主机颜色偏好",
                options: ["曜石黑", "纯净白"],
                selected: $chassisColorPreference,
                showsSelectionDot: true
            )

        case .hardware:
            if selectedBuildPreference == .aesthetic {
                AestheticStylePreferenceSection(
                    styles: AestheticBuildStyle.featured,
                    selectedID: $selectedAestheticStyleID
                )
            } else {
                UpgradePreferenceSection(selected: $upgradePreference)
            }
            if availableMemorySizeOptions.count > 1 {
                PreferenceSegmentGroup(title: "内存大小", options: availableMemorySizeOptions, selected: $selectedMemorySize)
            }
            if availableStorageSizeOptions.count > 1 {
                PreferenceSegmentGroup(title: "存储大小", options: availableStorageSizeOptions, selected: $selectedStorageSize)
            }
        }
    }

    private func handlePrimaryAction() {
        guard !isChangingStep else { return }
        isChangingStep = true

        if let next = nextStep {
            currentStep = next
        } else {
            applyLowBudgetDefaultsIfNeeded()
            onShowResult()
        }

        resetStepChangeLock()
    }

    private func goToPreviousStep() {
        guard !isChangingStep else { return }
        isChangingStep = true

        if let previous = previousStep {
            currentStep = previous
        }

        resetStepChangeLock()
    }

    private func resetStepChangeLock() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            isChangingStep = false
        }
    }

    private func applyLowBudgetDefaultsIfNeeded() {
        guard usesLowBudgetMode else { return }
        let defaults = AIBuildFlowRules.lowBudgetDefaults(useCase: selectedUseCase)
        selectedBuildPreference = defaults.buildPreference
        chassisColorPreference = defaults.colorPreference
    }

    private func clampCapacitySelections() {
        if !availableMemorySizeOptions.contains(selectedMemorySize),
           let fallback = availableMemorySizeOptions.last {
            selectedMemorySize = fallback
        }

        if !availableStorageSizeOptions.contains(selectedStorageSize),
           let fallback = availableStorageSizeOptions.last {
            selectedStorageSize = fallback
        }
    }
}

private struct StepProgressHeader: View {
    let currentStep: AIBuildStep
    let steps: [AIBuildStep]

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                ForEach(steps, id: \.self) { step in
                    StepIndicator(
                        title: step.title,
                        isActive: step == currentStep,
                        displayNumber: stepNumber(for: step),
                        isComplete: isComplete(step)
                    )

                    if step != steps.last {
                        Rectangle()
                            .fill(isComplete(step) ? AppTheme.primaryText : AppTheme.border)
                            .frame(height: 2)
                    }
                }
            }

            HStack {
                Text("第 \(currentStepIndex + 1)/\(steps.count) 步")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(AppTheme.primaryText)
                    .padding(.horizontal, 10)
                    .frame(height: 26)
                    .background(AppTheme.surface, in: Capsule())
                    .modifier(AppTheme.cardShadow)

                Spacer()
            }
        }
    }

    private var currentStepIndex: Int {
        steps.firstIndex(of: currentStep) ?? 0
    }

    private func stepNumber(for step: AIBuildStep) -> Int {
        (steps.firstIndex(of: step) ?? 0) + 1
    }

    private func isComplete(_ step: AIBuildStep) -> Bool {
        guard let index = steps.firstIndex(of: step) else { return false }
        return index < currentStepIndex
    }
}

private struct StepIndicator: View {
    let title: String
    let isActive: Bool
    let displayNumber: Int
    let isComplete: Bool

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(isActive || isComplete ? AppTheme.primaryText : AppTheme.surface)
                    .frame(width: 22, height: 22)
                    .overlay(
                        Circle()
                            .stroke(isActive || isComplete ? Color.clear : AppTheme.border, lineWidth: 1)
                    )

                if isComplete {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                } else {
                    Text("\(displayNumber)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(isActive ? .white : AppTheme.secondaryText)
                }
            }

            Text(title)
                .font(.system(size: 9, weight: isActive ? .bold : .semibold))
                .foregroundStyle(isActive ? AppTheme.primaryText : AppTheme.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(width: 66)
    }

}

private struct StepTitle: View {
    let step: AIBuildStep

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(step.title)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(AppTheme.primaryText)
            Text(step.subtitle)
                .font(.appBody)
                .foregroundStyle(AppTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct UpgradePreferenceSection: View {
    @Binding var selected: String

    private let options = ["当前体验优先", "保留升级空间"]

    var body: some View {
        PreferenceSegmentGroup(title: "后期升级计划", options: options, selected: $selected)
    }
}

private struct AestheticStylePreferenceSection: View {
    let styles: [AestheticBuildStyle]
    @Binding var selectedID: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("选择装机风格")
                .font(.appSubheadline)
                .foregroundStyle(AppTheme.primaryText)

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(styles) { style in
                    AestheticStyleChoiceCard(
                        style: style,
                        isSelected: style.id == selectedID
                    ) {
                        selectedID = style.id
                    }
                }
            }
        }
    }
}

private struct AestheticStyleChoiceCard: View {
    let style: AestheticBuildStyle
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 9) {
                ZStack(alignment: .topTrailing) {
                    Image(style.image)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 92)
                        .frame(maxWidth: .infinity)
                        .clipped()

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(8)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 4) {
                    Text(style.title)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(AppTheme.primaryText)
                        .lineLimit(1)

                    Text(style.summary)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(AppTheme.secondaryText)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? AppTheme.surface : AppTheme.softSurface, in: RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? AppTheme.primaryText : AppTheme.border, lineWidth: isSelected ? 1.4 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct WizardBottomBar: View {
    let canGoBack: Bool
    let primaryTitle: String
    let primaryIcon: String
    let onBack: () -> Void
    let onPrimary: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(canGoBack ? AppTheme.primaryText : AppTheme.mutedText)
                    .frame(width: 48, height: 48)
                    .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: AppTheme.controlRadius))
            }
            .buttonStyle(.plain)
            .disabled(!canGoBack)
            .accessibilityLabel("上一步")

            PrimaryButton(title: primaryTitle, icon: primaryIcon, action: onPrimary)
        }
        .padding(.vertical, 4)
    }
}

private struct BudgetSection: View {
    @Binding var budget: Double

    private let minimumBudget: Double = 3000
    private let maximumBudget: Double = 50000
    private let budgetStep: Double = 100

    private var valueText: String {
        let value = Int(budget)
        return "¥ \(value)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("预算范围")
                    .font(.appSubheadline)
                    .foregroundStyle(AppTheme.primaryText)
                Spacer()
                Text(valueText)
                    .font(.system(size: 22, weight: .heavy))
                    .foregroundStyle(AppTheme.primaryText)
                    .monospacedDigit()
            }

            HStack {
                Text("¥ 3000")
                Spacer()
                Text("¥ 50000")
            }
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(AppTheme.secondaryText)

            HStack(spacing: 12) {
                BudgetStepButton(systemName: "minus", isEnabled: budget > minimumBudget) {
                    updateBudget(by: -budgetStep)
                }

                Slider(value: $budget, in: minimumBudget...maximumBudget, step: budgetStep)
                    .tint(AppTheme.primaryText)

                BudgetStepButton(systemName: "plus", isEnabled: budget < maximumBudget) {
                    updateBudget(by: budgetStep)
                }
            }
        }
    }

    private func updateBudget(by amount: Double) {
        budget = min(max(budget + amount, minimumBudget), maximumBudget)
    }
}

private struct BudgetStepButton: View {
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

private struct ScenarioSelectionSection: View {
    let useCase: String
    let gameOptions: [String]
    let gameIcons: [String: String]
    let officeAppOptions: [String]
    @Binding var selectedGames: Set<String>
    @Binding var selectedOfficeApps: Set<String>

    private var showsGames: Bool {
        useCase == "游戏" || useCase == "游戏兼办公"
    }

    private var showsOfficeApps: Bool {
        useCase == "办公" || useCase == "游戏兼办公"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if showsGames {
                MultiChoiceChipSection(
                    title: "你玩什么游戏？",
                    subtitle: "可多选，AI 会按这些游戏调整 CPU 和显卡侧重点",
                    options: gameOptions,
                    selected: $selectedGames,
                    icons: gameIcons,
                    minimumChipWidth: 92,
                    usesSquareTiles: true,
                    footer: "游戏名称仅用于描述你的配置需求，本应用与相关游戏厂商无关联。"
                )
            }

            if showsOfficeApps {
                MultiChoiceChipSection(
                    title: "常用办公软件",
                    subtitle: "可多选",
                    options: officeAppOptions,
                    selected: $selectedOfficeApps
                )
            }
        }
    }
}

private struct MultiChoiceChipSection: View {
    let title: String
    let subtitle: String
    let options: [String]
    @Binding var selected: Set<String>
    var icons: [String: String] = [:]
    var minimumChipWidth: CGFloat = 92
    var usesSquareTiles = false
    var footer: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.appSubheadline)
                    .foregroundStyle(AppTheme.primaryText)
                Text(subtitle)
                    .font(.appCaption)
                    .foregroundStyle(AppTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: minimumChipWidth), spacing: 8)], alignment: .leading, spacing: 8) {
                ForEach(options, id: \.self) { option in
                    let isSelected = selected.contains(option)
                    MultiChoiceChip(
                        title: option,
                        systemImage: icons[option],
                        isSelected: isSelected,
                        usesSquareTile: usesSquareTiles
                    ) {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.88)) {
                            if isSelected {
                                selected.remove(option)
                            } else {
                                selected.insert(option)
                            }
                        }
                    }
                }
            }

            if let footer {
                Text(footer)
                    .font(.system(size: 10, weight: .regular))
                    .foregroundStyle(AppTheme.mutedText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct MultiChoiceChip: View {
    let title: String
    let systemImage: String?
    let isSelected: Bool
    let usesSquareTile: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            if usesSquareTile {
                ZStack(alignment: .topTrailing) {
                    VStack(spacing: 8) {
                        if let systemImage {
                            Image(systemName: systemImage)
                                .font(.system(size: 18, weight: .bold))
                        }

                        Text(title)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                            .minimumScaleFactor(0.72)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(10)

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 16, weight: .bold))
                            .padding(8)
                    }
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(isSelected ? .white : AppTheme.primaryText)
                .aspectRatio(1, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .background(isSelected ? AppTheme.primaryText : AppTheme.softSurface, in: RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isSelected ? Color.clear : AppTheme.border, lineWidth: 1)
                )
            } else {
                HStack(spacing: 6) {
                    if let systemImage {
                        Image(systemName: systemImage)
                            .font(.system(size: 10, weight: .bold))
                    }

                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                    }

                    Text(title)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(isSelected ? .white : AppTheme.primaryText)
                .frame(maxWidth: .infinity)
                .frame(height: 38)
                .padding(.horizontal, 8)
                .background(isSelected ? AppTheme.primaryText : AppTheme.softSurface, in: Capsule())
                .overlay(
                    Capsule()
                        .stroke(isSelected ? Color.clear : AppTheme.border, lineWidth: 1)
                )
            }
        }
        .buttonStyle(.plain)
    }
}

private struct PreferenceSegmentGroup: View {
    let title: String
    let options: [String]
    @Binding var selected: String
    var showsSelectionDot = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.appSubheadline)
                .foregroundStyle(AppTheme.primaryText)

            LiquidGlassSegmentedPicker(
                options: options,
                selection: $selected,
                showsSelectionDot: showsSelectionDot,
                title: { $0 }
            )
        }
    }
}

#Preview {
    AIBuildView(onBack: {}, onShowResult: {})
}
