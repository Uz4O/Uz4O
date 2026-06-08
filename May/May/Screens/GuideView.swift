import SwiftUI

struct GuideView: View {
    let onBack: () -> Void

    @State private var flow = GuideFlow()

    private let canvasWidth: CGFloat = 276

    var body: some View {
        VStack(spacing: 14) {
            ScreenHeader(title: "装机指南", trailingIcon: nil, onBack: onBack)
                .padding(.top, 8)

            stepHeader

            ProgressTrack(flow: $flow)

            Spacer(minLength: 2)

            AssemblyStage(step: flow.currentStep, canvasWidth: canvasWidth)
                .frame(maxWidth: .infinity)

            Spacer(minLength: 2)

            bottomControls
        }
        .padding(.horizontal, AppTheme.screenPadding)
        .padding(.bottom, 18)
    }

    private var stepHeader: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 5) {
                Text(String(format: "%02d / %02d", flow.currentStep.number, GuideFlow.steps.count))
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(AppTheme.secondaryText)

                Text(flow.currentStep.title)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(AppTheme.primaryText)
            }

            Spacer()

            Text(flow.currentStep.summary)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AppTheme.secondaryText)
                .lineLimit(2)
                .multilineTextAlignment(.trailing)
                .frame(width: 116, alignment: .trailing)
        }
    }

    private var bottomControls: some View {
        HStack(spacing: 12) {
            Button {
                withAnimation(.easeInOut(duration: 0.22)) {
                    flow.goPrevious()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "chevron.left")
                    Text("上一步")
                }
                .font(.appSubheadline)
                .foregroundStyle(flow.canGoPrevious ? AppTheme.primaryText : AppTheme.secondaryText)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: AppTheme.controlRadius))
                .overlay {
                    RoundedRectangle(cornerRadius: AppTheme.controlRadius)
                        .stroke(AppTheme.border, lineWidth: 1)
                }
            }
            .buttonStyle(.plain)
            .disabled(!flow.canGoPrevious)

            Button {
                withAnimation(.easeInOut(duration: 0.22)) {
                    flow.goNext()
                }
            } label: {
                HStack(spacing: 8) {
                    Text(flow.canGoNext ? "下一步" : "已到最后")
                    Image(systemName: flow.canGoNext ? "chevron.right" : "checkmark")
                }
                .font(.appSubheadline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(AppTheme.primaryButton, in: RoundedRectangle(cornerRadius: AppTheme.controlRadius))
            }
            .buttonStyle(.plain)
            .disabled(!flow.canGoNext)
        }
    }
}

private struct ProgressTrack: View {
    @Binding var flow: GuideFlow

    var body: some View {
        VStack(spacing: 10) {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(AppTheme.border)
                        .frame(height: 3)
                        .padding(.horizontal, 11)

                    Capsule()
                        .fill(AppTheme.primaryText)
                        .frame(width: trackFillWidth(totalWidth: proxy.size.width), height: 3)
                        .padding(.leading, 11)

                    HStack(spacing: 0) {
                        ForEach(Array(GuideFlow.steps.enumerated()), id: \.element.id) { index, step in
                            Button {
                                withAnimation(.easeInOut(duration: 0.22)) {
                                    flow.jump(to: index)
                                }
                            } label: {
                                TrackNode(
                                    number: step.number,
                                    isPast: index < flow.currentIndex,
                                    isCurrent: index == flow.currentIndex
                                )
                            }
                            .buttonStyle(.plain)
                            .frame(maxWidth: .infinity)
                            .accessibilityLabel("跳转到第 \(step.number) 步，\(step.title)")
                        }
                    }
                }
            }
            .frame(height: 34)

            HStack(spacing: 8) {
                Text("当前步骤")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(AppTheme.secondaryText)

                Text(flow.currentStep.title)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(AppTheme.primaryText)

                Spacer()

                Text("\(Int((flow.progressFraction * 100).rounded()))%")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(AppTheme.secondaryText)
            }
        }
        .padding(.horizontal, 2)
    }

    private func trackFillWidth(totalWidth: CGFloat) -> CGFloat {
        let availableWidth = max(totalWidth - 22, 0)
        return availableWidth * CGFloat(flow.progressFraction)
    }
}

private struct TrackNode: View {
    let number: Int
    let isPast: Bool
    let isCurrent: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(backgroundColor)
                .frame(width: isCurrent ? 23 : 14, height: isCurrent ? 23 : 14)
                .shadow(color: isCurrent ? AppTheme.primaryText.opacity(0.20) : .clear, radius: 8, x: 0, y: 4)

            Circle()
                .stroke(borderColor, lineWidth: isCurrent ? 2 : 1)
                .frame(width: isCurrent ? 23 : 14, height: isCurrent ? 23 : 14)

            if isCurrent {
                Text(String(format: "%02d", number))
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.white)
            } else if isPast {
                Circle()
                    .fill(.white)
                    .frame(width: 4, height: 4)
            }
        }
        .frame(height: 34)
    }

    private var backgroundColor: Color {
        if isCurrent { return AppTheme.primaryText }
        if isPast { return AppTheme.primaryText }
        return AppTheme.surface
    }

    private var borderColor: Color {
        if isCurrent || isPast { return AppTheme.primaryText }
        return AppTheme.border
    }
}

private struct AssemblyStage: View {
    let step: GuideStepContent
    let canvasWidth: CGFloat

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 24)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.92, green: 0.95, blue: 0.96),
                            Color(red: 0.80, green: 0.85, blue: 0.88)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color.white.opacity(0.9), lineWidth: 1)
                }

            HardwareAnimationMock(step: step)
                .padding(.top, 114)
                .frame(maxWidth: .infinity, alignment: .center)

            StepOverlayCard(step: step)
                .padding(14)
        }
        .frame(width: canvasWidth, height: 438)
        .shadow(color: Color.black.opacity(0.08), radius: 24, x: 0, y: 14)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(step.title)，\(step.action)，注意：\(step.caution)")
    }
}

private struct StepOverlayCard: View {
    let step: GuideStepContent

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 7) {
                Text(String(format: "%02d", step.number))
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 24, height: 24)
                    .background(AppTheme.primaryText, in: Circle())

                Text(step.title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(AppTheme.primaryText)
            }

            Text(step.action)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AppTheme.primaryText)
                .fixedSize(horizontal: false, vertical: true)

            HStack(alignment: .top, spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(AppTheme.warning)
                Text(step.caution)
                    .font(.system(size: 10))
                    .foregroundStyle(AppTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .frame(width: 218, alignment: .leading)
        .background(.white.opacity(0.92), in: RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(.white, lineWidth: 1)
        }
    }
}

private struct HardwareAnimationMock: View {
    let step: GuideStepContent

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(red: 0.14, green: 0.17, blue: 0.20))
                .frame(width: 208, height: 232)
                .overlay {
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color.white.opacity(0.18), lineWidth: 1)
                }

            VStack(spacing: 12) {
                HStack(spacing: 14) {
                    ChipBlock(width: 72, height: 58)
                    ChipBlock(width: 46, height: 58)
                }

                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.14))
                        .frame(width: 102, height: 82)
                    Image(systemName: step.symbol)
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(.white)
                        .symbolEffect(.pulse, options: .repeating.speed(0.8), value: step.id)
                }

                VStack(spacing: 7) {
                    ForEach(0..<4) { index in
                        Capsule()
                            .fill(index == step.number % 4 ? Color.white.opacity(0.75) : Color.white.opacity(0.24))
                            .frame(width: 148, height: 7)
                    }
                }
            }

            MovingPart(step: step)
                .offset(x: 64, y: -94)
        }
    }
}

private struct ChipBlock: View {
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(Color.white.opacity(0.18))
            .frame(width: width, height: height)
            .overlay {
                VStack(spacing: 5) {
                    ForEach(0..<3) { _ in
                        Capsule()
                            .fill(Color.white.opacity(0.25))
                            .frame(width: max(width - 18, 12), height: 4)
                    }
                }
            }
    }
}

private struct MovingPart: View {
    let step: GuideStepContent

    var body: some View {
        VStack(spacing: 7) {
            Image(systemName: step.symbol)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(AppTheme.primaryText)
                .frame(width: 48, height: 48)
                .background(.white, in: RoundedRectangle(cornerRadius: 14))
                .shadow(color: Color.black.opacity(0.15), radius: 12, x: 0, y: 8)

            Image(systemName: "arrow.down")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)
                .symbolEffect(.bounce, options: .repeating.speed(0.7), value: step.id)
        }
    }
}

#Preview {
    GuideView(onBack: {})
}
