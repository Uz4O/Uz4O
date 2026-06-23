//
//  ContentView.swift
//  May
//
//  Created by Uz4O on 2026/5/29.
//

import SwiftUI

struct ContentView: View {
    private let hardwareProfileStore = HardwareProfileStore()

    @StateObject private var session: AppSession
    @State private var appPhase: AppPhase = .login
    @State private var selectedTab: AppTab = .home
    @State private var onboardingProfile: OnboardingProfile
    @State private var selectedConfigSection = ConfigHubSection.defaultSelection
    @State private var presentedFullScreen: FullScreenRoute?

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

            switch appPhase {
            case .login:
                LoginView {
                    appPhase = .onboarding
                }
            case .onboarding:
                OnboardingChoiceView(initialHardwareProfile: onboardingProfile.hardwareProfile) { profile in
                    onboardingProfile = profile
                    selectedTab = .home
                    appPhase = .main
                }
            case .main:
                MainTabView(
                    session: session,
                    onboardingProfile: $onboardingProfile,
                    selectedTab: $selectedTab,
                    selectedConfigSection: $selectedConfigSection,
                    onPresentFullScreen: { presentedFullScreen = $0 },
                    onAccountDeleted: resetAfterAccountDeletion
                )
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

    @ViewBuilder
    private func fullScreenDestination(for route: FullScreenRoute) -> some View {
        switch route {
        case .aiBuild(let returnTarget):
            AIBuildFlowView(
                returnTarget: returnTarget,
                onClose: { closeFullScreen(returningTo: returnTarget) }
            )
        case .diy(let returnTab):
            DIYBuildView(
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
            selectedTab = .builds
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
    case onboarding
    case main
}

private enum MainRoute: Hashable {
    case computerProfile
    case upgrade
    case configReview
    case compatibility
    case guide
    case buildResult
    case contactComplaint
}

private enum FullScreenRoute: Identifiable, Equatable {
    case aiBuild(BuildResultReturnTarget)
    case diy(AppTab)

    var id: String {
        switch self {
        case .aiBuild(let returnTarget):
            return "aiBuild-\(returnTarget)"
        case .diy(let returnTab):
            return "diy-\(returnTab)"
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
    @State private var communityPath: [MainRoute] = []
    @State private var buildsPath: [MainRoute] = []
    @State private var profilePath: [MainRoute] = []

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack(path: $homePath) {
                HomeView(
                    profile: onboardingProfile,
                    onOpenAI: { onPresentFullScreen(.aiBuild(.fromAIBuild)) },
                    onOpenUpgrade: { homePath.append(.upgrade) },
                    onOpenGuide: { homePath.append(.guide) },
                    onOpenDIY: { onPresentFullScreen(.diy(.home)) },
                    onOpenConfigReview: { homePath.append(.configReview) },
                    onOpenCommunity: { selectedTab = .community },
                    onOpenBuilds: { selectedTab = .builds },
                    onOpenCompatibility: { homePath.append(.compatibility) }
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

            NavigationStack(path: $communityPath) {
                CommunityView(session: session)
                    .toolbar(.hidden, for: .navigationBar)
                    .navigationDestination(for: MainRoute.self) { route in
                        destination(for: route, path: $communityPath)
                    }
            }
            .tabItem {
                Label(AppTab.community.rawValue, systemImage: "bubble.left.and.bubble.right")
            }
            .tag(AppTab.community)

            NavigationStack(path: $buildsPath) {
                MyBuildsView(
                    hardwareProfile: onboardingProfile.hardwareProfile,
                    onOpenPlan: { buildsPath.append(.buildResult) },
                    onCreate: {
                        selectedConfigSection = .currentComputer
                        onPresentFullScreen(.aiBuild(.fromConfigAIBuild))
                    },
                    onOpenComputerProfile: { buildsPath.append(.computerProfile) },
                    onOpenUpgrade: {
                        selectedConfigSection = .currentComputer
                        buildsPath.append(.upgrade)
                    },
                    onOpenPerformanceTest: {
                        selectedConfigSection = .currentComputer
                        onPresentFullScreen(.diy(.builds))
                    },
                    selectedSection: $selectedConfigSection
                )
                .toolbar(.hidden, for: .navigationBar)
                .navigationDestination(for: MainRoute.self) { route in
                    destination(for: route, path: $buildsPath)
                }
            }
            .tabItem {
                Label(AppTab.builds.rawValue, systemImage: "doc.text")
            }
            .tag(AppTab.builds)

            NavigationStack(path: $profilePath) {
                ProfileView(
                    session: session,
                    hardwareProfile: onboardingProfile.hardwareProfile,
                    onOpenBuilds: { selectedTab = .builds },
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
        .background(NativeTabBarTuner(verticalOffset: -14))
    }

    @ViewBuilder
    private func destination(for route: MainRoute, path: Binding<[MainRoute]>) -> some View {
        switch route {
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
        case .guide:
            GuideView(onBack: { pop(path) })
                .toolbar(.hidden, for: .navigationBar)
                .toolbar(.hidden, for: .tabBar)
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
    let returnTarget: BuildResultReturnTarget
    let onClose: () -> Void

    @State private var showsResult = false

    var body: some View {
        Group {
            if showsResult {
                BuildResultView(
                    plan: AppMockData.samplePlan,
                    onBack: onClose
                )
            } else {
                AIBuildView(
                    onBack: onClose,
                    onShowResult: { showsResult = true }
                )
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
