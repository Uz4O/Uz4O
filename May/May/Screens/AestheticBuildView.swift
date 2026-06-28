import SwiftUI

struct AestheticBuildView: View {
    @Binding var flow: AestheticBuildFlow
    let onClose: () -> Void
    let onGenerate: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    ScreenHeader(title: "颜值装机", trailingIcon: nil, onBack: goBack)
                        .padding(.top, 8)

                    FlowStepIndicator(
                        currentStep: flow.step.rawValue + 1,
                        totalSteps: AestheticBuildStep.allCases.count,
                        currentTitle: flow.step.title
                    )

                    stepContent
                }
                .padding(.horizontal, AppTheme.screenPadding)
                .padding(.bottom, 10)
            }

            PrimaryButton(
                title: flow.step == .quote ? "生成配置方案" : "下一步",
                icon: flow.step == .quote ? "sparkles" : "arrow.right",
                action: handlePrimaryAction
            )
            .padding(.horizontal, AppTheme.screenPadding)
            .padding(.bottom, 18)
        }
        .background(AppTheme.background.ignoresSafeArea())
    }

    @ViewBuilder
    private var stepContent: some View {
        switch flow.step {
        case .restoration:
            RestorationStep(flow: $flow)
        case .games:
            GamesStep(flow: $flow)
        case .experience:
            ExperienceStep(flow: $flow)
        case .quote:
            QuoteStep(flow: $flow)
        }
    }

    private func goBack() {
        if flow.step == .restoration {
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
}

private struct RestorationStep: View {
    @Binding var flow: AestheticBuildFlow

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SoftCard(radius: 22) {
                HStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(flow.style.title)
                            .font(.system(size: 24, weight: .heavy))
                            .foregroundStyle(AppTheme.primaryText)

                        Text(flow.style.summary)
                            .font(.appBody)
                            .foregroundStyle(AppTheme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 8)

                    Image(flow.style.image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 128, height: 96)
                }
                .padding(18)
            }

            ForEach(flow.style.options) { option in
                RestorationOptionCard(
                    option: option,
                    isSelected: flow.restoration.id == option.id
                ) {
                    flow.selectTier(option.tier)
                }
            }
        }
    }
}

private struct RestorationOptionCard: View {
    let option: AestheticRestorationOption
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            SoftCard(radius: 18) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(option.tier.title)
                            .font(.appHeadline)
                            .foregroundStyle(AppTheme.primaryText)

                        Spacer()

                        Text("约 \(option.fidelity)%")
                            .font(.system(size: 18, weight: .heavy))
                            .foregroundStyle(AppTheme.primaryText)
                    }

                    Text(option.styleCost.label)
                        .font(.appSubheadline)
                        .foregroundStyle(AppTheme.secondaryText)

                    DetailLine(title: "保留：", value: option.keeps)
                    DetailLine(title: "取舍：", value: option.tradeoff)
                }
                .padding(16)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(isSelected ? AppTheme.primaryText : AppTheme.border, lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
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
                    QuoteRow(title: "性能核心", value: flow.quote.performanceCore.label)
                    QuoteRow(title: "外观与散热", value: flow.quote.styleModule.label)
                    QuoteRow(title: "其中颜值溢价", value: flow.quote.aestheticPremium.label)
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

            HStack(spacing: 10) {
                SecondaryActionButton(title: "少为外观花一点") {
                    flow.showRestoration()
                }

                SecondaryActionButton(title: "游戏性能低一点") {
                    flow.showExperience()
                }
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
