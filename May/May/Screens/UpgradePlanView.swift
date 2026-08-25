import SwiftUI
import UIKit

private let upgradeFlowBackground = Color(red: 0.972, green: 0.978, blue: 0.978)
private let upgradeFlowDivider = Color.black.opacity(0.10)

private enum UpgradePlanLoadState: Equatable {
    case idle
    case loading
    case loaded(UpgradePlanResponseDTO)
    case failed(String)
}

struct UpgradePlanView: View {
    let onBack: () -> Void
    let accessToken: String?

    @State private var configuration = UpgradePlanConfiguration.sample
    @State private var selectedHardwareCategory: HardwareOptionCategory?
    @State private var showsGamePicker = false
    @State private var showsGameSelectionAlert = false
    @State private var missingHardwareTitles: [String] = []
    @State private var isSaved = false
    @State private var isSaving = false
    @State private var saveError: String?
    @State private var planLoadState: UpgradePlanLoadState = .idle

    init(
        savedHardwareProfile: HardwareProfile,
        accessToken: String? = nil,
        initialResponse: UpgradePlanResponseDTO? = nil,
        onBack: @escaping () -> Void
    ) {
        self.onBack = onBack
        self.accessToken = accessToken
        var initialConfiguration = UpgradePlanConfiguration.sample
        initialConfiguration.apply(savedHardwareProfile)
        if let initialResponse {
            initialConfiguration.step = .result
            initialConfiguration.goal = .gaming
            initialConfiguration.budget = initialResponse.budget
            initialConfiguration.frameTarget = initialResponse.targetFps ?? initialConfiguration.frameTarget
            initialConfiguration.resolution = switch initialResponse.resolution {
            case "1080p": .fullHD
            case "4k": .fourK
            default: .twoK
            }
            initialConfiguration.selectedGames = Set(
                initialResponse.gameResults.compactMap { result in
                    UpgradePlanConfiguration.gameIDs.first { $0.value == result.game }?.key
                }
            )
        }
        _configuration = State(initialValue: initialConfiguration)
        _planLoadState = State(
            initialValue: initialResponse.map(UpgradePlanLoadState.loaded) ?? .idle
        )
        _isSaved = State(initialValue: initialResponse != nil)
    }

    var body: some View {
        VStack(spacing: 0) {
            UpgradeNavigationHeader(
                step: configuration.step,
                onBack: handleBack
            )
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .padding(.bottom, 8)

            Group {
                switch configuration.step {
                case .computer:
                    UpgradeComputerStep(
                        configuration: $configuration,
                        selectedCategory: $selectedHardwareCategory,
                        onNext: advanceFromComputer
                    )
                case .goal:
                    UpgradeGoalStep(
                        configuration: $configuration,
                        onChooseGames: { showsGamePicker = true },
                        onGenerate: generatePlan
                    )
                case .result:
                    UpgradeResultStep(
                        configuration: configuration,
                        loadState: planLoadState,
                        isSaved: isSaved,
                        isSaving: isSaving,
                        onAdjust: {
                            withAnimation(.easeOut(duration: 0.24)) {
                                configuration.step = .goal
                            }
                        },
                        onSave: savePlan,
                        onRetry: generatePlan
                    )
                }
            }
            .id(configuration.step)
            .transition(.opacity.combined(with: .move(edge: .trailing)))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(upgradeFlowBackground.ignoresSafeArea())
        .animation(.easeOut(duration: 0.24), value: configuration.step)
        .sheet(item: $selectedHardwareCategory) { category in
            HardwarePickerSheet(
                title: category.title,
                icon: category.icon,
                filters: filters(for: category),
                contextMessage: contextMessage(for: category),
                selectedValue: binding(for: category.title)
            )
            .presentationDetents([.large])
        }
        .sheet(isPresented: $showsGamePicker) {
            UpgradeGamePickerSheet(selectedGames: $configuration.selectedGames)
                .presentationDetents([.medium, .large])
        }
        .alert("请选择一个游戏", isPresented: $showsGameSelectionAlert) {
            Button("去选择") {
                showsGamePicker = true
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("至少选择一个优先参考的游戏后，才能生成游戏性能升级方案。")
        }
        .alert(
            "请先选好 5 项硬件",
            isPresented: Binding(
                get: { !missingHardwareTitles.isEmpty },
                set: { if !$0 { missingHardwareTitles = [] } }
            )
        ) {
            Button("继续选择", role: .cancel) { missingHardwareTitles = [] }
        } message: {
            Text("还需要选择：\(missingHardwareTitles.joined(separator: "、"))")
        }
        .alert(
            "保存失败",
            isPresented: Binding(
                get: { saveError != nil },
                set: { if !$0 { saveError = nil } }
            )
        ) {
            Button("知道了", role: .cancel) { saveError = nil }
        } message: {
            Text(saveError ?? "请稍后重试")
        }
        .onChange(of: configuration.selectedGames) { _, _ in
            configuration.clampFrameTarget()
        }
        .onChange(of: configuration.resolution) { _, _ in
            configuration.clampFrameTarget()
        }
    }

    private func handleBack() {
        if configuration.step == .computer {
            onBack()
        } else {
            withAnimation(.easeOut(duration: 0.24)) {
                configuration.goBack()
            }
        }
    }

    private func advance() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation(.easeOut(duration: 0.24)) {
            configuration.goNext()
        }
    }

    private func advanceFromComputer() {
        let missingTitles = configuration.missingRequiredHardwareTitles
        guard missingTitles.isEmpty else {
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            missingHardwareTitles = missingTitles
            return
        }
        advance()
    }

    private func generatePlan() {
        guard configuration.hasRequiredGameSelection else {
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            showsGameSelectionAlert = true
            return
        }
        let request = configuration.apiRequest
        planLoadState = .loading
        isSaved = false
        advance()
        Task { @MainActor in
            do {
                planLoadState = .loaded(try await AppAPIClient().upgradePlan(request))
            } catch {
                planLoadState = .failed(error.localizedDescription)
            }
        }
    }

    private func savePlan() {
        guard case .loaded(let response) = planLoadState else { return }
        guard let accessToken else {
            saveError = "登录状态已失效，请重新登录后保存。"
            return
        }
        isSaving = true
        Task { @MainActor in
            defer { isSaving = false }
            do {
                _ = try await AppAPIClient().saveUpgradePlan(
                    response,
                    title: savedPlanTitle(response),
                    token: accessToken
                )
                isSaved = true
            } catch {
                saveError = error.localizedDescription
            }
        }
    }

    private func savedPlanTitle(_ response: UpgradePlanResponseDTO) -> String {
        let games = response.gameResults.prefix(2).map { result in
            UpgradePlanConfiguration.gameIDs.first { $0.value == result.game }?.key ?? result.game
        }
        let gameTitle = games.isEmpty ? "游戏" : games.joined(separator: "、")
        let target = response.targetFps.map { "\($0) 帧" } ?? "升级"
        return "\(gameTitle) · \(configuration.resolution.rawValue) \(target)"
    }

    private func binding(for title: String) -> Binding<String> {
        Binding(
            get: { configuration.value(for: title) },
            set: { _ = configuration.hardwareProfile.updateValue($0, for: title) }
        )
    }

    private func filters(for category: HardwareOptionCategory) -> [HardwareCatalogFilter] {
        category.title == "主板"
            ? HardwareCatalog.motherboardFilters(compatibleWithCPU: configuration.hardwareProfile.cpu)
            : HardwareCatalog.filters(for: category.title)
    }

    private func contextMessage(for category: HardwareOptionCategory) -> String? {
        let cpu = configuration.hardwareProfile.cpu
        guard category.title == "主板", let socket = HardwareCatalog.cpuSocket(for: cpu) else { return nil }
        return "已根据 \(cpu) 筛选 \(socket) 兼容主板"
    }
}

private struct UpgradeNavigationHeader: View {
    let step: UpgradePlanStep
    let onBack: () -> Void

    var body: some View {
        ZStack {
            Text("升级建议")
                .font(.system(size: 18, weight: .heavy))
                .foregroundStyle(.black)

            HStack {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.black)
                    .frame(width: 28, height: 36)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("返回")

            Spacer()

                Text("\(step.rawValue) / 3")
                    .foregroundStyle(.black)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
            .accessibilityLabel("第 \(step.rawValue) 步，共 3 步，\(step.title)")
            }
        }
        .frame(height: 42)
    }
}

private struct UpgradeComputerStep: View {
    @Binding var configuration: UpgradePlanConfiguration
    @Binding var selectedCategory: HardwareOptionCategory?
    let onNext: () -> Void

    private let requiredTitles = ["CPU", "显卡", "主板", "内存", "电源"]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                UpgradeEditorialTitle(
                    title: "告诉我，\n你现在用的电脑。",
                    subtitle: "请完整选择 5 项核心硬件，用于准确判断升级空间"
                )

                UpgradeHardwareSection(
                    title: "5 项必选配置",
                    subtitle: "CPU、显卡、主板、内存和电源需要全部选择",
                    categories: categories(titles: requiredTitles),
                    startIndex: 1,
                    configuration: configuration,
                    onSelect: { selectedCategory = $0 }
                )
                .padding(.top, 30)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 22)
            .frame(maxWidth: 520, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .safeAreaInset(edge: .bottom) {
            UpgradePrimaryAction(title: "下一步", action: onNext)
                .padding(.horizontal, 24)
                .padding(.top, 10)
                .padding(.bottom, 14)
                .background(upgradeFlowBackground)
        }
    }

    private func categories(titles: [String]) -> [HardwareOptionCategory] {
        titles.compactMap { title in
            UpgradePlanConfiguration.categories.first { $0.title == title }
        }
    }
}

private struct UpgradeEditorialTitle: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.system(size: 42, weight: .heavy))
                .tracking(-1.3)
                .lineSpacing(-2)
                .foregroundStyle(.black)
                .fixedSize(horizontal: false, vertical: true)

            Text(subtitle)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.black.opacity(0.48))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 24)
    }
}

private struct UpgradeHardwareSection: View {
    let title: String
    let subtitle: String
    let categories: [HardwareOptionCategory]
    let startIndex: Int
    let configuration: UpgradePlanConfiguration
    let onSelect: (HardwareOptionCategory) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !title.isEmpty {
                Text(title)
                    .font(.system(size: 20, weight: .heavy))
                    .foregroundStyle(.black)

                Text(subtitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.black.opacity(0.42))
                    .padding(.top, 5)
                    .padding(.bottom, 12)
            }

            ForEach(Array(categories.enumerated()), id: \.element.id) { offset, category in
                Button {
                    onSelect(category)
                } label: {
                    HStack(spacing: 16) {
                        Text(String(format: "%02d", startIndex + offset))
                            .font(.system(size: 25, weight: .heavy, design: .rounded))
                            .foregroundStyle(.black)
                            .frame(width: 42, alignment: .leading)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(category.title)
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(.black)
                            Text(configuration.value(for: category.title))
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Color.black.opacity(0.42))
                                .lineLimit(1)
                        }

                        Spacer(minLength: 8)

                        Image(systemName: "arrow.right")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(.black)
                    }
                    .frame(height: 66)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Divider().overlay(upgradeFlowDivider)
            }
        }
    }
}

private struct UpgradeGoalStep: View {
    @Binding var configuration: UpgradePlanConfiguration
    let onChooseGames: () -> Void
    let onGenerate: () -> Void

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("设定你的游戏目标")
                        .font(.system(size: 35, weight: .heavy))
                        .tracking(-1.4)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)

                    Text("按游戏、分辨率和目标帧率生成可验证的升级建议")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.black.opacity(0.48))
                }
                .padding(.horizontal, 24)
                .padding(.top, 34)

                UpgradeConditionsSection(
                    configuration: $configuration,
                    onChooseGames: onChooseGames
                )
                .padding(.horizontal, 24)
                .padding(.top, 36)
            }
            .padding(.bottom, 22)
            .frame(maxWidth: 520, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .safeAreaInset(edge: .bottom) {
            UpgradePrimaryAction(title: "生成升级方案", action: onGenerate)
                .padding(.horizontal, 24)
                .padding(.top, 10)
                .padding(.bottom, 14)
                .background(upgradeFlowBackground)
        }
    }
}

private struct UpgradeConditionsSection: View {
    @Binding var configuration: UpgradePlanConfiguration
    let onChooseGames: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(configuration.goal.conditionsTitle)
                .font(.system(size: 22, weight: .heavy))
                .foregroundStyle(.black)

            UpgradeBudgetSlider(budget: $configuration.budget)
                .padding(.top, 24)

            UpgradeSelectedGames(
                selectedGames: $configuration.selectedGames,
                onAdd: onChooseGames
            )
            .padding(.top, 26)

            UpgradePerformanceTargets(configuration: $configuration)
                .padding(.top, 28)
        }
    }
}

private struct UpgradeBudgetSlider: View {
    @Binding var budget: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("预算上限")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.black.opacity(0.58))

            Text("¥\(budget)")
                .font(.system(size: 38, weight: .heavy, design: .rounded))
                .frame(maxWidth: .infinity)
                .padding(.top, 12)

            HStack(spacing: 12) {
                Text("¥500")
                Slider(
                    value: Binding(
                        get: { Double(budget) },
                        set: { budget = Int(($0 / 500).rounded()) * 500 }
                    ),
                    in: 500...12000,
                    step: 500
                )
                .tint(.black)
                Text("¥12000")
            }
            .font(.system(size: 11, weight: .medium))
            .padding(.top, 8)
        }
    }
}

private struct UpgradeSelectedGames: View {
    @Binding var selectedGames: Set<String>
    let onAdd: () -> Void

    private var displayedGames: [String] {
        UpgradePlanConfiguration.games.filter(selectedGames.contains).prefix(3).map { $0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("优先参考的游戏（可多选）")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.black.opacity(0.58))

            HStack(spacing: 10) {
                ForEach(displayedGames, id: \.self) { game in
                    Button {
                        selectedGames.remove(game)
                    } label: {
                        UpgradeGameCard(game: game)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("取消选择 \(game)")
                }

                Button(action: onAdd) {
                    VStack(spacing: 8) {
                        Image(systemName: "plus")
                            .font(.system(size: 23, weight: .medium))
                        Text("添加游戏")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 82)
                    .background(Color.white.opacity(0.52), in: RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.black.opacity(0.12), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct UpgradeGameCard: View {
    let game: String

    private var mark: String {
        switch game {
        case "无畏契约": return "V"
        case "三角洲行动": return "三角洲"
        case "云顶之弈": return "云顶"
        case "英雄联盟": return "LOL"
        case "使命召唤": return "COD"
        case "赛博朋克2077": return "2077"
        case "荒野大镖客2": return "RDR2"
        case "GTA5": return "GTA"
        case "黑神话悟空": return "悟空"
        case "地平线6": return "FH6"
        case "艾尔登法环": return "环"
        case "城市天际线": return "城市"
        case "我的世界": return "MC"
        default: return game
        }
    }

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Spacer()
                Image(systemName: "checkmark.square.fill")
                    .font(.system(size: 12, weight: .bold))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.black, .white)
            }

            Text(mark)
                .font(.system(size: mark.count > 4 ? 14 : 20, weight: .black))
                .minimumScaleFactor(0.68)
                .lineLimit(1)

            Text(game)
                .font(.system(size: 11, weight: .medium))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .foregroundStyle(.white)
        .padding(8)
        .frame(maxWidth: .infinity)
        .frame(height: 82)
        .background(.black, in: RoundedRectangle(cornerRadius: 14))
    }
}

private struct UpgradePerformanceTargets: View {
    @Binding var configuration: UpgradePlanConfiguration

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("性能目标")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.black.opacity(0.58))

            HStack(spacing: 0) {
                Menu {
                    ForEach(UpgradeResolution.allCases) { resolution in
                        Button(resolution.rawValue) { configuration.resolution = resolution }
                    }
                } label: {
                    UpgradePerformanceTarget(value: configuration.resolution.rawValue, title: "分辨率")
                }

                Rectangle()
                    .fill(upgradeFlowDivider)
                    .frame(width: 1, height: 70)

                Menu {
                    ForEach(configuration.frameTargetOptions, id: \.self) { target in
                        Button("\(target) 帧") { configuration.frameTarget = target }
                    }
                } label: {
                    UpgradePerformanceTarget(
                        value: configuration.frameLimit == nil ? "—" : "\(configuration.frameTarget)",
                        title: configuration.frameLimit.map { "参考上限 \($0) 帧" } ?? "选择游戏后计算"
                    )
                }
                .disabled(configuration.frameLimit == nil)
            }

        }
    }
}

private struct UpgradePerformanceTarget: View {
    let value: String
    let title: String

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.black.opacity(0.48))
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 15, weight: .semibold))
        }
        .foregroundStyle(.black)
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
    }
}

private struct UpgradeResultStep: View {
    let configuration: UpgradePlanConfiguration
    let loadState: UpgradePlanLoadState
    let isSaved: Bool
    let isSaving: Bool
    let onAdjust: () -> Void
    let onSave: () -> Void
    let onRetry: () -> Void

    var body: some View {
        ScrollView(showsIndicators: false) {
            resultContent
            .padding(.horizontal, 24)
            .padding(.bottom, 22)
            .frame(maxWidth: 520, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 8) {
                Button("重新调整条件", action: onAdjust)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.black)
                    .frame(height: 30)

                if case .failed = loadState {
                    UpgradePrimaryAction(title: "重新生成", action: onRetry)
                } else {
                    UpgradePrimaryAction(
                        title: isSaved ? "方案已保存" : isSaving ? "正在保存…" : "保存升级方案",
                        icon: isSaved ? "checkmark" : "arrow.right",
                        action: onSave
                    )
                    .disabled(isSaved || isSaving || !canSave)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .padding(.bottom, 14)
            .background(upgradeFlowBackground)
        }
    }

    @ViewBuilder
    private var resultContent: some View {
        switch loadState {
        case .idle, .loading:
            VStack(spacing: 18) {
                ProgressView()
                    .tint(.black)
                    .scaleEffect(1.2)
                Text("正在计算目标帧率与配件兼容性…")
                    .font(.system(size: 15, weight: .bold))
                Text("会同时检查 CPU、显卡、主板、内存和电源")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.black.opacity(0.46))
            }
            .frame(maxWidth: .infinity, minHeight: 420)
        case .failed(let message):
            UpgradeEditorialTitle(
                title: "这次没有生成成功。",
                subtitle: message
            )
        case .loaded(let response):
            loadedContent(response)
        }
    }

    private func loadedContent(_ response: UpgradePlanResponseDTO) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            UpgradeEditorialTitle(
                title: resultHeadline(response),
                subtitle: response.summary
            )

            VStack(alignment: .leading, spacing: 14) {
                Text(resultStatus(response))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.56))

                HStack(alignment: .bottom) {
                    Text(response.steps.first.map { roleLabel($0.role) } ?? "暂无可执行方案")
                        .font(.system(size: 28, weight: .heavy))
                    Spacer()
                    Text("¥\(response.totalEstimatedPrice)")
                        .font(.system(size: 17, weight: .heavy, design: .rounded))
                }
                .foregroundStyle(.white)

                if let target = response.targetFps {
                    Text("目标：\(configuration.resolution.rawValue) · \(target) 帧")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.66))
                }

                if !response.missingFields.isEmpty {
                    Text("需要补充：\(response.missingFields.joined(separator: "、"))")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.66))
                }
            }
            .padding(20)
            .background(.black, in: RoundedRectangle(cornerRadius: 20))
            .padding(.top, 28)

            if !response.steps.isEmpty {
                Text("升级套装")
                    .font(.system(size: 21, weight: .heavy))
                    .padding(.top, 30)
                    .padding(.bottom, 8)

                ForEach(stepBundles(response.steps), id: \.id) { bundle in
                    VStack(alignment: .leading, spacing: 0) {
                        HStack {
                            Text(bundle.title)
                                .font(.system(size: 14, weight: .heavy))
                            Spacer()
                            if bundle.requiredTogether {
                                Text("需同时更换")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(Color.black.opacity(0.52))
                            }
                        }
                        .padding(.top, 14)

                        ForEach(bundle.steps) { step in
                            UpgradeResultRow(
                                number: String(format: "%02d", step.order),
                                title: roleLabel(step.role),
                                detail: stepDetail(step),
                                explanation: step.reason
                            )
                        }
                    }
                }
            }

            if !response.gameResults.isEmpty {
                Text("预估游戏表现")
                    .font(.system(size: 21, weight: .heavy))
                    .padding(.top, 30)
                    .padding(.bottom, 8)

                ForEach(response.gameResults) { result in
                    UpgradeResultRow(
                        number: result.met ? "✓" : "—",
                        title: gameName(result.game),
                        detail: "\(result.beforeFps) → \(result.afterFps) 帧（目标 \(result.targetFps)）"
                    )
                }
            }

            if !response.notes.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("说明")
                        .font(.system(size: 17, weight: .heavy))
                    ForEach(response.notes, id: \.self) { note in
                        Text("· \(note)")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color.black.opacity(0.52))
                            .lineSpacing(4)
                    }
                }
                .padding(.top, 26)
            }

            if let priceDate = response.priceDate {
                Text("参考价日期：\(priceDate)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.black.opacity(0.42))
                    .padding(.top, 16)
            }
        }
    }

    private func stepBundles(_ steps: [UpgradeStepDTO]) -> [UpgradeStepBundle] {
        Dictionary(grouping: steps, by: \.bundleId)
            .map { bundleID, steps in
                UpgradeStepBundle(
                    id: bundleID,
                    title: steps.first?.bundleTitle ?? "升级套装",
                    requiredTogether: steps.contains(where: \.requiredTogether),
                    steps: steps.sorted { $0.order < $1.order }
                )
            }
            .sorted { ($0.steps.first?.order ?? 0) < ($1.steps.first?.order ?? 0) }
    }

    private func stepDetail(_ step: UpgradeStepDTO) -> String {
        let gain = step.expectedGainPercent > 0 ? " · 约 +\(step.expectedGainPercent)%" : ""
        return "\(step.fromName) → \(step.toName) · ¥\(step.estimatedPrice)\(gain)"
    }

    private var canSave: Bool {
        guard case .loaded(let response) = loadState else { return false }
        return response.status == "ready" && !response.steps.isEmpty
    }

    private func resultHeadline(_ response: UpgradePlanResponseDTO) -> String {
        if response.status == "already_sufficient" { return "当前配置，\n已经达到目标。" }
        if response.status == "needs_more_info" { return "还需要，\n补齐几项配置。" }
        if response.status == "no_plan" { return "这个预算内，\n暂无可执行方案。" }
        if response.targetMet == false { return "预算内，\n先做到最接近。" }
        return "这台电脑，\n按这个顺序升级。"
    }

    private func resultStatus(_ response: UpgradePlanResponseDTO) -> String {
        if response.status == "already_sufficient" { return "无需升级" }
        if response.targetMet == true { return "预估可达成目标" }
        if response.targetMet == false { return "预算内最接近方案" }
        return "核心建议"
    }

    private func roleLabel(_ role: String) -> String {
        [
            "cpu": "CPU", "gpu": "显卡", "motherboard": "主板",
            "ram": "内存", "psu": "电源", "cooler": "散热器", "case": "机箱"
        ][role] ?? role
    }

    private func gameName(_ gameID: String) -> String {
        UpgradePlanConfiguration.gameIDs.first { $0.value == gameID }?.key ?? gameID
    }
}

private struct UpgradeStepBundle: Identifiable {
    let id: String
    let title: String
    let requiredTogether: Bool
    let steps: [UpgradeStepDTO]
}

private struct UpgradeResultRow: View {
    let number: String
    let title: String
    let detail: String
    var explanation: String? = nil

    var body: some View {
        HStack(spacing: 18) {
            Text(number)
                .font(.system(size: 26, weight: .heavy, design: .rounded))
                .frame(width: 42, alignment: .leading)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 15, weight: .bold))
                Text(detail)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.black.opacity(0.44))
                if let explanation {
                    Text(explanation)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.black.opacity(0.42))
                        .lineLimit(2)
                }
            }

            Spacer()

            Image(systemName: "arrow.right")
                .font(.system(size: 16, weight: .medium))
        }
        .foregroundStyle(.black)
        .frame(minHeight: explanation == nil ? 70 : 88)
        .overlay(alignment: .bottom) {
            Rectangle().fill(upgradeFlowDivider).frame(height: 1)
        }
    }
}

private struct UpgradePrimaryAction: View {
    let title: String
    var icon: String = "arrow.right"
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: .heavy))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background {
                    ZStack {
                        Capsule().fill(Color.black.opacity(0.52)).offset(y: 4)
                        Capsule().fill(Color.black)
                    }
                }
                .overlay(alignment: .trailing) {
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.trailing, 24)
                }
                .shadow(color: Color.black.opacity(0.16), radius: 10, x: 0, y: 7)
        }
        .buttonStyle(Micro3DPressButtonStyle())
    }
}

private struct UpgradeGamePickerSheet: View {
    @Binding var selectedGames: Set<String>
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Capsule()
                .fill(Color.black.opacity(0.16))
                .frame(width: 42, height: 5)
                .frame(maxWidth: .infinity)
                .padding(.top, 10)

            Text("选择常玩的游戏")
                .font(.system(size: 28, weight: .heavy))

            Text("可以多选，推荐结果会优先参考这些游戏。")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.black.opacity(0.48))

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 2), spacing: 10) {
                ForEach(UpgradePlanConfiguration.games, id: \.self) { game in
                    let isSelected = selectedGames.contains(game)
                    Button {
                        if isSelected {
                            selectedGames.remove(game)
                        } else {
                            selectedGames.insert(game)
                        }
                    } label: {
                        HStack {
                            Text(game)
                                .font(.system(size: 14, weight: .bold))
                            Spacer()
                            Image(systemName: isSelected ? "checkmark" : "plus")
                                .font(.system(size: 13, weight: .bold))
                        }
                        .foregroundStyle(isSelected ? Color.white : Color.black)
                        .padding(.horizontal, 14)
                        .frame(height: 54)
                        .background(isSelected ? Color.black : Color.white, in: RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }

            Spacer(minLength: 0)

            UpgradePrimaryAction(title: "完成", icon: "checkmark") {
                dismiss()
            }
            .padding(.bottom, 12)
        }
        .padding(.horizontal, 24)
        .background(upgradeFlowBackground.ignoresSafeArea())
    }
}

#Preview {
    UpgradePlanView(savedHardwareProfile: .skipped, onBack: {})
}
