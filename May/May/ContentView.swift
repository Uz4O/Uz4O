//
//  ContentView.swift
//  May
//
//  Created by Uz4O on 2026/5/29.
//

import SwiftUI

struct ContentView: View {
    private let hardwareProfileStore = HardwareProfileStore()

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("hasCompletedLaunchIntro") private var hasCompletedLaunchIntro = false
    @StateObject private var session: AppSession
    @State private var appPhase: AppPhase
    @State private var selectedTab: AppTab = .home
    @State private var onboardingProfile: OnboardingProfile
    @State private var selectedConfigSection = ConfigHubSection.defaultSelection
    @State private var presentedFullScreen: FullScreenRoute?
    @State private var showsSplash = true
    @State private var isHomeWordmarkVisible: Bool
    @State private var isHomeContentVisible: Bool
    @State private var isMainTabBarVisible: Bool

    init() {
        let session = AppSession()
        _session = StateObject(wrappedValue: session)
        _appPhase = State(initialValue: .login)
        _isHomeWordmarkVisible = State(initialValue: false)
        _isHomeContentVisible = State(initialValue: false)
        _isMainTabBarVisible = State(initialValue: false)
        let savedHardwareProfile = HardwareProfileStore().load()
        _onboardingProfile = State(
            initialValue: OnboardingProfile(
                hardwareProfile: savedHardwareProfile
            )
        )
    }

    var body: some View {
        ZStack {
            AppTheme.background
                .ignoresSafeArea()

            appDestination

            if showsSplash {
                AppSplashView(
                    onReveal: prepareSplashDestination,
                    onFinish: finishSplash
                )
                .zIndex(10)
            }
        }
        .onChange(of: onboardingProfile.hardwareProfile) { _, profile in
            hardwareProfileStore.save(profile)
        }
        .fullScreenCover(item: $presentedFullScreen) { route in
            fullScreenDestination(for: route)
        }
        .onAppear {
            if !session.isRestoringSession && session.isAuthenticated && appPhase == .login {
                enterMainApp()
            }
        }
        .onChange(of: session.isAuthenticated) { _, isAuthenticated in
            if isAuthenticated {
                enterMainApp()
            } else {
                resetAfterLogout()
            }
        }
        .task {
            await session.restoreStoredSession()
            if session.isAuthenticated {
                enterMainApp()
            }
        }
    }

    private func enterMainApp() {
        selectedTab = .home

        if reduceMotion {
            appPhase = .main
        } else {
            withAnimation(.smooth(duration: 0.48)) {
                appPhase = .main
            }
        }
    }

    private func prepareSplashDestination() {
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            isHomeWordmarkVisible = true
            isHomeContentVisible = true
            isMainTabBarVisible = true
        }
    }

    private func finishSplash() {
        showsSplash = false
    }

    @ViewBuilder
    private var appDestination: some View {
        if ProcessInfo.processInfo.arguments.contains("-UITestWizard") {
            AIBuildView(onBack: {}, onComplete: { _, _ in })
        } else if !hasCompletedLaunchIntro, appPhase == .login {
            LaunchIntroView {
                hasCompletedLaunchIntro = true
            }
        } else {
            switch appPhase {
            case .login:
                LoginView(session: session, onLogin: enterMainApp)
                    .transition(
                        .asymmetric(
                            insertion: .opacity,
                            removal: .scale(scale: 1.035).combined(with: .opacity)
                        )
                    )
                    .zIndex(1)
            case .main:
                MainTabView(
                    session: session,
                    onboardingProfile: $onboardingProfile,
                    selectedTab: $selectedTab,
                    selectedConfigSection: $selectedConfigSection,
                    isHomeWordmarkVisible: isHomeWordmarkVisible,
                    isHomeContentVisible: isHomeContentVisible,
                    isTabBarVisible: isMainTabBarVisible,
                    onPresentFullScreen: { presentedFullScreen = $0 },
                    onLogout: resetAfterLogout,
                    onAccountDeleted: resetAfterAccountDeletion
                )
                .transition(
                    .asymmetric(
                        insertion: .scale(scale: 0.975).combined(with: .opacity),
                        removal: .opacity
                    )
                )
            }
        }
    }

    @ViewBuilder
    private func fullScreenDestination(for route: FullScreenRoute) -> some View {
        switch route {
        case .aiBuild(let returnTarget):
            AIBuildFlowView(
                returnTarget: returnTarget,
                accessToken: session.accessToken,
                onClose: { closeFullScreen(returningTo: returnTarget) }
            )
        case .aestheticBuild(let styleID):
            AestheticBuildFlowView(
                styleID: styleID,
                appearanceSelection: (
                    AestheticBuildStyle.all.first { $0.id == styleID }
                        ?? AestheticBuildStyle.all[0]
                ).buildSelection(color: .black, selectedAlternativeIDs: [:]),
                accessToken: session.accessToken,
                onClose: { presentedFullScreen = nil }
            )
        case .aestheticOverview(let styleID):
            AestheticStyleRouteView(
                styleID: styleID,
                accessToken: session.accessToken,
                onClose: { presentedFullScreen = nil }
            )
        case .performanceTest(let returnTab):
            GamePerformanceView(
                savedHardwareProfile: onboardingProfile.hardwareProfile,
                onBack: {
                    selectedTab = returnTab
                    presentedFullScreen = nil
                }
            )
        case .displayMatch(let returnTab):
            DisplayMatchView(
                savedHardwareProfile: onboardingProfile.hardwareProfile,
                onBack: {
                    selectedTab = returnTab
                    presentedFullScreen = nil
                }
            )
        }
    }

    private func closeFullScreen(returningTo target: BuildResultReturnTarget) {
        switch target {
        case .fromAIBuild:
            selectedTab = .home
        case .fromConfigTab, .fromConfigAIBuild:
            selectedTab = .profile
        }
        presentedFullScreen = nil
    }

    private func resetAfterLogout() {
        selectedTab = .home
        selectedConfigSection = ConfigHubSection.defaultSelection
        presentedFullScreen = nil
        appPhase = .login
    }

    private func resetAfterAccountDeletion() {
        hardwareProfileStore.clear()
        DIYBuildStore.clear()
        onboardingProfile = .skipped
        selectedTab = .home
        presentedFullScreen = nil
        appPhase = .login
    }
}

private enum AppPhase: Equatable {
    case login
    case main
}

private enum MainRoute: Hashable {
    case computerProfile
    case upgrade
    case configReview
    case compatibility
    case builds
    case savedBuild(SavedConfigurationDTO)
    case savedUpgrade(SavedUpgradePlanDTO)
    case contactComplaint
}

private enum FullScreenRoute: Identifiable, Equatable {
    case aiBuild(BuildResultReturnTarget)
    case aestheticBuild(styleID: String)
    case aestheticOverview(styleID: String)
    case performanceTest(AppTab)
    case displayMatch(AppTab)

    var id: String {
        switch self {
        case .aiBuild(let returnTarget):
            return "aiBuild-\(returnTarget)"
        case .aestheticBuild(let styleID):
            return "aesthetic-build-\(styleID)"
        case .aestheticOverview(let styleID):
            return "aesthetic-overview-\(styleID)"
        case .performanceTest(let returnTab):
            return "performance-test-\(returnTab)"
        case .displayMatch(let returnTab):
            return "display-match-\(returnTab)"
        }
    }
}

private struct MainTabView: View {
    @ObservedObject var session: AppSession
    @Binding var onboardingProfile: OnboardingProfile
    @Binding var selectedTab: AppTab
    @Binding var selectedConfigSection: ConfigHubSection

    let isHomeWordmarkVisible: Bool
    let isHomeContentVisible: Bool
    let isTabBarVisible: Bool
    let onPresentFullScreen: (FullScreenRoute) -> Void
    let onLogout: () -> Void
    let onAccountDeleted: () -> Void

    @State private var homePath: [MainRoute] = []
    @State private var profilePath: [MainRoute] = []
    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack(path: $homePath) {
                HomeView(
                    onOpenAI: { onPresentFullScreen(.aiBuild(.fromAIBuild)) },
                    onOpenPerformanceTest: { onPresentFullScreen(.performanceTest(.home)) },
                    onOpenConfigReview: { homePath.append(.configReview) },
                    onOpenUpgrade: { homePath.append(.upgrade) },
                    onOpenAestheticStyle: { styleID in
                        onPresentFullScreen(.aestheticOverview(styleID: styleID))
                    },
                    isWordmarkVisible: isHomeWordmarkVisible,
                    isContentVisible: isHomeContentVisible
                )
                .toolbar(.hidden, for: .navigationBar)
                .navigationDestination(for: MainRoute.self) { route in
                    destination(for: route, path: $homePath)
                }
            }
            .tabItem {
                Image(systemName: AppTab.home.icon(isSelected: selectedTab == .home))
                    .accessibilityLabel(AppTab.home.rawValue)
            }
            .tag(AppTab.home)

            NavigationStack {
                AestheticStylesView { styleID in
                    onPresentFullScreen(.aestheticOverview(styleID: styleID))
                }
                .toolbar(.hidden, for: .navigationBar)
            }
            .tabItem {
                Image(systemName: AppTab.styles.icon(isSelected: selectedTab == .styles))
                    .accessibilityLabel(AppTab.styles.rawValue)
            }
            .tag(AppTab.styles)

            NavigationStack {
                ToolsView(
                    onOpenDisplayMatch: { onPresentFullScreen(.displayMatch(.diy)) },
                    accessToken: session.accessToken
                )
                    .toolbar(.hidden, for: .navigationBar)
            }
            .tabItem {
                Image(systemName: AppTab.diy.icon(isSelected: selectedTab == .diy))
                    .accessibilityLabel(AppTab.diy.rawValue)
            }
            .tag(AppTab.diy)

            NavigationStack(path: $profilePath) {
                ProfileView(
                    session: session,
                    hardwareProfile: onboardingProfile.hardwareProfile,
                    onOpenBuilds: { profilePath.append(.builds) },
                    onOpenComputerProfile: { profilePath.append(.computerProfile) },
                    onOpenContactComplaint: { profilePath.append(.contactComplaint) },
                    onLogout: onLogout,
                    onAccountDeleted: onAccountDeleted
                )
                .toolbar(.hidden, for: .navigationBar)
                .navigationDestination(for: MainRoute.self) { route in
                    destination(for: route, path: $profilePath)
                }
            }
            .tabItem {
                Image(systemName: AppTab.profile.icon(isSelected: selectedTab == .profile))
                    .accessibilityLabel(AppTab.profile.rawValue)
            }
            .tag(AppTab.profile)
        }
        .tint(.black)
        .toolbar(isTabBarVisible ? .visible : .hidden, for: .tabBar)
        .preferredColorScheme(.light)
        .background(NativeTabBarTuner(verticalOffset: -14))
    }

    @ViewBuilder
    private func destination(for route: MainRoute, path: Binding<[MainRoute]>) -> some View {
        switch route {
        case .builds:
            MyBuildsView(
                hardwareProfile: onboardingProfile.hardwareProfile,
                accessToken: session.accessToken,
                onOpenPlan: { path.wrappedValue.append(.savedBuild($0)) },
                onOpenSavedUpgrade: { path.wrappedValue.append(.savedUpgrade($0)) },
                onCreate: {
                    selectedConfigSection = .currentComputer
                    onPresentFullScreen(.aiBuild(.fromConfigAIBuild))
                },
                onOpenComputerProfile: { path.wrappedValue.append(.computerProfile) },
                onOpenUpgrade: {
                    selectedConfigSection = .currentComputer
                    path.wrappedValue.append(.upgrade)
                },
                onOpenPerformanceTest: {
                    selectedConfigSection = .currentComputer
                    onPresentFullScreen(.performanceTest(.profile))
                },
                onBack: { pop(path) },
                selectedSection: $selectedConfigSection
            )
            .toolbar(.hidden, for: .navigationBar)
        case .computerProfile:
            ComputerProfileView(
                hardwareProfile: hardwareProfileBinding,
                onBack: { pop(path) }
            )
            .toolbar(.hidden, for: .navigationBar)
        case .upgrade:
            UpgradePlanView(
                savedHardwareProfile: onboardingProfile.hardwareProfile,
                accessToken: session.accessToken,
                onBack: { pop(path) }
            )
            .toolbar(.hidden, for: .navigationBar)
            .toolbar(.hidden, for: .tabBar)
        case .configReview:
            ConfigReviewView(onBack: { pop(path) })
                .toolbar(.hidden, for: .navigationBar)
                .toolbar(.hidden, for: .tabBar)
        case .compatibility:
            CompatibilityView(onBack: { pop(path) })
                .toolbar(.hidden, for: .navigationBar)
        case .savedBuild(let savedBuild):
            BuildResultView(
                plan: savedBuild.plan.model,
                onBack: { pop(path) }
            )
            .toolbar(.hidden, for: .navigationBar)
        case .savedUpgrade(let savedPlan):
            UpgradePlanView(
                savedHardwareProfile: onboardingProfile.hardwareProfile,
                accessToken: session.accessToken,
                initialResponse: savedPlan.plan,
                onBack: { pop(path) }
            )
            .toolbar(.hidden, for: .navigationBar)
            .toolbar(.hidden, for: .tabBar)
        case .contactComplaint:
            ContactComplaintView(onBack: { pop(path) })
                .toolbar(.hidden, for: .navigationBar)
                .toolbar(.hidden, for: .tabBar)
        }
    }

    private var hardwareProfileBinding: Binding<HardwareProfile> {
        Binding(
            get: { onboardingProfile.hardwareProfile },
            set: { onboardingProfile.hardwareProfile = $0 }
        )
    }

    private func pop(_ path: Binding<[MainRoute]>) {
        guard !path.wrappedValue.isEmpty else { return }
        path.wrappedValue.removeLast()
    }
}

private struct AIBuildFlowView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let returnTarget: BuildResultReturnTarget
    let accessToken: String?
    let onClose: () -> Void

    @State private var response: BuildOptionsResponseDTO?
    @State private var selectedOption: BuildOptionDTO?
    @State private var selectedPerformanceGames: [String] = []
    @State private var prefetchedPerformanceStates: [String: BuildPerformanceLoadState] = [:]
    @State private var selectionError: String?

    var body: some View {
        ZStack {
            AIBuildView(
                onBack: onClose,
                onComplete: { response, games in
                    let automaticSelection = shouldSkipOptionSelection(for: response)
                        ? response.options.first
                        : nil
                    withAnimation(resultAnimation) {
                        self.response = response
                        selectedPerformanceGames = games
                        selectedOption = automaticSelection
                    }
                    if let automaticSelection {
                        confirmSelection(automaticSelection)
                    }
                },
                prepareResults: { response, games in
                    prefetchedPerformanceStates = await preloadPerformance(
                        for: response,
                        games: games
                    )
                }
            )
            .allowsHitTesting(response == nil)
            .accessibilityHidden(response != nil)

            if let response, !shouldSkipOptionSelection(for: response) {
                BuildOptionsView(
                    response: response,
                    onBack: {
                        withAnimation(resultAnimation) {
                            self.response = nil
                        }
                    },
                    onSelect: { option in
                        openOption(option)
                    }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(AppTheme.background.ignoresSafeArea())
                .allowsHitTesting(selectedOption == nil)
                .accessibilityHidden(selectedOption != nil)
                .transition(resultTransition)
                .zIndex(1)
            }

            if let selectedOption {
                BuildResultView(
                    plan: selectedOption.makeBuildPlan(
                        performanceGameNames: selectedPerformanceGames
                    ),
                    initialPerformanceState: prefetchedPerformanceStates[selectedOption.id],
                    onBack: {
                        withAnimation(resultAnimation) {
                            self.selectedOption = nil
                            if let response = self.response {
                                if shouldSkipOptionSelection(for: response) {
                                    self.response = nil
                                }
                            }
                        }
                    },
                    onSave: { plan in
                        guard let accessToken else {
                            throw APIError.http(status: 401, message: "登录状态已失效，请重新登录")
                        }
                        _ = try await AppAPIClient().saveConfiguration(
                            SavedConfigurationPlanDTO(kind: .ai, plan: plan),
                            token: accessToken
                        )
                    },
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(AppTheme.background.ignoresSafeArea())
                .transition(resultTransition)
                .zIndex(2)
            }
        }
        .alert(
            "选择确认失败",
            isPresented: Binding(
                get: { selectionError != nil },
                set: { if !$0 { selectionError = nil } }
            )
        ) {
            Button("好的", role: .cancel) {}
        } message: {
            Text(selectionError ?? "配置仍可查看和保存，请稍后重试")
        }
    }

    private func shouldSkipOptionSelection(for response: BuildOptionsResponseDTO) -> Bool {
        AIBuildFlowRules.shouldSkipOptionSelection(optionCount: response.options.count)
    }

    private func openOption(_ option: BuildOptionDTO) {
        withAnimation(resultAnimation) {
            selectedOption = option
        }
        confirmSelection(option)
    }

    private func confirmSelection(_ option: BuildOptionDTO) {
        guard let selectionID = option.selectionId else { return }
        Task {
            do {
                try await AppAPIClient().selectBuildOption(selectionID: selectionID)
            } catch {
                selectionError = "配置仍可查看和保存。\(error.localizedDescription)"
            }
        }
    }

    private func preloadPerformance(
        for response: BuildOptionsResponseDTO,
        games: [String]
    ) async -> [String: BuildPerformanceLoadState] {
        let requests = response.options.map { option in
            (
                option.id,
                option.makeBuildPlan(performanceGameNames: games).performanceContext
            )
        }

        return await withTaskGroup(
            of: (String, BuildPerformanceLoadState).self,
            returning: [String: BuildPerformanceLoadState].self
        ) { group in
            for (optionID, context) in requests {
                group.addTask {
                    (optionID, await loadBuildPerformance(context: context))
                }
            }

            var states: [String: BuildPerformanceLoadState] = [:]
            for await (optionID, state) in group {
                states[optionID] = state
            }
            return states
        }
    }

    private var resultAnimation: Animation {
        reduceMotion ? .easeOut(duration: 0.18) : .easeOut(duration: 0.48)
    }

    private var resultTransition: AnyTransition {
        guard !reduceMotion else { return .opacity }
        return .opacity.combined(with: .scale(scale: 0.985))
    }
}

private struct AestheticStyleRouteView: View {
    let styleID: String
    let accessToken: String?
    let onClose: () -> Void

    @State private var showsBuildFlow = false
    @State private var appearanceSelection: AestheticBuildSelection?

    var body: some View {
        if showsBuildFlow, let appearanceSelection {
            AestheticBuildFlowView(
                styleID: styleID,
                appearanceSelection: appearanceSelection,
                accessToken: accessToken,
                onClose: onClose
            )
        } else {
            AestheticStyleOverviewView(
                styleID: styleID,
                onClose: onClose,
                onStartBuild: { selection in
                    appearanceSelection = selection
                    withAnimation(.easeOut(duration: 0.25)) {
                        showsBuildFlow = true
                    }
                }
            )
        }
    }
}

private struct AestheticBuildFlowView: View {
    let accessToken: String?
    let onClose: () -> Void
    @State private var flow: AestheticBuildFlow
    @State private var response: BuildOptionsResponseDTO?
    @State private var selectedOption: BuildOptionDTO?
    @State private var isGenerating = false
    @State private var generationError: String?

    init(
        styleID: String,
        appearanceSelection: AestheticBuildSelection,
        accessToken: String?,
        onClose: @escaping () -> Void
    ) {
        self.accessToken = accessToken
        self.onClose = onClose
        _flow = State(
            initialValue: AestheticBuildFlow(
                styleID: styleID,
                appearanceSelection: appearanceSelection
            )
        )
    }

    var body: some View {
        ZStack {
            AestheticBuildView(flow: $flow, onClose: onClose) {
                generateOptions()
            }
            .allowsHitTesting(response == nil && !isGenerating)

            if let response, selectedOption == nil {
                BuildOptionsView(
                    response: response,
                    onBack: { self.response = nil },
                    onSelect: openOption
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(AppTheme.background.ignoresSafeArea())
                .transition(.opacity)
                .zIndex(1)
            }

            if let selectedOption {
                BuildResultView(
                    plan: selectedOption.makeBuildPlan(
                        performanceGameNames: flow.selectedGames.map(\.name)
                    ),
                    onBack: {
                        self.selectedOption = nil
                        if response?.options.count == 1 {
                            response = nil
                        }
                    },
                    onSave: { plan in
                        guard let accessToken else {
                            throw APIError.http(status: 401, message: "登录状态已失效，请重新登录")
                        }
                        _ = try await AppAPIClient().saveConfiguration(
                            SavedConfigurationPlanDTO(kind: .ai, plan: plan),
                            token: accessToken
                        )
                    }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(AppTheme.background.ignoresSafeArea())
                .transition(.opacity)
                .zIndex(2)
            }

            if isGenerating {
                ZStack {
                    Color.black.opacity(0.18)
                        .ignoresSafeArea()

                    VStack(spacing: 14) {
                        ProgressView()
                            .tint(.black)
                        Text("正在生成真实配置方案")
                            .font(.appSubheadline)
                            .foregroundStyle(AppTheme.primaryText)
                    }
                    .padding(.horizontal, 28)
                    .frame(height: 112)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 20))
                }
                .zIndex(3)
            }
        }
        .animation(.easeOut(duration: 0.22), value: response != nil)
        .animation(.easeOut(duration: 0.22), value: selectedOption != nil)
        .alert(
            "操作失败",
            isPresented: Binding(
                get: { generationError != nil },
                set: { if !$0 { generationError = nil } }
            )
        ) {
            Button("好的", role: .cancel) {}
        } message: {
            Text(generationError ?? "请稍后重试")
        }
    }

    private func generateOptions() {
        guard !isGenerating else { return }
        isGenerating = true
        generationError = nil
        let games = flow.selectedGames.map(\.name)

        Task {
            do {
                let result = try await AppAPIClient().buildOptions(
                    budget: flow.performanceBudget,
                    useCase: flow.selectedUseCase,
                    gameCategories: games,
                    direction: flow.buildDirection.rawValue,
                    officeApps: [],
                    needsWirelessNetwork: flow.needsWirelessNetwork,
                    memorySize: flow.selectedMemorySize,
                    storageSize: flow.selectedStorageSize,
                    allowsFlexibleBudget: false,
                    noGPUBuild: flow.hasOwnedGPU,
                    ownedGPUModel: flow.hasOwnedGPU
                        ? flow.ownedGPUModel.trimmingCharacters(in: .whitespacesAndNewlines)
                        : nil,
                    aestheticStyle: flow.resolvedAppearanceSelection
                )
                guard !Task.isCancelled else { return }
                response = result
                if result.options.count == 1, let option = result.options.first {
                    openOption(option)
                }
                isGenerating = false
            } catch {
                guard !Task.isCancelled else { return }
                isGenerating = false
                generationError = error.localizedDescription
            }
        }
    }

    private func openOption(_ option: BuildOptionDTO) {
        selectedOption = option
        guard let selectionID = option.selectionId else { return }
        Task {
            do {
                try await AppAPIClient().selectBuildOption(selectionID: selectionID)
            } catch {
                generationError = "配置仍可查看和保存。\(error.localizedDescription)"
            }
        }
    }
}

private struct NativeTabBarTuner: UIViewControllerRepresentable {
    let verticalOffset: CGFloat

    func makeUIViewController(context: Context) -> UIViewController {
        TabBarTuningViewController(verticalOffset: verticalOffset)
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        guard let tuningController = uiViewController as? TabBarTuningViewController else { return }
        tuningController.verticalOffset = verticalOffset
        tuningController.applyWhenReady()
    }
}

private final class TabBarTuningViewController: UIViewController {
    var verticalOffset: CGFloat

    init(verticalOffset: CGFloat) {
        self.verticalOffset = verticalOffset
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        applyWhenReady()
    }

    func applyWhenReady() {
        DispatchQueue.main.async { [weak self] in
            self?.apply()
        }
    }

    private func apply() {
        guard let tabBarController = sequence(first: parent, next: { $0?.parent })
            .first(where: { $0 is UITabBarController }) as? UITabBarController
        else { return }

        tabBarController.tabBar.transform = CGAffineTransform(translationX: 0, y: verticalOffset)
        tabBarController.tabBar.tintColor = UIColor(red: 0.067, green: 0.094, blue: 0.153, alpha: 1)
        tabBarController.tabBar.unselectedItemTintColor = .black
    }
}

#Preview {
    ContentView()
}
