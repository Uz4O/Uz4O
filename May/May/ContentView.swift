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
    @State private var appPhase: AppPhase = .login
    @State private var selectedTab: AppTab = .home
    @State private var onboardingProfile: OnboardingProfile
    @State private var selectedConfigSection = ConfigHubSection.defaultSelection
    @State private var presentedFullScreen: FullScreenRoute?
    @State private var showsSplash = true

    init() {
        _session = StateObject(wrappedValue: AppSession())
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

            if !hasCompletedLaunchIntro, appPhase == .login {
                LaunchIntroView {
                    hasCompletedLaunchIntro = true
                }
            } else {
                switch appPhase {
                case .login:
                    LoginView(onLogin: enterMainApp)
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
                        onPresentFullScreen: { presentedFullScreen = $0 },
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

            if showsSplash {
                AppSplashView {
                    showsSplash = false
                }
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
            if DevelopmentLoginMode.restoresBackendSession, session.isAuthenticated, appPhase == .login {
                appPhase = .main
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

    @ViewBuilder
    private func fullScreenDestination(for route: FullScreenRoute) -> some View {
        switch route {
        case .aiBuild(let returnTarget):
            AIBuildFlowView(
                returnTarget: returnTarget,
                onClose: { closeFullScreen(returningTo: returnTarget) }
            )
        case .aestheticBuild(let styleID):
            AestheticBuildFlowView(styleID: styleID, onClose: { presentedFullScreen = nil })
        case .aestheticOverview(let styleID):
            AestheticStyleRouteView(styleID: styleID, onClose: { presentedFullScreen = nil })
        case .performanceTest(let returnTab):
            GamePerformanceView(
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

    private func resetAfterAccountDeletion() {
        hardwareProfileStore.clear()
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
    case buildResult
    case builds
    case contactComplaint
}

private enum FullScreenRoute: Identifiable, Equatable {
    case aiBuild(BuildResultReturnTarget)
    case aestheticBuild(styleID: String)
    case aestheticOverview(styleID: String)
    case performanceTest(AppTab)

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
        }
    }
}

private struct MainTabView: View {
    @ObservedObject var session: AppSession
    @Binding var onboardingProfile: OnboardingProfile
    @Binding var selectedTab: AppTab
    @Binding var selectedConfigSection: ConfigHubSection

    let onPresentFullScreen: (FullScreenRoute) -> Void
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
                    }
                )
                .toolbar(.hidden, for: .navigationBar)
                .navigationDestination(for: MainRoute.self) { route in
                    destination(for: route, path: $homePath)
                }
            }
            .tabItem {
                Label(AppTab.home.rawValue, systemImage: "house")
            }
            .tag(AppTab.home)

            NavigationStack {
                AestheticStylesView { styleID in
                    onPresentFullScreen(.aestheticOverview(styleID: styleID))
                }
                .toolbar(.hidden, for: .navigationBar)
            }
            .tabItem {
                Label(AppTab.styles.rawValue, systemImage: "paintpalette")
            }
            .tag(AppTab.styles)

            NavigationStack {
                DIYView()
                    .toolbar(.hidden, for: .navigationBar)
            }
            .tabItem {
                Label(AppTab.diy.rawValue, systemImage: AppTab.diy.icon(isSelected: false))
            }
            .tag(AppTab.diy)

            NavigationStack(path: $profilePath) {
                ProfileView(
                    session: session,
                    hardwareProfile: onboardingProfile.hardwareProfile,
                    onOpenBuilds: { profilePath.append(.builds) },
                    onOpenComputerProfile: { profilePath.append(.computerProfile) },
                    onOpenContactComplaint: { profilePath.append(.contactComplaint) },
                    onAccountDeleted: onAccountDeleted
                )
                .toolbar(.hidden, for: .navigationBar)
                .navigationDestination(for: MainRoute.self) { route in
                    destination(for: route, path: $profilePath)
                }
            }
            .tabItem {
                Label(AppTab.profile.rawValue, systemImage: "person")
            }
            .tag(AppTab.profile)
        }
        .tint(AppTheme.primaryText)
        .preferredColorScheme(.light)
        .background(NativeTabBarTuner(verticalOffset: -14))
    }

    @ViewBuilder
    private func destination(for route: MainRoute, path: Binding<[MainRoute]>) -> some View {
        switch route {
        case .builds:
            MyBuildsView(
                hardwareProfile: onboardingProfile.hardwareProfile,
                onOpenPlan: { path.wrappedValue.append(.buildResult) },
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
        case .buildResult:
            BuildResultView(
                plan: AppMockData.samplePlan,
                onBack: { pop(path) }
            )
            .toolbar(.hidden, for: .navigationBar)
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
    let onClose: () -> Void

    @State private var response: BuildOptionsResponseDTO?
    @State private var selectedOption: BuildOptionDTO?

    var body: some View {
        ZStack {
            AIBuildView(
                onBack: onClose,
                onComplete: { response in
                    let automaticSelection = shouldSkipOptionSelection(for: response)
                        ? response.options.first
                        : nil
                    withAnimation(resultAnimation) {
                        self.response = response
                        selectedOption = automaticSelection
                    }
                    if let automaticSelection {
                        confirmSelection(automaticSelection)
                    }
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
                    plan: selectedOption.buildPlan,
                    onBack: {
                        withAnimation(resultAnimation) {
                            self.selectedOption = nil
                            if let response = self.response {
                                if shouldSkipOptionSelection(for: response) {
                                    self.response = nil
                                }
                            }
                        }
                    }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(AppTheme.background.ignoresSafeArea())
                .transition(resultTransition)
                .zIndex(2)
            }
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
            try? await AppAPIClient().selectBuildOption(selectionID: selectionID)
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
    let onClose: () -> Void

    @State private var showsBuildFlow = false

    var body: some View {
        if showsBuildFlow {
            AestheticBuildFlowView(styleID: styleID, onClose: onClose)
        } else {
            AestheticStyleOverviewView(
                styleID: styleID,
                onClose: onClose,
                onStartBuild: {
                    withAnimation(.easeOut(duration: 0.25)) {
                        showsBuildFlow = true
                    }
                }
            )
        }
    }
}

private struct AestheticBuildFlowView: View {
    let onClose: () -> Void
    @State private var flow: AestheticBuildFlow
    @State private var showsResult = false

    init(styleID: String, onClose: @escaping () -> Void) {
        self.onClose = onClose
        _flow = State(initialValue: AestheticBuildFlow(styleID: styleID))
    }

    var body: some View {
        if showsResult {
            BuildResultView(plan: AppMockData.aestheticSamplePlan(for: flow), onBack: onClose)
        } else {
            AestheticBuildView(flow: $flow, onClose: onClose) {
                showsResult = true
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
    }
}

#Preview {
    ContentView()
}
