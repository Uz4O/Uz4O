import SwiftUI

struct DIYBuildView: View {
    let onBack: () -> Void

    @State private var flow = PerformanceTestFlow()
    @State private var selectedHardwareCategory: HardwareOptionCategory?

    private let designWidth: CGFloat = 328

    var body: some View {
        VStack(spacing: 14) {
            ScreenHeader(title: "游戏性能测试", trailingIcon: nil) {
                if flow.currentStep == .hardware {
                    onBack()
                } else {
                    flow.goPrevious()
                }
            }
            .padding(.top, 8)

            PerformanceStepIndicator(currentStep: flow.currentStep)

            Group {
                switch flow.currentStep {
                case .hardware:
                    HardwareSelectionStep(
                        hardwareProfile: $flow.hardwareProfile,
                        selectedCategory: $selectedHardwareCategory
                    )
                case .conditions:
                    TestConditionStep(
                        selectedResolution: $flow.selectedResolution,
                        selectedGames: $flow.selectedGames
                    )
                case .result:
                    PerformanceResultStep(flow: flow)
                }
            }
            .frame(width: designWidth)

            Spacer(minLength: 0)

            PrimaryButton(title: primaryButtonTitle, icon: primaryButtonIcon) {
                if flow.currentStep == .result {
                    flow.currentStep = .hardware
                } else {
                    flow.goNext()
                }
            }
            .frame(width: designWidth)
            .padding(.bottom, 22)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, AppTheme.screenPadding)
        .sheet(item: $selectedHardwareCategory) { category in
            PerformanceHardwareOptionSheet(
                category: category,
                selectedValue: binding(for: category.title)
            )
            .presentationDetents([.medium])
        }
    }

    private var primaryButtonTitle: String {
        switch flow.currentStep {
        case .hardware:
            return "下一步"
        case .conditions:
            return "开始测试"
        case .result:
            return "重新测试"
        }
    }

    private var primaryButtonIcon: String? {
        flow.currentStep == .result ? "arrow.clockwise" : "arrow.right"
    }

    private func binding(for title: String) -> Binding<String> {
        switch title {
        case "CPU":
            return $flow.hardwareProfile.cpu
        case "显卡":
            return $flow.hardwareProfile.gpu
        case "内存":
            return $flow.hardwareProfile.memory
        case "硬盘":
            return $flow.hardwareProfile.storage
        default:
            return $flow.hardwareProfile.powerSupply
        }
    }
}

private struct PerformanceStepIndicator: View {
    let currentStep: PerformanceTestStep

    var body: some View {
        HStack(spacing: 8) {
            ForEach(PerformanceTestStep.allCases, id: \.self) { step in
                HStack(spacing: 6) {
                    Text("\(step.rawValue + 1)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(step.rawValue <= currentStep.rawValue ? .white : AppTheme.secondaryText)
                        .frame(width: 22, height: 22)
                        .background(step.rawValue <= currentStep.rawValue ? AppTheme.primaryText : AppTheme.softSurface, in: Circle())

                    Text(step.title)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(step == currentStep ? AppTheme.primaryText : AppTheme.secondaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }

                if step != PerformanceTestStep.allCases.last {
                    Rectangle()
                        .fill(AppTheme.border)
                        .frame(width: 10, height: 1)
                }
            }
        }
        .frame(width: 328)
        .padding(.vertical, 6)
    }
}

private struct HardwareSelectionStep: View {
    @Binding var hardwareProfile: HardwareProfile
    @Binding var selectedCategory: HardwareOptionCategory?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            StepIntroCard(
                icon: "desktopcomputer",
                title: "选择自己的电脑配置",
                subtitle: "先选你知道的 CPU、显卡、内存和电源，不确定的地方可以选“不知道”。"
            )

            ScrollView(showsIndicators: false) {
                VStack(spacing: 12) {
                    ForEach(HardwareProfileOptions.categories, id: \.title) { category in
                        PerformanceHardwareRow(
                            category: category,
                            selectedValue: selectedValue(for: category.title)
                        ) {
                            selectedCategory = category
                        }
                    }
                }
                .padding(.bottom, 10)
            }
        }
    }

    private func selectedValue(for title: String) -> String {
        switch title {
        case "CPU":
            return hardwareProfile.cpu
        case "显卡":
            return hardwareProfile.gpu
        case "内存":
            return hardwareProfile.memory
        case "硬盘":
            return hardwareProfile.storage
        default:
            return hardwareProfile.powerSupply
        }
    }
}

private struct TestConditionStep: View {
    @Binding var selectedResolution: PerformanceResolution
    @Binding var selectedGames: [PerformanceGame]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                StepIntroCard(
                    icon: "display",
                    title: "选择屏幕分辨率和测试游戏",
                    subtitle: "分辨率越高越吃显卡，游戏可以多选，结果会优先参考第一个游戏。"
                )

                Text("屏幕分辨率")
                    .font(.appSubheadline)
                    .foregroundStyle(AppTheme.primaryText)

                ResolutionSegmentedControl(selectedResolution: $selectedResolution)

                Text("测试游戏")
                    .font(.appSubheadline)
                    .foregroundStyle(AppTheme.primaryText)
                    .padding(.top, 4)

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
                    .padding(.top, 4)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 9), count: 3), spacing: 10) {
                    ForEach(PerformanceGame.samples) { game in
                        PerformanceGameCard(
                            game: game,
                            isSelected: selectedGames.contains(game)
                        ) {
                            toggle(game)
                        }
                    }

                    ManualPerformanceGameCard()
                }
            }
            .padding(.bottom, 10)
        }
    }

    private func toggle(_ game: PerformanceGame) {
        if selectedGames.contains(game) {
            if selectedGames.count > 1 {
                selectedGames.removeAll { $0 == game }
            }
        } else {
            selectedGames.append(game)
        }
    }
}

private struct PerformanceResultStep: View {
    let flow: PerformanceTestFlow

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                SoftCard(radius: 18) {
                    HStack {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("\(flow.result.resolution) · \(flow.result.primaryGame)")
                                .font(.appSubheadline)
                                .foregroundStyle(AppTheme.secondaryText)
                            Text("平均 \(flow.result.averageFPS)")
                                .font(.system(size: 26, weight: .bold))
                                .foregroundStyle(AppTheme.primaryText)
                            Text("1% Low \(flow.result.lowFPS)")
                                .font(.appCaption)
                                .foregroundStyle(AppTheme.secondaryText)
                        }

                        Spacer()

                        Image(systemName: "speedometer")
                            .font(.system(size: 48, weight: .semibold))
                            .foregroundStyle(AppTheme.primaryText)
                            .frame(width: 86, height: 86)
                            .background(AppTheme.softSurface, in: RoundedRectangle(cornerRadius: 22))
                    }
                    .padding(18)
                }

                SoftCard(radius: 16) {
                    VStack(spacing: 16) {
                        PerformanceMetricRow(title: "屏幕分辨率", value: flow.result.resolution, detail: "按你选择的显示器目标估算")
                        PerformanceMetricRow(title: "测试游戏", value: "\(flow.selectedGames.count) 款", detail: flow.selectedGames.map(\.name).joined(separator: "、"))
                        PerformanceMetricRow(title: "性能瓶颈", value: flow.result.bottleneck, detail: flow.result.advice)
                    }
                    .padding(18)
                }

                SoftCard(radius: 16) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("配置摘要")
                            .font(.appSubheadline)
                            .foregroundStyle(AppTheme.primaryText)
                        Text(flow.hardwareProfile.summary)
                            .font(.appCaption)
                            .foregroundStyle(AppTheme.secondaryText)
                            .lineSpacing(3)
                    }
                    .padding(18)
                }
            }
            .padding(.bottom, 10)
        }
    }
}

private struct StepIntroCard: View {
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

private struct PerformanceHardwareRow: View {
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

private struct ResolutionSegmentedControl: View {
    @Binding var selectedResolution: PerformanceResolution
    @Namespace private var selectionNamespace

    var body: some View {
        HStack(spacing: 0) {
            ForEach(PerformanceResolution.allCases) { resolution in
                Button {
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
                        selectedResolution = resolution
                    }
                } label: {
                    ZStack {
                        if selectedResolution == resolution {
                            Capsule()
                                .fill(AppTheme.surface)
                                .matchedGeometryEffect(id: "performanceResolutionSelection", in: selectionNamespace)
                                .shadow(color: Color.black.opacity(0.10), radius: 18, x: 0, y: 10)
                        }

                        Text(resolution.title)
                            .font(.system(size: 15, weight: selectedResolution == resolution ? .bold : .semibold))
                            .foregroundStyle(selectedResolution == resolution ? AppTheme.primaryText : AppTheme.secondaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(AppTheme.softSurface, in: Capsule())
        .overlay(Capsule().stroke(AppTheme.border.opacity(0.75), lineWidth: 1))
        .shadow(color: Color.black.opacity(0.04), radius: 14, x: 0, y: 8)
    }
}

private struct PerformanceGameCard: View {
    let game: PerformanceGame
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.24, dampingFraction: 0.9)) {
                action()
            }
        } label: {
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

private struct ManualPerformanceGameCard: View {
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

private struct PerformanceMetricRow: View {
    let title: String
    let value: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.appSubheadline)
                    .foregroundStyle(AppTheme.primaryText)
                Text(detail)
                    .font(.appCaption)
                    .foregroundStyle(AppTheme.secondaryText)
                    .lineLimit(2)
            }

            Spacer()

            Text(value)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(AppTheme.primaryText)
                .frame(minWidth: 66, alignment: .trailing)
        }
    }
}

private struct PerformanceHardwareOptionSheet: View {
    let category: HardwareOptionCategory
    @Binding var selectedValue: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Capsule()
                .fill(AppTheme.border)
                .frame(width: 42, height: 5)
                .frame(maxWidth: .infinity)
                .padding(.top, 10)

            HStack(spacing: 10) {
                Image(systemName: category.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppTheme.primaryText)
                    .frame(width: 34, height: 34)
                    .background(AppTheme.softSurface, in: RoundedRectangle(cornerRadius: 10))

                Text("选择\(category.title)")
                    .font(.appHeadline)
                    .foregroundStyle(AppTheme.primaryText)

                Spacer()
            }

            VStack(spacing: 10) {
                ForEach(category.options, id: \.self) { option in
                    Button {
                        selectedValue = option
                        dismiss()
                    } label: {
                        HStack(spacing: 12) {
                            Text(option)
                                .font(.appBody)
                                .foregroundStyle(AppTheme.primaryText)

                            Spacer()

                            if selectedValue == option {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(AppTheme.success)
                            }
                        }
                        .padding(.horizontal, 14)
                        .frame(height: 44)
                        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(selectedValue == option ? AppTheme.primaryText : AppTheme.border, lineWidth: selectedValue == option ? 1.4 : 1)
                        )
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

#Preview {
    DIYBuildView(onBack: {})
}
