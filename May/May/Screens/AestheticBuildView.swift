import SwiftUI

struct AestheticBuildView: View {
    @Binding var flow: AestheticBuildFlow
    @State private var showsOwnedGPUSelectionAlert = false
    let onClose: () -> Void
    let onGenerate: () -> Void

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    ScreenHeader(title: "颜值装机", trailingIcon: nil, onBack: goBack)
                        .padding(.top, 8)

                    AestheticStepProgressHeader(currentStep: flow.step)

                    Group {
                        if flow.step == .games {
                            stepContent
                                .padding(.top, 4)
                        } else {
                            SoftCard(radius: 22) {
                                VStack(alignment: .leading, spacing: 18) {
                                    AestheticStepTitle(step: flow.step)
                                    stepContent
                                }
                                .padding(22)
                            }
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
                }
                .padding(.horizontal, AppTheme.screenPadding)
                .padding(.bottom, 92)
            }

            WizardBottomBar(
                canGoBack: flow.step != .performanceBudget,
                primaryTitle: flow.step == .hardware ? "生成配置方案" : "下一步",
                primaryIcon: flow.step == .hardware ? "sparkles" : "arrow.right",
                isLoading: false,
                onBack: goPreviousStep,
                onPrimary: handlePrimaryAction
            )
            .padding(.horizontal, AppTheme.screenPadding)
            .padding(.bottom, 18)
        }
        .background(AppTheme.background.ignoresSafeArea())
        .animation(.easeInOut(duration: 0.18), value: flow.step)
        .alert("请选择自备显卡型号", isPresented: $showsOwnedGPUSelectionAlert) {
            Button("知道了", role: .cancel) {}
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        switch flow.step {
        case .performanceBudget:
            PerformanceBudgetStep(flow: $flow)
        case .games:
            GamesStep(flow: $flow)
        case .hardware:
            HardwarePreferenceStep(flow: $flow)
        }
    }

    private func goBack() {
        if flow.step == .performanceBudget {
            onClose()
        } else {
            flow.goPrevious()
        }
    }

    private func handlePrimaryAction() {
        if flow.step == .hardware {
            guard !flow.hasOwnedGPU || !flow.ownedGPUModel.isEmpty else {
                showsOwnedGPUSelectionAlert = true
                return
            }
            onGenerate()
        } else {
            flow.goNext()
        }
    }

    private func goPreviousStep() {
        guard flow.step != .performanceBudget else { return }
        flow.goPrevious()
    }
}

private struct PerformanceBudgetStep: View {
    @Binding var flow: AestheticBuildFlow
    @State private var isOwnedGPUPickerPresented = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("性能预算")
                        .font(.appSubheadline)
                    Spacer()
                    Text("¥ \(flow.performanceBudget)")
                        .font(.system(size: 22, weight: .heavy))
                        .monospacedDigit()
                }

                HStack {
                    Text("¥ 4000")
                    Spacer()
                    Text("¥ 30000")
                }
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AppTheme.secondaryText)

                HStack(spacing: 12) {
                    AestheticBudgetStepButton(
                        systemName: "minus",
                        isEnabled: flow.performanceBudget > AestheticBuildFlow.minimumPerformanceBudget
                    ) {
                        flow.setPerformanceBudget(flow.performanceBudget - 100)
                    }

                    Slider(
                        value: Binding(
                            get: { Double(flow.performanceBudget) },
                            set: { flow.setPerformanceBudget(Int($0.rounded())) }
                        ),
                        in: Double(AestheticBuildFlow.minimumPerformanceBudget)...Double(AestheticBuildFlow.maximumPerformanceBudget),
                        step: 100
                    )
                    .tint(AppTheme.primaryText)

                    AestheticBudgetStepButton(
                        systemName: "plus",
                        isEnabled: flow.performanceBudget < AestheticBuildFlow.maximumPerformanceBudget
                    ) {
                        flow.setPerformanceBudget(flow.performanceBudget + 100)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("主要用途")
                    .font(.appSubheadline)
                    .foregroundStyle(AppTheme.primaryText)

                LiquidGlassSegmentedPicker(
                    options: AppMockData.useCases,
                    selection: Binding(
                        get: { flow.selectedUseCase },
                        set: { flow.selectUseCase($0) }
                    ),
                    usesNativeSegmentedStyle: true,
                    title: { $0 }
                )
            }

            Toggle(
                isOn: Binding(
                    get: { flow.hasOwnedGPU },
                    set: { flow.setHasOwnedGPU($0) }
                )
            ) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("自备显卡")
                        .font(.appSubheadline)
                        .foregroundStyle(AppTheme.primaryText)
                    Text(flow.hasOwnedGPU ? "性能预算不包含显卡" : "由 AI 在性能预算内搭配显卡")
                        .font(.appCaption)
                        .foregroundStyle(AppTheme.secondaryText)
                }
            }
            .tint(AppTheme.primaryText)

            if flow.hasOwnedGPU {
                Button {
                    isOwnedGPUPickerPresented = true
                } label: {
                    HStack(spacing: 12) {
                        Text("显卡型号")
                            .font(.appSubheadline)
                            .foregroundStyle(AppTheme.primaryText)

                        Spacer(minLength: 12)

                        Text(flow.ownedGPUModel.isEmpty ? "请选择" : flow.ownedGPUModel)
                            .font(.appBody)
                            .foregroundStyle(flow.ownedGPUModel.isEmpty ? AppTheme.secondaryText : AppTheme.primaryText)
                            .lineLimit(1)
                            .truncationMode(.middle)

                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(AppTheme.secondaryText)
                    }
                    .padding(.horizontal, 16)
                    .frame(minHeight: 56)
                    .background(
                        AppTheme.softSurface.opacity(0.72),
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("选择自备显卡型号")
                .accessibilityValue(flow.ownedGPUModel.isEmpty ? "未选择" : flow.ownedGPUModel)
            }

            Divider()

            HStack {
                Text("外观配件费用（另计）")
                    .foregroundStyle(AppTheme.secondaryText)
                Spacer()
                Text("¥\(flow.appearanceCost.formatted())")
                    .fontWeight(.semibold)
            }
            .font(.appSubheadline)
        }
        .animation(.easeOut(duration: 0.2), value: flow.hasOwnedGPU)
        .sheet(isPresented: $isOwnedGPUPickerPresented) {
            HardwarePickerSheet(
                title: "显卡",
                icon: "display",
                filters: HardwareCatalog.filters(for: "显卡"),
                selectedValue: Binding(
                    get: { flow.ownedGPUModel },
                    set: { flow.setOwnedGPUModel($0) }
                )
            )
            .presentationDetents([.large])
        }
    }
}

private struct AestheticBudgetStepButton: View {
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

private struct AestheticStepProgressHeader: View {
    let currentStep: AestheticBuildStep

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                ForEach(Array(AestheticBuildStep.allCases.enumerated()), id: \.offset) { index, step in
                    StepIndicator(
                        title: step.title,
                        isActive: step == currentStep,
                        displayNumber: index + 1,
                        isComplete: index < currentStep.rawValue
                    )

                    if index < AestheticBuildStep.allCases.count - 1 {
                        Rectangle()
                            .fill(index < currentStep.rawValue ? AppTheme.primaryText : AppTheme.border)
                            .frame(height: 2)
                    }
                }
            }

            HStack {
                Text("第 \(currentStep.rawValue + 1)/\(AestheticBuildStep.allCases.count) 步")
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

private struct AestheticStepTitle: View {
    let step: AestheticBuildStep

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

private struct GamesStep: View {
    @Binding var flow: AestheticBuildFlow

    private let columns = Array(
        repeating: GridItem(.flexible(), spacing: 8, alignment: .top),
        count: 4
    )

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 5) {
                Text("选择你常玩的游戏")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(AppTheme.primaryText)
                Text("可多选，AI 会按游戏需求调整性能配件")
                    .font(.appBody)
                    .foregroundStyle(AppTheme.secondaryText)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("全部游戏")
                    .font(.appSubheadline)
                    .foregroundStyle(AppTheme.primaryText)

                LazyVGrid(columns: columns, alignment: .leading, spacing: 14) {
                    ForEach(PerformanceGame.samples) { game in
                        GameArtworkTile(
                            title: game.name,
                            artworkName: AIBuildView.gameArtworkNames[game.name],
                            isSelected: flow.selectedGames.contains(game)
                        ) {
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.88)) {
                                flow.toggleGame(game)
                            }
                        }
                    }
                }
            }
        }
    }
}

private struct HardwarePreferenceStep: View {
    @Binding var flow: AestheticBuildFlow

    private let memorySizeOptions = ["16GB", "32GB"]
    private let storageSizeOptions = ["512GB", "1TB", "2TB"]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Toggle(isOn: $flow.needsWirelessNetwork) {
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

            PreferenceSegmentGroup(
                title: "内存大小",
                options: memorySizeOptions,
                selected: $flow.selectedMemorySize
            )
            PreferenceSegmentGroup(
                title: "存储大小",
                options: storageSizeOptions,
                selected: $flow.selectedStorageSize
            )
        }
    }
}
