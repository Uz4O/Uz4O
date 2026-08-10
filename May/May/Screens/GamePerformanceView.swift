import SwiftUI

struct GamePerformanceView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let savedHardwareProfile: HardwareProfile
    let onBack: () -> Void

    @State private var flow = PerformanceTestFlow()
    @State private var selectedHardwareCategory: HardwareOptionCategory?
    @State private var requestTask: Task<Void, Never>?
    @State private var isSubmitting = false
    @State private var validationMessage = ""
    @State private var showsValidationAlert = false

    var body: some View {
        ZStack {
            AppTheme.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                PerformanceNavigationHeader(
                    title: flow.currentStep == .setup ? "游戏性能测试" : "性能结果"
                ) {
                    cancelRequest()
                    if flow.currentStep == .setup {
                        onBack()
                    } else {
                        flow.goPrevious()
                    }
                }
                .padding(.horizontal, AppTheme.screenPadding)
                .padding(.top, 8)

                ZStack {
                    switch flow.currentStep {
                    case .setup:
                        TestSetupStep(
                            hardwareProfile: $flow.hardwareProfile,
                            selectedCategory: $selectedHardwareCategory,
                            selectedGameCount: flow.selectedGameCount,
                            areAllGamesSelected: flow.areAllGamesSelected,
                            isGameSelected: flow.isGameSelected,
                            onToggleGame: { flow.toggleGame($0) },
                            onToggleAllGames: { flow.toggleAllGames() }
                        )
                        .transition(setupPageTransition)
                    case .result:
                        PerformanceResultStep(
                            flow: flow,
                            onSelectResolution: selectResolution
                        )
                        .transition(resultPageTransition)
                    }
                }
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
                .animation(pageTransitionAnimation, value: flow.currentStep)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            bottomAction
        }
        .sheet(item: $selectedHardwareCategory) { category in
            HardwarePickerSheet(
                title: category.title,
                icon: category.icon,
                filters: HardwareCatalog.filters(for: category.title),
                contextMessage: nil,
                selectedValue: binding(for: category.title)
            )
            .presentationDetents([.large])
        }
        .onAppear {
            flow.applySavedHardwareIfNeeded(savedHardwareProfile)
        }
        .onDisappear(perform: cancelRequest)
        .alert("还不能查看预计帧率", isPresented: $showsValidationAlert) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text(validationMessage)
        }
    }

    @ViewBuilder
    private var bottomAction: some View {
        VStack(spacing: 0) {
            if flow.currentStep == .result, case .failed = flow.loadState {
                PrimaryButton(title: "重试", icon: "arrow.clockwise", action: startTest)
            } else if flow.currentStep == .result {
                PerformanceSecondaryButton(title: "修改测试内容", icon: "square.and.pencil") {
                    cancelRequest()
                    flow.goPrevious()
                }
            } else {
                if isSubmitting {
                    PerformanceLoadingButton()
                } else {
                    PrimaryButton(title: "查看预计帧率", icon: "arrow.right", action: submitOrExplain)
                }
            }
        }
        .frame(maxWidth: 520)
        .padding(.horizontal, AppTheme.screenPadding)
        .padding(.top, 10)
        .padding(.bottom, 10)
        .frame(maxWidth: .infinity)
        .background(AppTheme.background)
        .animation(.easeInOut(duration: 0.22), value: flow.currentStep)
        .animation(.easeInOut(duration: 0.18), value: isSubmitting)
    }

    private var setupPageTransition: AnyTransition {
        reduceMotion
            ? .opacity
            : .asymmetric(
                insertion: .move(edge: .leading).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            )
    }

    private var resultPageTransition: AnyTransition {
        reduceMotion
            ? .opacity
            : .asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .trailing).combined(with: .opacity)
            )
    }

    private var pageTransitionAnimation: Animation {
        reduceMotion
            ? .easeInOut(duration: 0.16)
            : .spring(response: 0.48, dampingFraction: 0.88, blendDuration: 0.08)
    }

    private func selectResolution(_ resolution: PerformanceResolution) {
        guard flow.selectedResolution != resolution else { return }
        cancelRequest()
        flow.selectResolution(resolution)
        startTest()
    }

    private func submitOrExplain() {
        guard !isSubmitting else { return }
        guard flow.canSubmit else {
            var missingItems: [String] = []
            if !HardwareCatalog.cpus.contains(where: { $0.name == flow.hardwareProfile.cpu }) {
                missingItems.append("CPU")
            }
            if !HardwareCatalog.gpus.contains(where: { $0.name == flow.hardwareProfile.gpu }) {
                missingItems.append("显卡")
            }
            if flow.selectedGames.isEmpty {
                missingItems.append("至少一款游戏")
            }

            validationMessage = "请先选择\(missingItems.joined(separator: "、"))。"
            showsValidationAlert = true
            return
        }

        startTest()
    }

    private func startTest() {
        requestTask?.cancel()
        let waitsOnSetup = flow.currentStep == .setup
        let minimumLoadingEnd = Date().addingTimeInterval(waitsOnSetup ? 2.4 : 0)
        guard let request = flow.beginRequest(advanceToResult: !waitsOnSetup) else {
            if waitsOnSetup, flow.loadState != .idle {
                flow.goNext()
            }
            return
        }
        isSubmitting = waitsOnSetup
        requestTask = Task {
            do {
                let response = try await AppAPIClient().estimatePerformance(
                    cpuID: request.input.cpuID,
                    gpuID: request.input.gpuID,
                    resolution: request.input.resolution,
                    gameIDs: request.input.gameIDs
                )
                let remainingLoadingTime = minimumLoadingEnd.timeIntervalSinceNow
                if remainingLoadingTime > 0 {
                    try await Task.sleep(
                        nanoseconds: UInt64(remainingLoadingTime * 1_000_000_000)
                    )
                }
                try Task.checkCancellation()
                flow.apply(response.model, for: request)
                if waitsOnSetup {
                    isSubmitting = false
                    flow.goNext()
                }
            } catch is CancellationError {
                return
            } catch {
                isSubmitting = false
                flow.failRequest(error.localizedDescription, for: request)
                if waitsOnSetup {
                    flow.goNext()
                }
            }
        }
    }

    private func cancelRequest() {
        requestTask?.cancel()
        requestTask = nil
        isSubmitting = false
        flow.cancelRequest()
    }

    private func binding(for title: String) -> Binding<String> {
        Binding(
            get: { flow.hardwareProfile.value(for: title) },
            set: {
                if title == "CPU" {
                    flow.hardwareProfile.cpu = $0
                } else {
                    flow.hardwareProfile.gpu = $0
                }
            }
        )
    }
}

private struct PerformanceLoadingButton: View {
    var body: some View {
        HStack(spacing: 10) {
            ProgressView()
                .tint(.white)

            Text("正在计算预计帧率")
        }
        .font(.appSubheadline)
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .frame(height: 48)
        .background(
            AppTheme.primaryButton,
            in: RoundedRectangle(cornerRadius: AppTheme.controlRadius)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("正在计算预计帧率")
    }
}

private struct PerformanceNavigationHeader: View {
    let title: String
    let onBack: () -> Void

    var body: some View {
        ZStack {
            Text(title)
                .font(.appHeadline)
                .foregroundStyle(AppTheme.primaryText)
                .contentTransition(.opacity)
                .animation(.easeInOut(duration: 0.2), value: title)

            HStack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(AppTheme.primaryText)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("返回")

                Spacer()
            }
        }
        .frame(height: 44)
    }
}

private struct TestSetupStep: View {
    @Binding var hardwareProfile: HardwareProfile
    @Binding var selectedCategory: HardwareOptionCategory?
    let selectedGameCount: Int
    let areAllGamesSelected: Bool
    let isGameSelected: (PerformanceGame) -> Bool
    let onToggleGame: (PerformanceGame) -> Void
    let onToggleAllGames: () -> Void

    private let hardwareCategories = Array(HardwareProfileOptions.categories.prefix(2))

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("测试配置")
                            .font(.appHeadline)
                            .foregroundStyle(AppTheme.primaryText)

                        Spacer()

                        Text("仅需 CPU 和显卡")
                            .font(.appCaption)
                            .foregroundStyle(AppTheme.secondaryText)
                    }

                    PerformanceHardwareCompactBar(
                        categories: hardwareCategories,
                        selectedValue: { hardwareProfile.value(for: $0) }
                    ) { category in
                        selectedCategory = category
                    }
                }

                VStack(alignment: .leading, spacing: 9) {
                    HStack(spacing: 10) {
                        Text("选择游戏")
                            .font(.appHeadline)
                            .foregroundStyle(AppTheme.primaryText)

                        Spacer()

                        Text("已选择 \(selectedGameCount) 款")
                            .font(.appCaption)
                            .foregroundStyle(AppTheme.secondaryText)

                        Button(areAllGamesSelected ? "清空" : "全选", action: onToggleAllGames)
                            .font(.appBody.weight(.semibold))
                            .foregroundStyle(AppTheme.primaryText)
                            .buttonStyle(.plain)
                            .frame(minWidth: 44, minHeight: 44, alignment: .trailing)
                    }

                    PerformanceGameSelectionList(
                        games: PerformanceGame.samples,
                        isGameSelected: isGameSelected,
                        onToggleGame: onToggleGame
                    )
                }
            }
            .padding(.horizontal, AppTheme.screenPadding)
            .padding(.top, 18)
            .padding(.bottom, 16)
        }
    }
}

private struct PerformanceHardwareCompactBar: View {
    let categories: [HardwareOptionCategory]
    let selectedValue: (String) -> String
    let onSelect: (HardwareOptionCategory) -> Void

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(categories.enumerated()), id: \.element.id) { index, category in
                Button {
                    onSelect(category)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: category.icon)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(AppTheme.primaryText)
                            .frame(width: 38, height: 38)
                            .background {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(AppTheme.softSurface)
                                    .shadow(color: Color.white.opacity(0.9), radius: 1, x: 0, y: -1)
                                    .shadow(color: Color.black.opacity(0.08), radius: 2.5, x: 0, y: 2)
                            }
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.white.opacity(0.85), lineWidth: 0.8)
                            )

                        VStack(alignment: .leading, spacing: 3) {
                            Text(category.title)
                                .font(.appSubheadline)
                                .foregroundStyle(AppTheme.primaryText)
                            Text(displayValue(for: category.title))
                                .font(.appCaption)
                                .foregroundStyle(AppTheme.secondaryText)
                                .lineLimit(1)
                        }

                        Spacer(minLength: 5)

                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(AppTheme.secondaryText)
                    }
                    .padding(.horizontal, 12)
                    .frame(maxWidth: .infinity)
                    .frame(height: 74)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PerformanceMicroPressButtonStyle())

                if index != categories.count - 1 {
                    Divider()
                        .frame(height: 44)
                }
            }
        }
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(AppTheme.border.opacity(0.62))
                    .offset(y: 3)

                RoundedRectangle(cornerRadius: 16)
                    .fill(AppTheme.surface)
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(AppTheme.border.opacity(0.72), lineWidth: 1)
        }
        .overlay(alignment: .top) {
            Capsule()
                .fill(Color.white.opacity(0.95))
                .frame(height: 1)
                .padding(.horizontal, 16)
                .padding(.top, 1)
        }
        .shadow(color: Color.black.opacity(0.075), radius: 9, x: 0, y: 5)
        .shadow(color: Color.white.opacity(0.9), radius: 2, x: 0, y: -2)
    }

    private func displayValue(for title: String) -> String {
        let value = selectedValue(title)
        return value == "不知道" ? "未选择" : value
    }
}

private struct PerformanceMicroPressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .offset(y: configuration.isPressed ? 1.5 : 0)
            .opacity(configuration.isPressed ? 0.86 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

private struct PerformanceGameSelectionList: View {
    let games: [PerformanceGame]
    let isGameSelected: (PerformanceGame) -> Bool
    let onToggleGame: (PerformanceGame) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(games.enumerated()), id: \.element.id) { index, game in
                let selected = isGameSelected(game)

                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        onToggleGame(game)
                    }
                } label: {
                    HStack(spacing: 12) {
                        PerformanceGameArtwork(game: game, size: 48)

                        Text(game.name)
                            .font(.appBody.weight(.semibold))
                            .foregroundStyle(AppTheme.primaryText)
                            .lineLimit(1)

                        Spacer(minLength: 8)

                        Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(selected ? AppTheme.primaryText : AppTheme.border)
                    }
                    .padding(.horizontal, 14)
                    .frame(height: 70)
                    .background(selected ? AppTheme.primaryText.opacity(0.035) : Color.clear)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PerformanceMicroPressButtonStyle())
                .accessibilityValue(selected ? "已选择" : "未选择")

                if index != games.count - 1 {
                    Divider()
                        .padding(.leading, 74)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(AppTheme.border.opacity(0.62))
                    .offset(y: 3)

                RoundedRectangle(cornerRadius: 16)
                    .fill(AppTheme.surface)
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(AppTheme.border.opacity(0.72), lineWidth: 1)
        }
        .overlay(alignment: .top) {
            Capsule()
                .fill(Color.white.opacity(0.95))
                .frame(height: 1)
                .padding(.horizontal, 16)
                .padding(.top, 1)
        }
        .shadow(color: Color.black.opacity(0.075), radius: 9, x: 0, y: 5)
        .shadow(color: Color.white.opacity(0.9), radius: 2, x: 0, y: -2)
    }
}

private struct PerformanceGameArtwork: View {
    let game: PerformanceGame
    let size: CGFloat

    var body: some View {
        Image(game.artworkAssetName)
            .resizable()
            .scaledToFill()
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.22))
            .overlay(
                RoundedRectangle(cornerRadius: size * 0.22)
                    .stroke(Color.black.opacity(0.06), lineWidth: 0.5)
            )
            .accessibilityHidden(true)
    }
}

private extension PerformanceGame {
    var artworkAssetName: String {
        switch id {
        case "valorant": "GameArtworkValorant"
        case "cs2": "GameArtworkCS2"
        case "pubg": "GameArtworkPUBG"
        case "delta-force": "GameArtworkDeltaForce"
        case "teamfight-tactics": "GameArtworkTeamfightTactics"
        case "league-of-legends": "GameArtworkLeagueOfLegends"
        case "call-of-duty-warzone": "GameArtworkCallOfDuty"
        case "cyberpunk-2077": "GameArtworkCyberpunk2077"
        case "red-dead-redemption-2": "GameArtworkRedDeadRedemption2"
        case "gta-v": "GameArtworkGTAV"
        case "black-myth-wukong": "GameArtworkBlackMythWukong"
        case "forza-horizon-6": "GameArtworkForzaHorizon6"
        case "elden-ring": "GameArtworkEldenRing"
        case "cities-skylines": "GameArtworkCitiesSkylines"
        case "minecraft-java-edition": "GameArtworkMinecraft"
        default: "GameArtworkValorant"
        }
    }
}

private struct PerformanceResultStep: View {
    let flow: PerformanceTestFlow
    let onSelectResolution: (PerformanceResolution) -> Void

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                if let score = flow.result?.gpuTimeSpyScore {
                    PerformanceTimeSpyResolutionCard(
                        score: score,
                        overallPercent: overallPerformancePercent,
                        selectedResolution: flow.selectedResolution,
                        onSelectResolution: onSelectResolution
                    )
                } else {
                    PerformanceResolutionControl(
                        selectedResolution: flow.selectedResolution,
                        onSelect: onSelectResolution
                    )
                }

                resultContent

                PerformanceHardwareSummary(profile: flow.hardwareProfile)

                Text("预计结果基于各游戏已校准的高画质条件；超分与帧生成设置以对应测试样本为准。实际表现会受游戏版本、驱动、散热和后台程序影响。")
                    .font(.appCaption)
                    .foregroundStyle(AppTheme.secondaryText)
                    .lineSpacing(3)
                    .padding(.horizontal, 4)
            }
            .padding(.horizontal, AppTheme.screenPadding)
            .padding(.top, 20)
            .padding(.bottom, 16)
        }
    }

    private var overallPerformancePercent: Int? {
        guard
            let score = flow.result?.gpuTimeSpyScore,
            let cpuID = HardwareCatalog.cpus.first(where: {
                $0.name == flow.hardwareProfile.cpu
            })?.id
        else { return nil }
        return PerformanceHardwarePercentile.overall(
            cpuID: cpuID,
            gpuTimeSpyScore: score
        )
    }

    @ViewBuilder
    private var resultContent: some View {
        switch flow.loadState {
        case .idle, .loading:
            PerformanceStateCard(
                icon: "hourglass",
                title: "正在查询 \(flow.selectedResolution.title) 性能",
                detail: "正在根据当前 CPU、显卡和所选游戏计算预计平均帧率。",
                showsProgress: true
            )
        case .empty:
            PerformanceStateCard(
                icon: "database",
                title: "当前分辨率暂无可靠数据",
                detail: "可以切换其他分辨率，或返回修改 CPU、显卡和游戏。"
            )
        case .failed(let message):
            PerformanceStateCard(
                icon: "wifi.exclamationmark",
                title: "查询失败",
                detail: message
            )
        case .loaded, .partial:
            if let result = flow.result {
                VStack(spacing: 16) {
                    VStack(spacing: 0) {
                        if flow.loadState == .partial {
                            Text("部分游戏暂无数据：\(result.missingGameNames.joined(separator: "、"))")
                                .font(.appCaption)
                                .foregroundStyle(AppTheme.secondaryText)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(AppTheme.warning.opacity(0.08))

                            Divider()
                        }

                        ForEach(Array(result.gameResults.enumerated()), id: \.element.gameID) { index, game in
                            PerformanceResultRow(game: game)

                            if index < result.gameResults.count - 1 {
                                Divider()
                                    .padding(.leading, 78)
                            }
                        }
                    }
                    .micro3DSurface(cornerRadius: 18)
                }
            }
        }
    }
}

private struct PerformanceTimeSpyResolutionCard: View {
    let score: Int
    let overallPercent: Int?
    let selectedResolution: PerformanceResolution
    let onSelectResolution: (PerformanceResolution) -> Void

    var body: some View {
        VStack(spacing: 0) {
            PerformanceTimeSpyGaugeCard(
                score: score,
                overallPercent: overallPercent
            )

            Rectangle()
                .fill(AppTheme.border.opacity(0.58))
                .frame(height: 1)
                .padding(.horizontal, 18)

            PerformanceResolutionControl(
                selectedResolution: selectedResolution,
                onSelect: onSelectResolution,
                isEmbedded: true
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .micro3DSurface(cornerRadius: 18)
    }
}

private struct PerformanceTimeSpyGaugeCard: View {
    let score: Int
    let overallPercent: Int?

    private var progress: Double {
        min(max(Double(score) / 47_539, 0), 1)
    }

    private var performanceLevel: String {
        switch score {
        case ..<5_000: "入门级"
        case ..<10_000: "主流级"
        case ..<20_000: "高端级"
        case ..<30_000: "旗舰级"
        default: "顶级"
        }
    }

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height

            ZStack(alignment: .topLeading) {
                VStack(alignment: .leading, spacing: height * 0.018) {
                    Text("Time Spy 显卡分数")
                        .font(.system(size: height * 0.064, weight: .medium))
                        .foregroundStyle(AppTheme.secondaryText)

                    Text(score.formatted(.number.grouping(.automatic)))
                        .font(.system(size: height * 0.215, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.primaryText)

                    Text("3DMark 图形性能基准")
                        .font(.system(size: height * 0.064, weight: .regular))
                        .foregroundStyle(AppTheme.secondaryText)

                    Spacer(minLength: height * 0.025)

                    HStack(spacing: 0) {
                        PerformanceTimeSpyMetric(
                            title: "性能级别",
                            value: performanceLevel
                        )

                        Divider()
                            .frame(height: height * 0.12)
                            .padding(.horizontal, width * 0.018)

                        PerformanceTimeSpyMetric(
                            title: "超越用户",
                            value: overallPercent.map { "\($0)%" } ?? "--"
                        )
                    }
                    .padding(.horizontal, width * 0.022)
                    .frame(height: height * 0.275)
                    .background(AppTheme.softSurface)
                    .clipShape(
                        RoundedRectangle(
                            cornerRadius: height * 0.032,
                            style: .continuous
                        )
                    )
                    .overlay {
                        RoundedRectangle(
                            cornerRadius: height * 0.032,
                            style: .continuous
                        )
                        .stroke(AppTheme.border.opacity(0.62), lineWidth: 1)
                    }
                }
                .frame(width: width * 0.445, height: height * 0.82)
                .position(x: width * 0.266, y: height * 0.515)

                Rectangle()
                    .fill(AppTheme.border.opacity(0.72))
                    .frame(width: 1)
                    .frame(height: height * 0.84)
                    .position(x: width * 0.547, y: height * 0.5)

                PerformanceTimeSpyGauge(progress: progress)
                    .frame(width: width * 0.365, height: height * 0.60)
                    .position(x: width * 0.766, y: height * 0.515)
            }
        }
        .aspectRatio(738 / 320, contentMode: .fit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Time Spy 显卡分数")
        .accessibilityValue(
            "\(score) 分，\(performanceLevel)，超越用户 "
                + (overallPercent.map { "\($0)%" } ?? "暂无数据")
        )
    }
}

private struct PerformanceTimeSpyMetric: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(AppTheme.secondaryText)
                .lineLimit(1)

            Text(value)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(AppTheme.primaryText)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct PerformanceTimeSpyGauge: View {
    let progress: Double

    var body: some View {
        GeometryReader { proxy in
            let center = CGPoint(x: proxy.size.width / 2, y: proxy.size.height - 9)
            let radius = min(proxy.size.width / 2 - 5, proxy.size.height - 14)

            ZStack {
                PerformanceGaugeArc(progress: 1)
                    .stroke(
                        AppTheme.border.opacity(0.72),
                        style: StrokeStyle(lineWidth: 9, lineCap: .round)
                    )

                PerformanceGaugeArc(progress: progress)
                    .stroke(
                        AppTheme.primaryText,
                        style: StrokeStyle(lineWidth: 9, lineCap: .round)
                    )

                Capsule()
                    .fill(AppTheme.primaryText)
                    .frame(width: radius - 12, height: 3)
                    .offset(x: (radius - 12) / 2)
                    .rotationEffect(.degrees(180 + progress * 180))
                    .position(center)

                Circle()
                    .fill(AppTheme.primaryText)
                    .frame(width: 12, height: 12)
                    .position(center)

                HStack {
                    Text("0")
                    Spacer()
                    Text("47K")
                }
                .font(.system(size: 9, weight: .semibold, design: .rounded))
                .foregroundStyle(AppTheme.secondaryText)
                .padding(.horizontal, 2)
                .frame(maxHeight: .infinity, alignment: .bottom)
            }
        }
    }
}

private struct PerformanceGaugeArc: Shape {
    let progress: Double

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.maxY - 9)
        let radius = min(rect.width / 2 - 5, rect.height - 14)
        var path = Path()
        path.addArc(
            center: center,
            radius: radius,
            startAngle: .degrees(180),
            endAngle: .degrees(180 + 180 * progress),
            clockwise: false
        )
        return path
    }
}

private struct PerformanceResolutionControl: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var selectionAnimation

    let selectedResolution: PerformanceResolution
    let onSelect: (PerformanceResolution) -> Void
    var isEmbedded = false

    var body: some View {
        Group {
            if isEmbedded {
                segments
                    .padding(.horizontal, 4)
                    .padding(.vertical, 6)
                    .background(AppTheme.softSurface.opacity(0.72))
            } else {
                segments
                    .padding(4)
                    .micro3DSurface(
                        cornerRadius: 18,
                        surfaceColor: AppTheme.softSurface
                    )
            }
        }
        .sensoryFeedback(.selection, trigger: selectedResolution)
    }

    private var segments: some View {
        HStack(spacing: 4) {
            ForEach(PerformanceResolution.allCases) { resolution in
                Button {
                    guard selectedResolution != resolution else { return }
                    withAnimation(selectionTransition) {
                        onSelect(resolution)
                    }
                } label: {
                    Text(resolution.title)
                        .font(.appSubheadline)
                        .foregroundStyle(
                            selectedResolution == resolution
                                ? Color.white
                                : AppTheme.secondaryText
                        )
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background {
                            if selectedResolution == resolution {
                                PerformanceResolutionSegmentSurface()
                                    .matchedGeometryEffect(
                                        id: "performance-resolution-selection",
                                        in: selectionAnimation
                                    )
                            }
                        }
                }
                .buttonStyle(Micro3DPressButtonStyle())
                .accessibilityAddTraits(selectedResolution == resolution ? .isSelected : [])
            }
        }
    }

    private var selectionTransition: Animation {
        reduceMotion
            ? .linear(duration: 0.01)
            : .spring(response: 0.38, dampingFraction: 0.82, blendDuration: 0.08)
    }
}

private struct PerformanceResolutionSegmentSurface: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.black.opacity(0.58))
                .offset(y: 3)

            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(AppTheme.primaryText)
        }
        .overlay(alignment: .top) {
            Capsule()
                .fill(Color.white.opacity(0.18))
                .frame(height: 1)
                .padding(.horizontal, 12)
                .padding(.top, 1)
        }
        .shadow(color: Color.black.opacity(0.16), radius: 6, x: 0, y: 4)
    }
}

private struct PerformanceResultRow: View {
    let game: GamePerformanceResult

    var body: some View {
        HStack(spacing: 14) {
            if let performanceGame = PerformanceGame.samples.first(where: { $0.id == game.gameID }) {
                PerformanceGameArtwork(game: performanceGame, size: 48)
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(PerformanceGame.name(for: game.gameID))
                    .font(.appSubheadline)
                    .foregroundStyle(AppTheme.primaryText)
                    .lineLimit(1)
                Text("预计平均帧率")
                    .font(.appCaption)
                    .foregroundStyle(AppTheme.secondaryText)
            }

            Spacer(minLength: 12)

            HStack(alignment: .lastTextBaseline, spacing: 5) {
                Text("\(game.averageFPS)")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.primaryText)
                Text("FPS")
                    .font(.appCaption.weight(.semibold))
                    .foregroundStyle(AppTheme.secondaryText)
            }
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 96)
    }
}

private struct PerformanceHardwareSummary: View {
    let profile: HardwareProfile

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("测试配置")
                .font(.appSubheadline)
                .foregroundStyle(AppTheme.primaryText)

            HStack(spacing: 0) {
                PerformanceHardwareInlineItem(icon: "cpu", title: "CPU", value: profile.cpu)

                Divider()
                    .frame(height: 34)
                    .padding(.horizontal, 12)

                PerformanceHardwareInlineItem(icon: "display", title: "显卡", value: profile.gpu)
            }
        }
        .padding(16)
        .micro3DSurface(cornerRadius: 16)
    }
}

private struct PerformanceHardwareInlineItem: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppTheme.primaryText)
                .frame(width: 30, height: 30)
                .background(AppTheme.softSurface, in: RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.appCaption.weight(.semibold))
                    .foregroundStyle(AppTheme.primaryText)
                Text(value)
                    .font(.appCaption)
                    .foregroundStyle(AppTheme.secondaryText)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct PerformanceStateCard: View {
    let icon: String
    let title: String
    let detail: String
    var showsProgress = false

    var body: some View {
        VStack(spacing: 12) {
            if showsProgress {
                PerformanceLoadingIndicator()
            } else {
                Image(systemName: icon)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(AppTheme.secondaryText)
            }
            Text(title)
                .font(.appSubheadline)
                .foregroundStyle(AppTheme.primaryText)
            Text(detail)
                .font(.appCaption)
                .foregroundStyle(AppTheme.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .micro3DSurface(cornerRadius: 18)
    }
}

private struct PerformanceLoadingIndicator: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isAnimating = false

    private let barHeights: [CGFloat] = [12, 21, 16, 25]

    var body: some View {
        HStack(alignment: .bottom, spacing: 4) {
            ForEach(barHeights.indices, id: \.self) { index in
                Capsule()
                    .fill(AppTheme.primaryText)
                    .frame(width: 4, height: barHeights[index])
                    .scaleEffect(
                        y: reduceMotion ? 0.72 : (isAnimating ? 1 : 0.34),
                        anchor: .bottom
                    )
                    .opacity(reduceMotion ? 0.72 : (isAnimating ? 1 : 0.42))
                    .animation(
                        reduceMotion
                            ? nil
                            : .easeInOut(duration: 0.52)
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.10),
                        value: isAnimating
                    )
            }
        }
        .frame(width: 44, height: 34)
        .background(AppTheme.softSurface, in: RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(AppTheme.border.opacity(0.72), lineWidth: 1)
        }
        .onAppear {
            isAnimating = true
        }
    }
}

private struct PerformanceSecondaryButton: View {
    let title: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                Text(title)
            }
            .font(.appSubheadline)
            .foregroundStyle(AppTheme.primaryText)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .micro3DSurface(cornerRadius: AppTheme.controlRadius)
        }
        .buttonStyle(Micro3DPressButtonStyle())
    }
}

#Preview {
    GamePerformanceView(savedHardwareProfile: .skipped, onBack: {})
}
