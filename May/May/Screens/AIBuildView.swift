import SwiftUI

struct AIBuildView: View {
    @State private var currentStep: AIBuildStep = .budget
    @State private var budget: Double = 0.55
    @State private var selectedUseCases: Set<String> = ["游戏"]
    @State private var purchasePreference = "不懂就默认"
    @State private var chassisColorPreference = "曜石黑"
    @State private var cpuPreference = "任意"
    @State private var gpuPreference = "任意"

    let onBack: () -> Void
    let onShowResult: () -> Void

    private let purchaseOptions = ["全新优先", "可接受二手", "不懂就默认"]

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
            MultiSegmentSection(title: "主要用途", options: AppMockData.useCases, selected: $selectedUseCases)

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
            PreferenceSegmentGroup(
                title: "显卡偏好",
                options: ["任意", "NVIDIA", "AMD"],
                selected: $gpuPreference
            )
            HardwareHint()
        }
    }

    private func handlePrimaryAction() {
        if let next = currentStep.next {
            currentStep = next
        } else {
            onShowResult()
        }
    }

    private func goToPreviousStep() {
        if let previous = currentStep.previous {
            currentStep = previous
        }
    }
}

private enum AIBuildStep: Int, CaseIterable {
    case budget
    case purchase
    case hardware

    var title: String {
        switch self {
        case .budget:
            return "预算和用途"
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

private struct MultiSegmentSection: View {
    let title: String
    let options: [String]
    @Binding var selected: Set<String>

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.appSubheadline)
                .foregroundStyle(AppTheme.primaryText)

            VStack(spacing: 8) {
                ForEach(chunkedOptions, id: \.self) { rowOptions in
                    HStack(spacing: 4) {
                        ForEach(rowOptions, id: \.self) { option in
                            let isSelected = selected.contains(option)
                            SegmentOptionButton(
                                title: option,
                                isSelected: isSelected,
                                showsSelectionDot: false
                            ) {
                                if isSelected {
                                    selected.remove(option)
                                } else {
                                    selected.insert(option)
                                }
                            }
                        }
                    }
                    .padding(5)
                    .background(AppTheme.softSurface, in: Capsule())
                    .overlay(Capsule().stroke(AppTheme.border, lineWidth: 1))
                }
            }
        }
    }

    private var chunkedOptions: [[String]] {
        stride(from: 0, to: options.count, by: 3).map { start in
            Array(options[start..<min(start + 3, options.count)])
        }
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

            HStack(spacing: 4) {
                ForEach(options, id: \.self) { option in
                    let isSelected = selected == option
                    SegmentOptionButton(
                        title: option,
                        isSelected: isSelected,
                        showsSelectionDot: showsSelectionDot
                    ) {
                        selected = option
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

private struct SegmentOptionButton: View {
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
            .background(isSelected ? AppTheme.surface : Color.clear, in: Capsule())
            .shadow(color: isSelected ? Color.black.opacity(0.08) : Color.clear, radius: 10, x: 0, y: 6)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    AIBuildView(onBack: {}, onShowResult: {})
}
