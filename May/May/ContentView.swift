//
//  ContentView.swift
//  May
//
//  Created by Uz4O on 2026/5/29.
//

import SwiftUI

struct ContentView: View {
    private let hardwareProfileStore = HardwareProfileStore()

    @State private var selectedScreen: AppScreen = .login
    @State private var selectedTab: AppTab = .home
    @State private var onboardingProfile: OnboardingProfile
    @State private var buildResultReturnTarget: BuildResultReturnTarget = .fromAIBuild
    @State private var selectedConfigSection = ConfigHubSection.defaultSelection
    @State private var toolReturnScreen: AppScreen = .home
    @State private var isComposerPresented = false

    init() {
        let savedHardwareProfile = HardwareProfileStore().load()
        _onboardingProfile = State(
            initialValue: OnboardingProfile(
                preference: .balanced,
                hardwareProfile: savedHardwareProfile
            )
        )
    }

    var body: some View {
        ZStack {
            AppTheme.background
                .ignoresSafeArea()

            Group {
                switch selectedScreen {
                case .login:
                    LoginView {
                        selectedScreen = .onboarding
                    }
                case .onboarding:
                    OnboardingChoiceView(initialHardwareProfile: onboardingProfile.hardwareProfile) { profile in
                        onboardingProfile = profile
                        selectedScreen = .home
                        selectedTab = .home
                    }
                case .home:
                    HomeView(
                        profile: onboardingProfile,
                        selectedTab: $selectedTab,
                        onSelectTab: handleTabSelection,
                        onComposePost: { isComposerPresented = true },
                        onOpenAI: { openAI() },
                        onOpenUpgrade: { openTool(.upgrade, returningTo: .home) },
                        onOpenGuide: { selectedScreen = .guide },
                        onOpenDIY: { openTool(.diy, returningTo: .home) },
                        onOpenConfigReview: { selectedScreen = .configReview },
                        onOpenCommunity: {
                            selectedTab = .community
                            selectedScreen = .community
                        },
                        onOpenBuilds: {
                            selectedTab = .builds
                            selectedScreen = .builds
                        },
                        onOpenCompatibility: {
                            selectedScreen = .compatibility
                        }
                    )
                case .aiBuild:
                    AIBuildView(
                        onBack: {
                            selectedScreen = buildResultReturnTarget.destination
                            if selectedScreen == .builds {
                                selectedTab = .builds
                            }
                        },
                        onShowResult: {
                            selectedScreen = .buildResult
                        }
                    )
                case .community:
                    CommunityView(
                        selectedTab: $selectedTab,
                        onSelectTab: handleTabSelection,
                        onComposePost: { isComposerPresented = true }
                    )
                case .builds:
                    MyBuildsView(
                        hardwareProfile: onboardingProfile.hardwareProfile,
                        selectedTab: $selectedTab,
                        onSelectTab: handleTabSelection,
                        onComposePost: { isComposerPresented = true },
                        onOpenPlan: {
                            buildResultReturnTarget = .fromConfigTab
                            selectedScreen = .buildResult
                        },
                        onCreate: {
                            selectedConfigSection = .currentComputer
                            openAI(returningTo: .fromConfigAIBuild)
                        },
                        onOpenComputerProfile: { selectedScreen = .computerProfile },
                        onOpenUpgrade: {
                            selectedConfigSection = .currentComputer
                            openTool(.upgrade, returningTo: .builds)
                        },
                        onOpenPerformanceTest: {
                            selectedConfigSection = .currentComputer
                            openTool(.diy, returningTo: .builds)
                        },
                        selectedSection: $selectedConfigSection
                    )
                case .profile:
                    ProfileView(
                        hardwareProfile: onboardingProfile.hardwareProfile,
                        selectedTab: $selectedTab,
                        onSelectTab: handleTabSelection,
                        onComposePost: { isComposerPresented = true },
                        onOpenBuilds: {
                            selectedTab = .builds
                            selectedScreen = .builds
                        },
                        onOpenComputerProfile: {
                            selectedScreen = .computerProfile
                        }
                    )
                case .computerProfile:
                    ComputerProfileView(
                        hardwareProfile: $onboardingProfile.hardwareProfile,
                        onBack: {
                            selectedTab = .profile
                            selectedScreen = .profile
                        }
                    )
                case .upgrade:
                    UpgradePlanView(
                        savedHardwareProfile: onboardingProfile.hardwareProfile,
                        onBack: { selectedScreen = toolReturnScreen }
                    )
                case .configReview:
                    ConfigReviewView(onBack: { selectedScreen = .home })
                case .compatibility:
                    CompatibilityView(onBack: { selectedScreen = .home })
                case .guide:
                    GuideView(onBack: { selectedScreen = .home })
                case .diy:
                    DIYBuildView(
                        savedHardwareProfile: onboardingProfile.hardwareProfile,
                        onBack: { selectedScreen = toolReturnScreen }
                    )
                case .buildResult:
                    BuildResultView(
                        plan: AppMockData.samplePlan,
                        onBack: {
                            selectedScreen = buildResultReturnTarget.destination
                            if selectedScreen == .builds {
                                selectedTab = .builds
                            }
                        }
                    )
                }
            }
            .transition(.opacity)
        }
        .animation(.easeInOut(duration: 0.18), value: selectedScreen)
        .onChange(of: onboardingProfile.hardwareProfile) { _, profile in
            hardwareProfileStore.save(profile)
        }
        .sheet(isPresented: $isComposerPresented) {
            CommunityComposerView()
        }
    }

    private func openAI(returningTo returnTarget: BuildResultReturnTarget = .fromAIBuild) {
        buildResultReturnTarget = returnTarget
        selectedScreen = .aiBuild
    }

    private func openTool(_ screen: AppScreen, returningTo returnScreen: AppScreen) {
        toolReturnScreen = returnScreen
        selectedScreen = screen
    }

    private func handleTabSelection(_ tab: AppTab) {
        selectedTab = tab
        switch tab {
        case .home:
            selectedScreen = .home
        case .community:
            selectedScreen = .community
        case .builds:
            selectedScreen = .builds
        case .profile:
            selectedScreen = .profile
        }
    }
}

#Preview {
    ContentView()
}
