import SwiftUI

struct DIYBuildView: View {
    let savedHardwareProfile: HardwareProfile
    let onBack: () -> Void

    @State private var flow = PerformanceTestFlow()
    @State private var selectedHardwareCategory: HardwareOptionCategory?
    @State private var feedbackMessage: String?

    var body: some View {
        VStack(spacing: 18) {
            ScreenHeader(title: "游戏性能测试", trailingIcon: nil) {
                if flow.currentStep == .hardware {
                    onBack()
                } else {
                    flow.goPrevious()
                }
            }
            .padding(.top, 8)

            FlowStepIndicator(
                currentStep: flow.currentStep.rawValue + 1,
                totalSteps: PerformanceTestStep.allCases.count,
                currentTitle: flow.currentStep.title
            )

            if let feedbackMessage {
                FlowFeedbackBanner(message: feedbackMessage)
            }

            Group {
                switch flow.currentStep {
                case .hardware:
                    HardwareSelectionStep(
                        hardwareProfile: $flow.hardwareProfile,
                        selectedCategory: $selectedHardwareCategory,
                        savedHardwareProfile: savedHardwareProfile,
                        onFeedback: showFeedback
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
            .frame(maxWidth: 520)
            .frame(maxWidth: .infinity)

            Spacer(minLength: 0)

            PrimaryButton(title: primaryButtonTitle, icon: primaryButtonIcon) {
                if flow.currentStep == .result {
                    flow.currentStep = .hardware
                } else {
                    flow.goNext()
                }
            }
            .frame(maxWidth: 520)
            .padding(.bottom, 22)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, AppTheme.screenPadding)
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
        Binding(
            get: { flow.hardwareProfile.value(for: title) },
            set: {
                let change = flow.hardwareProfile.updateValue($0, for: title)
                if let message = change.feedbackMessage {
                    showFeedback(message)
                }
            }
        )
    }

    private func showFeedback(_ message: String) {
        withAnimation(.easeInOut(duration: 0.2)) {
            feedbackMessage = message
        }

        Task {
            try? await Task.sleep(for: .seconds(3))
            if feedbackMessage == message {
                withAnimation(.easeInOut(duration: 0.2)) {
                    feedbackMessage = nil
                }
            }
        }
    }

    private func filters(for category: HardwareOptionCategory) -> [HardwareCatalogFilter] {
        category.title == "主板"
            ? HardwareCatalog.motherboardFilters(compatibleWithCPU: flow.hardwareProfile.cpu)
            : HardwareCatalog.filters(for: category.title)
    }

    private func contextMessage(for category: HardwareOptionCategory) -> String? {
        let cpu = flow.hardwareProfile.cpu
        guard category.title == "主板", let socket = HardwareCatalog.cpuSocket(for: cpu) else { return nil }
        return "已根据 \(cpu) 筛选 \(socket) 兼容主板"
    }
}

private struct HardwareSelectionStep: View {
    @Binding var hardwareProfile: HardwareProfile
    @Binding var selectedCategory: HardwareOptionCategory?
    let savedHardwareProfile: HardwareProfile
    let onFeedback: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HardwareConfigIntro(
                icon: "desktopcomputer",
                title: "选择自己的电脑配置",
                subtitle: "先选你知道的 CPU、显卡、内存和电源，不确定的地方可以选“不知道”。"
            )

            HardwareProfileImportRow(action: applySavedProfile)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("电脑配置")
                        .font(.appBody.weight(.semibold))
                        .foregroundStyle(AppTheme.secondaryText)

                    HardwareConfigurationList(
                        categories: HardwareProfileOptions.categories,
                        selectedValue: selectedValue(for:)
                    ) { category in
                        selectedCategory = category
                    }
                }
                .padding(.bottom, 10)
            }
        }
    }

    private func applySavedProfile() {
        if savedHardwareProfile.wasSkipped {
            onFeedback("还没有可导入的电脑档案")
        } else {
            hardwareProfile = savedHardwareProfile
            onFeedback("已套用 \(savedHardwareProfile.appliedItemCount) 项配置")
        }
    }

    private func selectedValue(for title: String) -> String {
        switch title {
        case "CPU":
            return hardwareProfile.cpu
        case "显卡":
            return hardwareProfile.gpu
        case "主板":
            return hardwareProfile.motherboard
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
                FlowIntroCard(
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
                            .lineLimit(2)
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

#Preview {
    DIYBuildView(savedHardwareProfile: .skipped, onBack: {})
}
