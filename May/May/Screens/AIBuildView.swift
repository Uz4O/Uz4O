import SwiftUI

struct AIBuildView: View {
    @State private var currentStep: AIBuildStep = .budget
    @State private var isChangingStep = false
    @State private var budget: Double = 0.55
    @State private var selectedUseCase = "游戏"
    @State private var selectedGameCategories: Set<String> = ["FPS"]
    @State private var presentedGameCategory: GameCategory?
    @State private var selectedOfficeApps: Set<String> = []
    @State private var purchasePreference = "全新优先"
    @State private var chassisColorPreference = "曜石黑"
    @State private var cpuPreference = "任意"
    @State private var gpuPreference = "任意"
    @State private var specifiedCPU = ""
    @State private var specifiedGPU = ""

    let onBack: () -> Void
    let onShowResult: () -> Void

    private let purchaseOptions = ["全新优先", "部分配件二手", "全二手"]
    private let gameCategories = GameCategory.defaultCategories
    private let officeAppOptions = ["Office", "WPS", "Photoshop", "Premiere", "AutoCAD", "Blender"]

    var body: some View {
        VStack(spacing: 14) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    ScreenHeader(title: "AI 写配置", trailingIcon: nil, onBack: onBack)
                        .padding(.top, 8)

                    StepProgressHeader(currentStep: currentStep)

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
            }

            WizardBottomBar(
                canGoBack: currentStep.previous != nil,
                primaryTitle: currentStep.next == nil ? "生成配置方案" : "下一步",
                primaryIcon: currentStep.next == nil ? "sparkles" : "arrow.right",
                onBack: goToPreviousStep,
                onPrimary: handlePrimaryAction
            )
            .padding(.horizontal, AppTheme.screenPadding)
            .padding(.bottom, 18)
        }
        .animation(.easeInOut(duration: 0.18), value: currentStep)
    }

    @ViewBuilder
    private var stepContent: some View {
        switch currentStep {
        case .budget:
            BudgetSection(budget: $budget)
            PreferenceSegmentGroup(title: "主要用途", options: AppMockData.useCases, selected: $selectedUseCase)

        case .scenario:
            ScenarioSelectionSection(
                useCase: selectedUseCase,
                gameCategories: gameCategories,
                officeAppOptions: officeAppOptions,
                selectedGameCategories: $selectedGameCategories,
                presentedGameCategory: $presentedGameCategory,
                selectedOfficeApps: $selectedOfficeApps
            )

        case .purchase:
            PreferenceSegmentGroup(title: "购买偏好", options: purchaseOptions, selected: $purchasePreference)
            PreferenceSegmentGroup(
                title: "主机颜色偏好",
                options: ["曜石黑", "纯净白"],
                selected: $chassisColorPreference,
                showsSelectionDot: true
            )

        case .hardware:
            PreferenceSegmentGroup(
                title: "CPU 偏好",
                options: ["任意", "Intel", "AMD"],
                selected: $cpuPreference
            )
            SpecificPartField(title: "指定 CPU 型号", placeholder: "例如 Ryzen 5 7500F", text: $specifiedCPU)
            PreferenceSegmentGroup(
                title: "显卡偏好",
                options: ["任意", "NVIDIA", "AMD"],
                selected: $gpuPreference
            )
            SpecificPartField(title: "指定显卡型号", placeholder: "例如 RTX 4070 Super", text: $specifiedGPU)
            HardwareHint()
        }
    }

    private func handlePrimaryAction() {
        guard !isChangingStep else { return }
        isChangingStep = true

        if let next = currentStep.next {
            currentStep = next
        } else {
            onShowResult()
        }

        resetStepChangeLock()
    }

    private func goToPreviousStep() {
        guard !isChangingStep else { return }
        isChangingStep = true

        if let previous = currentStep.previous {
            currentStep = previous
        }

        resetStepChangeLock()
    }

    private func resetStepChangeLock() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            isChangingStep = false
        }
    }
}

private enum AIBuildStep: Int, CaseIterable {
    case budget
    case scenario
    case purchase
    case hardware

    var title: String {
        switch self {
        case .budget:
            return "预算和用途"
        case .scenario:
            return "场景选择"
        case .purchase:
            return "购买和外观"
        case .hardware:
            return "硬件偏好"
        }
    }

    var subtitle: String {
        switch self {
        case .budget:
            return "先确定大方向，AI 会按预算控制配置。"
        case .scenario:
            return "选择常玩的游戏和常用软件，配置会更贴近真实负载。"
        case .purchase:
            return "选择你能接受的购买方式和主机外观。"
        case .hardware:
            return "不懂就保持任意，AI 会优先避开明显短板。"
        }
    }

    var indexText: String {
        "\(rawValue + 1)/\(Self.allCases.count)"
    }

    var next: AIBuildStep? {
        Self(rawValue: rawValue + 1)
    }

    var previous: AIBuildStep? {
        Self(rawValue: rawValue - 1)
    }
}

private struct StepProgressHeader: View {
    let currentStep: AIBuildStep

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                ForEach(AIBuildStep.allCases, id: \.self) { step in
                    StepIndicator(
                        title: step.title,
                        isActive: step == currentStep,
                        isComplete: step.rawValue < currentStep.rawValue
                    )

                    if step != AIBuildStep.allCases.last {
                        Rectangle()
                            .fill(step.rawValue < currentStep.rawValue ? AppTheme.primaryText : AppTheme.border)
                            .frame(height: 2)
                    }
                }
            }

            HStack {
                Text("第 \(currentStep.indexText) 步")
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
}

private struct StepIndicator: View {
    let title: String
    let isActive: Bool
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

    private var displayNumber: Int {
        AIBuildStep.allCases.firstIndex { $0.title == title }.map { $0 + 1 } ?? 1
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

private struct HardwareHint: View {
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "sparkles")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(AppTheme.primaryText)
                .frame(width: 28, height: 28)
                .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                Text("不知道选什么就保持任意")
                    .font(.appSubheadline)
                    .foregroundStyle(AppTheme.primaryText)
                Text("AI 会根据预算和用途自动平衡 CPU、显卡和升级空间。")
                    .font(.appCaption)
                    .foregroundStyle(AppTheme.secondaryText)
            }
        }
        .padding(12)
        .background(AppTheme.softSurface, in: RoundedRectangle(cornerRadius: 12))
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
        .padding(10)
        .background(.white.opacity(0.94), in: RoundedRectangle(cornerRadius: 18))
        .modifier(AppTheme.cardShadow)
    }
}

private struct BudgetSection: View {
    @Binding var budget: Double

    private var valueText: String {
        let value = Int(3000 + budget * 7000)
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
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(AppTheme.primaryText)
            }

            HStack {
                Text("¥ 3000")
                Spacer()
                Text("10000+")
            }
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(AppTheme.secondaryText)

            Slider(value: $budget)
                .tint(AppTheme.primaryText)
        }
    }
}

private struct GameCategory: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let symbol: String
    let examples: [GameExample]

    static let defaultCategories = [
        GameCategory(
            id: "FPS",
            title: "FPS",
            subtitle: "高帧率优先",
            symbol: "scope",
            examples: [
                GameExample(title: "无畏契约", symbol: "scope"),
                GameExample(title: "CS2", symbol: "target"),
                GameExample(title: "Apex 英雄", symbol: "bolt")
            ]
        ),
        GameCategory(
            id: "3A",
            title: "3A",
            subtitle: "画质和显卡优先",
            symbol: "gamecontroller",
            examples: [
                GameExample(title: "黑神话：悟空", symbol: "flame"),
                GameExample(title: "赛博朋克 2077", symbol: "sparkles"),
                GameExample(title: "荒野大镖客 2", symbol: "mountain.2")
            ]
        ),
        GameCategory(
            id: "腾讯全家桶",
            title: "腾讯全家桶",
            subtitle: "网游和多人开黑",
            symbol: "person.3",
            examples: [
                GameExample(title: "英雄联盟", symbol: "shield"),
                GameExample(title: "地下城与勇士", symbol: "hammer"),
                GameExample(title: "穿越火线", symbol: "crosshair")
            ]
        ),
        GameCategory(
            id: "大战场",
            title: "大战场",
            subtitle: "CPU 和内存压力更高",
            symbol: "map",
            examples: [
                GameExample(title: "战地 2042", symbol: "airplane"),
                GameExample(title: "三角洲行动", symbol: "location"),
                GameExample(title: "绝地求生", symbol: "figure.run")
            ]
        )
    ]
}

private struct GameExample: Identifiable {
    let id = UUID()
    let title: String
    let symbol: String
}

private struct ScenarioSelectionSection: View {
    let useCase: String
    let gameCategories: [GameCategory]
    let officeAppOptions: [String]
    @Binding var selectedGameCategories: Set<String>
    @Binding var presentedGameCategory: GameCategory?
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
                GameCategorySection(
                    categories: gameCategories,
                    selectedCategories: $selectedGameCategories,
                    presentedCategory: $presentedGameCategory
                )
            }

            if showsOfficeApps {
                MultiChoiceChipSection(
                    title: "常用办公软件",
                    subtitle: "可多选，剪辑、设计和建模软件会影响 CPU、内存和显卡选择。",
                    options: officeAppOptions,
                    selected: $selectedOfficeApps
                )
            }
        }
        .sheet(item: $presentedGameCategory) { category in
            GameExamplesSheet(category: category)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
    }
}

private struct GameCategorySection: View {
    let categories: [GameCategory]
    @Binding var selectedCategories: Set<String>
    @Binding var presentedCategory: GameCategory?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("游戏类型")
                    .font(.appSubheadline)
                    .foregroundStyle(AppTheme.primaryText)
                Text("可多选，AI 会按这些类型优先分配 CPU 和显卡预算。")
                    .font(.appCaption)
                    .foregroundStyle(AppTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(categories) { category in
                    let isSelected = selectedCategories.contains(category.id)
                    GameCategoryCard(
                        category: category,
                        isSelected: isSelected,
                        onSelect: {
                            withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
                                if isSelected {
                                    selectedCategories.remove(category.id)
                                } else {
                                    selectedCategories.insert(category.id)
                                }
                            }
                        },
                        onToggleInfo: {
                            presentedCategory = category
                        }
                    )
                }
            }
        }
    }
}

private struct GameCategoryCard: View {
    let category: GameCategory
    let isSelected: Bool
    let onSelect: () -> Void
    let onToggleInfo: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: category.symbol)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(AppTheme.primaryText, in: RoundedRectangle(cornerRadius: 9))

                Spacer(minLength: 6)

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(AppTheme.primaryText)
                }

                Button(action: onToggleInfo) {
                    Image(systemName: "exclamationmark.circle")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(AppTheme.primaryText)
                        .frame(width: 22, height: 22)
                        .background(AppTheme.surface, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(category.title) 示例游戏")
            }

            Button(action: onSelect) {
                VStack(alignment: .leading, spacing: 8) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(category.title)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(AppTheme.primaryText)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(category.subtitle)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(AppTheme.secondaryText)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .frame(minHeight: 124, alignment: .top)
        .background(isSelected ? AppTheme.surface : AppTheme.softSurface, in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(isSelected ? AppTheme.primaryText : AppTheme.border, lineWidth: isSelected ? 1.4 : 1)
        )
        .shadow(color: isSelected ? Color.black.opacity(0.08) : Color.clear, radius: 12, x: 0, y: 7)
    }
}

private struct GameExamplesSheet: View {
    let category: GameCategory

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("\(category.title) 示例游戏")
                    .font(.appTitle)
                    .foregroundStyle(AppTheme.primaryText)

                Spacer()

                Image(systemName: category.symbol)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .background(AppTheme.primaryText, in: RoundedRectangle(cornerRadius: 10))
            }

            Text("这些只是代表游戏，AI 会按同类游戏的性能压力来估算配置。")
                .font(.appBody)
                .foregroundStyle(AppTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(category.examples) { example in
                    GameExampleTile(example: example)
                }
            }

            Spacer()
        }
        .padding(22)
        .background(AppTheme.background.ignoresSafeArea())
    }
}

private struct GameExampleTile: View {
    let example: GameExample

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            ZStack {
                LinearGradient(
                    colors: [AppTheme.primaryText, AppTheme.secondaryText],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                Image(systemName: example.symbol)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(height: 74)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Text(example.title)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(AppTheme.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .padding(9)
        .frame(maxWidth: .infinity)
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct MultiChoiceChipSection: View {
    let title: String
    let subtitle: String
    let options: [String]
    @Binding var selected: Set<String>

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

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 8)], alignment: .leading, spacing: 8) {
                ForEach(options, id: \.self) { option in
                    let isSelected = selected.contains(option)
                    MultiChoiceChip(title: option, isSelected: isSelected) {
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
        }
    }
}

private struct MultiChoiceChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
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
        .buttonStyle(.plain)
    }
}

private struct PreferenceSegmentGroup: View {
    let title: String
    let options: [String]
    @Binding var selected: String
    var showsSelectionDot = false
    @Namespace private var selectionNamespace

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.appSubheadline)
                .foregroundStyle(AppTheme.primaryText)

            ZStack(alignment: .leading) {
                HStack(spacing: 4) {
                    ForEach(options, id: \.self) { option in
                        if selected == option {
                            Capsule()
                                .fill(AppTheme.surface)
                                .matchedGeometryEffect(id: "selection", in: selectionNamespace)
                                .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 6)
                                .frame(maxWidth: .infinity)
                                .frame(height: 42)
                        } else {
                            Color.clear
                                .frame(maxWidth: .infinity)
                                .frame(height: 42)
                        }
                    }
                }

                HStack(spacing: 4) {
                    ForEach(options, id: \.self) { option in
                        let isSelected = selected == option
                        SlidingSegmentOptionButton(
                            title: option,
                            isSelected: isSelected,
                            showsSelectionDot: showsSelectionDot
                        ) {
                            withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
                                selected = option
                            }
                        }
                    }
                }
            }
            .padding(5)
            .background(AppTheme.softSurface, in: Capsule())
            .overlay(
                Capsule()
                    .stroke(AppTheme.border, lineWidth: 1)
            )
        }
    }
}

private struct SpecificPartField: View {
    let title: String
    let placeholder: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.appSubheadline)
                .foregroundStyle(AppTheme.primaryText)

            TextField(placeholder, text: $text)
                .font(.appBody)
                .foregroundStyle(AppTheme.primaryText)
                .padding(.horizontal, 14)
                .frame(height: 46)
                .background(AppTheme.softSurface, in: RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(AppTheme.border, lineWidth: 1)
                )
        }
    }
}

private struct SlidingSegmentOptionButton: View {
    let title: String
    let isSelected: Bool
    var showsSelectionDot = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if showsSelectionDot {
                    Circle()
                        .fill(isSelected ? AppTheme.primaryText : Color.clear)
                        .frame(width: 15, height: 15)
                        .overlay(
                            Circle()
                                .stroke(isSelected ? Color.clear : AppTheme.secondaryText, lineWidth: 2)
                        )
                }

                Text(title)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(isSelected ? AppTheme.primaryText : AppTheme.secondaryText)
            .frame(maxWidth: .infinity)
            .frame(height: 42)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    AIBuildView(onBack: {}, onShowResult: {})
}
