import SwiftUI
import SceneKit

struct GuideView: View {
    let onBack: () -> Void

    @State private var flow = GuideFlow()
    @State private var availableWidth: CGFloat = UIScreen.main.bounds.width

    private let canvasWidth: CGFloat = 276
    private var contentWidth: CGFloat {
        AppTheme.responsiveContentWidth(for: availableWidth)
    }

    var body: some View {
        VStack(spacing: 14) {
            ScreenHeader(title: "装机指南", trailingIcon: nil, onBack: handleBack)
                .padding(.top, 44)

            if flow.isShowingComponentIntro {
                ComponentIntroPage(flow: $flow, contentWidth: contentWidth)
            } else {
                stepHeader
                    .frame(width: contentWidth)

                ProgressTrack(flow: $flow)
                    .frame(width: contentWidth)

                AssemblyStage(step: flow.currentStep, canvasWidth: max(canvasWidth, min(contentWidth - 28, 320)))
                    .frame(maxWidth: .infinity)

                Spacer(minLength: 0)

                bottomControls
                    .frame(width: contentWidth)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 18)
        .background(widthReader)
    }

    private var widthReader: some View {
        GeometryReader { proxy in
            Color.clear
                .onAppear {
                    availableWidth = proxy.size.width
                }
                .onChange(of: proxy.size.width) { _, width in
                    availableWidth = width
                }
        }
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

    private func handleBack() {
        guard !flow.isShowingComponentIntro else {
            onBack()
            return
        }

        withAnimation(.easeInOut(duration: 0.22)) {
            flow.showComponentIntro()
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
    let contentWidth: CGFloat
    @State private var isShowingAllComponents = false
    @State private var isShowingAssemblyInstructions = false
    @State private var selectedComponentID = GuideFlow.componentIntroItems[0].id
    @State private var componentScrollProgress: CGFloat = 0

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

                ComponentIntroFeatureCard(item: selectedComponent, contentWidth: contentWidth)

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
                            let scrollableWidth = max(contentBodyWidth - proxy.size.width, 1)
                            let scrollOffset = max(-minX, 0)
                            componentScrollProgress = min(max(scrollOffset / scrollableWidth, 0), 1)
                        }
                    }
                }
            }
            .frame(height: 104)
            .frame(width: contentWidth)

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
        .padding(.horizontal, 0)
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
                isShowingAssemblyInstructions = true
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
            .sheet(isPresented: $isShowingAssemblyInstructions) {
                AssemblyInstructionSheet {
                    isShowingAssemblyInstructions = false
                    withAnimation(.easeInOut(duration: 0.22)) {
                        flow.startAssembly()
                    }
                }
                .presentationDetents([.height(300)])
                .presentationBackground(.white)
                .presentationDragIndicator(.visible)
            }
        }
        .frame(width: contentWidth)
    }
}

private struct AssemblyInstructionSheet: View {
    let onStart: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: "hand.tap.fill")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(AppTheme.primaryButton, in: Circle())

                VStack(alignment: .leading, spacing: 5) {
                    Text("正式装机教程说明")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(AppTheme.primaryText)

                    Text("每个 3D 教学步骤都需要你手动推进")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(AppTheme.secondaryText)
                }
            }
            .padding(.top, 2)

            VStack(alignment: .leading, spacing: 14) {
                instructionRow(symbol: "1.circle.fill", text: "点击 3D 画面，会播放当前步骤的一小段动画。")
                instructionRow(symbol: "pause.circle.fill", text: "动画播完会停住，方便你看清动作和配件位置。")
                instructionRow(symbol: "hand.tap.fill", text: "再次点击画面，会进入下一小段动画。")
            }
            .padding(.top, 2)

            Button(action: onStart) {
                HStack(spacing: 8) {
                    Text("知道了，开始装机")
                    Image(systemName: "chevron.right")
                }
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .background(AppTheme.primaryButton, in: RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
        .padding(.top, 22)
        .padding(.bottom, 18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.white.ignoresSafeArea())
    }

    private func instructionRow(symbol: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(AppTheme.primaryText)
                .frame(width: 18)
                .padding(.top, 1)

            Text(text)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppTheme.primaryText)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
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
    let contentWidth: CGFloat

    private var imageColumnWidth: CGFloat {
        min(max(contentWidth * 0.38, 116), 130)
    }

    private var detailColumnWidth: CGFloat {
        max(contentWidth - imageColumnWidth - 49, 142)
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack(alignment: .center) {
                Image(item.imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: imageColumnWidth - 12, height: 128)
                    .shadow(color: Color.black.opacity(0.07), radius: 8, x: 0, y: 7)
            }
            .frame(width: imageColumnWidth, height: 142, alignment: .center)

            Rectangle()
                .fill(AppTheme.border)
                .frame(width: 1, height: 132)

            VStack(alignment: .leading, spacing: 10) {
                Text(item.title)
                    .font(.system(size: 24, weight: .black))
                    .foregroundStyle(AppTheme.primaryText)
                    .lineLimit(1)
                    .frame(width: detailColumnWidth, alignment: .leading)

                VStack(spacing: 0) {
                    ForEach(Array(item.detailPoints.enumerated()), id: \.element.id) { index, point in
                        ComponentDetailRow(point: point, contentWidth: detailColumnWidth)

                        if index < item.detailPoints.count - 1 {
                            Divider()
                                .padding(.leading, 42)
                                .padding(.vertical, 7)
                        }
                    }
                }
                .frame(width: detailColumnWidth, alignment: .leading)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 15)
        .frame(width: contentWidth)
        .frame(height: 190)
        .background(.white.opacity(0.96), in: RoundedRectangle(cornerRadius: 22))
        .overlay {
            RoundedRectangle(cornerRadius: 22)
                .stroke(AppTheme.border, lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.045), radius: 18, x: 0, y: 10)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.title)，\(item.subtitle)")
    }
}

private struct ComponentDetailRow: View {
    let point: GuideComponentDetailPoint
    let contentWidth: CGFloat

    var body: some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: point.symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppTheme.primaryText)
                .frame(width: 32, height: 32)
                .background(.white, in: RoundedRectangle(cornerRadius: 9))
                .overlay {
                    RoundedRectangle(cornerRadius: 9)
                        .stroke(AppTheme.border, lineWidth: 1)
                }

            VStack(alignment: .leading, spacing: 3) {
                Text(point.title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(AppTheme.primaryText)

                Text(point.text)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(AppTheme.secondaryText)
                    .lineSpacing(1.5)
                    .lineLimit(2)
                    .minimumScaleFactor(0.84)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(width: max(contentWidth - 41, 96), alignment: .leading)
        }
        .frame(width: contentWidth, alignment: .leading)
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
    private let pseudo3DStageHeight: CGFloat = 470

    var body: some View {
        if step.id == "cpu" {
            cpuAssemblyStage
                .frame(maxWidth: .infinity)
        } else if step.id == "memory" {
            memoryAssemblyStage
                .frame(maxWidth: .infinity)
        } else if step.id == "ssd" {
            ssdAssemblyStage
                .frame(maxWidth: .infinity)
        } else {
            defaultAssemblyStage
        }
    }

    private var defaultAssemblyStage: some View {
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

    private var cpuAssemblyStage: some View {
        GeometryReader { proxy in
            let stageWidth = max(proxy.size.width, canvasWidth)
            VStack(alignment: .leading, spacing: 8) {
                CPUInstallPseudo3DStage(stageWidth: stageWidth, caution: step.caution)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(.top, 0)
        }
        .frame(height: pseudo3DStageHeight)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(step.title)，\(step.action)，注意：\(step.caution)")
    }

    private var memoryAssemblyStage: some View {
        GeometryReader { proxy in
            let stageWidth = max(proxy.size.width, canvasWidth)
            VStack(alignment: .leading, spacing: 8) {
                MemoryInstallPseudo3DStage(stageWidth: stageWidth, caution: step.caution)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(.top, 0)
        }
        .frame(height: pseudo3DStageHeight)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(step.title)，\(step.action)，注意：\(step.caution)")
    }

    private var ssdAssemblyStage: some View {
        GeometryReader { proxy in
            let stageWidth = max(proxy.size.width, canvasWidth)
            VStack(alignment: .leading, spacing: 8) {
                SSDInstallPseudo3DStage(stageWidth: stageWidth, caution: step.caution)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(.top, 0)
        }
        .frame(height: pseudo3DStageHeight)
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

private struct TutorialSceneChrome<Scene: View>: View {
    let phase: CPUInstallPhase
    let phaseIndex: Int
    let width: CGFloat
    let height: CGFloat
    let sceneOffsetY: CGFloat
    let caution: String
    @ViewBuilder let scene: () -> Scene

    var body: some View {
        ZStack(alignment: .topLeading) {
            scene()
                .frame(width: width, height: height)
                .offset(x: 12, y: sceneOffsetY)
                .shadow(color: Color.black.opacity(0.12), radius: 16, x: 0, y: 12)

            VStack(alignment: .leading, spacing: 4) {
                Text(phase.title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(AppTheme.primaryText)
                Text(phase.subtitle)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(AppTheme.primaryText)

                if !caution.isEmpty {
                    Text(caution)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(AppTheme.primaryText)
                        .padding(.top, 2)
                }
            }
            .frame(width: 178, alignment: .leading)
            .padding(.leading, 18)
            .padding(.top, 14)
        }
        .frame(width: width, height: height + sceneOffsetY)
        .clipped()
    }
}

private struct TutorialPhaseProgress: View {
    let phaseIndex: Int
    let phaseCount: Int
    let localProgress: Double

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<phaseCount, id: \.self) { index in
                Capsule()
                    .fill(index == phaseIndex ? AppTheme.primaryText : AppTheme.border)
                    .frame(width: index == phaseIndex ? 32 : 14, height: 3)
                    .opacity(index == phaseIndex ? 0.9 + 0.1 * localProgress : 1)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.white, in: RoundedRectangle(cornerRadius: 13))
        .overlay {
            RoundedRectangle(cornerRadius: 13)
                .stroke(Color.black.opacity(0.04), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 4)
    }
}

private struct CPUInstallPseudo3DStage: View {
    let stageWidth: CGFloat
    let caution: String
    @State private var phaseIndex = 0
    @State private var phaseStartDate: Date?
    @State private var completedProgress: Double = 0
    @State private var isResettingLoop = false
    private let stepDuration: TimeInterval = 1.15

    private var sceneWidth: CGFloat {
        min(max(stageWidth, 300), 346)
    }

    private var sceneHeight: CGFloat {
        min(sceneWidth * 0.80, 276)
    }

    private let sceneOffsetY: CGFloat = 72

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            let localProgress = currentProgress(at: timeline.date)
            let visiblePhaseIndex = min(phaseIndex, GuideFlow.cpuInstallPhases.count - 1)
            let phase = GuideFlow.cpuInstallPhases[visiblePhaseIndex]
            let scenePhaseIndex = isResettingLoop ? GuideFlow.cpuInstallPhases.count : phaseIndex

            VStack(spacing: 30) {
                TutorialSceneChrome(
                    phase: phase,
                    phaseIndex: visiblePhaseIndex,
                    width: sceneWidth,
                    height: sceneHeight,
                    sceneOffsetY: sceneOffsetY,
                    caution: caution
                ) {
                    CPUInstallSceneView(phaseIndex: scenePhaseIndex, localProgress: localProgress)
                }

                TutorialPhaseProgress(
                    phaseIndex: visiblePhaseIndex,
                    phaseCount: GuideFlow.cpuInstallPhases.count,
                    localProgress: localProgress
                )
            }
            .frame(width: sceneWidth, height: sceneHeight + sceneOffsetY + 70)
            .contentShape(Rectangle())
            .onTapGesture {
                advancePhase()
            }
            .onChange(of: localProgress) { _, progress in
                if phaseStartDate != nil, progress >= 1 {
                    phaseStartDate = nil
                    completedProgress = 1
                }
            }
        }
    }

    private func currentProgress(at date: Date) -> Double {
        guard let phaseStartDate else {
            return completedProgress
        }

        let raw = min(max(date.timeIntervalSince(phaseStartDate) / stepDuration, 0), 1)
        return raw * raw * (3 - 2 * raw)
    }

    private func advancePhase() {
        guard phaseStartDate == nil else { return }

        if completedProgress >= 1 {
            if isResettingLoop {
                isResettingLoop = false
                phaseIndex = 0
            } else if phaseIndex == GuideFlow.cpuInstallPhases.count - 1 {
                isResettingLoop = true
            } else {
                phaseIndex += 1
            }
            completedProgress = 0
        }

        phaseStartDate = Date()
    }
}

private struct CPUInstallSceneView: UIViewRepresentable {
    let phaseIndex: Int
    let localProgress: Double

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView(frame: .zero)
        view.backgroundColor = .clear
        view.scene = CPUInstallSceneFactory.makeScene()
        view.allowsCameraControl = false
        view.autoenablesDefaultLighting = false
        view.isUserInteractionEnabled = false
        view.preferredFramesPerSecond = 30
        view.antialiasingMode = .multisampling4X
        return view
    }

    func updateUIView(_ view: SCNView, context: Context) {
        CPUInstallSceneFactory.updateScene(view.scene, phaseIndex: phaseIndex, localProgress: localProgress)
    }
}

private struct MemoryInstallPseudo3DStage: View {
    let stageWidth: CGFloat
    let caution: String
    @State private var phaseIndex = 0
    @State private var phaseStartDate: Date?
    @State private var completedProgress: Double = 0
    @State private var isResettingLoop = false
    private let stepDuration: TimeInterval = 1.15

    private var sceneWidth: CGFloat {
        min(max(stageWidth, 300), 346)
    }

    private var sceneHeight: CGFloat {
        min(sceneWidth * 0.80, 276)
    }

    private let sceneOffsetY: CGFloat = 72

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            let localProgress = currentProgress(at: timeline.date)
            let visiblePhaseIndex = min(phaseIndex, GuideFlow.memoryInstallPhases.count - 1)
            let phase = GuideFlow.memoryInstallPhases[visiblePhaseIndex]
            let scenePhaseIndex = isResettingLoop ? GuideFlow.memoryInstallPhases.count : phaseIndex

            VStack(spacing: 34) {
                TutorialSceneChrome(
                    phase: phase,
                    phaseIndex: visiblePhaseIndex,
                    width: sceneWidth,
                    height: sceneHeight,
                    sceneOffsetY: sceneOffsetY,
                    caution: caution
                ) {
                    MemoryInstallSceneView(phaseIndex: scenePhaseIndex, localProgress: localProgress)
                }

                TutorialPhaseProgress(
                    phaseIndex: visiblePhaseIndex,
                    phaseCount: GuideFlow.memoryInstallPhases.count,
                    localProgress: localProgress
                )
            }
            .frame(width: sceneWidth, height: sceneHeight + sceneOffsetY + 78)
            .contentShape(Rectangle())
            .onTapGesture {
                advancePhase()
            }
            .onChange(of: localProgress) { _, progress in
                if phaseStartDate != nil, progress >= 1 {
                    phaseStartDate = nil
                    completedProgress = 1
                }
            }
        }
    }

    private func currentProgress(at date: Date) -> Double {
        guard let phaseStartDate else {
            return completedProgress
        }

        let raw = min(max(date.timeIntervalSince(phaseStartDate) / stepDuration, 0), 1)
        return raw * raw * (3 - 2 * raw)
    }

    private func advancePhase() {
        guard phaseStartDate == nil else { return }

        if completedProgress >= 1 {
            if isResettingLoop {
                isResettingLoop = false
                phaseIndex = 0
            } else if phaseIndex == GuideFlow.memoryInstallPhases.count - 1 {
                isResettingLoop = true
            } else {
                phaseIndex += 1
            }
            completedProgress = 0
        }

        phaseStartDate = Date()
    }
}

private struct MemoryInstallSceneView: UIViewRepresentable {
    let phaseIndex: Int
    let localProgress: Double

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView(frame: .zero)
        view.backgroundColor = .clear
        view.scene = MemoryInstallSceneFactory.makeScene()
        view.allowsCameraControl = false
        view.autoenablesDefaultLighting = false
        view.isUserInteractionEnabled = false
        view.preferredFramesPerSecond = 30
        view.antialiasingMode = .multisampling4X
        return view
    }

    func updateUIView(_ view: SCNView, context: Context) {
        MemoryInstallSceneFactory.updateScene(view.scene, phaseIndex: phaseIndex, localProgress: localProgress)
    }
}

private struct SSDInstallPseudo3DStage: View {
    let stageWidth: CGFloat
    let caution: String
    @State private var phaseIndex = 0
    @State private var phaseStartDate: Date?
    @State private var completedProgress: Double = 0
    private let stepDuration: TimeInterval = 1.35

    private var sceneWidth: CGFloat {
        min(max(stageWidth, 300), 346)
    }

    private var sceneHeight: CGFloat {
        min(sceneWidth * 0.80, 276)
    }

    private let sceneOffsetY: CGFloat = 72

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            let localProgress = currentProgress(at: timeline.date)
            let phase = GuideFlow.ssdInstallPhases[phaseIndex]

            VStack(spacing: 34) {
                TutorialSceneChrome(
                    phase: phase,
                    phaseIndex: phaseIndex,
                    width: sceneWidth,
                    height: sceneHeight,
                    sceneOffsetY: sceneOffsetY,
                    caution: caution
                ) {
                    SSDInstallSceneView(phaseIndex: phaseIndex, localProgress: localProgress)
                }

                TutorialPhaseProgress(
                    phaseIndex: phaseIndex,
                    phaseCount: GuideFlow.ssdInstallPhases.count,
                    localProgress: localProgress
                )
            }
            .frame(width: sceneWidth, height: sceneHeight + sceneOffsetY + 78)
            .contentShape(Rectangle())
            .onTapGesture {
                advancePhase()
            }
            .onChange(of: localProgress) { _, progress in
                if phaseStartDate != nil, progress >= 1 {
                    phaseStartDate = nil
                    completedProgress = 1
                }
            }
        }
    }

    private func currentProgress(at date: Date) -> Double {
        guard let phaseStartDate else {
            return completedProgress
        }

        let raw = min(max(date.timeIntervalSince(phaseStartDate) / stepDuration, 0), 1)
        return raw * raw * (3 - 2 * raw)
    }

    private func advancePhase() {
        guard phaseStartDate == nil else { return }

        if completedProgress >= 1 {
            phaseIndex = (phaseIndex + 1) % GuideFlow.ssdInstallPhases.count
            completedProgress = 0
        }

        phaseStartDate = Date()
    }
}

private struct SSDInstallSceneView: UIViewRepresentable {
    let phaseIndex: Int
    let localProgress: Double

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView(frame: .zero)
        view.backgroundColor = .clear
        view.scene = SSDInstallSceneFactory.makeScene()
        view.allowsCameraControl = false
        view.autoenablesDefaultLighting = false
        view.isUserInteractionEnabled = false
        view.preferredFramesPerSecond = 30
        view.antialiasingMode = .multisampling4X
        return view
    }

    func updateUIView(_ view: SCNView, context: Context) {
        SSDInstallSceneFactory.updateScene(view.scene, phaseIndex: phaseIndex, localProgress: localProgress)
    }
}

private enum TutorialSceneLighting {
    static func install(in scene: SCNScene, keyIntensity: CGFloat, keyAngles: SCNVector3) {
        scene.lightingEnvironment.contents = UIColor(white: 0.82, alpha: 1)
        scene.lightingEnvironment.intensity = 0.56

        let ambient = SCNNode()
        let ambientLight = SCNLight()
        ambientLight.type = .ambient
        ambientLight.intensity = 210
        ambientLight.color = UIColor(red: 0.82, green: 0.87, blue: 0.92, alpha: 1)
        ambient.light = ambientLight
        scene.rootNode.addChildNode(ambient)

        let key = SCNNode()
        let keyLight = SCNLight()
        keyLight.type = .directional
        keyLight.intensity = keyIntensity
        keyLight.color = UIColor(red: 1.0, green: 0.96, blue: 0.90, alpha: 1)
        keyLight.castsShadow = true
        keyLight.shadowRadius = 10
        keyLight.shadowSampleCount = 16
        keyLight.shadowMapSize = CGSize(width: 1024, height: 1024)
        keyLight.shadowColor = UIColor.black.withAlphaComponent(0.34)
        key.light = keyLight
        key.eulerAngles = keyAngles
        scene.rootNode.addChildNode(key)

        let fill = SCNNode()
        let fillLight = SCNLight()
        fillLight.type = .omni
        fillLight.intensity = 260
        fillLight.color = UIColor(red: 0.62, green: 0.78, blue: 1.0, alpha: 1)
        fill.light = fillLight
        fill.position = SCNVector3(-2.8, 2.8, 2.4)
        scene.rootNode.addChildNode(fill)

        let rim = SCNNode()
        let rimLight = SCNLight()
        rimLight.type = .omni
        rimLight.intensity = 190
        rimLight.color = UIColor(red: 1.0, green: 0.78, blue: 0.58, alpha: 1)
        rim.light = rimLight
        rim.position = SCNVector3(2.8, 1.8, -2.6)
        scene.rootNode.addChildNode(rim)
    }

    static func configure(
        _ material: SCNMaterial,
        color: UIColor,
        roughness: CGFloat,
        metalness: CGFloat,
        emission: UIColor? = nil
    ) {
        material.lightingModel = .physicallyBased
        material.diffuse.contents = color
        material.roughness.contents = roughness
        material.metalness.contents = metalness
        material.ambientOcclusion.contents = UIColor(white: 0.72, alpha: 1)
        material.clearCoat.contents = metalness > 0.25 ? 0.16 : 0.05
        material.clearCoatRoughness.contents = min(roughness + 0.12, 1)
        material.isDoubleSided = true

        if let emission {
            material.emission.contents = emission
            material.emission.intensity = 0.35
        }
    }
}

private enum SSDInstallSceneFactory {
    private static let cameraName = "ssd-camera"
    private static let ssdName = "ssd-module"
    private static let heatsinkName = "ssd-heatsink"
    private static let screwName = "ssd-screw"
    private static let filmName = "ssd-film"
    private static let alignCueName = "ssd-align-cue"
    private static let pressCueName = "ssd-press-cue"

    static func makeScene() -> SCNScene {
        let scene = SCNScene()
        scene.background.contents = UIColor.clear

        let cameraNode = SCNNode()
        let camera = SCNCamera()
        camera.fieldOfView = 34
        camera.zNear = 0.1
        camera.zFar = 100
        cameraNode.name = cameraName
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(0.12, 3.35, 3.75)
        cameraNode.eulerAngles = SCNVector3(-0.66, 0.02, 0)
        scene.rootNode.addChildNode(cameraNode)

        TutorialSceneLighting.install(in: scene, keyIntensity: 980, keyAngles: SCNVector3(-0.72, 0.32, -0.24))

        scene.rootNode.addChildNode(makeBoard())
        scene.rootNode.addChildNode(makeSSD())
        scene.rootNode.addChildNode(makeHeatsink())
        scene.rootNode.addChildNode(makeScrew())
        scene.rootNode.addChildNode(makeAlignCue())
        scene.rootNode.addChildNode(makePressCue())

        return scene
    }

    static func updateScene(_ scene: SCNScene?, phaseIndex: Int, localProgress: Double) {
        guard let scene else { return }
        let progress = CGFloat(localProgress)

        updateCamera(in: scene, phaseIndex: phaseIndex, progress: progress)

        let ssd = scene.rootNode.childNode(withName: ssdName, recursively: true)
        ssd?.position = ssdPosition(phaseIndex: phaseIndex, progress: progress)
        ssd?.eulerAngles = ssdAngles(phaseIndex: phaseIndex, progress: progress)
        ssd?.opacity = ssdOpacity(phaseIndex: phaseIndex, progress: progress)

        let heatsink = scene.rootNode.childNode(withName: heatsinkName, recursively: true)
        heatsink?.position = heatsinkPosition(phaseIndex: phaseIndex, progress: progress)
        heatsink?.opacity = heatsinkOpacity(phaseIndex: phaseIndex, progress: progress)

        let screw = scene.rootNode.childNode(withName: screwName, recursively: true)
        screw?.position = screwPosition(phaseIndex: phaseIndex, progress: progress)
        screw?.opacity = screwOpacity(phaseIndex: phaseIndex, progress: progress)

        let film = scene.rootNode.childNode(withName: filmName, recursively: true)
        film?.position = filmPosition(phaseIndex: phaseIndex, progress: progress)
        film?.opacity = filmOpacity(phaseIndex: phaseIndex, progress: progress)

        scene.rootNode.childNode(withName: alignCueName, recursively: true)?.opacity = phaseIndex == 1 ? Double(0.45 + 0.45 * sin(progress * .pi)) : 0
        scene.rootNode.childNode(withName: pressCueName, recursively: true)?.opacity = phaseIndex == 3 ? Double(0.35 + 0.45 * sin(progress * .pi)) : 0
    }

    private static func makeBoard() -> SCNNode {
        let board = SCNNode()

        let base = boxNode(width: 3.8, height: 0.08, length: 4.6, radius: 0.06, material: material(UIColor(red: 0.06, green: 0.075, blue: 0.085, alpha: 1), roughness: 0.72, metalness: 0.15))
        board.addChildNode(base)

        let m2SlotMaterial = material(UIColor(red: 0.56, green: 0.58, blue: 0.56, alpha: 1), roughness: 0.54, metalness: 0.26)
        let m2Slot = boxNode(width: 0.32, height: 0.08, length: 0.66, radius: 0.025, material: m2SlotMaterial)
        m2Slot.position = SCNVector3(1.03, 0.135, -0.22)
        board.addChildNode(m2Slot)

        let socketLowerLip = boxNode(width: 0.08, height: 0.10, length: 0.66, radius: 0.014, material: m2SlotMaterial)
        socketLowerLip.position = SCNVector3(0.88, 0.205, -0.22)
        board.addChildNode(socketLowerLip)

        let socketUpperLip = boxNode(width: 0.24, height: 0.07, length: 0.66, radius: 0.014, material: m2SlotMaterial)
        socketUpperLip.position = SCNVector3(0.95, 0.285, -0.22)
        board.addChildNode(socketUpperLip)

        let socketOpening = boxNode(width: 0.028, height: 0.07, length: 0.50, radius: 0.008, material: material(UIColor(red: 0.03, green: 0.035, blue: 0.04, alpha: 1), roughness: 0.7, metalness: 0.12))
        socketOpening.position = SCNVector3(0.84, 0.245, -0.22)
        board.addChildNode(socketOpening)

        let keyBlock = boxNode(width: 0.04, height: 0.085, length: 0.09, radius: 0.006, material: material(UIColor(red: 0.36, green: 0.38, blue: 0.36, alpha: 1), roughness: 0.56, metalness: 0.20))
        keyBlock.position = SCNVector3(0.82, 0.25, -0.05)
        board.addChildNode(keyBlock)

        let contactMaterial = material(UIColor(red: 0.72, green: 0.70, blue: 0.62, alpha: 1), roughness: 0.42, metalness: 0.52)
        for side in [-1, 1] {
            for index in 0..<6 {
                let contact = boxNode(width: 0.018, height: 0.020, length: 0.034, radius: 0.002, material: contactMaterial)
                contact.position = SCNVector3(0.875 + Float(side) * 0.024, 0.245, -0.405 + Float(index) * 0.073)
                board.addChildNode(contact)
            }
        }

        let standoff = cylinderNode(radius: 0.09, height: 0.16, material: material(UIColor(red: 0.68, green: 0.66, blue: 0.58, alpha: 1), roughness: 0.42, metalness: 0.58))
        standoff.position = SCNVector3(-0.74, 0.16, -0.22)
        board.addChildNode(standoff)

        let lane = boxNode(width: 2.18, height: 0.018, length: 0.50, radius: 0.025, material: material(UIColor(red: 0.12, green: 0.14, blue: 0.15, alpha: 1), roughness: 0.62, metalness: 0.12))
        lane.position = SCNVector3(0.03, 0.095, -0.22)
        board.addChildNode(lane)

        for index in 0..<5 {
            let capacitor = cylinderNode(radius: 0.065, height: 0.18, material: material(UIColor(red: 0.18, green: 0.19, blue: 0.20, alpha: 1), roughness: 0.55, metalness: 0.45))
            capacitor.position = SCNVector3(-1.55 + Float(index) * 0.25, 0.18, -1.05)
            board.addChildNode(capacitor)
        }

        return board
    }

    private static func makeSSD() -> SCNNode {
        let ssd = SCNNode()
        ssd.name = ssdName

        let pcb = boxNode(width: 1.92, height: 0.055, length: 0.44, radius: 0.025, material: material(UIColor(red: 0.06, green: 0.34, blue: 0.25, alpha: 1), roughness: 0.62, metalness: 0.08))
        ssd.addChildNode(pcb)

        for index in 0..<3 {
            let chip = boxNode(width: 0.34, height: 0.07, length: 0.28, radius: 0.025, material: material(UIColor(red: 0.08, green: 0.09, blue: 0.10, alpha: 1), roughness: 0.50, metalness: 0.24))
            chip.position = SCNVector3(0.18 - Float(index) * 0.42, 0.055, 0.0)
            ssd.addChildNode(chip)
        }

        let contactMaterial = material(UIColor(red: 0.92, green: 0.62, blue: 0.30, alpha: 1), roughness: 0.34, metalness: 0.44)
        for index in 0..<6 {
            let contact = boxNode(width: 0.075, height: 0.018, length: 0.05, radius: 0.004, material: contactMaterial)
            contact.position = SCNVector3(0.78, 0.032, -0.15 + Float(index) * 0.06)
            ssd.addChildNode(contact)
        }

        let notch = boxNode(width: 0.10, height: 0.024, length: 0.14, radius: 0.006, material: material(UIColor(red: 0.04, green: 0.10, blue: 0.08, alpha: 1), roughness: 0.7, metalness: 0.04))
        notch.position = SCNVector3(0.59, 0.038, -0.13)
        ssd.addChildNode(notch)

        let screwHole = cylinderNode(radius: 0.055, height: 0.018, material: material(UIColor(red: 0.03, green: 0.05, blue: 0.05, alpha: 1), roughness: 0.55, metalness: 0.20))
        screwHole.position = SCNVector3(-0.86, 0.055, 0)
        ssd.addChildNode(screwHole)

        ssd.position = ssdPosition(phaseIndex: 0, progress: 0)
        ssd.eulerAngles = ssdAngles(phaseIndex: 0, progress: 0)
        return ssd
    }

    private static func makeHeatsink() -> SCNNode {
        let heatsink = SCNNode()
        heatsink.name = heatsinkName

        let body = boxNode(width: 2.28, height: 0.13, length: 0.62, radius: 0.05, material: material(UIColor(red: 0.16, green: 0.17, blue: 0.18, alpha: 1), roughness: 0.36, metalness: 0.48))
        heatsink.addChildNode(body)

        for index in 0..<5 {
            let groove = boxNode(width: 0.08, height: 0.025, length: 0.68, radius: 0.01, material: material(UIColor(red: 0.29, green: 0.30, blue: 0.31, alpha: 1), roughness: 0.46, metalness: 0.32))
            groove.position = SCNVector3(-0.72 + Float(index) * 0.36, 0.075, 0)
            heatsink.addChildNode(groove)
        }

        let film = boxNode(width: 2.05, height: 0.018, length: 0.42, radius: 0.015, material: material(UIColor(red: 0.52, green: 0.78, blue: 1.0, alpha: 0.78), roughness: 0.2, metalness: 0.0))
        film.name = filmName
        film.position = SCNVector3(0, -0.09, 0)
        heatsink.addChildNode(film)

        heatsink.position = heatsinkPosition(phaseIndex: 0, progress: 0)
        return heatsink
    }

    private static func makeScrew() -> SCNNode {
        let screw = cylinderNode(radius: 0.055, height: 0.055, material: material(UIColor(red: 0.70, green: 0.70, blue: 0.66, alpha: 1), roughness: 0.38, metalness: 0.72))
        screw.name = screwName
        screw.position = screwPosition(phaseIndex: 0, progress: 0)
        return screw
    }

    private static func makeAlignCue() -> SCNNode {
        let group = SCNNode()
        group.name = alignCueName
        group.opacity = 0
        let cueMaterial = material(UIColor(red: 1.0, green: 0.55, blue: 0.12, alpha: 1), roughness: 0.34, metalness: 0.08)

        let slotCue = boxNode(width: 0.16, height: 0.025, length: 0.42, radius: 0.012, material: cueMaterial)
        slotCue.position = SCNVector3(0.84, 0.34, -0.22)
        group.addChildNode(slotCue)

        let ssdCue = boxNode(width: 0.16, height: 0.025, length: 0.26, radius: 0.012, material: cueMaterial)
        ssdCue.position = SCNVector3(0.30, 0.74, -0.34)
        group.addChildNode(ssdCue)

        let connector = cylinderNode(radius: 0.012, height: 0.50, material: cueMaterial)
        connector.position = SCNVector3(0.57, 0.54, -0.28)
        group.addChildNode(connector)

        return group
    }

    private static func makePressCue() -> SCNNode {
        let group = SCNNode()
        group.name = pressCueName
        group.opacity = 0
        let cueMaterial = material(UIColor(red: 0.20, green: 0.58, blue: 1.0, alpha: 1), roughness: 0.36, metalness: 0)

        let highlight = boxNode(width: 0.30, height: 0.025, length: 0.34, radius: 0.018, material: cueMaterial)
        highlight.position = SCNVector3(-0.74, 0.52, -0.22)
        group.addChildNode(highlight)

        let arrow = coneNode(topRadius: 0, bottomRadius: 0.08, height: 0.18, material: cueMaterial)
        arrow.eulerAngles = SCNVector3(Float.pi, 0, 0)
        arrow.position = SCNVector3(-0.74, 0.80, -0.22)
        group.addChildNode(arrow)

        return group
    }

    private static func updateCamera(in scene: SCNScene, phaseIndex: Int, progress: CGFloat) {
        guard let cameraNode = scene.rootNode.childNode(withName: cameraName, recursively: true) else { return }

        let closePosition = SCNVector3(0.02, 3.05, 3.35)
        let closeAngles = SCNVector3(-0.66, 0.02, 0)
        let slotPosition = SCNVector3(0.26, 2.70, 2.85)
        let slotAngles = SCNVector3(-0.62, -0.04, 0)
        let insertPosition = SCNVector3(0.34, 2.86, 3.10)
        let insertAngles = SCNVector3(-0.64, -0.02, 0)
        let widePosition = SCNVector3(0.18, 3.45, 3.90)
        let wideAngles = SCNVector3(-0.68, 0.02, 0)

        let position: SCNVector3
        let angles: SCNVector3
        switch phaseIndex {
        case 1:
            let cameraProgress = easeHold(progress, startHold: 0.10, endHold: 0.10)
            position = mix(closePosition, slotPosition, cameraProgress)
            angles = mix(closeAngles, slotAngles, cameraProgress)
        case 2:
            let cameraProgress = easeHold(progress, startHold: 0.08, endHold: 0.16)
            position = mix(slotPosition, insertPosition, cameraProgress)
            angles = mix(slotAngles, insertAngles, cameraProgress)
        case 3:
            let cameraProgress = easeHold(progress, startHold: 0.14, endHold: 0.08)
            position = mix(insertPosition, widePosition, cameraProgress)
            angles = mix(insertAngles, wideAngles, cameraProgress)
        case 4:
            let cameraProgress = easeHold(progress, startHold: 0.12, endHold: 0.16)
            position = mix(widePosition, SCNVector3(0.12, 3.34, 3.76), cameraProgress)
            angles = mix(wideAngles, SCNVector3(-0.67, 0.02, 0), cameraProgress)
        default:
            position = closePosition
            angles = closeAngles
        }

        cameraNode.position = position
        cameraNode.eulerAngles = angles
    }

    private static func ssdPosition(phaseIndex: Int, progress: CGFloat) -> SCNVector3 {
        switch phaseIndex {
        case 0:
            return SCNVector3(0.20, 1.28, -1.28)
        case 1:
            let eased = easeHold(progress, startHold: 0.08, endHold: 0.14)
            return mix(SCNVector3(0.20, 1.28, -1.28), SCNVector3(-0.24, 0.90, -0.34), eased)
        case 2:
            let eased = easeHold(progress, startHold: 0.14, endHold: 0.18)
            return mix(SCNVector3(-0.24, 0.90, -0.34), SCNVector3(0.06, 0.55, -0.22), eased)
        case 3:
            let eased = easeHold(progress, startHold: 0.10, endHold: 0.12)
            return mix(SCNVector3(0.06, 0.55, -0.22), SCNVector3(0.12, 0.18, -0.22), eased)
        default:
            return SCNVector3(0.12, 0.18, -0.22)
        }
    }

    private static func ssdAngles(phaseIndex: Int, progress: CGFloat) -> SCNVector3 {
        let angled = SCNVector3(0, 0, -0.42)
        switch phaseIndex {
        case 0, 1, 2:
            return angled
        case 3:
            let eased = easeHold(progress, startHold: 0.10, endHold: 0.12)
            return mix(angled, SCNVector3Zero, eased)
        default:
            return SCNVector3Zero
        }
    }

    private static func ssdOpacity(phaseIndex: Int, progress: CGFloat) -> Double {
        if phaseIndex == 0 {
            return 0
        }
        if phaseIndex == 1 {
            return Double(min(max(progress * 1.8, 0), 1))
        }
        return 1
    }

    private static func heatsinkPosition(phaseIndex: Int, progress: CGFloat) -> SCNVector3 {
        let installed = SCNVector3(0.08, 0.60, -0.22)
        let removed = SCNVector3(-0.62, 1.10, -1.06)
        switch phaseIndex {
        case 0:
            return mix(installed, removed, easeHold(progress, startHold: 0.08, endHold: 0.12))
        case 4:
            let delayed = easeHold(progress, startHold: 0.28, endHold: 0.10)
            return mix(removed, installed, delayed)
        default:
            return removed
        }
    }

    private static func heatsinkOpacity(phaseIndex: Int, progress: CGFloat) -> Double {
        if phaseIndex == 0 || phaseIndex == 4 { return 1 }
        return 0.72
    }

    private static func screwPosition(phaseIndex: Int, progress: CGFloat) -> SCNVector3 {
        let fixed = SCNVector3(-0.74, 0.35, -0.22)
        let raised = SCNVector3(-0.74, 0.94, -0.22)
        switch phaseIndex {
        case 0:
            return mix(fixed, raised, easeHold(progress, startHold: 0.04, endHold: 0.18))
        case 3:
            return mix(raised, fixed, easeHold(progress, startHold: 0.18, endHold: 0.10))
        default:
            return phaseIndex < 3 ? raised : fixed
        }
    }

    private static func screwOpacity(phaseIndex: Int, progress: CGFloat) -> Double {
        if phaseIndex == 4 { return 0.35 }
        return 1
    }

    private static func filmPosition(phaseIndex: Int, progress: CGFloat) -> SCNVector3 {
        if phaseIndex == 4 {
            let peel = smoothStep(min(max(progress / 0.38, 0), 1))
            return SCNVector3(0.34 + Float(peel) * 0.42, -0.09 + Float(peel) * 0.24, 0.16 + Float(peel) * 0.22)
        }
        return SCNVector3(0, -0.09, 0)
    }

    private static func filmOpacity(phaseIndex: Int, progress: CGFloat) -> Double {
        if phaseIndex == 4 {
            return max(0, 1 - Double(progress) * 1.8)
        }
        return phaseIndex == 0 ? 1 : 0.85
    }

    private static func mix(_ start: SCNVector3, _ end: SCNVector3, _ progress: CGFloat) -> SCNVector3 {
        let t = Float(progress)
        return SCNVector3(start.x + (end.x - start.x) * t, start.y + (end.y - start.y) * t, start.z + (end.z - start.z) * t)
    }

    private static func smoothStep(_ value: CGFloat) -> CGFloat {
        value * value * (3 - 2 * value)
    }

    private static func easeHold(_ value: CGFloat, startHold: CGFloat, endHold: CGFloat) -> CGFloat {
        let available = max(1 - startHold - endHold, 0.001)
        let normalized = min(max((value - startHold) / available, 0), 1)
        return normalized * normalized * normalized * (normalized * (normalized * 6 - 15) + 10)
    }

    private static func boxNode(width: CGFloat, height: CGFloat, length: CGFloat, radius: CGFloat, material: SCNMaterial) -> SCNNode {
        let box = SCNBox(width: width, height: height, length: length, chamferRadius: radius)
        box.materials = [material]
        return SCNNode(geometry: box)
    }

    private static func cylinderNode(radius: CGFloat, height: CGFloat, material: SCNMaterial) -> SCNNode {
        let cylinder = SCNCylinder(radius: radius, height: height)
        cylinder.radialSegmentCount = 18
        cylinder.materials = [material]
        return SCNNode(geometry: cylinder)
    }

    private static func coneNode(topRadius: CGFloat, bottomRadius: CGFloat, height: CGFloat, material: SCNMaterial) -> SCNNode {
        let cone = SCNCone(topRadius: topRadius, bottomRadius: bottomRadius, height: height)
        cone.radialSegmentCount = 18
        cone.materials = [material]
        return SCNNode(geometry: cone)
    }

    private static func material(_ color: UIColor, roughness: CGFloat = 0.6, metalness: CGFloat = 0.0) -> SCNMaterial {
        let material = SCNMaterial()
        TutorialSceneLighting.configure(material, color: color, roughness: roughness, metalness: metalness)
        return material
    }
}

private enum MemoryInstallSceneFactory {
    private static let cameraName = "memory-camera"
    private static let firstStickName = "first-memory-stick"
    private static let secondStickName = "second-memory-stick"
    private static let targetGlowName = "memory-target-glow"
    private static let ramNotchCueName = "memory-ram-notch-cue"
    private static let slotNotchCueName = "memory-slot-notch-cue"
    private static let pressCueName = "memory-press-cue"
    private static let latchPrefix = "memory-latch-"

    static func makeScene() -> SCNScene {
        let scene = SCNScene()
        scene.background.contents = UIColor.clear

        let cameraNode = SCNNode()
        let camera = SCNCamera()
        camera.zNear = 0.1
        camera.zFar = 100
        camera.fieldOfView = 26
        cameraNode.name = cameraName
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(1.10, 2.20, 2.58)
        cameraNode.eulerAngles = SCNVector3(-0.56, 0.10, 0.0)
        scene.rootNode.addChildNode(cameraNode)

        TutorialSceneLighting.install(in: scene, keyIntensity: 1_000, keyAngles: SCNVector3(-0.72, 0.30, -0.25))

        scene.rootNode.addChildNode(makeBoard())
        scene.rootNode.addChildNode(makeMemoryStick(name: firstStickName))
        scene.rootNode.addChildNode(makeMemoryStick(name: secondStickName))
        scene.rootNode.addChildNode(makeRamNotchCues())
        scene.rootNode.addChildNode(makeSlotNotchCues())
        scene.rootNode.addChildNode(makePressCues())

        return scene
    }

    static func updateScene(_ scene: SCNScene?, phaseIndex: Int, localProgress: Double) {
        guard let scene else { return }
        let progress = CGFloat(localProgress)
        updateCamera(in: scene, phaseIndex: phaseIndex, progress: progress)
        scene.rootNode.childNode(withName: firstStickName, recursively: true)?.position = firstStickPosition(phaseIndex: phaseIndex, progress: progress)
        scene.rootNode.childNode(withName: secondStickName, recursively: true)?.position = secondStickPosition(phaseIndex: phaseIndex, progress: progress)
        scene.rootNode.childNode(withName: ramNotchCueName, recursively: true)?.opacity = phaseIndex == 1 ? Double(0.50 + 0.36 * sin(progress * .pi)) : 0
        scene.rootNode.childNode(withName: slotNotchCueName, recursively: true)?.opacity = phaseIndex == 2 ? Double(0.48 + 0.40 * sin(progress * .pi)) : 0
        updateRamNotchCue(in: scene, phaseIndex: phaseIndex, progress: progress)
        updatePressCue(in: scene, phaseIndex: phaseIndex, progress: progress)

        scene.rootNode.childNode(withName: firstStickName, recursively: true)?.eulerAngles = firstStickAngles(phaseIndex: phaseIndex, progress: progress)
        scene.rootNode.childNode(withName: secondStickName, recursively: true)?.eulerAngles = secondStickAngles(phaseIndex: phaseIndex, progress: progress)

        scene.rootNode.childNode(withName: targetGlowName, recursively: true)?.opacity = phaseIndex == 0 ? 0.55 + 0.25 * Double(sin(progress * .pi)) : 0.22

        for slot in [1, 3] {
            let openAmount = latchOpenAmount(slot: slot, phaseIndex: phaseIndex, progress: progress)
            for end in 0..<2 {
                let node = scene.rootNode.childNode(withName: "\(latchPrefix)\(slot)-\(end)", recursively: true)
                node?.eulerAngles = SCNVector3(openAmount * (end == 0 ? -0.78 : 0.78), 0, 0)
            }
        }
    }

    private static func updateCamera(in scene: SCNScene, phaseIndex: Int, progress: CGFloat) {
        guard let cameraNode = scene.rootNode.childNode(withName: cameraName, recursively: true) else { return }

        let inspectPosition = SCNVector3(1.02, 2.02, 2.22)
        let inspectAngles = SCNVector3(-0.48, 0.04, 0.0)
        let alignPosition = SCNVector3(0.96, 2.10, 2.42)
        let alignAngles = SCNVector3(-0.54, 0.07, 0.0)
        let installPosition = SCNVector3(1.02, 2.16, 2.64)
        let installAngles = SCNVector3(-0.57, 0.08, 0.0)
        let completedPosition = SCNVector3(1.10, 2.20, 2.58)
        let completedAngles = SCNVector3(-0.56, 0.10, 0.0)
        let closePosition: SCNVector3
        let closeAngles: SCNVector3
        if phaseIndex == 1 {
            let startPosition = SCNVector3(1.10, 2.20, 2.58)
            let startAngles = SCNVector3(-0.56, 0.10, 0.0)
            let blendIn = min(progress * 0.8, 1)
            closePosition = mix(startPosition, inspectPosition, blendIn)
            closeAngles = mix(startAngles, inspectAngles, blendIn)
        } else if phaseIndex == 2 {
            closePosition = mix(inspectPosition, alignPosition, 0.35 + progress * 0.65)
            closeAngles = mix(inspectAngles, alignAngles, 0.35 + progress * 0.65)
        } else if phaseIndex == 3 {
            closePosition = mix(alignPosition, installPosition, min(progress * 1.2, 1))
            closeAngles = mix(alignAngles, installAngles, min(progress * 1.2, 1))
        } else if phaseIndex == 4 {
            let cameraProgress = smoothStep(min(max((progress - 0.18) / 0.74, 0), 1))
            closePosition = mix(installPosition, completedPosition, cameraProgress)
            closeAngles = mix(installAngles, completedAngles, cameraProgress)
        } else if phaseIndex == 5 {
            let resetProgress = smoothStep(progress)
            closePosition = mix(completedPosition, completedPosition, resetProgress)
            closeAngles = mix(completedAngles, completedAngles, resetProgress)
        } else {
            closePosition = completedPosition
            closeAngles = completedAngles
        }
        let widePosition = SCNVector3(0.0, 4.65, 5.35)
        let wideAngles = SCNVector3(-0.72, 0.0, 0.0)

        let blend: CGFloat
        if phaseIndex <= 2 {
            blend = 0
        } else if phaseIndex == 3 {
            blend = min(max((progress - 0.28) * 1.15, 0), 1)
        } else if phaseIndex == 4 {
            blend = 1 - 0.22 * (1 - smoothStep(min(max((progress - 0.18) / 0.74, 0), 1)))
        } else if phaseIndex == 5 {
            blend = 1 - smoothStep(progress)
        } else {
            blend = 1
        }

        cameraNode.position = mix(closePosition, widePosition, blend)
        cameraNode.eulerAngles = mix(closeAngles, wideAngles, blend)
        cameraNode.camera?.fieldOfView = 26 + Double(blend) * 14
    }

    private static func updatePressCue(in scene: SCNScene, phaseIndex: Int, progress: CGFloat) {
        guard let pressCue = scene.rootNode.childNode(withName: pressCueName, recursively: true) else { return }
        guard phaseIndex == 4 else {
            pressCue.opacity = 0
            pressCue.position = SCNVector3Zero
            return
        }

        let fadeIn = min(progress / 0.18, 1)
        let fadeOut = min(max((0.72 - progress) / 0.24, 0), 1)
        let opacity = max(min(fadeIn, fadeOut), 0)
        pressCue.opacity = Double(opacity)
        let pressProgress = smoothStep(min(max(progress / 0.72, 0), 1))
        pressCue.position = SCNVector3(0, -0.16 * Float(pressProgress), 0)
    }

    private static func updateRamNotchCue(in scene: SCNScene, phaseIndex: Int, progress: CGFloat) {
        let positions = [
            firstStickPosition(phaseIndex: phaseIndex, progress: progress),
            secondStickPosition(phaseIndex: phaseIndex, progress: progress)
        ]

        for index in 0..<2 {
            let cue = scene.rootNode.childNode(withName: "\(ramNotchCueName)-\(index)", recursively: true)
            cue?.position = SCNVector3(positions[index].x, positions[index].y - 0.24, positions[index].z - 0.13)
        }
    }

    private static func makeBoard() -> SCNNode {
        let board = SCNNode()

        let base = boxNode(
            width: 3.8,
            height: 0.08,
            length: 4.6,
            radius: 0.06,
            material: material(UIColor(red: 0.06, green: 0.075, blue: 0.085, alpha: 1), roughness: 0.72, metalness: 0.15)
        )
        base.position = SCNVector3(0, 0, 0)
        board.addChildNode(base)

        let cpuSocket = boxNode(width: 1.06, height: 0.11, length: 1.06, radius: 0.05, material: material(UIColor(red: 0.34, green: 0.36, blue: 0.36, alpha: 1), roughness: 0.70, metalness: 0.10))
        cpuSocket.position = SCNVector3(-0.54, 0.14, -0.58)
        board.addChildNode(cpuSocket)

        let cpuPlate = boxNode(width: 0.74, height: 0.09, length: 0.74, radius: 0.045, material: material(UIColor(red: 0.72, green: 0.74, blue: 0.70, alpha: 1), roughness: 0.44, metalness: 0.35))
        cpuPlate.position = SCNVector3(-0.54, 0.24, -0.58)
        board.addChildNode(cpuPlate)

        let slotMaterial = material(UIColor(red: 0.10, green: 0.11, blue: 0.12, alpha: 1), roughness: 0.65, metalness: 0.18)
        let targetMaterial = material(UIColor(red: 0.18, green: 0.19, blue: 0.20, alpha: 1), roughness: 0.56, metalness: 0.18)
        for index in 0..<4 {
            let x = 0.56 + Float(index) * 0.24
            board.addChildNode(makeMemorySlot(x: x, isTarget: index == 1 || index == 3, slotMaterial: slotMaterial, targetMaterial: targetMaterial))

            for end in 0..<2 {
                board.addChildNode(makeMemoryLatch(name: "\(latchPrefix)\(index)-\(end)", x: x, end: end))
            }
        }

        let targetGlow = SCNNode()
        targetGlow.name = targetGlowName
        let glowMaterial = material(UIColor(red: 0.40, green: 0.72, blue: 1.0, alpha: 1), roughness: 0.4, metalness: 0)
        for x in [Float(0.80), Float(1.28)] {
            let glow = boxNode(width: 0.075, height: 0.012, length: 2.50, radius: 0.008, material: glowMaterial)
            glow.position = SCNVector3(x, 0.222, -0.20)
            targetGlow.addChildNode(glow)
        }
        board.addChildNode(targetGlow)

        let m2Slot = boxNode(width: 1.26, height: 0.08, length: 0.16, radius: 0.025, material: material(UIColor(red: 0.50, green: 0.52, blue: 0.52, alpha: 1), roughness: 0.54, metalness: 0.26))
        m2Slot.position = SCNVector3(-0.30, 0.16, 0.42)
        board.addChildNode(m2Slot)

        let pcieSlot = boxNode(width: 1.58, height: 0.10, length: 0.16, radius: 0.025, material: material(UIColor(red: 0.52, green: 0.54, blue: 0.54, alpha: 1), roughness: 0.54, metalness: 0.28))
        pcieSlot.position = SCNVector3(-0.46, 0.16, 1.08)
        board.addChildNode(pcieSlot)

        return board
    }

    private static func makeMemorySlot(x: Float, isTarget: Bool, slotMaterial: SCNMaterial, targetMaterial: SCNMaterial) -> SCNNode {
        let slot = SCNNode()
        let shellMaterial = isTarget ? targetMaterial : slotMaterial
        let innerMaterial = material(UIColor(red: 0.025, green: 0.028, blue: 0.030, alpha: 1), roughness: 0.72, metalness: 0.08)
        let contactMaterial = material(UIColor(red: 0.68, green: 0.70, blue: 0.68, alpha: 1), roughness: 0.42, metalness: 0.52)
        let keyMaterial = material(UIColor(red: 0.40, green: 0.42, blue: 0.41, alpha: 1), roughness: 0.56, metalness: 0.24)

        let shell = boxNode(width: 0.17, height: 0.13, length: 2.82, radius: 0.024, material: shellMaterial)
        shell.position = SCNVector3(x, 0.14, -0.20)
        slot.addChildNode(shell)

        let opening = boxNode(width: 0.105, height: 0.035, length: 2.62, radius: 0.01, material: innerMaterial)
        opening.position = SCNVector3(x, 0.215, -0.20)
        slot.addChildNode(opening)

        for side in [-1, 1] {
            for index in 0..<26 {
                let tooth = boxNode(width: 0.018, height: 0.028, length: 0.030, radius: 0.002, material: contactMaterial)
                tooth.position = SCNVector3(
                    x + Float(side) * 0.047,
                    0.238,
                    -1.43 + Float(index) * 0.098
                )
                slot.addChildNode(tooth)
            }
        }

        let keyBlock = boxNode(width: 0.12, height: 0.055, length: 0.115, radius: 0.008, material: keyMaterial)
        keyBlock.position = SCNVector3(x, 0.252, -0.18)
        slot.addChildNode(keyBlock)

        return slot
    }

    private static func makeMemoryLatch(name: String, x: Float, end: Int) -> SCNNode {
        let direction: Float = end == 0 ? -1 : 1
        let pivot = SCNNode()
        pivot.name = name
        pivot.position = SCNVector3(x, 0.24, end == 0 ? -1.62 : 1.22)

        let latchMaterial = material(UIColor(red: 0.31, green: 0.34, blue: 0.35, alpha: 1), roughness: 0.54, metalness: 0.22)
        let hingeMaterial = material(UIColor(red: 0.45, green: 0.48, blue: 0.49, alpha: 1), roughness: 0.48, metalness: 0.36)

        let foot = boxNode(width: 0.18, height: 0.08, length: 0.16, radius: 0.022, material: latchMaterial)
        foot.position = SCNVector3(0, -0.02, 0)
        pivot.addChildNode(foot)

        let hinge = cylinderNode(radius: 0.032, height: 0.18, material: hingeMaterial)
        hinge.eulerAngles = SCNVector3(0, 0, Float.pi / 2)
        hinge.position = SCNVector3(0, 0.03, direction * 0.02)
        pivot.addChildNode(hinge)

        let arm = boxNode(width: 0.16, height: 0.34, length: 0.10, radius: 0.018, material: latchMaterial)
        arm.position = SCNVector3(0, 0.19, direction * 0.04)
        pivot.addChildNode(arm)

        let hook = boxNode(width: 0.18, height: 0.055, length: 0.18, radius: 0.018, material: latchMaterial)
        hook.position = SCNVector3(0, 0.36, direction * 0.08)
        pivot.addChildNode(hook)

        let innerLip = boxNode(width: 0.13, height: 0.045, length: 0.08, radius: 0.012, material: hingeMaterial)
        innerLip.position = SCNVector3(0, 0.30, -direction * 0.04)
        pivot.addChildNode(innerLip)

        return pivot
    }

    private static func makeMemoryStick(name: String) -> SCNNode {
        let stick = SCNNode()
        stick.name = name

        let pcb = boxNode(width: 0.12, height: 0.58, length: 3.44, radius: 0.03, material: material(UIColor(red: 0.12, green: 0.42, blue: 0.24, alpha: 1), roughness: 0.58, metalness: 0.08))
        stick.addChildNode(pcb)

        let heatSpreader = boxNode(width: 0.16, height: 0.38, length: 3.10, radius: 0.035, material: material(UIColor(red: 0.18, green: 0.20, blue: 0.22, alpha: 1), roughness: 0.36, metalness: 0.46))
        heatSpreader.position = SCNVector3(0, 0.06, 0.02)
        stick.addChildNode(heatSpreader)

        let label = boxNode(width: 0.17, height: 0.13, length: 1.04, radius: 0.01, material: material(UIColor(red: 0.78, green: 0.80, blue: 0.78, alpha: 1), roughness: 0.44, metalness: 0.22))
        label.position = SCNVector3(0.02, 0.08, -0.34)
        stick.addChildNode(label)

        let contactMaterial = material(UIColor(red: 0.90, green: 0.64, blue: 0.32, alpha: 1), roughness: 0.34, metalness: 0.42)
        for index in 0..<24 {
            let contact = boxNode(width: 0.035, height: 0.08, length: 0.09, radius: 0.004, material: contactMaterial)
            contact.position = SCNVector3(0.02, -0.34, -1.52 + Float(index) * 0.132)
            stick.addChildNode(contact)
        }

        let notch = boxNode(width: 0.055, height: 0.12, length: 0.20, radius: 0.004, material: material(UIColor(red: 0.04, green: 0.13, blue: 0.08, alpha: 1), roughness: 0.72, metalness: 0.02))
        notch.position = SCNVector3(0.04, -0.34, -0.18)
        stick.addChildNode(notch)

        for z in [Float(-1.62), Float(1.62)] {
            let endCap = boxNode(width: 0.17, height: 0.42, length: 0.14, radius: 0.018, material: material(UIColor(red: 0.10, green: 0.11, blue: 0.12, alpha: 1), roughness: 0.42, metalness: 0.38))
            endCap.position = SCNVector3(0, 0.06, z)
            stick.addChildNode(endCap)
        }

        stick.scale = SCNVector3(0.82, 0.82, 0.82)
        stick.eulerAngles = SCNVector3(-0.10, 0, 0)
        stick.position = name == firstStickName ? firstStickPosition(phaseIndex: 0, progress: 0) : secondStickPosition(phaseIndex: 0, progress: 0)
        return stick
    }

    private static func makePressCues() -> SCNNode {
        let group = SCNNode()
        group.name = pressCueName
        group.opacity = 0

        for x in [Float(0.80), Float(1.28)] {
            for z in [Float(-1.05), Float(0.65)] {
                let highlight = boxNode(width: 0.22, height: 0.02, length: 0.34, radius: 0.018, material: material(UIColor(red: 0.20, green: 0.58, blue: 1.0, alpha: 1), roughness: 0.36, metalness: 0.0))
                highlight.position = SCNVector3(x, 0.75, z)
                group.addChildNode(highlight)

                let arrow = arrowNode()
                arrow.position = SCNVector3(x, 1.22, z)
                group.addChildNode(arrow)
            }
        }

        return group
    }

    private static func makeRamNotchCues() -> SCNNode {
        let group = SCNNode()
        group.name = ramNotchCueName
        group.opacity = 0
        let cueMaterial = material(UIColor(red: 1.0, green: 0.55, blue: 0.12, alpha: 1), roughness: 0.34, metalness: 0.08)

        for index in 0..<2 {
            let stickCue = boxNode(width: 0.24, height: 0.026, length: 0.24, radius: 0.012, material: cueMaterial)
            stickCue.name = "\(ramNotchCueName)-\(index)"
            group.addChildNode(stickCue)
        }

        return group
    }

    private static func makeSlotNotchCues() -> SCNNode {
        let group = SCNNode()
        group.name = slotNotchCueName
        group.opacity = 0
        let cueMaterial = material(UIColor(red: 1.0, green: 0.55, blue: 0.12, alpha: 1), roughness: 0.34, metalness: 0.08)

        for x in [Float(0.80), Float(1.28)] {
            let slotCue = boxNode(width: 0.20, height: 0.03, length: 0.18, radius: 0.01, material: cueMaterial)
            slotCue.position = SCNVector3(x, 0.31, -0.18)
            group.addChildNode(slotCue)

            let connector = cylinderNode(radius: 0.012, height: 0.44, material: cueMaterial)
            connector.position = SCNVector3(x, 0.55, -0.18)
            group.addChildNode(connector)
        }

        return group
    }

    private static func firstStickPosition(phaseIndex: Int, progress: CGFloat) -> SCNVector3 {
        switch phaseIndex {
        case 0:
            return SCNVector3(0.80, 1.34, -1.08)
        case 1:
            let eased = progress * progress * (3 - 2 * progress)
            return SCNVector3(0.80, 1.34 - Float(eased) * 0.16, -1.08 + Float(eased) * 0.18)
        case 2:
            let eased = progress * progress * (3 - 2 * progress)
            return SCNVector3(0.80, 1.18 - Float(eased) * 0.26, -0.90 + Float(eased) * 0.70)
        case 3:
            let rawProgress = min(max((progress - 0.10) / 0.68, 0), 1)
            let firstProgress = rawProgress * rawProgress * (3 - 2 * rawProgress)
            return SCNVector3(0.80, 0.92 - Float(firstProgress) * 0.52, -0.20)
        case 4:
            let pressProgress = smoothStep(min(max(progress / 0.72, 0), 1))
            return SCNVector3(0.80, 0.40 - Float(pressProgress) * 0.02, -0.20)
        case 5:
            let resetProgress = smoothStep(progress)
            return mix(SCNVector3(0.80, 0.38, -0.20), SCNVector3(0.80, 1.34, -1.08), resetProgress)
        default:
            return SCNVector3(0.80, 0.40, -0.20)
        }
    }

    private static func secondStickPosition(phaseIndex: Int, progress: CGFloat) -> SCNVector3 {
        switch phaseIndex {
        case 0:
            return SCNVector3(1.28, 1.46, -1.10)
        case 1:
            let eased = progress * progress * (3 - 2 * progress)
            return SCNVector3(1.28, 1.46 - Float(eased) * 0.20, -1.10 + Float(eased) * 0.20)
        case 2:
            let eased = progress * progress * (3 - 2 * progress)
            return SCNVector3(1.28, 1.26 - Float(eased) * 0.34, -0.90 + Float(eased) * 0.70)
        case 3:
            let rawProgress = min(max((progress - 0.34) / 0.66, 0), 1)
            let secondProgress = rawProgress * rawProgress * (3 - 2 * rawProgress)
            return SCNVector3(1.28, 0.92 - Float(secondProgress) * 0.52, -0.20)
        case 4:
            let pressProgress = smoothStep(min(max(progress / 0.72, 0), 1))
            return SCNVector3(1.28, 0.40 - Float(pressProgress) * 0.02, -0.20)
        case 5:
            let resetProgress = smoothStep(progress)
            return mix(SCNVector3(1.28, 0.38, -0.20), SCNVector3(1.28, 1.46, -1.10), resetProgress)
        default:
            return SCNVector3(1.28, 0.40, -0.20)
        }
    }

    private static func firstStickAngles(phaseIndex: Int, progress: CGFloat) -> SCNVector3 {
        if phaseIndex == 3 {
            let rawProgress = min(max((progress - 0.10) / 0.68, 0), 1)
            return SCNVector3(-0.10 + Float(smoothStep(rawProgress)) * 0.10, 0, 0)
        }
        if phaseIndex == 4 {
            return SCNVector3Zero
        }
        if phaseIndex == 5 {
            return SCNVector3(-Float(smoothStep(progress)) * 0.10, 0, 0)
        }
        return SCNVector3(-0.10, 0, 0)
    }

    private static func secondStickAngles(phaseIndex: Int, progress: CGFloat) -> SCNVector3 {
        if phaseIndex == 3 {
            let rawProgress = min(max((progress - 0.34) / 0.66, 0), 1)
            return SCNVector3(-0.10 + Float(smoothStep(rawProgress)) * 0.10, 0, 0)
        }
        if phaseIndex == 4 {
            return SCNVector3Zero
        }
        if phaseIndex == 5 {
            return SCNVector3(-Float(smoothStep(progress)) * 0.10, 0, 0)
        }
        return SCNVector3(-0.10, 0, 0)
    }

    private static func latchOpenAmount(slot: Int, phaseIndex: Int, progress: CGFloat) -> Float {
        if phaseIndex == 0 {
            return Float(progress)
        }
        if phaseIndex == 4 {
            let latchProgress = min(max((progress - 0.45) / 0.55, 0), 1)
            return Float(1 - latchProgress)
        }
        if phaseIndex == 5 {
            return Float(smoothStep(progress))
        }
        return 1
    }

    private static func mix(_ start: SCNVector3, _ end: SCNVector3, _ progress: CGFloat) -> SCNVector3 {
        let t = Float(progress)
        return SCNVector3(
            start.x + (end.x - start.x) * t,
            start.y + (end.y - start.y) * t,
            start.z + (end.z - start.z) * t
        )
    }

    private static func smoothStep(_ value: CGFloat) -> CGFloat {
        value * value * (3 - 2 * value)
    }

    private static func boxNode(width: CGFloat, height: CGFloat, length: CGFloat, radius: CGFloat, material: SCNMaterial) -> SCNNode {
        let box = SCNBox(width: width, height: height, length: length, chamferRadius: radius)
        box.materials = [material]
        return SCNNode(geometry: box)
    }

    private static func cylinderNode(radius: CGFloat, height: CGFloat, material: SCNMaterial) -> SCNNode {
        let cylinder = SCNCylinder(radius: radius, height: height)
        cylinder.radialSegmentCount = 18
        cylinder.materials = [material]
        return SCNNode(geometry: cylinder)
    }

    private static func coneNode(topRadius: CGFloat, bottomRadius: CGFloat, height: CGFloat, material: SCNMaterial) -> SCNNode {
        let cone = SCNCone(topRadius: topRadius, bottomRadius: bottomRadius, height: height)
        cone.radialSegmentCount = 18
        cone.materials = [material]
        return SCNNode(geometry: cone)
    }

    private static func arrowNode() -> SCNNode {
        let group = SCNNode()
        let arrowMaterial = material(UIColor(red: 0.18, green: 0.50, blue: 1.0, alpha: 1), roughness: 0.34, metalness: 0.08)

        let shaft = cylinderNode(radius: 0.024, height: 0.34, material: arrowMaterial)
        shaft.position = SCNVector3(0, 0.10, 0)
        group.addChildNode(shaft)

        let head = coneNode(topRadius: 0, bottomRadius: 0.075, height: 0.15, material: arrowMaterial)
        head.eulerAngles = SCNVector3(Float.pi, 0, 0)
        head.position = SCNVector3(0, -0.12, 0)
        group.addChildNode(head)

        return group
    }

    private static func material(_ color: UIColor, roughness: CGFloat = 0.6, metalness: CGFloat = 0.0) -> SCNMaterial {
        let material = SCNMaterial()
        TutorialSceneLighting.configure(material, color: color, roughness: roughness, metalness: metalness)
        return material
    }
}

private enum CPUInstallSceneFactory {
    private static let cpuNodeName = "cpu-node"
    private static let leverPivotName = "lever-pivot"
    private static let socketMarkerName = "socket-marker"
    private static let cpuMarkerName = "cpu-marker"
    private static let socketGlowName = "socket-glow"

    static func makeScene() -> SCNScene {
        let scene = SCNScene()
        scene.background.contents = UIColor.clear

        let cameraNode = SCNNode()
        let camera = SCNCamera()
        camera.fieldOfView = 38
        camera.zNear = 0.1
        camera.zFar = 100
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(0.10, 4.15, 5.15)
        cameraNode.eulerAngles = SCNVector3(-0.72, 0.012, 0.01)
        scene.rootNode.addChildNode(cameraNode)

        TutorialSceneLighting.install(in: scene, keyIntensity: 1_040, keyAngles: SCNVector3(-0.75, 0.35, -0.34))

        scene.rootNode.addChildNode(makeBoard())
        scene.rootNode.addChildNode(makeSocket())
        scene.rootNode.addChildNode(makeLever())
        scene.rootNode.addChildNode(makeCPU())

        return scene
    }

    static func updateScene(_ scene: SCNScene?, phaseIndex: Int, localProgress: Double) {
        guard let scene else { return }
        let progress = CGFloat(localProgress)
        let cpuNode = scene.rootNode.childNode(withName: cpuNodeName, recursively: true)
        let leverPivot = scene.rootNode.childNode(withName: leverPivotName, recursively: true)
        let socketMarker = scene.rootNode.childNode(withName: socketMarkerName, recursively: true)
        let cpuMarker = scene.rootNode.childNode(withName: cpuMarkerName, recursively: true)
        let socketGlow = scene.rootNode.childNode(withName: socketGlowName, recursively: true)

        let cpuPosition = cpuPosition(phaseIndex: phaseIndex, progress: progress)
        cpuNode?.position = cpuPosition
        cpuNode?.eulerAngles = SCNVector3(0, cpuYaw(phaseIndex: phaseIndex, progress: progress), 0)
        cpuNode?.opacity = phaseIndex == 0 ? 0.46 + 0.42 * Double(progress) : (phaseIndex == 4 ? 1 - 0.54 * Double(progress) : 1)

        leverPivot?.eulerAngles = SCNVector3(leverOpenAmount(phaseIndex: phaseIndex, progress: progress) * Float.pi * 0.58, 0, 0)

        let isAligning = phaseIndex == 1 || phaseIndex == 4
        let glowOpacity: CGFloat = isAligning ? 0.75 + 0.25 * sin(progress * .pi) : 0.22
        socketMarker?.opacity = Double(glowOpacity)
        cpuMarker?.opacity = Double(glowOpacity)
        socketGlow?.opacity = phaseIndex == 2 ? Double(0.2 + 0.42 * progress) : (phaseIndex == 3 ? 0.52 : (phaseIndex == 4 ? Double(0.52 - 0.36 * progress) : 0.16))
    }

    private static func makeBoard() -> SCNNode {
        let board = SCNNode()

        let base = boxNode(
            width: 3.8,
            height: 0.08,
            length: 4.6,
            radius: 0.06,
            material: material(UIColor(red: 0.06, green: 0.075, blue: 0.085, alpha: 1), roughness: 0.72, metalness: 0.15)
        )
        base.position = SCNVector3(0, 0, 0)
        base.opacity = 0.98
        base.castsShadow = true
        board.addChildNode(base)

        for index in 0..<4 {
            let slot = boxNode(
                width: 0.16,
                height: 0.16,
                length: 2.0,
                radius: 0.03,
                material: material(UIColor(red: 0.16, green: 0.17, blue: 0.18, alpha: 1), roughness: 0.68, metalness: 0.2)
            )
            slot.position = SCNVector3(1.05 + Float(index) * 0.24, 0.14, -0.28)
            board.addChildNode(slot)
        }

        let pcieSlot = boxNode(
            width: 2.05,
            height: 0.12,
            length: 0.16,
            radius: 0.025,
            material: material(UIColor(red: 0.09, green: 0.10, blue: 0.11, alpha: 1), roughness: 0.62, metalness: 0.24)
        )
        pcieSlot.position = SCNVector3(-0.06, 0.14, 1.64)
        board.addChildNode(pcieSlot)

        for index in 0..<7 {
            let capacitor = cylinderNode(
                radius: 0.08,
                height: 0.22,
                material: material(UIColor(red: 0.20, green: 0.21, blue: 0.22, alpha: 1), roughness: 0.58, metalness: 0.55)
            )
            capacitor.position = SCNVector3(-1.55, 0.18, -1.35 + Float(index) * 0.32)
            board.addChildNode(capacitor)
        }

        for index in 0..<3 {
            let heatSink = boxNode(
                width: 0.45,
                height: 0.28,
                length: 0.55,
                radius: 0.05,
                material: material(UIColor(red: 0.10, green: 0.11, blue: 0.12, alpha: 1), roughness: 0.5, metalness: 0.45)
            )
            heatSink.position = SCNVector3(-0.95 + Float(index) * 0.48, 0.22, -1.86)
            board.addChildNode(heatSink)
        }

        let screwMaterial = material(UIColor(red: 0.55, green: 0.57, blue: 0.56, alpha: 1), roughness: 0.46, metalness: 0.68)
        for position in [
            SCNVector3(-1.62, 0.085, -1.92),
            SCNVector3(1.62, 0.085, -1.92),
            SCNVector3(-1.62, 0.085, 1.92),
            SCNVector3(1.62, 0.085, 1.92)
        ] {
            let screw = cylinderNode(radius: 0.12, height: 0.026, material: screwMaterial)
            screw.position = position
            board.addChildNode(screw)
        }

        return board
    }

    private static func makeSocket() -> SCNNode {
        let socket = SCNNode()

        let socketBase = boxNode(
            width: 1.46,
            height: 0.11,
            length: 1.46,
            radius: 0.06,
            material: material(UIColor(red: 0.34, green: 0.36, blue: 0.36, alpha: 1), roughness: 0.7, metalness: 0.1)
        )
        socketBase.position = SCNVector3(0, 0.15, 0.14)
        socket.addChildNode(socketBase)

        let well = boxNode(
            width: 1.05,
            height: 0.035,
            length: 1.05,
            radius: 0.035,
            material: material(UIColor(red: 0.42, green: 0.43, blue: 0.42, alpha: 1), roughness: 0.82, metalness: 0.02)
        )
        well.position = SCNVector3(0, 0.235, 0.14)
        socket.addChildNode(well)

        let railMaterial = material(UIColor(red: 0.72, green: 0.72, blue: 0.68, alpha: 1), roughness: 0.38, metalness: 0.62)
        for x in [-0.74, 0.74] {
            let rail = boxNode(width: 0.075, height: 0.07, length: 1.36, radius: 0.018, material: railMaterial)
            rail.position = SCNVector3(Float(x), 0.31, 0.14)
            socket.addChildNode(rail)
        }
        for z in [-0.60, 0.88] {
            let rail = boxNode(width: 1.46, height: 0.055, length: 0.07, radius: 0.018, material: railMaterial)
            rail.position = SCNVector3(0, 0.305, Float(z))
            socket.addChildNode(rail)
        }

        let glow = boxNode(
            width: 1.47,
            height: 0.018,
            length: 1.47,
            radius: 0.05,
            material: material(UIColor(red: 0.96, green: 0.40, blue: 0.13, alpha: 1), roughness: 0.5, metalness: 0)
        )
        glow.name = socketGlowName
        glow.position = SCNVector3(0, 0.126, 0.14)
        socket.addChildNode(glow)

        let pinMaterial = material(UIColor(red: 0.91, green: 0.66, blue: 0.35, alpha: 1), roughness: 0.42, metalness: 0.45)
        for row in 0..<8 {
            for column in 0..<8 {
                let pin = boxNode(width: 0.032, height: 0.016, length: 0.032, radius: 0.004, material: pinMaterial)
                pin.position = SCNVector3(-0.34 + Float(column) * 0.095, 0.265, -0.20 + Float(row) * 0.095)
                socket.addChildNode(pin)
            }
        }

        let marker = markerNode(size: 0.14)
        marker.name = socketMarkerName
        marker.position = SCNVector3(-0.61, 0.295, -0.48)
        socket.addChildNode(marker)

        return socket
    }

    private static func makeLever() -> SCNNode {
        let pivot = SCNNode()
        pivot.name = leverPivotName
        pivot.position = SCNVector3(0.86, 0.32, 0.92)

        let hinge = cylinderNode(
            radius: 0.065,
            height: 0.34,
            material: material(UIColor(red: 0.74, green: 0.72, blue: 0.68, alpha: 1), roughness: 0.36, metalness: 0.68)
        )
        hinge.eulerAngles = SCNVector3(0, 0, Float.pi / 2)
        pivot.addChildNode(hinge)

        let lever = cylinderNode(
            radius: 0.032,
            height: 1.56,
            material: material(UIColor(red: 0.92, green: 0.54, blue: 0.22, alpha: 1), roughness: 0.28, metalness: 0.76)
        )
        lever.eulerAngles = SCNVector3(Float.pi / 2, 0, 0)
        lever.position = SCNVector3(0, 0, -0.78)
        pivot.addChildNode(lever)

        let handle = sphereNode(
            radius: 0.085,
            material: material(UIColor(red: 1.0, green: 0.54, blue: 0.20, alpha: 1), roughness: 0.34, metalness: 0.45)
        )
        handle.position = SCNVector3(0, 0, -1.58)
        pivot.addChildNode(handle)

        return pivot
    }

    private static func makeCPU() -> SCNNode {
        let cpu = SCNNode()
        cpu.name = cpuNodeName

        let substrate = boxNode(
            width: 1.16,
            height: 0.055,
            length: 1.16,
            radius: 0.045,
            material: material(UIColor(red: 0.16, green: 0.36, blue: 0.31, alpha: 1), roughness: 0.66, metalness: 0.08)
        )
        substrate.position = SCNVector3(0, -0.03, 0)
        cpu.addChildNode(substrate)

        let heatSpreader = boxNode(
            width: 0.86,
            height: 0.09,
            length: 0.86,
            radius: 0.05,
            material: material(UIColor(red: 0.77, green: 0.79, blue: 0.75, alpha: 1), roughness: 0.36, metalness: 0.46)
        )
        heatSpreader.position = SCNVector3(0, 0.035, 0)
        cpu.addChildNode(heatSpreader)

        let centerPlate = boxNode(
            width: 0.58,
            height: 0.014,
            length: 0.28,
            radius: 0.012,
            material: material(UIColor(red: 0.58, green: 0.61, blue: 0.58, alpha: 1), roughness: 0.58, metalness: 0.18)
        )
        centerPlate.position = SCNVector3(0, 0.088, 0.04)
        cpu.addChildNode(centerPlate)

        let marker = markerNode(size: 0.13)
        marker.name = cpuMarkerName
        marker.position = SCNVector3(-0.49, 0.012, -0.49)
        cpu.addChildNode(marker)

        let pinMaterial = material(UIColor(red: 0.92, green: 0.62, blue: 0.31, alpha: 1), roughness: 0.30, metalness: 0.54)
        for row in 0..<7 {
            for column in 0..<7 {
                let pin = cylinderNode(radius: 0.018, height: 0.055, material: pinMaterial)
                pin.position = SCNVector3(-0.36 + Float(column) * 0.12, -0.105, -0.36 + Float(row) * 0.12)
                cpu.addChildNode(pin)
            }
        }

        for x in [-0.36, 0.36] {
            let notch = boxNode(
                width: 0.16,
                height: 0.018,
                length: 0.045,
                radius: 0.006,
                material: material(UIColor(red: 0.05, green: 0.12, blue: 0.11, alpha: 1), roughness: 0.72, metalness: 0.02)
            )
            notch.position = SCNVector3(Float(x), 0.002, -0.595)
            cpu.addChildNode(notch)
        }

        cpu.position = SCNVector3(-0.94, 1.20, -0.48)
        return cpu
    }

    private static func cpuPosition(phaseIndex: Int, progress: CGFloat) -> SCNVector3 {
        switch phaseIndex {
        case 0:
            return SCNVector3(-0.94 + Float(progress) * 0.10, 1.20 + Float(sin(progress * .pi)) * 0.08, -0.56 + Float(progress) * 0.10)
        case 1:
            return SCNVector3(-0.84 + Float(progress) * 0.84, 1.17 + Float(sin(progress * .pi)) * 0.05, -0.46 + Float(progress) * 0.60)
        case 2:
            let easedDrop = progress * progress * (3 - 2 * progress)
            return SCNVector3(0, 1.12 - Float(easedDrop) * 0.79, 0.14)
        case 4:
            let resetProgress = progress * progress * (3 - 2 * progress)
            return SCNVector3(
                -Float(resetProgress) * 0.94,
                0.33 + Float(resetProgress) * 0.87,
                0.14 - Float(resetProgress) * 0.70
            )
        default:
            return SCNVector3(0, 0.33, 0.14)
        }
    }

    private static func cpuYaw(phaseIndex: Int, progress: CGFloat) -> Float {
        switch phaseIndex {
        case 0:
            return -0.18
        case 1:
            return -0.18 + Float(progress) * 0.18
        case 4:
            let resetProgress = progress * progress * (3 - 2 * progress)
            return -Float(resetProgress) * 0.18
        default:
            return 0
        }
    }

    private static func leverOpenAmount(phaseIndex: Int, progress: CGFloat) -> Float {
        switch phaseIndex {
        case 0:
            return Float(progress)
        case 1, 2:
            return 1
        case 4:
            let reopenProgress = progress * progress * (3 - 2 * progress)
            return Float(reopenProgress)
        default:
            return Float(1 - progress)
        }
    }

    private static func boxNode(width: CGFloat, height: CGFloat, length: CGFloat, radius: CGFloat, material: SCNMaterial) -> SCNNode {
        let box = SCNBox(width: width, height: height, length: length, chamferRadius: radius)
        box.materials = [material]
        return SCNNode(geometry: box)
    }

    private static func cylinderNode(radius: CGFloat, height: CGFloat, material: SCNMaterial) -> SCNNode {
        let cylinder = SCNCylinder(radius: radius, height: height)
        cylinder.radialSegmentCount = 18
        cylinder.materials = [material]
        return SCNNode(geometry: cylinder)
    }

    private static func sphereNode(radius: CGFloat, material: SCNMaterial) -> SCNNode {
        let sphere = SCNSphere(radius: radius)
        sphere.segmentCount = 18
        sphere.materials = [material]
        return SCNNode(geometry: sphere)
    }

    private static func markerNode(size: CGFloat) -> SCNNode {
        let cone = SCNCone(topRadius: 0, bottomRadius: size * 0.55, height: size)
        cone.radialSegmentCount = 3
        cone.materials = [material(UIColor(red: 1.0, green: 0.43, blue: 0.11, alpha: 1), emission: UIColor(red: 0.58, green: 0.18, blue: 0.02, alpha: 1))]
        let node = SCNNode(geometry: cone)
        node.eulerAngles = SCNVector3(Float.pi / 2, 0, Float.pi / 3)
        return node
    }

    private static func material(_ color: UIColor, roughness: CGFloat = 0.6, metalness: CGFloat = 0.0, emission: UIColor? = nil) -> SCNMaterial {
        let material = SCNMaterial()
        TutorialSceneLighting.configure(material, color: color, roughness: roughness, metalness: metalness, emission: emission)
        return material
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
