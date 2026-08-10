import SwiftUI

struct AestheticBuildView: View {
    @Binding var flow: AestheticBuildFlow
    let onClose: () -> Void
    let onGenerate: () -> Void

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    ScreenHeader(title: "颜值装机", trailingIcon: nil, onBack: goBack)
                        .padding(.top, 8)

                    AestheticStepProgressHeader(currentStep: flow.step)

                    stepContent
                }
                .padding(.horizontal, AppTheme.screenPadding)
                .padding(.bottom, 92)
            }

            HStack(spacing: 12) {
                Button(action: goPreviousStep) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(flow.step == .performanceBudget ? AppTheme.mutedText : AppTheme.primaryText)
                        .frame(width: 48, height: 48)
                        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: AppTheme.controlRadius))
                }
                .buttonStyle(.plain)
                .disabled(flow.step == .performanceBudget)
                .accessibilityLabel("上一步")

                PrimaryButton(
                    title: flow.step == .quote ? "生成配置方案" : "下一步",
                    icon: flow.step == .quote ? "sparkles" : "arrow.right",
                    action: handlePrimaryAction
                )
            }
            .padding(.horizontal, AppTheme.screenPadding)
            .padding(.bottom, 18)
        }
        .background(AppTheme.background.ignoresSafeArea())
    }

    @ViewBuilder
    private var stepContent: some View {
        switch flow.step {
        case .performanceBudget:
            PerformanceBudgetStep(flow: $flow)
        case .games:
            GamesStep(flow: $flow)
        case .experience:
            ExperienceStep(flow: $flow)
        case .quote:
            QuoteStep(flow: $flow)
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
        if flow.step == .quote {
            flow.confirmQuote()
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

    var body: some View {
        SoftCard(radius: 22) {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 7) {
                    Text("性能预算和用途")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(AppTheme.primaryText)

                    Text("外观方案费用已单独计算，AI 会按性能预算选择其他核心配件。")
                        .font(.appBody)
                        .foregroundStyle(AppTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

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
                    TextField(
                        "例如 RTX 5070",
                        text: Binding(
                            get: { flow.ownedGPUModel },
                            set: { flow.setOwnedGPUModel($0) }
                        )
                    )
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel("自备显卡型号")
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
            .padding(22)
        }
        .animation(.easeOut(duration: 0.2), value: flow.hasOwnedGPU)
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
                    VStack(spacing: 6) {
                        ZStack {
                            Circle()
                                .fill(index <= currentStep.rawValue ? AppTheme.primaryText : AppTheme.surface)
                                .frame(width: 22, height: 22)
                                .overlay(
                                    Circle()
                                        .stroke(index <= currentStep.rawValue ? Color.clear : AppTheme.border, lineWidth: 1)
                                )

                            if index < currentStep.rawValue {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.white)
                            } else {
                                Text("\(index + 1)")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(index == currentStep.rawValue ? .white : AppTheme.secondaryText)
                            }
                        }

                        Text(step.title)
                            .font(.system(size: 9, weight: index == currentStep.rawValue ? .bold : .semibold))
                            .foregroundStyle(index == currentStep.rawValue ? AppTheme.primaryText : AppTheme.secondaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                    }
                    .frame(width: 66)

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

private struct GamesStep: View {
    @Binding var flow: AestheticBuildFlow

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 2)

    var body: some View {
        SoftCard(radius: 22) {
            VStack(alignment: .leading, spacing: 14) {
                Text("常玩游戏")
                    .font(.appHeadline)
                    .foregroundStyle(AppTheme.primaryText)

                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(PerformanceGame.samples) { game in
                        GameChoiceRow(
                            game: game,
                            isSelected: flow.selectedGames.contains(game)
                        ) {
                            flow.toggleGame(game)
                        }
                    }
                }
            }
            .padding(18)
        }
    }
}

private struct GameChoiceRow: View {
    let game: PerformanceGame
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(game.mark)
                    .font(.system(size: game.mark.count > 3 ? 11 : 14, weight: .black))
                    .frame(width: 34, height: 34)
                    .background(isSelected ? Color.white.opacity(0.16) : AppTheme.softSurface, in: RoundedRectangle(cornerRadius: 9))

                Text(game.name)
                    .font(.appSubheadline)
                    .lineLimit(1)

                Spacer(minLength: 4)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundStyle(isSelected ? Color.white : AppTheme.primaryText)
            .padding(.horizontal, 10)
            .frame(height: 48)
            .background(isSelected ? AppTheme.primaryText : AppTheme.surface, in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? AppTheme.primaryText : AppTheme.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct ExperienceStep: View {
    @Binding var flow: AestheticBuildFlow

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(AestheticExperience.allCases) { experience in
                Button {
                    flow.selectExperience(experience)
                } label: {
                    SoftCard(radius: 18) {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(experience.title)
                                    .font(.appHeadline)
                                    .foregroundStyle(AppTheme.primaryText)
                                Text(experience.detail)
                                    .font(.appBody)
                                    .foregroundStyle(AppTheme.secondaryText)
                            }

                            Spacer()

                            Image(systemName: flow.selectedExperience == experience ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(flow.selectedExperience == experience ? AppTheme.primaryText : AppTheme.border)
                        }
                        .padding(16)
                    }
                }
                .buttonStyle(.plain)
            }

            SoftCard(radius: 18) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("屏幕分辨率")
                        .font(.appHeadline)
                        .foregroundStyle(AppTheme.primaryText)

                    HStack(spacing: 9) {
                        ForEach(AestheticResolutionChoice.allCases) { resolution in
                            Button {
                                flow.selectResolution(resolution)
                            } label: {
                                Text(resolution.title)
                                    .font(.appSubheadline)
                                    .foregroundStyle(flow.selectedResolution == resolution ? Color.white : AppTheme.primaryText)
                                    .frame(height: 32)
                                    .padding(.horizontal, 13)
                                    .background(
                                        flow.selectedResolution == resolution ? AppTheme.primaryText : AppTheme.softSurface,
                                        in: Capsule()
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if flow.selectedResolution == .unknown {
                        Text("不知道也没关系，演示报价暂按 2K 估算。")
                            .font(.appCaption)
                            .foregroundStyle(AppTheme.secondaryText)
                    }
                }
                .padding(16)
            }
        }
    }
}

private struct QuoteStep: View {
    @Binding var flow: AestheticBuildFlow

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(flow.quote.total.midpointLabel)
                .font(.system(size: 34, weight: .heavy))
                .foregroundStyle(AppTheme.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)

            SoftCard(radius: 22) {
                VStack(spacing: 14) {
                    QuoteRow(title: "性能配件预算", value: flow.quote.performanceCore.label)
                    QuoteRow(title: "外观配件费用", value: flow.quote.styleModule.label)
                    QuoteRow(title: "整机预计", value: flow.quote.total.label)

                    if flow.selectedResolution == .unknown {
                        Text("屏幕不知道时，报价暂按 2K 估算。")
                            .font(.appCaption)
                            .foregroundStyle(AppTheme.secondaryText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(18)
            }

            Text("演示估价，仅用于验证流程，不作为购买报价。")
                .font(.appCaption)
                .foregroundStyle(AppTheme.warning)

            SecondaryActionButton(title: "游戏性能低一点") {
                flow.showExperience()
            }
        }
    }
}

private struct QuoteRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .font(.appBody)
                .foregroundStyle(AppTheme.secondaryText)
            Spacer()
            Text(value)
                .font(.appSubheadline)
                .foregroundStyle(AppTheme.primaryText)
        }
    }
}

private struct DetailLine: View {
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            Text(title)
                .font(.appCaption.weight(.semibold))
                .foregroundStyle(AppTheme.primaryText)
            Text(value)
                .font(.appCaption)
                .foregroundStyle(AppTheme.secondaryText)
        }
    }
}

private struct SecondaryActionButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.appSubheadline)
                .foregroundStyle(AppTheme.primaryText)
                .frame(maxWidth: .infinity)
                .frame(height: 42)
                .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: AppTheme.controlRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.controlRadius)
                        .stroke(AppTheme.border, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}
