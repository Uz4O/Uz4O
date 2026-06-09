//
//  ContentView.swift
//  May
//
//  Created by Uz4O on 2026/5/29.
//

import SwiftUI

struct ContentView: View {
    @State private var selectedScreen: AppScreen = .login
    @State private var selectedTab: AppTab = .home
    @State private var onboardingProfile: OnboardingProfile = .skipped
    @State private var buildResultReturnTarget: BuildResultReturnTarget = .fromAIBuild

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
                    OnboardingChoiceView { profile in
                        onboardingProfile = profile
                        selectedScreen = .home
                        selectedTab = .home
                    }
                case .home:
                    HomeView(
                        profile: onboardingProfile,
                        selectedTab: $selectedTab,
                        onSelectTab: handleTabSelection,
                        onOpenAI: { openAI() },
                        onOpenUpgrade: { selectedScreen = .upgrade },
                        onOpenGuide: { selectedScreen = .guide },
                        onOpenDIY: { selectedScreen = .diy },
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
                        onBack: { selectedScreen = .home },
                        onShowResult: {
                            buildResultReturnTarget = .fromAIBuild
                            selectedScreen = .buildResult
                        }
                    )
                case .community:
                    CommunityView(selectedTab: $selectedTab, onSelectTab: handleTabSelection)
                case .builds:
                    MyBuildsView(
                        hardwareProfile: onboardingProfile.hardwareProfile,
                        selectedTab: $selectedTab,
                        onSelectTab: handleTabSelection,
                        onOpenPlan: {
                            buildResultReturnTarget = .fromConfigTab
                            selectedScreen = .buildResult
                        },
                        onCreate: { openAI() },
                        onOpenComputerProfile: { selectedScreen = .computerProfile }
                    )
                case .profile:
                    ProfileView(
                        hardwareProfile: onboardingProfile.hardwareProfile,
                        selectedTab: $selectedTab,
                        onSelectTab: handleTabSelection,
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
                        hardwareProfile: onboardingProfile.hardwareProfile,
                        onBack: {
                            selectedTab = .profile
                            selectedScreen = .profile
                        }
                    )
                case .upgrade:
                    UpgradePlanView(onBack: { selectedScreen = .home })
                case .configReview:
                    ConfigReviewView(onBack: { selectedScreen = .home })
                case .compatibility:
                    CompatibilityView(onBack: { selectedScreen = .home })
                case .guide:
                    GuideView(onBack: { selectedScreen = .home })
                case .diy:
                    DIYBuildView(onBack: { selectedScreen = .home })
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
    }

    private func openAI() {
        selectedScreen = .aiBuild
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
