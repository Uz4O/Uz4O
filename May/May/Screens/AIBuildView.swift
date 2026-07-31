import SwiftUI

struct AIBuildOptionsInput {
    let budget: Int
    let useCase: String
    let games: [String]
    let direction: AIBuildDirection
    let officeApps: [String]
    let needsWirelessNetwork: Bool
    let memorySize: String
    let storageSize: String
    let noGPUBuild: Bool
    let ownedGPUModel: String?
}

struct AIBuildView: View {
    typealias LoadOptions = (AIBuildOptionsInput) async throws -> BuildOptionsResponseDTO

    private let minimumGenerationDuration: TimeInterval = 14.5
    private let completionAnimationDuration: TimeInterval = 0.8

    @State private var currentStep: AIBuildStep = .budget
    @State private var isChangingStep = false
    @State private var isSubmitting = false
    @State private var isGenerationComplete = false
    @State private var directionRecommendation: AIBuildDirection?
    @State private var submissionError: String?
    @State private var generationTask: Task<Void, Never>?
    @State private var budget: Double = 6850
    @State private var selectedUseCase = "游戏"
    @State private var selectedGames: Set<String> = []
    @State private var selectedDirection = AIBuildDirection.balanced
    @State private var selectedOfficeApps: Set<String> = []
    @State private var usesNoGpuBuild = false
    @State private var ownedGPUModel = ""
    @State private var needsWirelessNetwork = false
    @State private var selectedBuildPreference = BuildPreference.defaultAISelection
    @State private var chassisColorPreference = "曜石黑"
    @State private var upgradePreference = "当前体验优先"
    @State private var selectedMemorySize = "16GB"
    @State private var selectedStorageSize = "1TB"
    @State private var selectedAestheticStyleID = AestheticBuildStyle.featured[0].id

    let onBack: () -> Void
    let onComplete: (BuildOptionsResponseDTO) -> Void
    let loadOptions: LoadOptions

    init(
        onBack: @escaping () -> Void,
        onComplete: @escaping (BuildOptionsResponseDTO) -> Void,
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
                noGPUBuild: input.noGPUBuild,
                ownedGPUModel: input.ownedGPUModel
            )
        }
    ) {
        self.onBack = onBack
        self.onComplete = onComplete
        self.loadOptions = loadOptions
    }

    private let gameOptions = [
        "什么都玩", "瓦罗兰特", "CS2", "PUBG", "三角洲行动", "云顶之弈", "LOL",
        "COD", "赛博朋克2077", "荒野大镖客2", "GTA5", "黑神话悟空", "地平线6",
        "艾尔登法环", "城市天际线", "我的世界"
    ]
    private let gameIcons = [
        "什么都玩": "gamecontroller",
        "瓦罗兰特": "scope",
        "CS2": "target",
        "PUBG": "figure.run",
        "三角洲行动": "map",
        "云顶之弈": "checkerboard.shield",
        "LOL": "shield",
        "COD": "crosshair",
        "赛博朋克2077": "sparkles",
        "荒野大镖客2": "mountain.2",
        "GTA5": "car",
        "黑神话悟空": "flame",
        "地平线6": "steeringwheel",
        "艾尔登法环": "circle.hexagongrid",
        "城市天际线": "building.2",
        "我的世界": "cube"
    ]
    private let officeAppOptions = ["Office", "WPS", "Photoshop", "Premiere", "AutoCAD", "Blender"]
    private let officeAppIcons = [
        "Office": "doc.text",
        "WPS": "doc.richtext",
        "Photoshop": "photo",
        "Premiere": "film",
        "AutoCAD": "ruler",
        "Blender": "cube.transparent"
    ]
    private let memorySizeOptions = ["16GB", "32GB"]
    private let storageSizeOptions = ["512GB", "1TB", "2TB"]

    private var availableMemorySizeOptions: [String] {
        let budgetValue = Int(budget)
        if budgetValue < 5000 {
            return ["16GB"]
        }
        if budgetValue < 15000 {
            return ["16GB", "32GB"]
        }
        return memorySizeOptions
    }

    private var availableStorageSizeOptions: [String] {
        let budgetValue = Int(budget)
        if budgetValue < 4000 {
            return ["512GB"]
        }
        if budgetValue < 8000 {
            return ["512GB", "1TB"]
        }
        if budgetValue < 15000 {
            return ["512GB", "1TB", "2TB"]
        }
        return storageSizeOptions
    }

    private var visibleSteps: [AIBuildStep] {
        AIBuildFlowRules.visibleSteps(
            budget: Int(budget),
            ownedParts: []
        )
    }

    private var nextStep: AIBuildStep? {
        guard let index = visibleSteps.firstIndex(of: currentStep) else {
            return visibleSteps.first
        }
        let nextIndex = index + 1
        return nextIndex < visibleSteps.count ? visibleSteps[nextIndex] : nil
    }

    private var previousStep: AIBuildStep? {
        guard let index = visibleSteps.firstIndex(of: currentStep), index > 0 else {
            return nil
        }
        return visibleSteps[index - 1]
    }

    private var usesLowBudgetMode: Bool {
        AIBuildFlowRules.usesLowBudgetMode(
            budget: Int(budget),
            ownedParts: []
        )
    }

    private var recommendedDirection: AIBuildDirection {
        AIBuildFlowRules.recommendedDirection(for: selectedGames)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    ScreenHeader(title: "AI 写配置", trailingIcon: nil, onBack: handleHeaderBack)
                        .padding(.top, 8)

                    StepProgressHeader(currentStep: currentStep, steps: visibleSteps)

                    SoftCard(radius: 22) {
                        VStack(alignment: .leading, spacing: 18) {
                            if currentStep != .scenario {
                                StepTitle(step: currentStep)
                            }

                            stepContent
                        }
                        .padding(22)
                    }
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
                }
                .padding(.horizontal, AppTheme.screenPadding)
                .padding(.bottom, 92)
            }

            WizardBottomBar(
                canGoBack: previousStep != nil,
                primaryTitle: nextStep == nil ? "生成配置方案" : "下一步",
                primaryIcon: nextStep == nil ? "sparkles" : "arrow.right",
                isLoading: isSubmitting,
                onBack: goToPreviousStep,
                onPrimary: handlePrimaryAction
            )
            .padding(.horizontal, AppTheme.screenPadding)
            .padding(.bottom, 18)

            if isSubmitting {
                AIBuildGeneratingView(isComplete: isGenerationComplete)
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    .zIndex(2)
            }
        }
        .animation(.easeInOut(duration: 0.18), value: currentStep)
        .animation(.easeOut(duration: 0.28), value: isSubmitting)
        .onAppear(perform: clampCapacitySelections)
        .onChange(of: budget) { _, _ in
            clampCapacitySelections()
        }
        .onDisappear(perform: cancelGeneration)
        .alert("生成失败", isPresented: showsSubmissionError) {
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
        .sheet(item: $directionRecommendation) { recommendation in
            BuildDirectionRecommendationSheet(
                recommendedDirection: recommendation,
                selectedDirection: $selectedDirection
            ) {
                directionRecommendation = nil
                advanceFlow()
            }
            .presentationDetents([.height(510)])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(28)
            .presentationBackground(Color.white)
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        switch currentStep {
        case .budget:
            BudgetSection(budget: $budget)
            PreferenceSegmentGroup(title: "主要用途", options: AppMockData.useCases, selected: $selectedUseCase)
            Toggle(isOn: $usesNoGpuBuild) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("无显卡方案")
                        .font(.appSubheadline)
                        .foregroundStyle(AppTheme.primaryText)
                    Text("是否自备显卡")
                        .font(.appCaption)
                        .foregroundStyle(AppTheme.secondaryText)
                }
            }
            .tint(AppTheme.primaryText)
            if usesNoGpuBuild {
                TextField("例如 RTX 5070", text: $ownedGPUModel)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel("自备显卡型号")
            }

        case .scenario:
            ScenarioSelectionSection(
                useCase: selectedUseCase,
                gameOptions: gameOptions,
                gameIcons: gameIcons,
                officeAppOptions: officeAppOptions,
                officeAppIcons: officeAppIcons,
                selectedGames: $selectedGames,
                selectedOfficeApps: $selectedOfficeApps
            )

        case .purchase:
            Toggle(isOn: $needsWirelessNetwork) {
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
            VStack(alignment: .leading, spacing: 8) {
                Text("装机偏好")
                    .font(.appSubheadline)
                    .foregroundStyle(AppTheme.primaryText)

                LiquidGlassSegmentedPicker(
                    options: BuildPreference.aiBuildOptions,
                    selection: $selectedBuildPreference,
                    title: \.title
                )
            }
            PreferenceSegmentGroup(
                title: "主机颜色偏好",
                options: ["曜石黑", "纯净白"],
                selected: $chassisColorPreference,
                showsSelectionDot: true
            )

        case .hardware:
            if selectedBuildPreference == .aesthetic {
                AestheticStylePreferenceSection(
                    styles: AestheticBuildStyle.featured,
                    selectedID: $selectedAestheticStyleID
                )
            } else {
                UpgradePreferenceSection(selected: $upgradePreference)
            }
            if availableMemorySizeOptions.count > 1 {
                PreferenceSegmentGroup(title: "内存大小", options: availableMemorySizeOptions, selected: $selectedMemorySize)
            }
            if availableStorageSizeOptions.count > 1 {
                PreferenceSegmentGroup(title: "存储大小", options: availableStorageSizeOptions, selected: $selectedStorageSize)
            }
        }
    }

    private func handlePrimaryAction() {
        guard !isChangingStep else { return }

        if currentStep == .scenario,
           selectedUseCase != "办公",
           !selectedGames.isEmpty {
            selectedDirection = recommendedDirection
            directionRecommendation = recommendedDirection
            return
        }

        advanceFlow()
    }

    private func advanceFlow() {
        isChangingStep = true

        if let next = nextStep {
            currentStep = next
        } else {
            applyLowBudgetDefaultsIfNeeded()
            submitBuildOptions()
        }

        resetStepChangeLock()
    }

    private func goToPreviousStep() {
        guard !isChangingStep else { return }
        isChangingStep = true

        if let previous = previousStep {
            currentStep = previous
        }

        resetStepChangeLock()
    }

    private func resetStepChangeLock() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            isChangingStep = false
        }
    }

    private var showsSubmissionError: Binding<Bool> {
        Binding(
            get: { submissionError != nil },
            set: { isPresented in
                if !isPresented {
                    submissionError = nil
                }
            }
        )
    }

    private func submitBuildOptions() {
        guard !isSubmitting else { return }
        if usesNoGpuBuild && ownedGPUModel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            submissionError = "请填写自备显卡型号"
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
            noGPUBuild: usesNoGpuBuild,
            ownedGPUModel: usesNoGpuBuild
                ? ownedGPUModel.trimmingCharacters(in: .whitespacesAndNewlines)
                : nil
        )
        let minimumGenerationEnd = Date().addingTimeInterval(minimumGenerationDuration)
        let completionStart = minimumGenerationEnd.addingTimeInterval(-completionAnimationDuration)
        isGenerationComplete = false
        isSubmitting = true

        generationTask = Task {
            do {
                let response = try await loadOptions(input)
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
                onComplete(response)
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
    }

    private func applyLowBudgetDefaultsIfNeeded() {
        guard usesLowBudgetMode else { return }
        let defaults = AIBuildFlowRules.lowBudgetDefaults(useCase: selectedUseCase)
        selectedBuildPreference = defaults.buildPreference
        chassisColorPreference = defaults.colorPreference
    }

    private func clampCapacitySelections() {
        if !availableMemorySizeOptions.contains(selectedMemorySize),
           let fallback = availableMemorySizeOptions.last {
            selectedMemorySize = fallback
        }

        if !availableStorageSizeOptions.contains(selectedStorageSize),
           let fallback = availableStorageSizeOptions.last {
            selectedStorageSize = fallback
        }
    }
}

private struct AIBuildGeneratingView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var progress = 3
    @State private var isPulsing = false
    @State private var ringRotation = 0.0
    @State private var hasAppeared = false
    @State private var completionBloom = false

    let isComplete: Bool

    private let stages = ["分析需求", "检查兼容性", "优化配置方案", "生成最终结果"]

    private var currentStage: Int {
        min(stages.count - 1, progress / 25)
    }

    var body: some View {
        GeometryReader { proxy in
            let usesCompactLayout = proxy.size.height < 900
            let contentWidth = min(proxy.size.width - 32, 398)
            let dialSize = min(contentWidth - 10, usesCompactLayout ? 304 : 342)

            ZStack {
                Color.white
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        Text("UzBox")
                            .font(.system(size: 28, weight: .heavy))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, usesCompactLayout ? 4 : 10)
                            .opacity(hasAppeared ? 1 : 0)
                            .offset(y: hasAppeared ? 0 : -8)
                            .animation(.easeOut(duration: 0.42).delay(0.03), value: hasAppeared)

                        VStack(spacing: 8) {
                            Text("AI 正在生成配置单")
                                .font(.system(size: 30, weight: .bold))
                                .foregroundStyle(.black)

                            Text("正在根据你的需求匹配更适合的硬件方案")
                                .font(.system(size: 15))
                                .foregroundStyle(Color.black.opacity(0.45))
                        }
                        .multilineTextAlignment(.center)
                        .padding(.top, usesCompactLayout ? 26 : 42)
                        .opacity(hasAppeared ? 1 : 0)
                        .offset(y: hasAppeared ? 0 : 14)
                        .animation(.easeOut(duration: 0.48).delay(0.08), value: hasAppeared)

                        GenerationProgressDial(
                            progress: progress,
                            size: dialSize,
                            isComplete: isComplete,
                            isPulsing: isPulsing,
                            ringRotation: ringRotation
                        )
                        .padding(.top, usesCompactLayout ? 14 : 24)
                        .opacity(hasAppeared ? 1 : 0)
                        .scaleEffect(hasAppeared ? 1 : 0.9)
                        .blur(radius: hasAppeared ? 0 : 8)
                        .animation(.spring(response: 0.7, dampingFraction: 0.84).delay(0.14), value: hasAppeared)

                        GenerationStageCard(
                            stages: stages,
                            currentStage: currentStage,
                            isComplete: isComplete,
                            isCompact: usesCompactLayout
                        )
                        .padding(.top, usesCompactLayout ? 16 : 28)
                        .opacity(hasAppeared ? 1 : 0)
                        .offset(y: hasAppeared ? 0 : 22)
                        .animation(.smooth(duration: 0.55).delay(0.24), value: hasAppeared)

                    }
                    .frame(width: contentWidth)
                    .frame(maxWidth: .infinity)
                }

                Text("通常需要几秒钟，请稍候")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.black.opacity(0.42))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .padding(.bottom, usesCompactLayout ? 12 : 24)
                    .opacity(hasAppeared ? 1 : 0)
                    .animation(.easeOut(duration: 0.38).delay(0.4), value: hasAppeared)

                Circle()
                    .fill(.white)
                    .frame(width: 132, height: 132)
                    .scaleEffect(completionBloom ? 12 : 0.1)
                    .opacity(completionBloom && !reduceMotion ? 1 : 0)
                    .position(x: proxy.size.width / 2, y: proxy.size.height * 0.39)
                    .allowsHitTesting(false)
                    .zIndex(10)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("AI 正在生成配置方案，当前进度百分之\(progress)，\(stages[currentStage])")
        .onAppear {
            if reduceMotion {
                hasAppeared = true
                return
            }
            withAnimation(.smooth(duration: 0.5)) {
                hasAppeared = true
            }
            withAnimation(.easeInOut(duration: 1.25).repeatForever(autoreverses: true)) {
                isPulsing = true
            }
            withAnimation(.linear(duration: 120).repeatForever(autoreverses: false)) {
                ringRotation = 360
            }
        }
        .task {
            while progress < 99, !Task.isCancelled, !isComplete {
                do {
                    try await Task.sleep(nanoseconds: 140_000_000)
                } catch {
                    return
                }
                progress = min(99, progress + 1)
            }
        }
        .onChange(of: isComplete) { _, complete in
            guard complete else { return }
            withAnimation(reduceMotion ? .none : .easeOut(duration: 0.32)) {
                progress = 100
            }
            guard !reduceMotion else { return }
            withAnimation(.easeIn(duration: 0.55).delay(0.16)) {
                completionBloom = true
            }
        }
    }
}

private struct GenerationProgressDial: View {
    let progress: Int
    let size: CGFloat
    let isComplete: Bool
    let isPulsing: Bool
    let ringRotation: Double

    var body: some View {
        ZStack {
            RadialGradient(
                colors: [Color.black.opacity(0.045), .clear],
                center: .center,
                startRadius: 10,
                endRadius: size * 0.48
            )
            .clipShape(Circle())

            ZStack {
                ForEach(0..<96, id: \.self) { index in
                    Capsule()
                        .fill(Color.black.opacity(index.isMultiple(of: 4) ? 0.12 : 0.065))
                        .frame(width: 1, height: index.isMultiple(of: 4) ? 9 : 6)
                        .offset(y: -size / 2 + 8)
                        .rotationEffect(.degrees(Double(index) / 96 * 360))
                }
            }
            .frame(width: size, height: size)
            .rotationEffect(.degrees(ringRotation))

            Circle()
                .stroke(Color.black.opacity(0.035), lineWidth: 14)
                .padding(22)
                .scaleEffect(isPulsing ? 1.012 : 0.992)
                .opacity(isPulsing ? 0.72 : 1)

            Circle()
                .stroke(Color.black.opacity(0.05), lineWidth: 1)
                .padding(15)

            Circle()
                .trim(from: 0, to: CGFloat(progress) / 100)
                .stroke(.black, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .padding(24)
                .animation(.linear(duration: 0.12), value: progress)

            Circle()
                .fill(.white)
                .frame(width: 13, height: 13)
                .shadow(color: Color.black.opacity(0.08), radius: 8)
                .offset(y: -size / 2 + 24)
                .rotationEffect(.degrees(Double(progress) * 3.6))
                .scaleEffect(isPulsing ? 1.16 : 0.88)
                .animation(.linear(duration: 0.12), value: progress)
                .animation(.easeInOut(duration: 1.25), value: isPulsing)

            Image("PCTower")
                .resizable()
                .scaledToFit()
                .saturation(0)
                .brightness(0.055)
                .contrast(0.9)
                .frame(width: size * 0.58, height: size * 0.58)
                .offset(y: -3)
                .shadow(color: Color.black.opacity(0.12), radius: 12, x: 0, y: 9)

            VStack(spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 1) {
                    Text("\(progress)")
                        .font(.system(size: 42, weight: .medium))
                        .monospacedDigit()
                        .transaction { transaction in
                            transaction.animation = nil
                        }
                    Text("%")
                        .font(.system(size: 17, weight: .semibold))
                }
                Text(isComplete ? "已完成" : "生成中")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.black.opacity(0.46))
            }
            .foregroundStyle(.black)
            .frame(width: 90, height: 90)
            .background(.white, in: Circle())
            .shadow(color: Color.black.opacity(0.1), radius: 18, x: 0, y: 10)
            .offset(y: size * 0.38)
        }
        .frame(width: size, height: size)
        .padding(.bottom, 18)
    }
}

private struct GenerationStageCard: View {
    let stages: [String]
    let currentStage: Int
    let isComplete: Bool
    let isCompact: Bool

    var body: some View {
        ZStack(alignment: .topLeading) {
            VStack(spacing: 0) {
                ForEach(stages.indices, id: \.self) { index in
                    HStack(alignment: .top, spacing: 16) {
                        ZStack(alignment: .top) {
                            if index < stages.count - 1 {
                                Rectangle()
                                    .fill(Color.black.opacity(index < currentStage || isComplete ? 0.38 : 0.16))
                                    .frame(width: 1, height: rowHeight)
                                    .offset(y: 11.5)
                            }

                            GenerationStageIndicator(
                                isCompleted: isComplete || index < currentStage,
                                isCurrent: !isComplete && index == currentStage,
                                isMovingCurrent: !isComplete && index == currentStage
                            )
                        }
                        .frame(width: 42, height: rowHeight)

                        VStack(alignment: .leading, spacing: 0) {
                            Text("\(index + 1).  \(stages[index])")
                                .font(.system(size: 16, weight: index == currentStage ? .medium : .regular))
                                .foregroundStyle(index > currentStage && !isComplete ? Color.black.opacity(0.38) : .black)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            if index < stages.count - 1 {
                                GeometryReader { proxy in
                                    Divider()
                                        .frame(width: proxy.size.width * 0.6, alignment: .leading)
                                        .overlay(Color.black.opacity(0.08))
                                }
                                .padding(.top, isCompact ? 13 : 18)
                                .frame(height: isCompact ? 35 : 45)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(minHeight: rowHeight)
                }
            }

            if !isComplete {
                Circle()
                    .fill(.black)
                    .frame(width: 23, height: 23)
                    .offset(x: 9.5, y: CGFloat(currentStage) * rowHeight)
            }
        }
        .padding(.horizontal, 4)
        .animation(.smooth(duration: 0.45), value: currentStage)
        .animation(.smooth(duration: 0.5), value: isComplete)
    }

    private var rowHeight: CGFloat {
        isCompact ? 54 : 64
    }
}

private struct GenerationStageIndicator: View {
    let isCompleted: Bool
    let isCurrent: Bool
    let isMovingCurrent: Bool

    var body: some View {
        ZStack {
            if !isMovingCurrent {
                Circle()
                    .fill(isCompleted || isCurrent ? Color.black : Color.white)
                    .frame(width: 23, height: 23)
                    .overlay(
                        Circle()
                            .stroke(isCompleted || isCurrent ? Color.clear : Color.black.opacity(0.3), lineWidth: 1.5)
                    )
            }

            if isCompleted {
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
                    .transition(.scale(scale: 0.7).combined(with: .opacity))
            }
        }
        .animation(.smooth(duration: 0.35), value: isCompleted)
        .animation(.smooth(duration: 0.38), value: isCurrent)
    }
}

private struct StepProgressHeader: View {
    let currentStep: AIBuildStep
    let steps: [AIBuildStep]

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                ForEach(steps, id: \.self) { step in
                    StepIndicator(
                        title: step.title,
                        isActive: step == currentStep,
                        displayNumber: stepNumber(for: step),
                        isComplete: isComplete(step)
                    )

                    if step != steps.last {
                        Rectangle()
                            .fill(isComplete(step) ? AppTheme.primaryText : AppTheme.border)
                            .frame(height: 2)
                    }
                }
            }

            HStack {
                Text("第 \(currentStepIndex + 1)/\(steps.count) 步")
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

    private var currentStepIndex: Int {
        steps.firstIndex(of: currentStep) ?? 0
    }

    private func stepNumber(for step: AIBuildStep) -> Int {
        (steps.firstIndex(of: step) ?? 0) + 1
    }

    private func isComplete(_ step: AIBuildStep) -> Bool {
        guard let index = steps.firstIndex(of: step) else { return false }
        return index < currentStepIndex
    }
}

private struct StepIndicator: View {
    let title: String
    let isActive: Bool
    let displayNumber: Int
    let isComplete: Bool

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(isActive || isComplete ? AppTheme.primaryText : AppTheme.surface)
                    .frame(width: 22, height: 22)
                    .overlay(
                        Circle()
                            .stroke(isActive || isComplete ? Color.clear : AppTheme.border, lineWidth: 1)
                    )

                if isComplete {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                } else {
                    Text("\(displayNumber)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(isActive ? .white : AppTheme.secondaryText)
                }
            }

            Text(title)
                .font(.system(size: 9, weight: isActive ? .bold : .semibold))
                .foregroundStyle(isActive ? AppTheme.primaryText : AppTheme.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(width: 66)
    }

}

private struct StepTitle: View {
    let step: AIBuildStep

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

private struct UpgradePreferenceSection: View {
    @Binding var selected: String

    private let options = ["当前体验优先", "保留升级空间"]

    var body: some View {
        PreferenceSegmentGroup(title: "后期升级计划", options: options, selected: $selected)
    }
}

private struct AestheticStylePreferenceSection: View {
    let styles: [AestheticBuildStyle]
    @Binding var selectedID: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("选择装机风格")
                .font(.appSubheadline)
                .foregroundStyle(AppTheme.primaryText)

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(styles) { style in
                    AestheticStyleChoiceCard(
                        style: style,
                        isSelected: style.id == selectedID
                    ) {
                        selectedID = style.id
                    }
                }
            }
        }
    }
}

private struct AestheticStyleChoiceCard: View {
    let style: AestheticBuildStyle
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 9) {
                ZStack(alignment: .topTrailing) {
                    Image(style.image)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 92)
                        .frame(maxWidth: .infinity)
                        .clipped()

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(8)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 4) {
                    Text(style.title)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(AppTheme.primaryText)
                        .lineLimit(1)

                    Text(style.summary)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(AppTheme.secondaryText)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? AppTheme.surface : AppTheme.softSurface, in: RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? AppTheme.primaryText : AppTheme.border, lineWidth: isSelected ? 1.4 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct WizardBottomBar: View {
    let canGoBack: Bool
    let primaryTitle: String
    let primaryIcon: String
    let isLoading: Bool
    let onBack: () -> Void
    let onPrimary: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(canGoBack ? AppTheme.primaryText : AppTheme.mutedText)
                    .frame(width: 48, height: 48)
                    .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: AppTheme.controlRadius))
            }
            .buttonStyle(.plain)
            .disabled(!canGoBack || isLoading)
            .accessibilityLabel("上一步")

            if isLoading {
                HStack(spacing: 8) {
                    ProgressView()
                        .tint(.white)
                    Text("正在生成...")
                }
                .font(.appSubheadline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(AppTheme.primaryButton, in: RoundedRectangle(cornerRadius: AppTheme.controlRadius))
                .accessibilityLabel("正在生成配置方案")
            } else {
                PrimaryButton(title: primaryTitle, icon: primaryIcon, action: onPrimary)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct BudgetSection: View {
    @Binding var budget: Double

    private let minimumBudget: Double = 3000
    private let maximumBudget: Double = 30000
    private let budgetStep: Double = 100

    private var valueText: String {
        let value = Int(budget)
        return "¥ \(value)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("预算范围")
                    .font(.appSubheadline)
                    .foregroundStyle(AppTheme.primaryText)
                Spacer()
                Text(valueText)
                    .font(.system(size: 22, weight: .heavy))
                    .foregroundStyle(AppTheme.primaryText)
                    .monospacedDigit()
            }

            HStack {
                Text("¥ 3000")
                Spacer()
                Text("¥ 30000")
            }
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(AppTheme.secondaryText)

            HStack(spacing: 12) {
                BudgetStepButton(systemName: "minus", isEnabled: budget > minimumBudget) {
                    updateBudget(by: -budgetStep)
                }

                Slider(value: $budget, in: minimumBudget...maximumBudget, step: budgetStep)
                    .tint(AppTheme.primaryText)

                BudgetStepButton(systemName: "plus", isEnabled: budget < maximumBudget) {
                    updateBudget(by: budgetStep)
                }
            }
        }
    }

    private func updateBudget(by amount: Double) {
        budget = min(max(budget + amount, minimumBudget), maximumBudget)
    }
}

private struct BudgetStepButton: View {
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

private struct ScenarioSelectionSection: View {
    let useCase: String
    let gameOptions: [String]
    let gameIcons: [String: String]
    let officeAppOptions: [String]
    let officeAppIcons: [String: String]
    @Binding var selectedGames: Set<String>
    @Binding var selectedOfficeApps: Set<String>

    private var showsGames: Bool {
        useCase == "游戏" || useCase == "游戏兼办公"
    }

    private var showsOfficeApps: Bool {
        useCase == "办公" || useCase == "游戏兼办公"
    }

    private var pageTitle: String {
        if showsGames && showsOfficeApps { return "选择游戏和常用软件" }
        return showsGames ? "选择你常玩的游戏" : "选择你常用的软件"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 5) {
                Text(pageTitle)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(AppTheme.primaryText)
                Text("可多选，AI 会自动调整配置")
                    .font(.appBody)
                    .foregroundStyle(AppTheme.secondaryText)
            }

            if showsGames {
                MultiChoiceChipSection(
                    title: "热门游戏",
                    subtitle: selectedGames.isEmpty ? "选择你玩过或准备玩的" : "已选 \(selectedGames.count) 个",
                    options: gameOptions,
                    selected: $selectedGames,
                    icons: gameIcons,
                    minimumChipWidth: 76,
                    usesSquareTiles: true
                )
            }

            if showsOfficeApps {
                MultiChoiceChipSection(
                    title: "常用软件",
                    subtitle: selectedOfficeApps.isEmpty ? "选择你常用的" : "已选 \(selectedOfficeApps.count) 个",
                    options: officeAppOptions,
                    selected: $selectedOfficeApps,
                    icons: officeAppIcons,
                    minimumChipWidth: 76,
                    usesSquareTiles: true
                )
            }
        }
    }
}

private struct BuildDirectionRecommendationSheet: View {
    let recommendedDirection: AIBuildDirection
    @Binding var selectedDirection: AIBuildDirection
    let onConfirm: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 10) {
                Text("为你推荐「\(recommendedDirection.title)」")
                    .font(.appTitle)
                    .foregroundStyle(AppTheme.primaryText)

                Text(recommendedDirection.recommendation)
                    .font(.appBody)
                    .foregroundStyle(AppTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: 10) {
                ForEach(AIBuildDirection.allCases, id: \.self) { direction in
                    Button {
                        selectedDirection = direction
                    } label: {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 8) {
                                    Text(direction.title)
                                        .font(.appSubheadline)

                                    if direction == recommendedDirection {
                                        Text("推荐")
                                            .font(.system(size: 10, weight: .bold))
                                            .padding(.horizontal, 7)
                                            .frame(height: 21)
                                            .background(AppTheme.softSurface, in: Capsule())
                                    }
                                }

                                Text(direction.summary)
                                    .font(.appCaption)
                                    .foregroundStyle(AppTheme.secondaryText)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)

                            Image(systemName: selectedDirection == direction ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 20, weight: .semibold))
                        }
                        .foregroundStyle(AppTheme.primaryText)
                        .padding(.horizontal, 16)
                        .frame(maxWidth: .infinity, minHeight: 64)
                        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 16))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(
                                    selectedDirection == direction ? AppTheme.primaryText : AppTheme.border,
                                    lineWidth: selectedDirection == direction ? 1.5 : 1
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            PrimaryButton(title: "按此方向继续", icon: "arrow.right", action: onConfirm)
        }
        .padding(.horizontal, AppTheme.screenPadding)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .background(Color.white.ignoresSafeArea())
    }
}

private struct MultiChoiceChipSection: View {
    let title: String
    let subtitle: String
    let options: [String]
    @Binding var selected: Set<String>
    var icons: [String: String] = [:]
    var minimumChipWidth: CGFloat = 92
    var usesSquareTiles = false
    var footer: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.appSubheadline)
                    .foregroundStyle(AppTheme.primaryText)
                Text(subtitle)
                    .font(.appCaption)
                    .foregroundStyle(AppTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: minimumChipWidth), spacing: 8)], alignment: .leading, spacing: 8) {
                ForEach(options, id: \.self) { option in
                    let isSelected = selected.contains(option)
                    MultiChoiceChip(
                        title: option,
                        systemImage: icons[option],
                        isSelected: isSelected,
                        usesSquareTile: usesSquareTiles
                    ) {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.88)) {
                            if isSelected {
                                selected.remove(option)
                            } else {
                                selected.insert(option)
                            }
                        }
                    }
                }
            }

            if let footer {
                Text(footer)
                    .font(.system(size: 10, weight: .regular))
                    .foregroundStyle(AppTheme.mutedText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct MultiChoiceChip: View {
    let title: String
    let systemImage: String?
    let isSelected: Bool
    let usesSquareTile: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            if usesSquareTile {
                ZStack(alignment: .topTrailing) {
                    VStack(spacing: 8) {
                        if let systemImage {
                            Image(systemName: systemImage)
                                .font(.system(size: 18, weight: .bold))
                        }

                        Text(title)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                            .minimumScaleFactor(0.72)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(10)

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 16, weight: .bold))
                            .padding(8)
                    }
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(isSelected ? .white : AppTheme.primaryText)
                .aspectRatio(1.18, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .background(isSelected ? AppTheme.primaryText : AppTheme.softSurface, in: RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isSelected ? Color.clear : AppTheme.border, lineWidth: 1)
                )
            } else {
                HStack(spacing: 6) {
                    if let systemImage {
                        Image(systemName: systemImage)
                            .font(.system(size: 10, weight: .bold))
                    }

                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                    }

                    Text(title)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(isSelected ? .white : AppTheme.primaryText)
                .frame(maxWidth: .infinity)
                .frame(height: 38)
                .padding(.horizontal, 8)
                .background(isSelected ? AppTheme.primaryText : AppTheme.softSurface, in: Capsule())
                .overlay(
                    Capsule()
                        .stroke(isSelected ? Color.clear : AppTheme.border, lineWidth: 1)
                )
            }
        }
        .buttonStyle(.plain)
    }
}

private struct PreferenceSegmentGroup: View {
    let title: String
    let options: [String]
    @Binding var selected: String
    var showsSelectionDot = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.appSubheadline)
                .foregroundStyle(AppTheme.primaryText)

            LiquidGlassSegmentedPicker(
                options: options,
                selection: $selected,
                showsSelectionDot: showsSelectionDot,
                title: { $0 }
            )
        }
    }
}

#Preview {
    AIBuildView(onBack: {}, onComplete: { _ in })
}
