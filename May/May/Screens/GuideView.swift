import SwiftUI

struct GuideView: View {
    let onBack: () -> Void

    @State private var flow = GuideFlow()

    private let canvasWidth: CGFloat = 276

    var body: some View {
        VStack(spacing: 14) {
            ScreenHeader(title: "装机指南", trailingIcon: nil, onBack: onBack)
                .padding(.top, 8)

            if flow.isShowingComponentIntro {
                ComponentIntroPage(flow: $flow)
            } else {
                stepHeader

                ProgressTrack(flow: $flow)

                Spacer(minLength: 2)

                AssemblyStage(step: flow.currentStep, canvasWidth: canvasWidth)
                    .frame(maxWidth: .infinity)

                Spacer(minLength: 2)

                bottomControls
            }
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

private struct ComponentIntroPage: View {
    @Binding var flow: GuideFlow
    @State private var isShowingAllComponents = false
    @State private var selectedComponentID = GuideFlow.componentIntroItems[0].id
    @State private var componentScrollProgress: CGFloat = 0

    private let contentWidth: CGFloat = 306
    private let indicatorWidth: CGFloat = 220
    private let pickerCardWidth: CGFloat = 70
    private let pickerCardSpacing: CGFloat = 9

    private var selectedComponent: GuideComponentIntroItem {
        GuideFlow.componentIntroItems.first { $0.id == selectedComponentID } ?? GuideFlow.componentIntroItems[0]
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .center, spacing: 14) {
                introHero

                componentPicker

                ComponentIntroFeatureCard(item: selectedComponent)

                tipCard

                bottomActions
                    .padding(.top, 2)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 8)
            .padding(.bottom, 6)
        }
    }

    private var componentPicker: some View {
        VStack(spacing: 10) {
            GeometryReader { proxy in
                Group {
                    if #available(iOS 18.0, *) {
                        ScrollView(.horizontal, showsIndicators: false) {
                            pickerRow(containerWidth: proxy.size.width)
                        }
                        .onScrollGeometryChange(for: CGFloat.self) { geometry in
                            let contentWidth = geometry.contentSize.width
                            let containerWidth = geometry.containerSize.width
                            let scrollableWidth = max(contentWidth - containerWidth, 1)
                            return min(max(geometry.contentOffset.x / scrollableWidth, 0), 1)
                        } action: { _, progress in
                            componentScrollProgress = progress
                        }
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            pickerRow(containerWidth: proxy.size.width)
                                .background(
                                    GeometryReader { contentProxy in
                                        Color.clear.preference(
                                            key: ComponentPickerOffsetPreferenceKey.self,
                                            value: contentProxy.frame(in: .named("componentPickerScroll")).minX
                                        )
                                    }
                                )
                        }
                        .coordinateSpace(name: "componentPickerScroll")
                        .onPreferenceChange(ComponentPickerOffsetPreferenceKey.self) { minX in
                            let itemCount = CGFloat(GuideFlow.componentIntroItems.count)
                            let contentBodyWidth = itemCount * pickerCardWidth + max(itemCount - 1, 0) * pickerCardSpacing
                            let scrollableWidth = max(contentBodyWidth + AppTheme.screenPadding * 2 - proxy.size.width, 1)
                            let scrollOffset = max(-minX, 0)
                            componentScrollProgress = min(max(scrollOffset / scrollableWidth, 0), 1)
                        }
                    }
                }
            }
            .frame(height: 104)

            ComponentScrollIndicator(progress: componentScrollProgress)
                .frame(width: indicatorWidth)
        }
    }

    private func pickerRow(containerWidth: CGFloat) -> some View {
        HStack(spacing: pickerCardSpacing) {
            ForEach(GuideFlow.componentIntroItems) { item in
                ComponentIntroPickerCard(
                    item: item,
                    isSelected: item.id == selectedComponentID
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedComponentID = item.id
                    }
                }
            }
        }
        .padding(.horizontal, AppTheme.screenPadding)
        .padding(.vertical, 2)
        .frame(minWidth: containerWidth, alignment: .leading)
    }

    private var introHero: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(spacing: 8) {
                Label("准备阶段", systemImage: "book.closed.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(AppTheme.primaryText)

                Circle()
                    .fill(AppTheme.secondaryText.opacity(0.45))
                    .frame(width: 4, height: 4)

                Text("装机前先认识配件")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppTheme.secondaryText)
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .background(.white.opacity(0.78), in: Capsule())
            .overlay {
                Capsule()
                    .stroke(AppTheme.border, lineWidth: 1)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("先认识这些配件")
                    .font(.system(size: 27, weight: .black))
                    .foregroundStyle(AppTheme.primaryText)
                    .fixedSize(horizontal: false, vertical: true)

                Text("了解常见配件的外观和作用，为接下来的装机步骤打好基础。")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.secondaryText)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(width: contentWidth, alignment: .leading)
    }

    private var tipCard: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "lightbulb.fill")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(Color(red: 0.34, green: 0.54, blue: 0.94), in: Circle())

            VStack(alignment: .leading, spacing: 6) {
                Text("小贴士")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(AppTheme.primaryText)

                Text("建议先熟悉外观与名称，后续每一步都会高亮对应配件，让装机更简单。")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(AppTheme.secondaryText)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .frame(width: contentWidth, alignment: .leading)
        .background(Color(red: 0.94, green: 0.97, blue: 1.0), in: RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(red: 0.78, green: 0.87, blue: 0.98), lineWidth: 1)
        }
    }

    private var bottomActions: some View {
        HStack(spacing: 12) {
            Button {
                isShowingAllComponents = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "square.grid.2x2")
                    Text("查看全部配件")
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppTheme.primaryText)
                .frame(maxWidth: .infinity)
                .frame(height: 42)
                .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: AppTheme.controlRadius))
                .overlay {
                    RoundedRectangle(cornerRadius: AppTheme.controlRadius)
                        .stroke(AppTheme.border, lineWidth: 1)
                }
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $isShowingAllComponents) {
                ComponentIntroDetailSheet()
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }

            Button {
                withAnimation(.easeInOut(duration: 0.22)) {
                    flow.startAssembly()
                }
            } label: {
                HStack(spacing: 8) {
                    Text("开始正式装机")
                    Image(systemName: "chevron.right")
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 42)
                .background(AppTheme.primaryButton, in: RoundedRectangle(cornerRadius: AppTheme.controlRadius))
            }
            .buttonStyle(.plain)
        }
        .frame(width: contentWidth)
    }
}

private struct ComponentPickerOffsetProbe: View {
    var body: some View {
        GeometryReader { proxy in
            Color.clear.preference(
                key: ComponentPickerOffsetPreferenceKey.self,
                value: proxy.frame(in: .named("componentPickerScroll")).minX
            )
        }
    }
}

private struct ComponentPickerOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct ComponentScrollIndicator: View {
    let progress: CGFloat

    var body: some View {
        GeometryReader { proxy in
            let trackWidth = proxy.size.width
            let thumbWidth: CGFloat = 28
            let travelWidth = max(trackWidth - thumbWidth, 0)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(AppTheme.border)
                    .frame(width: trackWidth, height: 4)

                Capsule()
                    .fill(AppTheme.primaryText)
                    .frame(width: thumbWidth, height: 4)
                    .offset(x: travelWidth * progress)
                    .animation(.easeInOut(duration: 0.12), value: progress)
            }
        }
        .frame(height: 4)
    }
}

private struct ComponentIntroDetailSheet: View {
    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(GuideFlow.componentIntroItems) { item in
                        HStack(spacing: 12) {
                            Image(item.imageName)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 44, height: 44)
                                .background(AppTheme.softSurface, in: RoundedRectangle(cornerRadius: 10))

                            VStack(alignment: .leading, spacing: 3) {
                                Text(item.title)
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundStyle(AppTheme.primaryText)

                                Text(item.subtitle)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(AppTheme.secondaryText)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                } footer: {
                    Text("正式装机时会按步骤高亮当前要安装或连接的配件。")
                }
            }
            .navigationTitle("全部配件")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct ComponentIntroPickerCard: View {
    let item: GuideComponentIntroItem
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 7) {
                ZStack(alignment: .topTrailing) {
                    Image(item.imageName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 54, height: 50)
                        .padding(.top, 4)

                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 19, height: 19)
                            .background(AppTheme.primaryText, in: Circle())
                            .padding(3)
                    }
                }

                Text(item.title)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(AppTheme.primaryText)
            }
            .frame(width: 70, height: 94)
            .background(.white.opacity(0.9), in: RoundedRectangle(cornerRadius: 14))
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? AppTheme.primaryText : .white, lineWidth: isSelected ? 2 : 1)
            }
            .shadow(color: isSelected ? Color.black.opacity(0.10) : Color.black.opacity(0.04), radius: isSelected ? 12 : 8, x: 0, y: 6)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.title)，\(item.subtitle)")
    }
}

private struct ComponentIntroFeatureCard: View {
    let item: GuideComponentIntroItem

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            Image(item.imageName)
                .resizable()
                .scaledToFit()
                .frame(width: 122, height: 140)

            VStack(alignment: .leading, spacing: 9) {
                Text(item.title)
                    .font(.system(size: 24, weight: .black))
                    .foregroundStyle(AppTheme.primaryText)
                    .lineLimit(1)

                VStack(spacing: 0) {
                    ForEach(Array(item.detailPoints.enumerated()), id: \.element.id) { index, point in
                        ComponentDetailRow(point: point)

                        if index < item.detailPoints.count - 1 {
                            Divider()
                                .padding(.leading, 36)
                                .padding(.vertical, 6)
                        }
                    }
                }
            }
        }
        .padding(14)
        .frame(width: 306)
        .frame(height: 214)
        .background(.white.opacity(0.92), in: RoundedRectangle(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(.white, lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.05), radius: 14, x: 0, y: 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.title)，\(item.subtitle)")
    }
}

private struct ComponentDetailRow: View {
    let point: GuideComponentDetailPoint

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: point.symbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppTheme.primaryText)
                .frame(width: 28, height: 28)
                .background(Color(red: 0.88, green: 0.93, blue: 1.0), in: RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 3) {
                Text(point.title)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(AppTheme.primaryText)

                Text(point.text)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(AppTheme.secondaryText)
                    .lineSpacing(1)
                    .lineLimit(2)
                    .minimumScaleFactor(0.86)
                    .fixedSize(horizontal: false, vertical: true)
            }
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
