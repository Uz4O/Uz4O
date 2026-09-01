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
    @State private var isUsingCPUPlatformAlternative = false
    @State private var isSavingConfiguration = false
    @State private var hasSavedConfiguration = false

    let plan: BuildPlan
    let onBack: () -> Void
    let onSave: ((BuildPlan) async throws -> Void)?
    let onEditInDIY: (() -> Void)?

    init(
        plan: BuildPlan,
        initialPerformanceState: BuildPerformanceLoadState? = nil,
        onBack: @escaping () -> Void,
        onSave: ((BuildPlan) async throws -> Void)? = nil,
        onEditInDIY: (() -> Void)? = nil
    ) {
        self.plan = plan
        self.onBack = onBack
        self.onSave = onSave
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
        if isUsingCPUPlatformAlternative,
           let alternative = plan.cpuPlatformAlternative,
           let replacementCPU = alternative.replacementParts.first(
               where: { $0.part.category == "CPU" }
           ),
           let context = plan.performanceContext {
            return BuildPerformanceContext(
                cpuID: replacementCPU.componentID,
                gpuID: context.gpuID,
                gameIDs: context.gameIDs,
                unavailableGameNames: context.unavailableGameNames
            )
        }
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
        guard let originalTotal = Int(plan.totalPrice.filter(\.isNumber)) else {
            return plan.totalPrice
        }
        let priceDifference = if isUsingCPUPlatformAlternative {
            plan.cpuPlatformAlternative?.priceDifference ?? 0
        } else if isUsingGPUAlternative {
            plan.usedGPUAlternative?.priceDifference ?? 0
        } else {
            0
        }
        return "¥ \((originalTotal + priceDifference).formatted(.number.grouping(.automatic)))"
    }

    private var displayedBudget: Int? {
        Int(plan.budget.filter(\.isNumber))
    }

    private var displayedTotal: Int? {
        Int(displayedTotalPrice.filter(\.isNumber))
    }

    private var displayedPlan: BuildPlan {
        var parts = plan.parts
        if isUsingCPUPlatformAlternative,
           let alternative = plan.cpuPlatformAlternative {
            let replacements = Dictionary(
                uniqueKeysWithValues: alternative.replacementParts.map {
                    ($0.part.category, $0.part)
                }
            )
            parts = parts.map { part in
                guard let replacement = replacements[part.category] else { return part }
                return PCPart(
                    id: part.id,
                    category: replacement.category,
                    model: replacement.model,
                    price: replacement.price,
                    condition: replacement.condition,
                    icon: replacement.icon,
                    accent: replacement.accent
                )
            }
        } else if isUsingGPUAlternative,
                  let alternative = plan.usedGPUAlternative {
            parts = parts.map { part in
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
        }
        return BuildPlan(
            name: plan.name,
            budget: plan.budget,
            totalPrice: displayedTotalPrice,
            useCase: plan.useCase,
            createdAt: plan.createdAt,
            parts: parts,
            usedGPUAlternative: plan.usedGPUAlternative,
            cpuPlatformAlternative: plan.cpuPlatformAlternative,
            performanceContext: activePerformanceContext
        )
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                resultHeader

                ResultBudgetSummary(
                    total: displayedTotal,
                    budget: displayedBudget
                )

                Divider()
                    .overlay(ResultColors.divider)

                PartsListCard(
                    plan: displayedPlan,
                    isVisible: isVisible,
                    hasRevealed: hasRevealed,
                    isGPUAlternativeApplied: isUsingGPUAlternative,
                    onToggleGPUAlternative: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isUsingCPUPlatformAlternative = false
                            isUsingGPUAlternative.toggle()
                        }
                    },
                    isCPUPlatformAlternativeApplied: isUsingCPUPlatformAlternative,
                    onToggleCPUPlatformAlternative: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isUsingGPUAlternative = false
                            isUsingCPUPlatformAlternative.toggle()
                        }
                    }
                )
                TotalPriceSection(totalPrice: displayedTotalPrice)
            }
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : 8)
            .animation(.easeOut(duration: 0.28), value: hasRevealed)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            resultActions
        }
        .background(Color.white.ignoresSafeArea())
        .toolbar(.hidden, for: .tabBar)
        .onAppear {
            guard !reduceMotion else { return }
            hasRevealed = true
        }
        .task(id: activePerformanceContext?.requestKey) {
            await loadPerformance()
        }
        .onChange(of: isUsingGPUAlternative) { _, _ in
            hasSavedConfiguration = false
        }
        .onChange(of: isUsingCPUPlatformAlternative) { _, _ in
            hasSavedConfiguration = false
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
                    .font(.system(size: 21, weight: .medium))
                    .foregroundStyle(.black)
                    .frame(width: 26, height: 34)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("返回")

            VStack(alignment: .leading, spacing: 5) {
                Text("配置方案详情")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.black)

                Text("根据你的需求生成的装机方案")
                    .font(.system(size: 13))
                    .foregroundStyle(ResultColors.secondaryText)
            }

            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.top, 14)
        .padding(.bottom, 28)
    }

    private var resultActions: some View {
        HStack(spacing: 10) {
            ResultActionButton(
                title: "保存为图片",
                systemName: "photo",
                isPrimary: false,
                action: saveConfigurationImage
            )

            if onSave != nil {
                ResultActionButton(
                    title: hasSavedConfiguration
                        ? "已保存"
                        : (isSavingConfiguration ? "保存中" : "保存配置"),
                    systemName: hasSavedConfiguration ? "checkmark" : "archivebox",
                    isPrimary: true,
                    action: saveConfiguration
                )
                .disabled(isSavingConfiguration || hasSavedConfiguration)
            }
        }
        .frame(maxWidth: 420)
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 10)
        .frame(maxWidth: .infinity)
        .background(.white)
        .overlay(alignment: .top) {
            Divider().overlay(ResultColors.divider)
        }
    }

    @MainActor
    private func saveConfigurationImage() {
        let renderer = ImageRenderer(
            content: BuildResultShareCard(
                plan: displayedPlan,
                performanceState: performanceState,
                isGPUAlternativeApplied: isUsingGPUAlternative,
                isCPUPlatformAlternativeApplied: isUsingCPUPlatformAlternative
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
                Task { @MainActor in
                    presentFeedback("没有相册添加权限，请在设置中允许 UzBox 访问照片")
                }
                return
            }

            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            }) { success, error in
                let message: String
                if success {
                    message = "配置图片已保存到相册"
                } else if let detail = error?.localizedDescription, !detail.isEmpty {
                    message = "保存失败：\(detail)"
                } else {
                    message = "保存失败：系统未能写入相册，请稍后重试"
                }
                Task { @MainActor in presentFeedback(message) }
            }
        }
    }

    private func presentFeedback(_ message: String) {
        feedbackMessage = message
        showsFeedback = true
    }

    private func saveConfiguration() {
        guard let onSave, !isSavingConfiguration else { return }
        isSavingConfiguration = true
        Task {
            do {
                try await onSave(displayedPlan)
                hasSavedConfiguration = true
                presentFeedback("已保存到“我的配置单”")
            } catch {
                presentFeedback("保存失败：\(error.localizedDescription)")
            }
            isSavingConfiguration = false
        }
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
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(isPrimary ? Color.white : Color.black)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background {
                    LinearGradient(
                        colors: isPrimary
                            ? [Color(red: 0.09, green: 0.09, blue: 0.09), .black]
                            : [.white, Color(red: 0.97, green: 0.97, blue: 0.98)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(ResultColors.divider, lineWidth: isPrimary ? 0 : 1)
                }
        }
        .buttonStyle(ResultActionButtonStyle())
    }
}

private struct ResultActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.99 : 1)
            .offset(y: configuration.isPressed ? 2 : 0)
            .shadow(
                color: .black.opacity(configuration.isPressed ? 0.06 : 0.14),
                radius: configuration.isPressed ? 1 : 4,
                x: 0,
                y: configuration.isPressed ? 1 : 3
            )
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

private struct ResultBudgetSummary: View {
    let total: Int?
    let budget: Int?

    private var remaining: Int? {
        guard let total, let budget else { return nil }
        return budget - total
    }

    private var progress: Double {
        guard let total, let budget, budget > 0 else { return 0 }
        return min(max(Double(total) / Double(budget), 0), 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("方案总价")
                .font(.system(size: 14))
                .foregroundStyle(ResultColors.secondaryText)

            Text(total.map(currency) ?? "--")
                .font(.system(size: 38, weight: .bold))
                .foregroundStyle(.black)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            HStack {
                budgetLabel
                Spacer()
                remainingLabel
            }
            .font(.system(size: 14))

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(ResultColors.progressTrack)
                    Capsule()
                        .fill(.black)
                        .frame(width: proxy.size.width * progress)
                }
            }
            .frame(height: 5)
        }
        .padding(.horizontal, 30)
        .padding(.bottom, 14)
    }

    private var budgetLabel: Text {
        Text("预算 ").foregroundStyle(ResultColors.secondaryText)
            + Text(budget.map(currency) ?? "--").bold().foregroundStyle(.black)
    }

    private var remainingLabel: Text {
        guard let remaining else {
            return Text("剩余 --").foregroundStyle(ResultColors.secondaryText)
        }
        let title = remaining >= 0 ? "剩余 " : "超出 "
        return Text(title).foregroundStyle(ResultColors.secondaryText)
            + Text(currency(abs(remaining))).bold().foregroundStyle(.black)
    }

    private func currency(_ value: Int) -> String {
        "¥\(value.formatted(.number.grouping(.automatic)))"
    }
}

private struct BuildResultShareCard: View {
    let plan: BuildPlan
    let performanceState: BuildPerformanceLoadState
    let isGPUAlternativeApplied: Bool
    let isCPUPlatformAlternativeApplied: Bool

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 5) {
                Text("配置方案详情")
                    .font(.system(size: 20, weight: .bold))
                Text("根据你的需求生成的装机方案")
                    .font(.system(size: 13))
                    .foregroundStyle(ResultColors.secondaryText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 28)

            ResultBudgetSummary(
                total: Int(plan.totalPrice.filter(\.isNumber)),
                budget: Int(plan.budget.filter(\.isNumber))
            )

            Divider().overlay(ResultColors.divider)
            PartsListCard(
                plan: plan,
                isVisible: true,
                hasRevealed: true,
                isGPUAlternativeApplied: isGPUAlternativeApplied,
                onToggleGPUAlternative: nil,
                isCPUPlatformAlternativeApplied: isCPUPlatformAlternativeApplied,
                onToggleCPUPlatformAlternative: nil
            )
            TotalPriceSection(totalPrice: plan.totalPrice)
        }
        .padding(.top, 16)
        .foregroundStyle(.black)
        .background(Color.white)
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
        HStack {
            Text("合计")
                .font(.system(size: 13))
                .foregroundStyle(ResultColors.secondaryText)
            Spacer()
            Text(totalPrice.replacingOccurrences(of: "¥ ", with: "¥"))
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.black)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .padding(.horizontal, 30)
        .frame(height: 48)
        .overlay(alignment: .top) {
            Divider().overlay(ResultColors.divider)
        }
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
            return "+¥\(alternative.priceDifference.formatted())"
        }
        if alternative.priceDifference < 0 {
            return "-¥\((-alternative.priceDifference).formatted())"
        }
        return "¥0"
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
                            .font(.system(size: 10.5, weight: .semibold))
                            .foregroundStyle(ResultColors.secondaryText)

                        Text("\(alternative.model) · 二手")
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundStyle(ResultColors.secondaryText)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Text(priceComparison)
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(ResultColors.secondaryText)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(ResultColors.secondaryText)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
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
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            ResultColors.alternativeBackground,
            in: RoundedRectangle(cornerRadius: 10)
        )
        .padding(.bottom, 9)
    }
}

private struct CPUPlatformAlternativeCard: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isExpanded = false

    let alternative: CPUPlatformAlternativeRecommendation
    let isApplied: Bool
    let onToggle: (() -> Void)?

    private var cpu: CPUPlatformReplacementRecommendation? {
        alternative.replacementParts.first { $0.part.category == "CPU" }
    }

    private var priceComparison: String {
        if alternative.priceDifference > 0 {
            return "+¥\(alternative.priceDifference.formatted())"
        }
        if alternative.priceDifference < 0 {
            return "-¥\((-alternative.priceDifference).formatted())"
        }
        return "¥0"
    }

    private var replacementSummary: String {
        alternative.replacementParts.map(\.part.category).joined(separator: "、")
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
                        Text(isApplied ? "已切换平台" : "更强平台替代")
                            .font(.system(size: 10.5, weight: .semibold))
                            .foregroundStyle(ResultColors.secondaryText)

                        Text("\(cpu?.part.model ?? "i5-14600KF") · 全新")
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundStyle(ResultColors.secondaryText)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Text(priceComparison)
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(ResultColors.secondaryText)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(ResultColors.secondaryText)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isExpanded ? "收起 CPU 平台替代建议" : "展开 CPU 平台替代建议")

            if isExpanded {
                VStack(alignment: .leading, spacing: 7) {
                    Divider()
                        .overlay(ResultColors.divider)
                        .padding(.vertical, 2)

                    Text("综合 CPU 性能约 +\(alternative.performanceGainPercent)% · \(priceComparison)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(ResultColors.secondaryText)

                    Text("本次同步更换：\(replacementSummary)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(ResultColors.secondaryText)

                    Text("7500F：当前性能较弱，但 AM5 后续升级空间更大。")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(ResultColors.secondaryText)

                    Text("14600KF：当前性能更强，但 LGA1700 后续升级空间较小；以后升级通常需要连同 CPU、主板和内存一起更换。")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(ResultColors.secondaryText)

                    if let onToggle {
                        Button(action: onToggle) {
                            Text(isApplied ? "恢复 7500F 平台" : "切换到 14600KF 平台")
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
                .padding(.top, 7)
                .transition(expansionTransition)
            }
        }
        .animation(expansionAnimation, value: isExpanded)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            ResultColors.alternativeBackground,
            in: RoundedRectangle(cornerRadius: 10)
        )
        .padding(.bottom, 9)
    }
}

private struct PartsListCard: View {
    let plan: BuildPlan
    let isVisible: Bool
    let hasRevealed: Bool
    let isGPUAlternativeApplied: Bool
    let onToggleGPUAlternative: (() -> Void)?
    let isCPUPlatformAlternativeApplied: Bool
    let onToggleCPUPlatformAlternative: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("配置清单")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.black)
                .padding(.top, 18)
                .padding(.bottom, 7)

            Label("兼容性检查通过", systemImage: "checkmark.circle")
                .font(.system(size: 12))
                .foregroundStyle(ResultColors.secondaryText)
                .padding(.bottom, 10)

            ForEach(Array(plan.parts.enumerated()), id: \.element.id) { index, part in
                ResultPartRow(part: part)
                    .opacity(isVisible ? 1 : 0)
                    .offset(y: isVisible ? 0 : 10)
                    .animation(
                        .easeOut(duration: 0.24).delay(0.08 + Double(index) * 0.025),
                        value: hasRevealed
                    )

                if part.category == "CPU", let alternative = plan.cpuPlatformAlternative {
                    CPUPlatformAlternativeCard(
                        alternative: alternative,
                        isApplied: isCPUPlatformAlternativeApplied,
                        onToggle: onToggleCPUPlatformAlternative
                    )
                }

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
        .padding(.horizontal, 30)
    }
}

private struct ResultPartRow: View {
    let part: PCPart

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(part.category)
                    .font(.system(size: 11.5))
                    .foregroundStyle(ResultColors.secondaryText)

                Text(part.model)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.black)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(part.price.replacingOccurrences(of: "¥ ", with: "¥"))
                .font(.system(size: 14.5, weight: .semibold))
                .foregroundStyle(.black)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .fixedSize()
        }
        .frame(minHeight: 49)
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
    static let progressTrack = Color(red: 0.81, green: 0.82, blue: 0.85)
    static let alternativeBackground = Color(red: 0.96, green: 0.96, blue: 0.97)
}

#Preview {
    BuildResultView(plan: AppMockData.samplePlan, onBack: {})
}
