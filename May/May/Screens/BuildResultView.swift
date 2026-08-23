import SwiftUI
import Photos
import UIKit

struct BuildResultView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hasRevealed = false
    @State private var feedbackMessage = ""
    @State private var showsFeedback = false
    @State private var performanceState: BuildPerformanceLoadState
    @State private var performanceCache: [String: BuildPerformanceLoadState]
    @State private var isUsingGPUAlternative = false

    let plan: BuildPlan
    let onBack: () -> Void
    let onEditInDIY: (() -> Void)?

    init(
        plan: BuildPlan,
        initialPerformanceState: BuildPerformanceLoadState? = nil,
        onBack: @escaping () -> Void,
        onEditInDIY: (() -> Void)? = nil
    ) {
        self.plan = plan
        self.onBack = onBack
        self.onEditInDIY = onEditInDIY
        _performanceState = State(initialValue: initialPerformanceState ?? .idle)

        var initialCache: [String: BuildPerformanceLoadState] = [:]
        if let requestKey = plan.performanceContext?.requestKey,
           let initialPerformanceState {
            switch initialPerformanceState {
            case .idle, .loading:
                break
            case .loaded, .unavailable, .failed:
                initialCache[requestKey] = initialPerformanceState
            }
        }
        _performanceCache = State(initialValue: initialCache)
    }

    private var isVisible: Bool {
        hasRevealed || reduceMotion
    }

    private var activePerformanceContext: BuildPerformanceContext? {
        guard isUsingGPUAlternative,
              let alternative = plan.usedGPUAlternative,
              let context = plan.performanceContext else {
            return plan.performanceContext
        }
        return BuildPerformanceContext(
            cpuID: context.cpuID,
            gpuID: alternative.componentID,
            gameIDs: context.gameIDs,
            unavailableGameNames: context.unavailableGameNames
        )
    }

    private var displayedTotalPrice: String {
        guard isUsingGPUAlternative,
              let alternative = plan.usedGPUAlternative,
              let originalTotal = Int(plan.totalPrice.filter(\.isNumber)) else {
            return plan.totalPrice
        }
        return "¥ \((originalTotal + alternative.priceDifference).formatted(.number.grouping(.automatic)))"
    }

    private var displayedPlan: BuildPlan {
        guard isUsingGPUAlternative, let alternative = plan.usedGPUAlternative else {
            return plan
        }
        let parts = plan.parts.map { part in
            guard part.category == "显卡" else { return part }
            return PCPart(
                id: part.id,
                category: part.category,
                model: alternative.model,
                price: "¥ \(alternative.referencePrice.formatted(.number.grouping(.automatic)))",
                condition: "二手",
                icon: part.icon,
                accent: part.accent
            )
        }
        return BuildPlan(
            name: plan.name,
            budget: plan.budget,
            totalPrice: displayedTotalPrice,
            useCase: plan.useCase,
            createdAt: plan.createdAt,
            parts: parts,
            usedGPUAlternative: alternative,
            performanceContext: activePerformanceContext
        )
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                resultHeader
                    .padding(.bottom, 4)

                PerformanceCard(
                    state: performanceState,
                    onRetry: {
                        Task { await loadPerformance() }
                    }
                )
                PartsListCard(
                    plan: displayedPlan,
                    isVisible: isVisible,
                    hasRevealed: hasRevealed,
                    isGPUAlternativeApplied: isUsingGPUAlternative,
                    onToggleGPUAlternative: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isUsingGPUAlternative.toggle()
                        }
                    }
                )
                TotalPriceSection(totalPrice: displayedTotalPrice)

                HStack(spacing: 12) {
                    ResultActionButton(
                        title: "保存为图片",
                        systemName: "photo",
                        isPrimary: false,
                        action: saveConfigurationImage
                    )

                    if let onEditInDIY {
                        ResultActionButton(
                            title: "进入DIY界面编辑",
                            systemName: "wrench.and.screwdriver",
                            isPrimary: true,
                            action: onEditInDIY
                        )
                    }
                }
                .frame(maxWidth: 420)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 2)
                .padding(.bottom, 22)
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : 8)
            .animation(.easeOut(duration: 0.28), value: hasRevealed)
        }
        .background(Color(red: 0.985, green: 0.985, blue: 0.985).ignoresSafeArea())
        .onAppear {
            guard !reduceMotion else { return }
            hasRevealed = true
        }
        .task(id: activePerformanceContext?.requestKey) {
            await loadPerformance()
        }
        .alert("配置方案", isPresented: $showsFeedback) {
            Button("好的", role: .cancel) {}
        } message: {
            Text(feedbackMessage)
        }
    }

    private var resultHeader: some View {
        HStack(alignment: .top, spacing: 14) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(.black)
                    .frame(width: 28, height: 38)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("返回")

            VStack(alignment: .leading, spacing: 5) {
                Text("配置方案详情")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.black)

                Text(plan.useCase)
                    .font(.system(size: 13))
                    .foregroundStyle(ResultColors.secondaryText)
                    .lineLimit(2)
            }

            Spacer()
        }
    }

    @MainActor
    private func saveConfigurationImage() {
        let renderer = ImageRenderer(
            content: BuildResultShareCard(
                plan: displayedPlan,
                performanceState: performanceState,
                isGPUAlternativeApplied: isUsingGPUAlternative
            )
                .frame(width: 430)
        )
        renderer.scale = 3

        guard let image = renderer.uiImage else {
            presentFeedback("图片生成失败，请重试")
            return
        }

        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else {
                Task { @MainActor in presentFeedback("没有相册保存权限") }
                return
            }
            UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
            Task { @MainActor in presentFeedback("配置图片已保存到相册") }
        }
    }

    private func presentFeedback(_ message: String) {
        feedbackMessage = message
        showsFeedback = true
    }

    @MainActor
    private func loadPerformance() async {
        guard let context = activePerformanceContext else {
            performanceState = await loadBuildPerformance(context: nil)
            return
        }

        if let cachedState = performanceCache[context.requestKey] {
            performanceState = cachedState
            return
        }

        performanceState = .loading
        let state = await loadBuildPerformance(context: context)
        guard !Task.isCancelled else { return }
        performanceCache[context.requestKey] = state
        performanceState = state
    }
}

private struct ResultActionButton: View {
    let title: String
    let systemName: String
    let isPrimary: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isPrimary ? Color.white : Color.black)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(isPrimary ? Color.black : Color.white, in: RoundedRectangle(cornerRadius: AppTheme.controlRadius))
                .overlay {
                    RoundedRectangle(cornerRadius: AppTheme.controlRadius)
                        .stroke(ResultColors.divider, lineWidth: isPrimary ? 0 : 1)
                }
        }
        .buttonStyle(.plain)
    }
}

private struct BuildResultShareCard: View {
    let plan: BuildPlan
    let performanceState: BuildPerformanceLoadState
    let isGPUAlternativeApplied: Bool

    var body: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 5) {
                Text("配置方案详情")
                    .font(.system(size: 24, weight: .bold))
                Text(plan.useCase)
                    .font(.system(size: 13))
                    .foregroundStyle(ResultColors.secondaryText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            PerformanceCard(state: performanceState)
            PartsListCard(
                plan: plan,
                isVisible: true,
                hasRevealed: true,
                isGPUAlternativeApplied: isGPUAlternativeApplied,
                onToggleGPUAlternative: nil
            )
            TotalPriceSection(totalPrice: plan.totalPrice)
        }
        .padding(16)
        .foregroundStyle(.black)
        .background(Color(red: 0.985, green: 0.985, blue: 0.985))
    }
}

private struct PerformanceCard: View {
    let state: BuildPerformanceLoadState
    var onRetry: (() -> Void)?

    init(
        state: BuildPerformanceLoadState,
        onRetry: (() -> Void)? = nil
    ) {
        self.state = state
        self.onRetry = onRetry
    }

    var body: some View {
        ResultCard {
            VStack(alignment: .leading, spacing: 11) {
                Text("游戏性能表现")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.black)

                performanceContent
            }
        }
    }

    @ViewBuilder
    private var performanceContent: some View {
        switch state {
        case .idle, .loading:
            HStack(spacing: 10) {
                ProgressView()
                    .tint(.black)
                Text("正在读取游戏性能测试数据")
                    .font(.system(size: 13))
                    .foregroundStyle(ResultColors.secondaryText)
            }
            .frame(maxWidth: .infinity, minHeight: 94)
        case .loaded(let metrics, let unavailableGameNames):
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 0) {
                    PerformanceGauge(fps: fps(for: .twoK, in: metrics))
                        .frame(maxWidth: .infinity)

                    Rectangle()
                        .fill(ResultColors.divider)
                        .frame(width: 1, height: 56)

                    PerformanceMetric(
                        title: "1080P 电竞",
                        value: fps(for: .fullHD, in: metrics)
                    )
                    .frame(maxWidth: .infinity)

                    Rectangle()
                        .fill(ResultColors.divider)
                        .frame(width: 1, height: 56)

                    PerformanceMetric(
                        title: "4K 高画质",
                        value: fps(for: .fourK, in: metrics)
                    )
                    .frame(maxWidth: .infinity)
                }
                .frame(height: 105)

                Text("游戏性能测试估算平均帧，实际会受画质、版本、驱动和散热影响")
                    .font(.system(size: 11))
                    .foregroundStyle(ResultColors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)

                if !unavailableGameNames.isEmpty {
                    Text("暂未收录：\(unavailableGameNames.joined(separator: "、"))")
                        .font(.system(size: 11))
                        .foregroundStyle(ResultColors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        case .unavailable(let message), .failed(let message):
            VStack(spacing: 10) {
                Text(message)
                    .font(.system(size: 13))
                    .foregroundStyle(ResultColors.secondaryText)
                    .multilineTextAlignment(.center)

                if case .failed = state, let onRetry {
                    Button("重新加载", action: onRetry)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.black)
                        .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 94)
        }
    }

    private func fps(
        for resolution: PerformanceResolution,
        in metrics: [BuildResolutionPerformance]
    ) -> Int? {
        metrics.first(where: { $0.resolution == resolution })?.averageFPS
    }
}

private struct PerformanceGauge: View {
    let fps: Int?

    var body: some View {
        ZStack {
            Circle()
                .stroke(ResultColors.gaugeTrack, lineWidth: 1)
                .frame(width: 84, height: 84)

            Circle()
                .trim(from: 0, to: min(Double(fps ?? 0) / 360, 1))
                .stroke(.black, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: 84, height: 84)

            VStack(spacing: -1) {
                Text(fps.map(String.init) ?? "--")
                    .font(.system(size: 30, weight: .medium))
                Text("FPS")
                    .font(.system(size: 11))
                Text("2K 平均帧")
                    .font(.system(size: 10))
                    .padding(.top, 5)
            }
            .foregroundStyle(.black)
        }
        .frame(width: 108, height: 108)
    }
}

private struct PerformanceMetric: View {
    let title: String
    let value: Int?

    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.system(size: 11))
            Text(value.map(String.init) ?? "--")
                .font(.system(size: 25, weight: .medium))
            Text("FPS")
                .font(.system(size: 11))
        }
        .foregroundStyle(.black)
    }
}

struct BuildResolutionPerformance: Sendable {
    let resolution: PerformanceResolution
    let averageFPS: Int?
    let missingGameNames: [String]
}

enum BuildPerformanceLoadState: Sendable {
    case idle
    case loading
    case loaded(
        metrics: [BuildResolutionPerformance],
        unavailableGameNames: [String]
    )
    case unavailable(String)
    case failed(String)
}

func loadBuildPerformance(
    context: BuildPerformanceContext?
) async -> BuildPerformanceLoadState {
    guard let context else {
        return .unavailable("当前方案没有关联游戏性能测试")
    }
    guard !context.gameIDs.isEmpty else {
        let message = context.unavailableGameNames.isEmpty
            ? "当前方案没有可用的游戏性能数据"
            : "游戏性能测试暂未收录：" + context.unavailableGameNames.joined(separator: "、")
        return .unavailable(message)
    }

    do {
        async let fullHD = requestBuildPerformance(
            context: context,
            resolution: .fullHD
        )
        async let twoK = requestBuildPerformance(
            context: context,
            resolution: .twoK
        )
        async let fourK = requestBuildPerformance(
            context: context,
            resolution: .fourK
        )
        let metrics = try await [fullHD, twoK, fourK]
        try Task.checkCancellation()

        let unavailableGameNames = Array(
            Set(
                context.unavailableGameNames
                    + metrics.flatMap(\.missingGameNames)
            )
        ).sorted()
        if metrics.allSatisfy({ $0.averageFPS == nil }) {
            return .unavailable("当前配置与所选游戏暂无平均帧数据")
        }
        return .loaded(
            metrics: metrics,
            unavailableGameNames: unavailableGameNames
        )
    } catch is CancellationError {
        return .idle
    } catch {
        return .failed("游戏性能数据加载失败")
    }
}

private func requestBuildPerformance(
    context: BuildPerformanceContext,
    resolution: PerformanceResolution
) async throws -> BuildResolutionPerformance {
    let response = try await AppAPIClient().estimatePerformance(
        cpuID: context.cpuID,
        gpuID: context.gpuID,
        resolution: resolution.apiValue,
        gameIDs: context.gameIDs
    )
    return BuildResolutionPerformance(
        resolution: resolution,
        averageFPS: response.averageFps,
        missingGameNames: response.missingGames.map { PerformanceGame.name(for: $0) }
    )
}

private struct TotalPriceSection: View {
    let totalPrice: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("总计")
                .font(.system(size: 13))
                .foregroundStyle(ResultColors.secondaryText)

            Text(totalPrice.replacingOccurrences(of: "¥ ", with: "¥"))
                .font(.system(size: 36, weight: .bold))
                .foregroundStyle(.black)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 2)
        .padding(.top, 4)
    }
}

private struct UsedGPUAlternativeCard: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isExpanded = false

    let alternative: UsedGPUAlternativeRecommendation
    let isApplied: Bool
    let onToggle: (() -> Void)?

    private var priceComparison: String {
        if alternative.priceDifference > 0 {
            return "多 ¥\(alternative.priceDifference.formatted())"
        }
        if alternative.priceDifference < 0 {
            return "省 ¥\((-alternative.priceDifference).formatted())"
        }
        return "同价"
    }

    private var performanceComparison: String {
        if let gainPercent = alternative.gamingPerformanceGainPercent,
           gainPercent > 0 {
            return "游戏性能 +\(gainPercent)%"
        }
        return alternative.performanceComparison == "higher"
            ? "游戏性能更高"
            : "游戏性能接近"
    }

    private var expansionAnimation: Animation {
        reduceMotion ? .easeOut(duration: 0.12) : .smooth(duration: 0.36)
    }

    private var expansionTransition: AnyTransition {
        guard !reduceMotion else { return .opacity }
        return .opacity.combined(with: .scale(scale: 0.985, anchor: .top))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(expansionAnimation) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(isApplied ? "已替换" : "更强替代")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(ResultColors.secondaryText)

                        Text("二手 \(alternative.model) · ¥\(alternative.referencePrice.formatted())")
                            .font(.system(size: 13.5, weight: .semibold))
                            .foregroundStyle(.black)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(ResultColors.secondaryText)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isExpanded ? "收起显卡替代建议" : "展开显卡替代建议")

            if isExpanded {
                VStack(alignment: .leading, spacing: 0) {
                    Divider()
                        .overlay(ResultColors.divider)
                        .padding(.vertical, 9)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("\(performanceComparison) · \(priceComparison)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(ResultColors.secondaryText)

                        Text(
                            isApplied
                                ? "RTX 40 系无矿卡风险 · 已计入当前总价"
                                : "RTX 40 系无矿卡风险 · 不计入当前总价"
                        )
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(ResultColors.secondaryText)

                        if let onToggle {
                            Button(action: onToggle) {
                                Text(isApplied ? "恢复原显卡" : "替换为这张显卡")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(isApplied ? Color.black : Color.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 36)
                                    .background(
                                        isApplied ? Color.white : Color.black,
                                        in: RoundedRectangle(cornerRadius: 9)
                                    )
                                    .overlay {
                                        if isApplied {
                                            RoundedRectangle(cornerRadius: 9)
                                                .stroke(ResultColors.divider, lineWidth: 1)
                                        }
                                    }
                            }
                            .buttonStyle(.plain)
                            .padding(.top, 3)
                        }
                    }
                }
                .transition(expansionTransition)
            }
        }
        .animation(expansionAnimation, value: isExpanded)
        .padding(11)
        .background(
            Color(red: 0.95, green: 0.95, blue: 0.96),
            in: RoundedRectangle(cornerRadius: 10)
        )
        .padding(.bottom, 10)
    }
}

private struct PartsListCard: View {
    let plan: BuildPlan
    let isVisible: Bool
    let hasRevealed: Bool
    let isGPUAlternativeApplied: Bool
    let onToggleGPUAlternative: (() -> Void)?

    var body: some View {
        ResultCard(verticalPadding: 16, horizontalPadding: 16) {
            VStack(alignment: .leading, spacing: 0) {
                Text("配件清单")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.black)
                    .padding(.bottom, 9)

                ForEach(Array(plan.parts.enumerated()), id: \.element.id) { index, part in
                    ResultPartRow(part: part)
                        .opacity(isVisible ? 1 : 0)
                        .offset(y: isVisible ? 0 : 10)
                        .animation(
                            .easeOut(duration: 0.24).delay(0.08 + Double(index) * 0.025),
                            value: hasRevealed
                        )

                    if part.category == "显卡", let alternative = plan.usedGPUAlternative {
                        UsedGPUAlternativeCard(
                            alternative: alternative,
                            isApplied: isGPUAlternativeApplied,
                            onToggle: onToggleGPUAlternative
                        )
                    }

                    if part.id != plan.parts.last?.id {
                        Divider()
                            .overlay(ResultColors.divider)
                    }
                }
            }
        }
    }
}

private struct ResultPartRow: View {
    let part: PCPart

    private var conditionColor: Color {
        part.condition == "全新"
            ? Color(red: 0.10, green: 0.39, blue: 0.70)
            : Color(red: 0.18, green: 0.48, blue: 0.21)
    }

    private var conditionBackground: Color {
        part.condition == "全新"
            ? Color(red: 0.91, green: 0.95, blue: 1.00)
            : Color(red: 0.92, green: 0.97, blue: 0.92)
    }

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: part.icon)
                .font(.system(size: 27, weight: .regular))
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(.black)
                .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text(part.category)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.black)

                    Text(part.condition)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(conditionColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(conditionBackground, in: Capsule())
                }

                Text(part.model)
                    .font(.system(size: 13.5))
                    .foregroundStyle(.black)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(part.price.replacingOccurrences(of: "¥ ", with: "¥"))
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(.black)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .fixedSize()
        }
        .frame(minHeight: 72)
    }
}

private struct ResultCard<Content: View>: View {
    var verticalPadding: CGFloat = 15
    var horizontalPadding: CGFloat = 16
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(.vertical, verticalPadding)
            .padding(.horizontal, horizontalPadding)
            .frame(maxWidth: .infinity)
            .background(Color.white, in: RoundedRectangle(cornerRadius: AppTheme.cardRadius))
            .shadow(color: Color.black.opacity(0.05), radius: 14, x: 0, y: 6)
    }
}

private enum ResultColors {
    static let divider = Color(red: 0.86, green: 0.87, blue: 0.89)
    static let gaugeTrack = Color(red: 0.86, green: 0.87, blue: 0.89)
    static let secondaryText = Color(red: 0.40, green: 0.43, blue: 0.50)
}

#Preview {
    BuildResultView(plan: AppMockData.samplePlan, onBack: {})
}
