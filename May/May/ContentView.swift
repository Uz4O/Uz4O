//
//  ContentView.swift
//  May
//
//  Created by Uz4O on 2026/5/29.
//

import SwiftUI

enum AppScreen: Hashable {
    case login
    case home
    case aiBuild
    case tools
    case builds
    case profile
    case upgrade
    case configReview
    case compatibility
    case guide
    case diy
    case buildResult
}

struct ContentView: View {
    @State private var selectedScreen: AppScreen = .login
    @State private var selectedTab: AppTab = .home

    var body: some View {
        ZStack {
            AppTheme.background
                .ignoresSafeArea()

            Group {
                switch selectedScreen {
                case .login:
                    LoginView {
                        selectedScreen = .home
                        selectedTab = .home
                    }
                case .home:
                    HomeView(
                        selectedTab: $selectedTab,
                        onSelectTab: handleTabSelection,
                        onOpenAI: { openAI() },
                        onOpenUpgrade: { selectedScreen = .upgrade },
                        onOpenGuide: { selectedScreen = .guide },
                        onOpenDIY: { selectedScreen = .diy },
                        onOpenConfigReview: { selectedScreen = .configReview }
                    )
                case .aiBuild:
                    AIBuildView(onBack: { selectedScreen = .home }, onShowResult: { selectedScreen = .buildResult })
                case .tools:
                    ToolsView(
                        selectedTab: $selectedTab,
                        onSelectTab: handleTabSelection,
                        onOpenCompatibility: {
                            selectedTab = .tools
                            selectedScreen = .compatibility
                        }
                    )
                case .builds:
                    MyBuildsView(selectedTab: $selectedTab, onSelectTab: handleTabSelection, onOpenPlan: { selectedScreen = .buildResult }, onCreate: { openAI() })
                case .profile:
                    ProfileView(selectedTab: $selectedTab, onSelectTab: handleTabSelection, onOpenBuilds: {
                        selectedTab = .builds
                        selectedScreen = .builds
                    })
                case .upgrade:
                    UpgradePlanView(onBack: { selectedScreen = .home })
                case .configReview:
                    ConfigReviewView(onBack: { selectedScreen = .home })
                case .compatibility:
                    CompatibilityView(onBack: { selectedScreen = .tools })
                case .guide:
                    GuideView(onBack: { selectedScreen = .home })
                case .diy:
                    DIYBuildView(onBack: { selectedScreen = .home })
                case .buildResult:
                    BuildResultView(plan: AppMockData.samplePlan, onBack: { selectedScreen = .home })
                }
            }
            .transition(.opacity)
        }
        .animation(.easeInOut(duration: 0.18), value: selectedScreen)
    }

    private func openAI() {
        selectedTab = .ai
        selectedScreen = .aiBuild
    }

    private func handleTabSelection(_ tab: AppTab) {
        selectedTab = tab
        switch tab {
        case .home:
            selectedScreen = .home
        case .tools:
            selectedScreen = .tools
        case .ai:
            selectedScreen = .aiBuild
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
