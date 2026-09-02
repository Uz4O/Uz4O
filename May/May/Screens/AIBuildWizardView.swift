import SwiftUI

/// The reference flow is one vertical canvas. Keeping the four pages in the
/// same stack lets the drag position drive both the page transition and the
/// small card morphs instead of asking SwiftUI to swap unrelated screens.
struct AIBuildView: View {
    typealias LoadOptions = (AIBuildOptionsInput) async throws -> BuildOptionsResponseDTO
    typealias PrepareResults = @MainActor (BuildOptionsResponseDTO, [String]) async -> Void

    private let minimumGenerationDuration: TimeInterval = 2.5
    private let completionAnimationDuration: TimeInterval = 0.8

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var currentStep: AIBuildStep = .budget
    @State private var dragOffset: CGFloat = 0
    // Keeps the same budget-card view parked on the games page after the
    // first transition. The page-local mini card is only a layout anchor.
    @State private var budgetCardOnGames = false
    @State private var preferenceCardOnCapacity = false
    @State private var isChangingStep = false
    @State private var settleTask: Task<Void, Never>?
    @State private var transitionToken = 0
    @State private var flowMessage: String?
    @State private var flowMessageTask: Task<Void, Never>?

    @State private var isSubmitting = false
    @State private var isGenerationComplete = false
    @State private var submissionError: String?
    @State private var generationTask: Task<Void, Never>?

    @State private var budget: Double = 6850
    @State private var selectedUseCase = "游戏"
    @State private var selectedGames: Set<String> = []
    @State private var selectedDirection = AIBuildDirection.balanced
    @State private var selectedOfficeApps: Set<String> = []
    @State private var usesNoGpuBuild = false
    @State private var ownedGPUModel = ""
    @State private var isOwnedGPUPickerPresented = false
    @State private var needsWirelessNetwork = true
    @State private var selectedBuildPreference = BuildPreference.defaultAISelection
    @State private var chassisColorPreference = "曜石黑"
    @State private var selectedMemorySize = "16GB"
    @State private var selectedStorageSize = "1TB"
    @State private var allowsFlexibleBudget = false
    @State private var selectedGPUPreference = "AI 智能选择"

    let onBack: () -> Void
    let onComplete: (BuildOptionsResponseDTO, [String]) -> Void
    let loadOptions: LoadOptions
    let prepareResults: PrepareResults

    init(
        onBack: @escaping () -> Void,
        onComplete: @escaping (BuildOptionsResponseDTO, [String]) -> Void,
        prepareResults: @escaping PrepareResults = { _, _ in },
        loadOptions: @escaping LoadOptions = { input in
            try await AppAPIClient().buildOptions(
                budget: input.budget,
                useCase: input.useCase,
                gameCategories: input.games,
                direction: input.direction.rawValue,
                officeApps: input.officeApps,
                needsWirelessNetwork: input.needsWirelessNetwork,
                memorySize: input.memorySize,
                storageSize: input.storageSize,
                allowsFlexibleBudget: input.allowsFlexibleBudget,
                noGPUBuild: input.noGPUBuild,
                ownedGPUModel: input.ownedGPUModel,
                gpuPreference: input.gpuPreference
            )
        }
    ) {
        self.onBack = onBack
        self.onComplete = onComplete
        self.prepareResults = prepareResults
        self.loadOptions = loadOptions
    }

    private let gameOptions = [
        "什么都玩", "瓦罗兰特", "CS2", "PUBG", "三角洲行动", "永劫无间", "暗区突围",
        "穿越火线", "云顶之弈", "LOL", "COD", "NBA2K", "赛博朋克2077", "荒野大镖客2",
        "GTA5", "黑神话悟空", "地平线6", "艾尔登法环", "城市天际线", "我的世界"
    ]

    // Keep the complete maintained mapping for API/performance reuse. The
    // reference layout shows the first sixteen tiles, which fit the viewport.
    static let gameArtworkNames = [
        "瓦罗兰特": "GameArtworkValorant",
        "CS2": "GameArtworkCS2",
        "PUBG": "GameArtworkPUBG",
        "三角洲行动": "GameArtworkDeltaForce",
        "永劫无间": "GameArtworkNarakaBladepoint",
        "暗区突围": "GameArtworkArenaBreakout",
        "NBA2K": "GameArtworkNBA2K",
        "穿越火线": "GameArtworkCrossFire",
        "云顶之弈": "GameArtworkTeamfightTactics",
        "LOL": "GameArtworkLeagueOfLegends",
        "COD": "GameArtworkCallOfDuty",
        "赛博朋克2077": "GameArtworkCyberpunk2077",
        "荒野大镖客2": "GameArtworkRedDeadRedemption2",
        "GTA5": "GameArtworkGTAV",
        "黑神话悟空": "GameArtworkBlackMythWukong",
        "地平线6": "GameArtworkForzaHorizon6",
        "艾尔登法环": "GameArtworkEldenRing",
        "城市天际线": "GameArtworkCitiesSkylines",
        "我的世界": "GameArtworkMinecraft"
    ]

    private var referenceGameOptions: [String] { Array(gameOptions.prefix(16)) }

    private var recommendedDirection: AIBuildDirection {
        AIBuildFlowRules.recommendedDirection(for: selectedGames)
    }

    private var showsGPUPreference: Bool {
        AIBuildFlowRules.shouldShowGPUPreference(
            budget: Int(budget),
            useCase: selectedUseCase,
            hasOwnedGPU: usesNoGpuBuild
        )
    }

    private var gpuPreference: String? {
        guard showsGPUPreference else { return nil }
        return ["指定N卡": "NVIDIA", "指定A卡": "AMD"][selectedGPUPreference]
    }

    var body: some View {
        GeometryReader { _ in
            ZStack(alignment: .top) {
                LinearGradient(
                    colors: [Color.white, Color(red: 0.955, green: 0.958, blue: 0.968)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    AIWizardHeader(currentStep: currentStep.rawValue, onBack: handleHeaderBack)
                        .padding(.horizontal, 24)
                        .padding(.top, 14)

                    AIWizardProgress(currentStep: currentStep.rawValue)
                        .padding(.horizontal, 24)
                        .padding(.top, 16)
                        .padding(.bottom, 10)

                    GeometryReader { pagerProxy in
                        pager(height: pagerProxy.size.height)
                            // The page stack is taller than the viewport. Keep
                            // the clip boundary tied to this GeometryReader so
                            // the next page cannot peek into the current one.
                            .frame(
                                width: pagerProxy.size.width,
                                height: pagerProxy.size.height,
                                alignment: .top
                            )
                            .clipped()
                            .contentShape(Rectangle())
                            .simultaneousGesture(pagerGesture(height: pagerProxy.size.height))
                    }
                }

                if let flowMessage {
                    Text(flowMessage)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppTheme.primaryText)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 11)
                        .background(.white.opacity(0.96), in: Capsule())
                        .shadow(color: .black.opacity(0.12), radius: 16, y: 7)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .frame(maxHeight: .infinity, alignment: .bottom)
                        .padding(.bottom, 18)
                        .zIndex(3)
                }

                if isSubmitting {
                    AIBuildGeneratingView(isComplete: isGenerationComplete)
                        .transition(.opacity.combined(with: .scale(scale: 0.985)))
                        .zIndex(4)
                }
            }
        }
        .alert("暂时无法生成合适方案", isPresented: submissionErrorBinding) {
            Button("重试") {
                submissionError = nil
                submitBuildOptions()
            }
            Button("取消", role: .cancel) {
                submissionError = nil
            }
        } message: {
            Text(submissionError ?? "请稍后重试")
        }
        .sheet(isPresented: $isOwnedGPUPickerPresented) {
            HardwarePickerSheet(
                title: "显卡",
                icon: "display",
                filters: HardwareCatalog.filters(for: "显卡"),
                selectedValue: $ownedGPUModel
            )
            .presentationDetents([.large])
        }
        .onChange(of: usesNoGpuBuild) { _, isOwned in
            if !isOwned { ownedGPUModel = "" }
        }
        .onDisappear {
            cancelGeneration()
            settleTask?.cancel()
            flowMessageTask?.cancel()
        }
    }

    @ViewBuilder
    private func pager(height: CGFloat) -> some View {
        let page = currentStep.rawValue
        let progress = pageProgress(height: height)
        let heroTransition = activeHeroTransition
        let heroIsSettled = dragOffset == 0 && (
            (heroTransition == .budget && currentStep == .scenario && budgetCardOnGames)
            || (heroTransition == .games && currentStep == .purchase && budgetCardOnGames)
            || (heroTransition == .preference && currentStep == .hardware && preferenceCardOnCapacity)
        )
        let budgetIsDockedTravel = heroTransition == .budget && (
            (currentStep == .scenario && dragOffset < 0)
            || (currentStep == .purchase && dragOffset > 0)
        )
        let heroProgress = heroIsSettled || budgetIsDockedTravel ? 1 : progress
        let heroIsForward = dragOffset == 0 || budgetIsDockedTravel
            || (heroTransition == .budget && currentStep == .budget)
            || (heroTransition == .preference && currentStep == .purchase)
            || (heroTransition == .games && currentStep == .scenario)
        let gamesGridPinOffset: CGFloat = {
            guard height > 1 else { return 0 }
            return 0
        }()
        let budgetCardPinOffset: CGFloat = {
            guard height > 1 else { return 0 }
            switch currentStep {
            case .scenario where dragOffset < 0:
                return -dragOffset
            case .purchase where budgetCardOnGames && dragOffset >= 0:
                return height - dragOffset
            default:
                return 0
            }
        }()
        let gamesGridOpacity: CGFloat = {
            if currentStep == .budget, dragOffset < 0 {
                return aiSmoothStep((progress - 0.18) / 0.50)
            }
            if currentStep == .scenario, dragOffset > 0 {
                return 1 - aiSmoothStep((progress - 0.18) / 0.50)
            }
            guard heroTransition == .games else { return 1 }
            // The morph overlay is the only game-card surface during this
            // transition. Let the page card take over only after the state
            // settles, otherwise the reverse gesture briefly shows two cards.
            return 0
        }()
        let gamesHeadingOpacity: CGFloat = {
            guard heroTransition == .games else { return 1 }
            let morphProgress = heroIsForward ? heroProgress : 1 - heroProgress
            return 1 - aiSmoothStep((morphProgress - 0.13) / 0.24)
        }()
        let gamesThirdPageOpacity: CGFloat = {
            guard heroTransition == .games else { return 1 }
            let morphProgress = heroIsForward ? heroProgress : 1 - heroProgress
            return aiSmoothStep((morphProgress - 0.68) / 0.24)
        }()

        ZStack(alignment: .top) {
            VStack(spacing: 0) {
                AIBudgetWizardPage(
                    budget: $budget,
                    usesNoGpuBuild: $usesNoGpuBuild,
                    ownedGPUModel: $ownedGPUModel,
                    collapseProgress: collapseAmount(for: 0, height: height),
                    hidesHeroCard: heroTransition == .budget,
                    onPickGPU: { isOwnedGPUPickerPresented = true }
                )
                .padding(.top, 26)
                .frame(height: height)
                .allowsHitTesting(page == 0 && !isChangingStep && !isSubmitting && dragOffset == 0)

                AIGamesWizardPage(
                    budget: Int(budget),
                    options: referenceGameOptions,
                    artworkNames: Self.gameArtworkNames,
                    selectedGames: $selectedGames,
                    budgetCardOpacity: 1,
                    hidesBudgetCard: heroTransition == .budget
                        || heroTransition == .games
                        || heroTransition == .preference,
                    gamesGridPinOffset: gamesGridPinOffset,
                    budgetCardPinOffset: budgetCardPinOffset,
                    gamesGridOpacity: gamesGridOpacity,
                    headingOpacity: gamesHeadingOpacity
                )
                .padding(.top, 24)
                .frame(height: height)
                .allowsHitTesting(page == 1 && !isChangingStep && !isSubmitting && dragOffset == 0)

                AIPreferenceWizardPage(
                    selectedGames: selectedGames,
                    options: referenceGameOptions,
                    artworkNames: Self.gameArtworkNames,
                    needsWirelessNetwork: $needsWirelessNetwork,
                    selectedBuildPreference: $selectedBuildPreference,
                    chassisColorPreference: $chassisColorPreference,
                    collapseProgress: heroTransition == .preference ? 0 : collapseAmount(for: 2, height: height),
                    gameCardOpacity: currentStep == .purchase && dragOffset < 0 ? 1 - progress : 1,
                    hidesPreferenceCard: heroTransition == .preference,
                    hidesGameSummaryCard: currentStep.rawValue >= AIBuildStep.purchase.rawValue
                        || heroTransition == .games
                        || heroTransition == .preference,
                    contentOpacity: gamesThirdPageOpacity
                )
                .padding(.top, 44)
                .frame(height: height)
                .allowsHitTesting(page == 2 && !isChangingStep && !isSubmitting && dragOffset == 0)

                AICapacityWizardPage(
                    selectedBuildPreference: selectedBuildPreference,
                    chassisColorPreference: chassisColorPreference,
                    needsWirelessNetwork: needsWirelessNetwork,
                    selectedMemorySize: $selectedMemorySize,
                    selectedStorageSize: $selectedStorageSize,
                    allowsFlexibleBudget: $allowsFlexibleBudget,
                    isSubmitting: isSubmitting,
                    hidesHeroCard: heroTransition == .preference,
                    onGenerate: submitBuildOptions
                )
                .padding(.top, 44)
                .frame(height: height)
                .allowsHitTesting(page == 3 && !isChangingStep && !isSubmitting && dragOffset == 0)
            }
            .offset(y: -CGFloat(page) * height + dragOffset)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .coordinateSpace(name: AIHeroCoordinateSpace.pager)
        .overlayPreferenceValue(AIHeroAnchorKey.self) { anchors in
            AIHeroMorphOverlay(
                transition: heroTransition,
                anchors: anchors,
                progress: heroProgress,
                isForward: heroIsForward,
                settledPage: page,
                pageHeight: height,
                dragOffset: dragOffset,
                budget: Int(budget),
                selectedGames: referenceGameOptions.filter { selectedGames.contains($0) },
                artworkNames: Self.gameArtworkNames,
                selectedBuildPreference: selectedBuildPreference,
                chassisColorPreference: chassisColorPreference,
                needsWirelessNetwork: needsWirelessNetwork,
                usesNoGpuBuild: usesNoGpuBuild,
                ownedGPUModel: ownedGPUModel,
                gameOptions: referenceGameOptions
            )
            .allowsHitTesting(false)
        }
        .clipped()
    }

    private var activeHeroTransition: AIHeroTransition? {
        switch currentStep {
        case .budget where dragOffset < 0:
            return .budget
        case .scenario where dragOffset < 0:
            return .games
        case .scenario where budgetCardOnGames:
            // At rest this is the settled hero; with a positive drag it is
            // the exact reverse route back to the full budget card.
            return .budget
        case .purchase where dragOffset > 0:
            return .games
        case .purchase where dragOffset < 0:
            return .preference
        case .purchase where budgetCardOnGames && dragOffset == 0:
            return .games
        case .hardware where preferenceCardOnCapacity && dragOffset >= 0:
            return .preference
        default:
            return nil
        }
    }

    private func pageProgress(height: CGFloat) -> CGFloat {
        // The actual height is supplied to collapseAmount; this fallback keeps
        // opacity stable while SwiftUI is measuring the pager for the first time.
        guard height > 1 else { return 0 }
        return aiClamp(abs(dragOffset) / height)
    }

    private func collapseAmount(for page: Int, height: CGFloat) -> CGFloat {
        guard height > 1 else { return 0 }
        let progress = aiClamp(abs(dragOffset) / height)
        if currentStep.rawValue == page, dragOffset < 0 { return progress }
        if currentStep.rawValue == page + 1, dragOffset > 0 { return 1 - progress }
        return 0
    }

    private func pagerGesture(height: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                guard !isChangingStep, !isSubmitting else { return }
                guard abs(value.translation.height) > abs(value.translation.width) * 1.15 else { return }

                dragOffset = CGFloat(
                    AIBuildPagerRules.dragOffset(
                        translation: Double(value.translation.height),
                        currentPage: currentStep.rawValue,
                        pageExtent: Double(height)
                    )
                )
            }
            .onEnded { value in
                guard !isChangingStep, !isSubmitting else { return }
                finishDrag(value, height: height)
            }
    }

    private func finishDrag(_ value: DragGesture.Value, height: CGFloat) {
        guard abs(value.translation.height) > abs(value.translation.width) * 1.15 else {
            // A horizontal control (notably the budget slider) can end the
            // simultaneous gesture. It did not move the pager, so do not
            // start a settling task or lock the page unnecessarily.
            if dragOffset != 0 {
                settle(to: currentStep.rawValue, height: height)
            }
            return
        }

        let projected = max(
            abs(value.translation.height),
            abs(value.predictedEndTranslation.height) * 0.5
        )
        let signedTranslation = abs(value.translation.height) > 4
            ? value.translation.height
            : value.predictedEndTranslation.height
        let projectedTranslation = signedTranslation < 0 ? -projected : projected
        let target = AIBuildPagerRules.targetPage(
            currentPage: currentStep.rawValue,
            translation: Double(projectedTranslation),
            pageExtent: Double(height),
            selectedGameCount: selectedGames.count
        )

        let blockedForMissingGame = currentStep == .scenario
            && signedTranslation < 0
            && projected >= height * CGFloat(AIBuildPagerRules.defaultThresholdRatio)
            && selectedGames.isEmpty
        if blockedForMissingGame {
            settle(to: currentStep.rawValue, height: height)
            showFlowMessage("至少选择一款游戏")
            return
        }

        guard target != currentStep.rawValue else {
            settle(to: currentStep.rawValue, height: height)
            return
        }

        if target == AIBuildStep.purchase.rawValue {
            selectedDirection = recommendedDirection
        }
        settle(to: target, height: height)
    }

    private func settle(to target: Int, height: CGFloat) {
        guard let targetStep = AIBuildStep(rawValue: target) else { return }
        let startStep = currentStep.rawValue
        transitionToken += 1
        let token = transitionToken
        settleTask?.cancel()
        isChangingStep = true

        let duration = reduceMotion ? 0.20 : 0.46
        let targetOffset = -CGFloat(target - startStep) * height
        withAnimation(.easeOut(duration: duration)) {
            dragOffset = targetOffset
        }

        settleTask = Task { @MainActor in
            do {
                try await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000) + 30_000_000)
            } catch {
                return
            }
            guard !Task.isCancelled, token == transitionToken else { return }
            var transaction = Transaction()
            transaction.animation = nil
            withTransaction(transaction) {
                currentStep = targetStep
                dragOffset = 0
                if startStep == AIBuildStep.budget.rawValue,
                   targetStep == .scenario {
                    budgetCardOnGames = true
                } else if startStep == AIBuildStep.scenario.rawValue,
                          targetStep == .budget {
                    budgetCardOnGames = false
                }
                if startStep == AIBuildStep.purchase.rawValue,
                   targetStep == .hardware {
                    preferenceCardOnCapacity = true
                } else if startStep == AIBuildStep.hardware.rawValue,
                          targetStep == .purchase {
                    preferenceCardOnCapacity = false
                }
            }
            isChangingStep = false
            settleTask = nil
        }
    }

    private func showFlowMessage(_ message: String) {
        flowMessageTask?.cancel()
        withAnimation(.easeOut(duration: 0.18)) {
            flowMessage = message
        }
        flowMessageTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_200_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.18)) {
                flowMessage = nil
            }
        }
    }

    private var submissionErrorBinding: Binding<Bool> {
        Binding(
            get: { submissionError != nil },
            set: { if !$0 { submissionError = nil } }
        )
    }

    private func submitBuildOptions() {
        guard !isSubmitting else { return }
        if usesNoGpuBuild && ownedGPUModel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            submissionError = "请选择自备显卡型号"
            return
        }

        let input = AIBuildOptionsInput(
            budget: Int(budget),
            useCase: selectedUseCase,
            games: selectedGames.sorted(),
            direction: selectedDirection,
            officeApps: selectedOfficeApps.sorted(),
            needsWirelessNetwork: needsWirelessNetwork,
            memorySize: selectedMemorySize,
            storageSize: selectedStorageSize,
            allowsFlexibleBudget: allowsFlexibleBudget,
            noGPUBuild: usesNoGpuBuild,
            ownedGPUModel: usesNoGpuBuild
                ? ownedGPUModel.trimmingCharacters(in: .whitespacesAndNewlines)
                : nil,
            gpuPreference: gpuPreference
        )

        let minimumGenerationEnd = Date().addingTimeInterval(minimumGenerationDuration)
        let completionStart = minimumGenerationEnd.addingTimeInterval(-completionAnimationDuration)
        isGenerationComplete = false
        isSubmitting = true

        generationTask = Task {
            do {
                let response = try await loadOptions(input)
                await prepareResults(response, input.games)
                guard !Task.isCancelled else { return }
                let remainingBeforeCompletion = completionStart.timeIntervalSinceNow
                if remainingBeforeCompletion > 0 {
                    try await Task.sleep(nanoseconds: UInt64(remainingBeforeCompletion * 1_000_000_000))
                }
                guard !Task.isCancelled else { return }
                withAnimation(.easeOut(duration: 0.3)) {
                    isGenerationComplete = true
                }
                try await Task.sleep(nanoseconds: UInt64(completionAnimationDuration * 1_000_000_000))
                guard !Task.isCancelled else { return }
                generationTask = nil
                onComplete(response, input.games)
                isSubmitting = false
            } catch {
                guard !Task.isCancelled else { return }
                generationTask = nil
                isGenerationComplete = false
                isSubmitting = false
                submissionError = error.localizedDescription
            }
        }
    }

    private func handleHeaderBack() {
        cancelGeneration()
        onBack()
    }

    private func cancelGeneration() {
        generationTask?.cancel()
        generationTask = nil
    }

}

private func aiClamp(_ value: CGFloat) -> CGFloat {
    min(1, max(0, value))
}

// The page stack moves independently from the hero card.  These anchors let
// one overlay card interpolate between the two resting bounds while the page
// content continues to follow the finger.  The page-local cards keep their
// layout (opacity only changes), so there is no reflow during the morph.
private enum AIHeroTransition: Equatable {
    case budget
    case games
    case preference
}

private enum AIHeroAnchorID: Hashable {
    case budgetFull
    case budgetMini
    case gamesGrid
    case gamesSummary
    case preferenceFull
    case preferenceSummary
}

private enum AIHeroCoordinateSpace {
    static let pager = "ai-build-pager"
}

private struct AIHeroAnchorKey: PreferenceKey {
    static var defaultValue: [AIHeroAnchorID: Anchor<CGRect>] = [:]

    static func reduce(
        value: inout [AIHeroAnchorID: Anchor<CGRect>],
        nextValue: () -> [AIHeroAnchorID: Anchor<CGRect>]
    ) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

private extension View {
    func aiHeroAnchor(_ id: AIHeroAnchorID) -> some View {
        anchorPreference(key: AIHeroAnchorKey.self, value: .bounds) { anchor in
            [id: anchor]
        }
    }
}

private struct AIHeroMorphOverlay: View {
    let transition: AIHeroTransition?
    let anchors: [AIHeroAnchorID: Anchor<CGRect>]
    let progress: CGFloat
    let isForward: Bool
    let settledPage: Int
    let pageHeight: CGFloat
    let dragOffset: CGFloat
    let budget: Int
    let selectedGames: [String]
    let artworkNames: [String: String]
    let selectedBuildPreference: BuildPreference
    let chassisColorPreference: String
    let needsWirelessNetwork: Bool
    let usesNoGpuBuild: Bool
    let ownedGPUModel: String
    let gameOptions: [String]

    private let gameDockOffset: CGFloat = 2

    var body: some View {
        GeometryReader { proxy in
            if let transition,
               let pair = framePair(for: transition, in: proxy) {
                if transition == .budget {
                    let frame = interpolate(pair.source, pair.target, progress)
                    let collapse = isForward ? aiClamp(progress) : 1 - aiClamp(progress)
                    let fullSize = isForward ? pair.source.size : pair.target.size
                    let compactSize = isForward ? pair.target.size : pair.source.size
                    let targetScale = aiClamp(compactSize.width / max(fullSize.width, 1))
                    let lift = heroLift(collapse)
                    let dockedTravel = budgetDockedTravel

                    AIBudgetHeroCard(
                        budget: .constant(Double(budget)),
                        usesNoGpuBuild: .constant(usesNoGpuBuild),
                        ownedGPUModel: .constant(ownedGPUModel),
                        onPickGPU: {},
                        noGPUVisibility: 1 - aiSmoothStep(collapse / 0.42)
                    )
                    // The source card keeps its natural aspect ratio. Only a
                    // uniform scale and a bottom-edge 3D rotation change it;
                    // its controls are never replaced or clipped.
                    .frame(width: max(fullSize.width, 1), height: max(fullSize.height, 1))
                    .scaleEffect(
                        heroScale(collapse, targetScale: targetScale),
                        anchor: .bottom
                    )
                    .rotation3DEffect(
                        .degrees(Double(heroAngle(collapse, finalAngle: 69))),
                        axis: (x: 1, y: 0, z: 0),
                        anchor: .bottom,
                        perspective: 0.78
                    )
                    .shadow(
                        color: .black.opacity(0.16 - 0.09 * collapse),
                        radius: 18 - 10 * collapse,
                        y: 11 - 7 * collapse
                    )
                    // Place the card by the bottom-edge pivot. Interpolating
                    // midY leaves the full-height layout box below the dock,
                    // so a steeply tilted card appears much too low.
                    .position(
                        x: frame.midX,
                        y: frame.maxY - fullSize.height / 2 + lift + dockedTravel.offset
                    )
                    .opacity(dockedTravel.opacity)
                } else if transition == .preference {
                    ZStack {
                        if let budgetFrame = budgetDockFrame(in: proxy) {
                            fixedBudgetCard(
                                frame: budgetFrame,
                                in: proxy
                            )
                        }
                        fixedGameCard(in: proxy)

                        let frame = interpolate(pair.source, pair.target, progress)
                        let collapse = isForward ? aiClamp(progress) : 1 - aiClamp(progress)
                        let fullSize = isForward ? pair.source.size : pair.target.size
                        let compactSize = isForward ? pair.target.size : pair.source.size
                        let targetScale = aiClamp(compactSize.width / max(fullSize.width, 1))
                        let finalAngle: CGFloat = 69
                        let perspectiveHeight = compactSize.height / max(
                            0.1,
                            CGFloat(cos(Double(finalAngle) * .pi / 180))
                        )
                        let targetHeightScale = perspectiveHeight / max(fullSize.height, 1)
                        let widthScale = heroScale(collapse, targetScale: targetScale)
                        let heightScale = 1 + (targetHeightScale - 1)
                            * aiSmoothStep(collapse / 0.95)

                        AITravelingHeroCard(
                            transition: .preference,
                            compactness: collapse,
                            budget: budget,
                            selectedGames: selectedGames,
                            artworkNames: artworkNames,
                            selectedBuildPreference: selectedBuildPreference,
                            chassisColorPreference: chassisColorPreference,
                            needsWirelessNetwork: needsWirelessNetwork
                        )
                        .frame(width: max(fullSize.width, 1), height: max(fullSize.height, 1))
                        .scaleEffect(x: widthScale, y: heightScale, anchor: .bottom)
                        .rotation3DEffect(
                            .degrees(Double(heroAngle(collapse, finalAngle: finalAngle))),
                            axis: (x: 1, y: 0, z: 0),
                            anchor: .bottom,
                            perspective: 0.78
                        )
                        .shadow(
                            color: .black.opacity(0.16 - 0.09 * collapse),
                            radius: 18 - 10 * collapse,
                            y: 11 - 7 * collapse
                        )
                        .position(
                            x: frame.midX,
                            y: frame.maxY - fullSize.height / 2 + heroLift(collapse)
                        )
                        .zIndex(11)
                    }
                } else if transition == .games {
                    ZStack {
                        let dockFrame = pair.target.offsetBy(dx: 0, dy: gameDockOffset)

                        fixedBudgetCard(
                            frame: pair.target,
                            in: proxy
                        )

                        AIGamesCardMorph(
                            progress: progress,
                            isForward: isForward,
                            sourceFrame: pair.source,
                            targetFrame: dockFrame,
                            selectedGames: selectedGames,
                            options: gameOptions,
                            artworkNames: artworkNames
                        )
                    }
                } else {
                    let frame = interpolate(pair.source, pair.target, progress)
                    AITravelingHeroCard(
                        transition: transition,
                        compactness: compactness(for: transition),
                        budget: budget,
                        selectedGames: selectedGames,
                        artworkNames: artworkNames,
                        selectedBuildPreference: selectedBuildPreference,
                        chassisColorPreference: chassisColorPreference,
                        needsWirelessNetwork: needsWirelessNetwork
                    )
                    .frame(width: max(frame.width, 1), height: max(frame.height, 1))
                    .rotation3DEffect(
                        .degrees(-4 * Double(compactness(for: transition))),
                        axis: (x: 1, y: 0, z: 0),
                        perspective: 0.72
                    )
                    .position(x: frame.midX, y: frame.midY)
                    .opacity(cardOpacity(for: transition))
                }
            }
        }
    }

    @ViewBuilder
    private func fixedBudgetCard(frame: CGRect, in proxy: GeometryProxy) -> some View {
        if let anchor = anchors[.budgetFull] {
            let fullFrame = proxy[anchor]
            let targetScale = aiClamp(frame.width / max(fullFrame.width, 1))

            AIBudgetHeroCard(
                budget: .constant(Double(budget)),
                usesNoGpuBuild: .constant(usesNoGpuBuild),
                ownedGPUModel: .constant(ownedGPUModel),
                onPickGPU: {},
                noGPUVisibility: 0
            )
            .frame(width: max(fullFrame.width, 1), height: max(fullFrame.height, 1))
            .scaleEffect(
                heroScale(1, targetScale: targetScale),
                anchor: .bottom
            )
            .rotation3DEffect(
                .degrees(Double(heroAngle(1, finalAngle: 69))),
                axis: (x: 1, y: 0, z: 0),
                anchor: .bottom,
                perspective: 0.78
            )
            .shadow(color: .black.opacity(0.07), radius: 8, y: 4)
            .position(
                x: frame.midX,
                y: frame.maxY - fullFrame.height / 2
            )
        } else {
            AIBudgetDockCard(budget: budget)
                .position(x: frame.midX, y: frame.midY)
        }
    }

    @ViewBuilder
    private func fixedGameCard(in proxy: GeometryProxy) -> some View {
        if let targetFrame = gameCardTargetFrame(in: proxy),
           let gridAnchor = anchors[.gamesGrid] {
            // Keep the real games-grid dimensions as the morph source. Using
            // the compact target dimensions here makes the back-face artwork
            // receive the large-card pre-scale twice and stretch vertically.
            let sourceFrame = proxy[gridAnchor]

            AIGamesCardMorph(
                progress: 1,
                isForward: true,
                sourceFrame: sourceFrame,
                targetFrame: targetFrame,
                selectedGames: selectedGames,
                options: gameOptions,
                artworkNames: artworkNames
            )
            .zIndex(10)
        }
    }

    private func gameCardTargetFrame(in proxy: GeometryProxy) -> CGRect? {
        // The persistent game card must keep the same compact footprint it
        // had after the second-to-third-page morph. The page-three summary is
        // only a 160x34 layout hint; using it as the target shrinks the game
        // card again and makes it appear to drift during the next transition.
        guard let budgetFrame = budgetDockFrame(in: proxy) else { return nil }
        return budgetFrame.offsetBy(dx: 0, dy: gameDockOffset)
    }

    private func gamesSummaryDockFrame(in proxy: GeometryProxy) -> CGRect? {
        guard let summaryAnchor = anchors[.gamesSummary],
              let budgetFrame = budgetDockFrame(in: proxy) else { return nil }
        let summaryFrame = proxy[summaryAnchor].offsetBy(
            dx: 0,
            dy: CGFloat(settledPage - AIBuildStep.purchase.rawValue) * pageHeight
                - dragOffset
        )
        return CGRect(
            x: summaryFrame.minX,
            y: budgetFrame.maxY + gameDockOffset - summaryFrame.height,
            width: summaryFrame.width,
            height: summaryFrame.height
        )
    }

    private func budgetDockFrame(in proxy: GeometryProxy) -> CGRect? {
        guard let budgetAnchor = anchors[.budgetMini] else { return nil }
        return proxy[budgetAnchor].offsetBy(
            dx: 0,
            dy: CGFloat(settledPage - AIBuildStep.scenario.rawValue) * pageHeight
                - dragOffset
        )
    }

    private func framePair(
        for transition: AIHeroTransition,
        in proxy: GeometryProxy
    ) -> (source: CGRect, target: CGRect)? {
        func rect(_ id: AIHeroAnchorID) -> CGRect? {
            guard let anchor = anchors[id] else { return nil }
            return proxy[anchor]
        }

        func restingRect(_ id: AIHeroAnchorID, page: Int) -> CGRect? {
            guard let frame = rect(id) else { return nil }
            return frame.offsetBy(
                dx: 0,
                dy: CGFloat(settledPage - page) * pageHeight - dragOffset
            )
        }

        switch transition {
        case .budget:
            guard let full = restingRect(.budgetFull, page: 0),
                  let mini = restingRect(.budgetMini, page: 1) else { return nil }
            return isForward ? (full, mini) : (mini, full)

        case .games:
            // The page-two budget card is pinned in place while this
            // transition runs, so both the morph target and the visible lower
            // card come from the same screen-space anchor.
            let mini = rect(.budgetMini)
            let grid = rect(.gamesGrid)
            guard let mini, let grid else { return nil }
            return (grid, mini)

        case .preference:
            guard let full = restingRect(.preferenceFull, page: 2),
                  let summary = restingRect(.preferenceSummary, page: 3) else { return nil }
            let alignedSummary: CGRect
            if let gameSummary = gamesSummaryDockFrame(in: proxy) {
                // Land on the same compact footprint as the persistent games
                // card, with its visible bottom edge four points above the
                // target frame used by the games morph.
                alignedSummary = CGRect(
                    x: gameSummary.minX,
                    y: gameSummary.minY - 4,
                    width: gameSummary.width,
                    height: gameSummary.height
                )
            } else {
                alignedSummary = summary
            }
            return isForward ? (full, alignedSummary) : (alignedSummary, full)
        }
    }

    private var budgetDockedTravel: (offset: CGFloat, opacity: CGFloat) {
        guard pageHeight > 1 else { return (0, 1) }
        if settledPage == 1, dragOffset < 0 {
            let progress = aiClamp(-dragOffset / pageHeight)
            return (dragOffset, 1 - progress)
        }
        if settledPage == 2, dragOffset > 0 {
            let progress = aiClamp(dragOffset / pageHeight)
            return (dragOffset - pageHeight, progress)
        }
        return (0, 1)
    }

    private func compactness(for transition: AIHeroTransition) -> CGFloat {
        switch transition {
        case .games:
            return 1
        case .budget, .preference:
            return isForward ? progress : 1 - progress
        }
    }

    private func cardOpacity(for transition: AIHeroTransition) -> CGFloat {
        guard transition == .games else { return 1 }
        if isForward {
            return aiClamp((progress - 0.08) / 0.32)
        }
        return aiClamp((1 - progress) / 0.32)
    }

    private func interpolate(_ source: CGRect, _ target: CGRect, _ rawProgress: CGFloat) -> CGRect {
        let p = aiClamp(rawProgress)
        return CGRect(
            x: source.minX + (target.minX - source.minX) * p,
            y: source.minY + (target.minY - source.minY) * p,
            width: source.width + (target.width - source.width) * p,
            height: source.height + (target.height - source.height) * p
        )
    }

    private func heroScale(_ collapse: CGFloat, targetScale: CGFloat) -> CGFloat {
        let p = aiClamp(collapse)
        let finalScale = min(0.86, max(0.36, targetScale))
        let earlyScale = max(finalScale, 0.97)
        let middleScale = max(finalScale, 0.82)
        let lateScale = max(finalScale, 0.58)
        if p <= 0.15 {
            return 1 + (earlyScale - 1) * aiSmoothStep(p / 0.15)
        }
        if p <= 0.45 {
            return earlyScale + (middleScale - earlyScale)
                * aiSmoothStep((p - 0.15) / 0.30)
        }
        if p <= 0.75 {
            return middleScale + (lateScale - middleScale)
                * aiSmoothStep((p - 0.45) / 0.30)
        }
        return lateScale + (finalScale - lateScale)
            * aiSmoothStep((p - 0.75) / 0.25)
    }

    private func heroLift(_ collapse: CGFloat) -> CGFloat {
        let p = aiClamp(collapse)
        if p <= 0.15 {
            return -8 * aiSmoothStep(p / 0.15)
        }
        return -8 * (1 - aiSmoothStep((p - 0.15) / 0.85))
    }

    private func heroAngle(_ collapse: CGFloat, finalAngle: CGFloat) -> CGFloat {
        let p = aiClamp(collapse)
        let earlyAngle = finalAngle * (5 / 69)
        let middleAngle = finalAngle * (33 / 69)
        let lateAngle = finalAngle * (60 / 69)
        if p <= 0.15 {
            return earlyAngle * aiSmoothStep(p / 0.15)
        }
        if p <= 0.45 {
            return earlyAngle + (middleAngle - earlyAngle)
                * aiSmoothStep((p - 0.15) / 0.30)
        }
        if p <= 0.75 {
            return middleAngle + (lateAngle - middleAngle)
                * aiSmoothStep((p - 0.45) / 0.30)
        }
        return lateAngle + (finalAngle - lateAngle)
            * aiSmoothStep((p - 0.75) / 0.25)
    }
}

private struct AIGamesCardMorph: View {
    let progress: CGFloat
    let isForward: Bool
    let sourceFrame: CGRect
    let targetFrame: CGRect
    let selectedGames: [String]
    let options: [String]
    let artworkNames: [String: String]

    var body: some View {
        let morphProgress = isForward ? aiClamp(progress) : 1 - aiClamp(progress)
        let cardTarget = targetFrame
        let finalAngle = CGFloat(69)
        let projectedHeight = max(1, cardTarget.height - 6)
        let perspectiveHeight = projectedHeight / max(0.1, CGFloat(cos(Double(finalAngle) * .pi / 180)))
        // Match the budget card width exactly and end just above it, leaving
        // one clean lower edge visible without side slivers.
        let targetSize = CGSize(
            width: max(1, cardTarget.width),
            height: perspectiveHeight
        )
        // Shrink the shared surface continuously while it turns. The y scale
        // compensates for the shared 3D perspective so the visible height
        // matches the fixed budget card rather than collapsing to a sliver.
        let sizeProgress = aiSmoothStep(morphProgress / 0.95)
        let dockProgress = aiSmoothStep((morphProgress - 0.55) / 0.45)
        let cornerRadius = 24 - 2 * dockProgress
        let widthScale = 1 + (targetSize.width / max(sourceFrame.width, 1) - 1) * sizeProgress
        let heightScale = 1 + (targetSize.height / max(sourceFrame.height, 1) - 1) * sizeProgress
        let bottom = sourceFrame.maxY
            + (cardTarget.maxY - sourceFrame.maxY) * morphProgress
            - 4 * dockProgress

        AIGamesDoubleSidedCard(
            options: options,
            artworkNames: artworkNames,
            selectedGames: .constant(Set(selectedGames)),
            flipProgress: morphProgress,
            fixedSize: sourceFrame.size,
            cornerRadius: cornerRadius
        )
        .frame(width: max(sourceFrame.width, 1), height: max(sourceFrame.height, 1))
        .scaleEffect(x: widthScale, y: heightScale, anchor: .bottom)
        .rotation3DEffect(
            .degrees(Double(finalAngle * dockProgress)),
            axis: (x: 1, y: 0, z: 0),
            anchor: .bottom,
            perspective: 0.78
        )
        .shadow(
            color: .black.opacity(0.12 + 0.10 * aiSmoothStep(morphProgress / 0.15)),
            radius: 16 - 7 * sizeProgress,
            y: 10 - 5 * sizeProgress
        )
        .position(
            x: sourceFrame.midX + (cardTarget.midX - sourceFrame.midX) * morphProgress,
            y: bottom - sourceFrame.height / 2
        )
        .zIndex(10)
        .allowsHitTesting(false)
    }

}

private struct AITravelingHeroCard: View {
    let transition: AIHeroTransition
    let compactness: CGFloat
    let budget: Int
    let selectedGames: [String]
    let artworkNames: [String: String]
    let selectedBuildPreference: BuildPreference
    let chassisColorPreference: String
    let needsWirelessNetwork: Bool

    private var compactProgress: CGFloat { aiClamp(compactness) }
    private var contentProgress: CGFloat {
        // Keep the detailed copy legible until the card is mostly compact,
        // then replace it as one unit instead of leaving text behind.
        aiSmoothStep((compactProgress - 0.38) / 0.34)
    }

    var body: some View {
        GeometryReader { proxy in
            let radius = 22 - 10 * compactProgress
            ZStack {
                backLayers(radius: radius)

                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .stroke(Color.black.opacity(0.05), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.12 - 0.04 * compactProgress), radius: 17 - 8 * compactProgress, y: 10 - 4 * compactProgress)

                content
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch transition {
        case .budget:
            ZStack {
                budgetExpanded
                    .opacity(1 - contentProgress)
                budgetCompact
                    .opacity(contentProgress)
            }
        case .games:
            gamesCompact
        case .preference:
            ZStack {
                preferenceExpanded
                    .opacity(1 - contentProgress)
                preferenceCompact
                    .opacity(contentProgress)
            }
        }
    }

    @ViewBuilder
    private func backLayers(radius: CGFloat) -> some View {
        if transition == .budget {
            ForEach(0..<3, id: \.self) { index in
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(Color.white.opacity(0.82 - 0.08 * compactProgress))
                    .offset(y: CGFloat(index + 1) * 7 * (1 - compactProgress))
                    .opacity(1 - compactProgress)
            }
        } else if transition == .preference {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(Color.white.opacity(0.86))
                .offset(y: 10 * (1 - compactProgress))
                .opacity(1 - compactProgress)
        } else {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(Color.white.opacity(0.82))
                .offset(y: 7 * (1 - compactProgress))
                .opacity(1 - compactProgress)
        }
    }

    private var budgetExpanded: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("装机预算")
                    .font(.system(size: 19, weight: .bold))
                Spacer()
                Text("STEP 01")
                    .font(.system(size: 14))
                    .foregroundStyle(Color(red: 0.30, green: 0.36, blue: 0.46))
            }

            Text("¥ " + budget.formatted())
                .font(.system(size: 38, weight: .heavy))
                .monospacedDigit()
                .frame(maxWidth: .infinity)
                .padding(.top, 25)

            HStack {
                Text("¥ 3,000")
                Spacer()
                Text("¥ 30,000")
            }
            .font(.system(size: 13))
            .foregroundStyle(Color(red: 0.30, green: 0.36, blue: 0.46))
            .padding(.top, 19)

            HStack(spacing: 10) {
                Circle().stroke(Color.black.opacity(0.14), lineWidth: 1).frame(width: 34, height: 34)
                Capsule().fill(Color.black.opacity(0.88)).frame(height: 4)
                Circle().stroke(Color.black.opacity(0.14), lineWidth: 1).frame(width: 34, height: 34)
            }
            .padding(.top, 11)

            Divider().overlay(Color.black.opacity(0.08)).padding(.top, 18)

            HStack(spacing: 13) {
                Image(systemName: "display")
                    .font(.system(size: 22))
                    .frame(width: 34, height: 34)
                VStack(alignment: .leading, spacing: 4) {
                    Text("无显卡方案")
                        .font(.system(size: 17, weight: .semibold))
                    Text("不单独购买独立显卡")
                        .font(.system(size: 14))
                        .foregroundStyle(Color(red: 0.30, green: 0.36, blue: 0.46))
                }
                Spacer()
                Capsule().fill(Color(red: 0.83, green: 0.84, blue: 0.87)).frame(width: 53, height: 31)
            }
            .padding(.top, 17)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
    }

    private var budgetCompact: some View {
        VStack(spacing: 1) {
            HStack(alignment: .firstTextBaseline) {
                Text("装机预算")
                    .font(.system(size: 8, weight: .bold))
                Spacer(minLength: 0)
                Text("STEP 01")
                    .font(.system(size: 8))
                    .foregroundStyle(Color(red: 0.30, green: 0.36, blue: 0.46))
            }

            Text("¥ " + budget.formatted())
                .font(.system(size: 17, weight: .heavy))
                .monospacedDigit()

            HStack(spacing: 7) {
                Circle()
                    .fill(Color.white)
                    .frame(width: 11, height: 11)
                    .overlay(Circle().stroke(Color.black.opacity(0.12), lineWidth: 0.8))
                    .overlay(Text("−").font(.system(size: 8, weight: .bold)))
                Capsule()
                    .fill(Color.black.opacity(0.88))
                    .frame(height: 2)
                Circle()
                    .fill(Color.white)
                    .frame(width: 11, height: 11)
                    .overlay(Circle().stroke(Color.black.opacity(0.12), lineWidth: 0.8))
                    .overlay(Text("+").font(.system(size: 8, weight: .bold)))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }

    private var gamesCompact: some View {
        HStack(spacing: 5) {
            ForEach(Array(selectedGames.prefix(3)), id: \.self) { game in
                gameImage(for: game)
            }
            if selectedGames.count > 3 {
                Text("…")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color(red: 0.42, green: 0.45, blue: 0.50))
                    .frame(width: 28, height: 28)
                    .background(Color(red: 0.90, green: 0.91, blue: 0.93), in: RoundedRectangle(cornerRadius: 7))
            }
        }
        .padding(.horizontal, 13)
    }

    @ViewBuilder
    private func gameImage(for game: String) -> some View {
        if game == "什么都玩" {
            GameArtworkCollage()
                .frame(width: 28, height: 28)
                .clipShape(RoundedRectangle(cornerRadius: 7))
        } else if let name = artworkNames[game] {
            Image(name)
                .resizable()
                .scaledToFill()
                .frame(width: 28, height: 28)
                .clipShape(RoundedRectangle(cornerRadius: 7))
        }
    }

    private var preferenceExpanded: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("偏好与外观").font(.system(size: 19, weight: .bold))
                Spacer()
                Text("STEP 03").font(.system(size: 14)).foregroundStyle(Color(red: 0.30, green: 0.36, blue: 0.46))
            }

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("无线网络").font(.system(size: 17, weight: .semibold))
                    Text("房间没有墙上网口时建议打开").font(.system(size: 14)).foregroundStyle(Color(red: 0.30, green: 0.36, blue: 0.46))
                }
                Spacer()
                AIToggle(isOn: .constant(needsWirelessNetwork))
            }
            .padding(.top, 25)

            Divider().overlay(Color.black.opacity(0.08)).padding(.top, 22)
            Text("装机偏好").font(.system(size: 17, weight: .semibold)).padding(.top, 22)
            AIChoiceTrack(
                options: BuildPreference.aiBuildOptions.map(\.title),
                selection: .constant(selectedBuildPreference.title)
            )
                .padding(.top, 13)

            Divider().overlay(Color.black.opacity(0.08)).padding(.top, 21)
            Text("主机颜色").font(.system(size: 17, weight: .semibold)).padding(.top, 21)
            AIChoiceTrack(
                options: ["曜石黑", "纯净白"],
                selection: .constant(chassisColorPreference),
                showsColorDots: true
            )
                .padding(.top, 13)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
    }

    private var preferenceCompact: some View {
        HStack(spacing: 8) {
            Text("偏好与外观").font(.system(size: 12, weight: .semibold))
            Circle()
                .fill(chassisColorPreference == "曜石黑" ? Color.black : Color.white)
                .frame(width: 16, height: 16)
                .overlay(Circle().stroke(Color.black.opacity(0.16), lineWidth: 1))
            Text("\(selectedBuildPreference.title) · \(chassisColorPreference) · \(needsWirelessNetwork ? "无线网络" : "有线网络")")
                .font(.system(size: 12, weight: .semibold))
                .lineLimit(1)
            if needsWirelessNetwork { Image(systemName: "wifi").font(.system(size: 13, weight: .bold)) }
            Spacer(minLength: 2)
            Text("STEP 03").font(.system(size: 11)).foregroundStyle(Color(red: 0.30, green: 0.36, blue: 0.46))
        }
        .padding(.horizontal, 13)
    }

}

private func aiSmoothStep(_ value: CGFloat) -> CGFloat {
    let p = aiClamp(value)
    return p * p * (3 - 2 * p)
}

private struct AIWizardHeader: View {
    let currentStep: Int
    let onBack: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 23, weight: .semibold))
                    .foregroundStyle(.black)
                    .frame(width: 30, height: 34)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("返回")

            Text("AI 写配置")
                .font(.system(size: 23, weight: .bold))
                .foregroundStyle(.black)

            Spacer(minLength: 0)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(String(format: "%02d", currentStep + 1))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.black)
                Text("/ 04")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(Color(red: 0.30, green: 0.35, blue: 0.44))
            }
        }
        .frame(height: 39)
    }
}

private struct AIWizardProgress: View {
    let currentStep: Int

    var body: some View {
        HStack(spacing: 21) {
            ForEach(0..<4, id: \.self) { index in
                Capsule()
                    .fill(index == currentStep ? Color.black : index < currentStep ? Color(red: 0.32, green: 0.37, blue: 0.46) : Color(red: 0.80, green: 0.81, blue: 0.84))
                    .frame(width: 66)
                    .frame(height: 2)
            }
        }
        .frame(maxWidth: .infinity)
        .animation(.easeInOut(duration: 0.22), value: currentStep)
    }
}

private struct AIPageHeading: View {
    let title: String
    let subtitle: String
    var textAlignment: TextAlignment = .center
    var alignment: HorizontalAlignment = .center

    var body: some View {
        VStack(alignment: alignment, spacing: 8) {
            Text(title)
                .font(.system(size: 29, weight: .bold))
                .foregroundStyle(.black)
                .multilineTextAlignment(textAlignment)
            Text(subtitle)
                .font(.system(size: 17, weight: .regular))
                .foregroundStyle(Color(red: 0.30, green: 0.36, blue: 0.46))
                .multilineTextAlignment(textAlignment)
        }
    }
}

private struct AIContinueHint: View {
    var body: some View {
        VStack(spacing: 7) {
            Text("继续下滑")
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(Color(red: 0.30, green: 0.36, blue: 0.46))

            ZStack {
                Image(systemName: "chevron.down")
                    .font(.system(size: 19, weight: .medium))
                    .offset(y: -3)
                Image(systemName: "chevron.down")
                    .font(.system(size: 19, weight: .medium))
                    .offset(y: 7)
            }
            .foregroundStyle(Color(red: 0.30, green: 0.36, blue: 0.46))
            .frame(height: 23)
        }
        .accessibilityLabel("继续下滑")
    }
}

private struct AIBudgetWizardPage: View {
    @Binding var budget: Double
    @Binding var usesNoGpuBuild: Bool
    @Binding var ownedGPUModel: String
    let collapseProgress: CGFloat
    let hidesHeroCard: Bool
    let onPickGPU: () -> Void

    private var titleOpacity: CGFloat { 1 - collapseProgress }
    private var coveredProgress: CGFloat {
        aiSmoothStep(collapseProgress / 0.24)
    }
    private var tierVisibility: CGFloat {
        1 - aiSmoothStep((collapseProgress - 0.16) / 0.08)
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 8)

            VStack(spacing: 8) {
                AIPageHeading(
                    title: "先定预算，\n剩下的交给 AI。",
                    subtitle: "AI 会在预算范围内平衡整套配置",
                    textAlignment: .leading,
                    alignment: .leading
                )
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .opacity(titleOpacity)
            .offset(y: -30 * collapseProgress)

            Spacer(minLength: 48)

            AIBudgetHeroCard(
                budget: $budget,
                usesNoGpuBuild: $usesNoGpuBuild,
                ownedGPUModel: $ownedGPUModel,
                onPickGPU: onPickGPU
            )
            .aiHeroAnchor(.budgetFull)
            .opacity(hidesHeroCard ? 0 : 1)

            Spacer(minLength: 50)

            AIBudgetTierView(budget: budget)
                .scaleEffect(0.8)
                .opacity(tierVisibility)
                .offset(y: -118 * coveredProgress)

            Spacer(minLength: 40)
            AIContinueHint()
                .opacity(1 - aiSmoothStep(collapseProgress / 0.18))
                .offset(y: -118 * coveredProgress)
        }
        .offset(y: -24)
        .padding(.horizontal, 30)
        .padding(.bottom, 6)
    }
}

private struct AIBudgetHeroCard: View {
    @Binding var budget: Double
    @Binding var usesNoGpuBuild: Bool
    @Binding var ownedGPUModel: String
    let onPickGPU: () -> Void
    var noGPUVisibility: CGFloat = 1

    private let minimumBudget = 3000.0
    private let maximumBudget = 30000.0

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline) {
                    Text("装机预算")
                        .font(.system(size: 19, weight: .bold))
                    Spacer()
                    Text("STEP 01")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(Color(red: 0.30, green: 0.36, blue: 0.46))
                }

                Text("¥ " + Int(budget).formatted())
                    .font(.system(size: 38, weight: .heavy))
                    .monospacedDigit()
                    .frame(maxWidth: .infinity)
                    .padding(.top, 25)

                HStack {
                    Text("¥ 3,000")
                    Spacer()
                    Text("¥ 30,000")
                }
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(Color(red: 0.30, green: 0.36, blue: 0.46))
                .padding(.top, 19)

                HStack(spacing: 10) {
                    BudgetStepButton(systemName: "minus", isEnabled: budget > minimumBudget) {
                        withAnimation(.easeInOut(duration: 0.24)) {
                            budget = max(minimumBudget, budget - 100)
                        }
                    }

                    Slider(value: $budget, in: minimumBudget...maximumBudget, step: 100)
                        .tint(.black)

                    BudgetStepButton(systemName: "plus", isEnabled: budget < maximumBudget) {
                        withAnimation(.easeInOut(duration: 0.24)) {
                            budget = min(maximumBudget, budget + 100)
                        }
                    }
                }
                .padding(.top, 11)

                Divider()
                    .overlay(Color.black.opacity(0.08))
                    .padding(.top, 18)
                    .opacity(noGPUVisibility)

                HStack(spacing: 13) {
                    Button(action: { if usesNoGpuBuild { onPickGPU() } }) {
                        HStack(spacing: 13) {
                            Image("NoGPUArtwork")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 44, height: 44)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("无显卡方案")
                                    .font(.system(size: 15, weight: .semibold))
                                Text(usesNoGpuBuild
                                     ? (ownedGPUModel.isEmpty ? "请选择自备显卡型号" : ownedGPUModel)
                                     : "不单独购买独立显卡")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Color(red: 0.30, green: 0.36, blue: 0.46))
                                    .lineLimit(1)
                            }
                        }
                        .foregroundStyle(.black)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    Spacer(minLength: 4)
                    AIToggle(isOn: $usesNoGpuBuild)
                }
                .padding(.top, 17)
                .opacity(noGPUVisibility)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 21)
            .background {
                ZStack(alignment: .top) {
                    // Two thin back plates plus the face make three visible
                    // card layers in total.
                    ForEach(Array(stride(from: 1, through: 0, by: -1)), id: \.self) { layer in
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(Color.white.opacity(0.96 - Double(layer) * 0.05))
                            .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.black.opacity(0.06), lineWidth: 1))
                            .offset(y: CGFloat(layer + 1) * 8)
                            .shadow(color: .black.opacity(0.10), radius: 8, y: 5)
                    }

                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(Color.white)
                        .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.black.opacity(0.045), lineWidth: 1))
                        .shadow(color: .black.opacity(0.12), radius: 18, y: 10)
                }
            }
            .frame(maxWidth: .infinity)
    }
}

private struct AIBudgetTierView: View {
    let budget: Double

    private var tierIndex: Int {
        switch budget {
        case ..<5000: 0
        case ..<6500: 1
        case ..<9000: 2
        default: 3
        }
    }

    private var tierName: String { ["入门", "主流", "中高端", "高端"][tierIndex] }

    private var rangeText: String {
        ["约 ¥3,000—¥5,000 档位", "约 ¥5,000—¥6,500 档位", "约 ¥6,000—¥9,000 档位", "约 ¥9,000 以上"][tierIndex]
    }

    var body: some View {
        VStack(spacing: 13) {
            HStack {
                Text("当前预算档位")
                    .font(.system(size: 18, weight: .semibold))
                Spacer()
                Text(tierName)
                    .font(.system(size: 19, weight: .bold))
            }

            VStack(spacing: 8) {
                GeometryReader { proxy in
                    let trackWidth = proxy.size.width
                    let markerX = trackWidth * budgetProgress

                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color(red: 0.78, green: 0.80, blue: 0.84))
                            .frame(height: 1)

                        Rectangle()
                            .fill(.black)
                            .frame(width: markerX, height: 2)

                        ForEach(0..<4, id: \.self) { index in
                            Circle()
                                .fill(.white)
                                .frame(width: 9, height: 9)
                                .overlay(
                                    Circle().stroke(
                                        Color(red: 0.78, green: 0.80, blue: 0.84),
                                        lineWidth: 1.5
                                    )
                                )
                                .position(
                                    x: trackWidth * CGFloat(index) / 3,
                                    y: proxy.size.height / 2
                                )
                        }

                        Circle()
                            .fill(.black)
                            .frame(width: 11, height: 11)
                            .position(x: markerX, y: proxy.size.height / 2)
                    }
                }
                .frame(height: 12)

                HStack {
                    ForEach(["入门", "主流", "中高端", "高端"], id: \.self) { name in
                        Text(name)
                            .font(.system(size: 13, weight: .regular))
                            .frame(maxWidth: .infinity)
                    }
                }
            }

            Text(rangeText)
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(Color(red: 0.30, green: 0.36, blue: 0.46))
                .padding(.top, 4)
        }
        .foregroundStyle(.black)
    }

    private var budgetProgress: CGFloat {
        let value = CGFloat(min(max(budget, 3000), 9000))
        let segment: CGFloat
        let local: CGFloat

        switch value {
        case ..<5000:
            segment = 0
            local = (value - 3000) / 2000
        case ..<6500:
            segment = 1
            local = (value - 5000) / 1500
        case ..<9000:
            segment = 2
            local = (value - 6500) / 2500
        default:
            segment = 3
            local = 0
        }

        return min(1, max(0, (segment + local) / 3))
    }
}

private struct AIGamesWizardPage: View {
    let budget: Int
    let options: [String]
    let artworkNames: [String: String]
    @Binding var selectedGames: Set<String>
    let budgetCardOpacity: CGFloat
    let hidesBudgetCard: Bool
    let gamesGridPinOffset: CGFloat
    let budgetCardPinOffset: CGFloat
    let gamesGridOpacity: CGFloat
    let headingOpacity: CGFloat

    var body: some View {
        VStack(spacing: 0) {
            AIBudgetMiniCard(budget: budget)
                .aiHeroAnchor(.budgetMini)
                .opacity(budgetCardOpacity)
                .opacity(hidesBudgetCard ? 0 : 1)
                .padding(.top, 8)
                .offset(y: budgetCardPinOffset)

            Spacer(minLength: 34)

            AIPageHeading(
                title: "选择你常玩的游戏",
                subtitle: "可多选，AI 会按游戏需求调整配置"
            )
            .opacity(headingOpacity)

            HStack {
                Spacer()
                Text("已选 \(selectedGames.count)")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(Color(red: 0.30, green: 0.36, blue: 0.46))
            }
            .padding(.top, 18)
            .opacity(headingOpacity)

            AIGamesDoubleSidedCard(
                options: options,
                artworkNames: artworkNames,
                selectedGames: $selectedGames,
                flipProgress: 0,
                fixedSize: nil
            )
            .aiHeroAnchor(.gamesGrid)
            .padding(.top, 11)
            .layoutPriority(1)
            .offset(y: gamesGridPinOffset)
            .opacity(gamesGridOpacity)

            Spacer(minLength: 40)
            AIContinueHint()
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 4)
    }
}

private struct AIBudgetMiniCard: View {
    let budget: Int

    var body: some View {
        AIBudgetDockCard(budget: budget)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("装机预算，预算 \(budget) 元")
    }
}

private struct AIBudgetDockCard: View {
    let budget: Int

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.black.opacity(0.05), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.11), radius: 9, y: 6)

            VStack(spacing: 1) {
                HStack(alignment: .firstTextBaseline) {
                    Text("装机预算")
                        .font(.system(size: 7, weight: .bold))
                    Spacer(minLength: 0)
                    Text("STEP 01")
                        .font(.system(size: 7, weight: .regular))
                        .foregroundStyle(Color(red: 0.30, green: 0.36, blue: 0.46))
                }

                Text("¥ " + budget.formatted())
                    .font(.system(size: 17, weight: .heavy))
                    .monospacedDigit()

                HStack(spacing: 7) {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 11, height: 11)
                        .overlay(Circle().stroke(Color.black.opacity(0.12), lineWidth: 0.8))
                        .overlay(Text("−").font(.system(size: 8, weight: .bold)))

                    Capsule()
                        .fill(Color.black.opacity(0.88))
                        .frame(height: 2)

                    Circle()
                        .fill(Color.white)
                        .frame(width: 11, height: 11)
                        .overlay(Circle().stroke(Color.black.opacity(0.12), lineWidth: 0.8))
                        .overlay(Text("+").font(.system(size: 8, weight: .bold)))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
        }
        .frame(width: 160, height: 44)
        .rotationEffect(.degrees(-5))
    }
}

private struct AIGamesDoubleSidedCard: View {
    let options: [String]
    let artworkNames: [String: String]
    @Binding var selectedGames: Set<String>
    let flipProgress: CGFloat
    let fixedSize: CGSize?
    let cornerRadius: CGFloat

    init(
        options: [String],
        artworkNames: [String: String],
        selectedGames: Binding<Set<String>>,
        flipProgress: CGFloat,
        fixedSize: CGSize?,
        cornerRadius: CGFloat = 24
    ) {
        self.options = options
        self.artworkNames = artworkNames
        self._selectedGames = selectedGames
        self.flipProgress = flipProgress
        self.fixedSize = fixedSize
        self.cornerRadius = cornerRadius
    }

    private var clampedFlip: CGFloat { aiClamp(flipProgress) }

    var body: some View {
        faces
        .rotation3DEffect(
            .degrees(Double(clampedFlip) * 180),
            axis: (x: 1, y: 0, z: 0),
            perspective: 0.85
        )
    }

    private var front: some View {
        AIGameCardSurface(cornerRadius: cornerRadius) {
            AIGameArtworkGrid(
                options: options,
                artworkNames: artworkNames,
                selectedGames: $selectedGames
            )
        }
    }

    @ViewBuilder
    private var faces: some View {
        if let fixedSize {
            ZStack {
                front
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .opacity(clampedFlip <= 0.5 ? 1 : 0)

                back
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    // The shared surface flips around its horizontal axis.
                    // Mirror only the back's contents so its text and icons
                    // stay upright.
                    .scaleEffect(y: -1)
                    .opacity(clampedFlip > 0.5 ? 1 : 0)
            }
            .frame(width: fixedSize.width, height: fixedSize.height)
        } else {
            ZStack {
                front
                    .opacity(clampedFlip <= 0.5 ? 1 : 0)

                back
                    .scaleEffect(y: -1)
                    .opacity(clampedFlip > 0.5 ? 1 : 0)
            }
        }
    }

    private var back: some View {
        AIGameCardSurface(cornerRadius: cornerRadius) {
            AIGameSelectionBack(
                selectedGames: options.filter { selectedGames.contains($0) },
                artworkNames: artworkNames
            )
        }
    }
}

private struct AIGameCardSurface<Content: View>: View {
    let cornerRadius: CGFloat
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                ZStack(alignment: .top) {
                    ForEach(Array(stride(from: 1, through: 0, by: -1)), id: \.self) { layer in
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(Color.white.opacity(0.96 - Double(layer) * 0.05))
                            .overlay(
                                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                    .stroke(Color.black.opacity(0.06), lineWidth: 1)
                            )
                            .offset(y: CGFloat(layer + 1) * 8)
                            .shadow(color: .black.opacity(0.10), radius: 8, y: 5)
                    }

                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(Color.white)
                        .overlay(
                            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                .stroke(Color.black.opacity(0.045), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.12), radius: 18, y: 10)
                }
            )
    }
}

private struct AIGameSelectionBack: View {
    let selectedGames: [String]
    let artworkNames: [String: String]

    private var iconSize: CGFloat {
        switch selectedGames.count {
        case 1...2: 88
        case 3: 80
        default: 72
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            ForEach(Array(selectedGames.prefix(3)), id: \.self) { game in
                gameImage(for: game)
            }
            if selectedGames.count > 3 {
                Text("…")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(Color(red: 0.42, green: 0.45, blue: 0.50))
                    .frame(width: iconSize, height: iconSize)
                    .background(Color(red: 0.90, green: 0.91, blue: 0.93), in: RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(.horizontal, 8)
        .frame(maxWidth: 420, minHeight: 52)
        .scaleEffect(y: 4.0)
    }

    @ViewBuilder
    private func gameImage(for game: String) -> some View {
        if game == "什么都玩" {
            GameArtworkCollage()
                .frame(width: iconSize, height: iconSize)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        } else if let name = artworkNames[game] {
            Image(name)
                .resizable()
                .scaledToFill()
                .frame(width: iconSize, height: iconSize)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}

private struct AIGameArtworkGrid: View {
    let options: [String]
    let artworkNames: [String: String]
    @Binding var selectedGames: Set<String>

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 9), count: 4)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 24) {
            ForEach(Array(options.enumerated()), id: \.element) { index, option in
                AIGameArtworkTile(
                    title: option,
                    artworkName: artworkNames[option],
                    isSelected: selectedGames.contains(option)
                ) {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                        if selectedGames.contains(option) {
                            selectedGames.remove(option)
                        } else {
                            selectedGames.insert(option)
                        }
                    }
                }
            }
        }
    }
}

private struct AIGameArtworkTile: View {
    let title: String
    let artworkName: String?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            artwork
                .aspectRatio(1, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(isSelected ? Color.black.opacity(0.72) : Color.white.opacity(0.88), lineWidth: isSelected ? 1.8 : 1)
                )
                .shadow(color: .black.opacity(isSelected ? 0.20 : 0.10), radius: isSelected ? 10 : 7, y: isSelected ? 7 : 4)
        }
        .buttonStyle(Micro3DPressButtonStyle())
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder
    private var artwork: some View {
        if title == "什么都玩" {
            GameArtworkCollage()
        } else if let artworkName {
            Image(artworkName)
                .resizable()
                .scaledToFill()
        } else {
            Color.white
        }
    }
}

private struct AIPreferenceWizardPage: View {
    let selectedGames: Set<String>
    let options: [String]
    let artworkNames: [String: String]
    @Binding var needsWirelessNetwork: Bool
    @Binding var selectedBuildPreference: BuildPreference
    @Binding var chassisColorPreference: String
    let collapseProgress: CGFloat
    let gameCardOpacity: CGFloat
    let hidesPreferenceCard: Bool
    let hidesGameSummaryCard: Bool
    let contentOpacity: CGFloat

    private var selectedGameNames: [String] {
        options.filter { selectedGames.contains($0) }
    }

    private var selectionSummary: String {
        "\(selectedBuildPreference.title) · \(chassisColorPreference) · \(needsWirelessNetwork ? "无线网络" : "有线网络")"
    }

    var body: some View {
        VStack(spacing: 0) {
            AIGameSummaryCard(
                games: selectedGameNames,
                artworkNames: artworkNames
            )
            .aiHeroAnchor(.gamesSummary)
            .opacity(hidesGameSummaryCard ? 0 : gameCardOpacity)
            .padding(.top, 8)
            .offset(y: -20)

            Group {
                Spacer(minLength: 57)
                AIPageHeading(title: "确定装机偏好", subtitle: "再补充外观与连接方式")
                Spacer(minLength: 18)

                AIPreferenceCard(
                    needsWirelessNetwork: $needsWirelessNetwork,
                    selectedBuildPreference: $selectedBuildPreference,
                    chassisColorPreference: $chassisColorPreference,
                    collapseProgress: collapseProgress
                )
                .aiHeroAnchor(.preferenceFull)
                .opacity(hidesPreferenceCard ? 0 : 1)

                AISummaryRow(label: "当前选择", value: selectionSummary)
                    .padding(.top, 15)

                Spacer(minLength: 72)
                AIContinueHint()
            }
            .opacity(contentOpacity)
        }
        .padding(.horizontal, 30)
        .padding(.bottom, 4)
    }
}

private struct AIGameSummaryCard: View {
    let games: [String]
    let artworkNames: [String: String]

    private var shownGames: [String] { Array(games.prefix(3)) }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.82))
                .offset(y: 7)
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.white)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.black.opacity(0.05), lineWidth: 1))
                .shadow(color: .black.opacity(0.11), radius: 9, y: 6)

            HStack(spacing: 5) {
                ForEach(shownGames, id: \.self) { game in
                    gameImage(for: game)
                }
                if games.count > 3 {
                    Text("…")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color(red: 0.42, green: 0.45, blue: 0.50))
                        .frame(width: 22, height: 22)
                        .background(Color(red: 0.90, green: 0.91, blue: 0.93), in: RoundedRectangle(cornerRadius: 6))
                }
            }
        }
        .frame(width: 160, height: 34)
        .rotationEffect(.degrees(-5))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("已选 \(games.count) 款游戏")
    }

    @ViewBuilder
    private func gameImage(for game: String) -> some View {
        if game == "什么都玩" {
            GameArtworkCollage()
                .frame(width: 22, height: 22)
                .clipShape(RoundedRectangle(cornerRadius: 7))
        } else if let name = artworkNames[game] {
            Image(name)
                .resizable()
                .scaledToFill()
                .frame(width: 22, height: 22)
                .clipShape(RoundedRectangle(cornerRadius: 7))
        }
    }
}

private struct AIPreferenceCard: View {
    @Binding var needsWirelessNetwork: Bool
    @Binding var selectedBuildPreference: BuildPreference
    @Binding var chassisColorPreference: String
    let collapseProgress: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline) {
                    Text("偏好与外观")
                        .font(.system(size: 19, weight: .bold))
                    Spacer()
                    Text("STEP 03")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(Color(red: 0.30, green: 0.36, blue: 0.46))
                }

                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("无线网络")
                            .font(.system(size: 17, weight: .semibold))
                        Text("房间没有墙上网口时建议打开")
                            .font(.system(size: 14))
                            .foregroundStyle(Color(red: 0.30, green: 0.36, blue: 0.46))
                    }
                    Spacer(minLength: 8)
                    AIToggle(isOn: $needsWirelessNetwork)
                }
                .padding(.top, 25)

                Divider()
                    .overlay(Color.black.opacity(0.08))
                    .padding(.top, 22)

                Text("装机偏好")
                    .font(.system(size: 17, weight: .semibold))
                    .padding(.top, 22)

                AIChoiceTrack(
                    options: BuildPreference.aiBuildOptions.map(\.title),
                    selection: Binding(
                        get: { selectedBuildPreference.title },
                        set: { title in
                            selectedBuildPreference = BuildPreference.allCases.first { $0.title == title } ?? selectedBuildPreference
                        }
                    )
                )
                .padding(.top, 13)

                Divider()
                    .overlay(Color.black.opacity(0.08))
                    .padding(.top, 21)

                Text("主机颜色")
                    .font(.system(size: 17, weight: .semibold))
                    .padding(.top, 21)

                AIChoiceTrack(
                    options: ["曜石黑", "纯净白"],
                    selection: $chassisColorPreference,
                    showsColorDots: true
                )
                .padding(.top, 13)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 20)
            .background(.white, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.black.opacity(0.045), lineWidth: 1))
            .shadow(color: .black.opacity(0.11), radius: 17, y: 10)
            .opacity(1 - 0.22 * collapseProgress)
            .scaleEffect(1 - 0.40 * collapseProgress)
            .rotation3DEffect(
                .degrees(-7 * Double(collapseProgress)),
                axis: (x: 1, y: 0, z: 0),
                perspective: 0.72
            )
            .offset(y: -65 * collapseProgress)
        // Keep the thin backplate tied to the card's measured bounds. A
        // standalone shape in the ZStack can expand to the page's full
        // vertical proposal and leave a large empty white slab underneath.
        .background(alignment: .top) {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.86))
                .offset(y: 10 * (1 - collapseProgress))
                .opacity(1 - 0.7 * collapseProgress)
        }
    }
}

private struct AICapacityWizardPage: View {
    let selectedBuildPreference: BuildPreference
    let chassisColorPreference: String
    let needsWirelessNetwork: Bool
    @Binding var selectedMemorySize: String
    @Binding var selectedStorageSize: String
    @Binding var allowsFlexibleBudget: Bool
    let isSubmitting: Bool
    let hidesHeroCard: Bool
    let onGenerate: () -> Void

    private var summary: String {
        "\(selectedMemorySize) · \(selectedStorageSize) · \(allowsFlexibleBudget ? "预算可浮动" : "预算不浮动")"
    }

    var body: some View {
        VStack(spacing: 0) {
            AIPreferenceSummaryCard(
                preference: selectedBuildPreference.title,
                color: chassisColorPreference,
                wireless: needsWirelessNetwork
            )
            .aiHeroAnchor(.preferenceSummary)
            .opacity(hidesHeroCard ? 0 : 1)
            .padding(.top, 8)

            Spacer(minLength: 56)
            AIPageHeading(title: "补充最后偏好", subtitle: "再确认容量与预算范围")
            Spacer(minLength: 18)

            AICapacityCard(
                selectedMemorySize: $selectedMemorySize,
                selectedStorageSize: $selectedStorageSize,
                allowsFlexibleBudget: $allowsFlexibleBudget
            )

            AISummaryRow(label: "最终偏好", value: summary)
                .padding(.top, 15)

            Spacer(minLength: 62)

            Button(action: onGenerate) {
                HStack(spacing: 11) {
                    if isSubmitting { ProgressView().tint(.white) }
                    Text(isSubmitting ? "正在生成配置…" : "生成配置方案")
                    if !isSubmitting {
                        Image(systemName: "sparkles")
                    }
                }
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(Color.black, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: .black.opacity(0.16), radius: 12, y: 7)
            }
            .buttonStyle(Micro3DPressButtonStyle())
            .disabled(isSubmitting)
            .accessibilityLabel(isSubmitting ? "正在生成配置" : "生成配置方案")
        }
        .padding(.horizontal, 30)
        .padding(.bottom, 15)
    }
}

private struct AIPreferenceSummaryCard: View {
    let preference: String
    let color: String
    let wireless: Bool

    var body: some View {
        HStack(spacing: 10) {
                Text("偏好与外观")
                    .font(.system(size: 12, weight: .semibold))
                Circle()
                    .fill(color == "曜石黑" ? Color.black : Color.white)
                    .frame(width: 16, height: 16)
                    .overlay(Circle().stroke(Color.black.opacity(0.16), lineWidth: 1))
                Text("\(preference) · \(color) · \(wireless ? "无线网络" : "有线网络")")
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
                if wireless {
                    Image(systemName: "wifi")
                        .font(.system(size: 13, weight: .bold))
                }
                Spacer(minLength: 2)
                Text("STEP 03")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(Color(red: 0.30, green: 0.36, blue: 0.46))
            }
            .padding(.horizontal, 13)
            .background(.white, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.black.opacity(0.05), lineWidth: 1))
            .shadow(color: .black.opacity(0.11), radius: 9, y: 6)
        .frame(width: 286)
        .frame(height: 34)
    }
}

private struct AICapacityCard: View {
    @Binding var selectedMemorySize: String
    @Binding var selectedStorageSize: String
    @Binding var allowsFlexibleBudget: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("容量与预算")
                    .font(.system(size: 19, weight: .bold))
                Spacer()
                Text("STEP 04")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(Color(red: 0.30, green: 0.36, blue: 0.46))
            }

            Text("内存大小")
                .font(.system(size: 17, weight: .semibold))
                .padding(.top, 25)
            AIChoiceTrack(options: ["16GB", "32GB"], selection: $selectedMemorySize)
                .padding(.top, 13)

            Divider()
                .overlay(Color.black.opacity(0.08))
                .padding(.top, 21)

            Text("存储大小")
                .font(.system(size: 17, weight: .semibold))
                .padding(.top, 21)
            AIChoiceTrack(options: ["512GB", "1TB", "2TB"], selection: $selectedStorageSize)
                .padding(.top, 13)

            Divider()
                .overlay(Color.black.opacity(0.08))
                .padding(.top, 21)

            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("预算可小幅浮动")
                        .font(.system(size: 17, weight: .semibold))
                    Text("生成时允许最多比预算高 500 元")
                        .font(.system(size: 14))
                        .foregroundStyle(Color(red: 0.30, green: 0.36, blue: 0.46))
                }
                Spacer(minLength: 5)
                AIToggle(isOn: $allowsFlexibleBudget)
            }
            .padding(.top, 21)
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 21)
        .background(.white, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.black.opacity(0.045), lineWidth: 1))
        .shadow(color: .black.opacity(0.11), radius: 17, y: 10)
    }
}

private struct AIChoiceTrack: View {
    let options: [String]
    @Binding var selection: String
    var showsColorDots = false

    private var selectedIndex: Int { options.firstIndex(of: selection) ?? 0 }

    var body: some View {
        GeometryReader { proxy in
            let itemWidth = proxy.size.width / CGFloat(max(options.count, 1))
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color(red: 0.93, green: 0.93, blue: 0.95))

                Capsule()
                    .fill(.white)
                    .shadow(color: .black.opacity(0.12), radius: 9, y: 5)
                    .frame(width: itemWidth - 2, height: 43)
                    .offset(x: CGFloat(selectedIndex) * itemWidth + 1)
                    .animation(.easeInOut(duration: 0.24), value: selectedIndex)

                HStack(spacing: 0) {
                    ForEach(options, id: \.self) { option in
                        Button {
                            withAnimation(.easeInOut(duration: 0.24)) {
                                selection = option
                            }
                        } label: {
                            HStack(spacing: 8) {
                                if showsColorDots {
                                    Circle()
                                        .fill(option == "曜石黑" ? .black : .white)
                                        .frame(width: 14, height: 14)
                                        .overlay(Circle().stroke(Color.black.opacity(option == "曜石黑" ? 0 : 0.14), lineWidth: 1))
                                }
                                Text(option)
                                    .font(.system(size: 15, weight: selection == option ? .bold : .regular))
                            }
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 45)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .frame(height: 45)
        .clipShape(Capsule())
    }
}

private struct AIToggle: View {
    @Binding var isOn: Bool

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.20)) {
                isOn.toggle()
            }
        } label: {
            ZStack(alignment: isOn ? .trailing : .leading) {
                Capsule()
                    .fill(isOn ? Color.black : Color(red: 0.83, green: 0.84, blue: 0.87))
                    .frame(width: 53, height: 31)
                Circle()
                    .fill(.white)
                    .frame(width: 27, height: 27)
                    .shadow(color: .black.opacity(0.16), radius: 3, y: 1)
                    .padding(2)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("开关")
        .accessibilityValue(isOn ? "已开启" : "已关闭")
    }
}

private struct AISummaryRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(label)
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(Color(red: 0.30, green: 0.36, blue: 0.46))
            Spacer(minLength: 8)
            Text(value)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.black)
                .multilineTextAlignment(.trailing)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        }
    }
}
