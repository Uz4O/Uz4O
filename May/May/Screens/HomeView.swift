import SwiftUI

struct HomeView: View {
    let profile: OnboardingProfile
    @Binding var selectedTab: AppTab
    let onSelectTab: (AppTab) -> Void
    let onOpenAI: () -> Void
    let onOpenUpgrade: () -> Void
    let onOpenGuide: () -> Void
    let onOpenDIY: () -> Void
    let onOpenConfigReview: () -> Void
    let onOpenCommunity: () -> Void
    let onOpenBuilds: () -> Void
    let onOpenCompatibility: () -> Void
    private let designWidth: CGFloat = 328
    @State private var visibleCommunityPostIDs: Set<String> = []
    @State private var isComposerPresented = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 12) {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        HStack {
                            Text("AI 装机助手")
                                .font(.system(size: 23, weight: .bold))
                                .foregroundStyle(AppTheme.primaryText)
                            Spacer()
                            Image(systemName: "bell")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(AppTheme.primaryText)
                        }
                        .frame(width: designWidth)
                        .padding(.top, 8)

                        Button(action: onOpenAI) {
                            HeroBuildCard(subtitle: profile.homeHeroSubtitle, buttonTitle: profile.homeHeroButtonTitle)
                        }
                        .buttonStyle(.plain)
                        .frame(width: designWidth)

                        VStack(spacing: 14) {
                            ForEach(Array(featureRows.enumerated()), id: \.offset) { _, row in
                                HStack(spacing: 14) {
                                    ForEach(row, id: \.kind) { feature in
                                        HomeFeatureCard(feature: feature, action: action(for: feature.kind))
                                    }
                                }
                            }
                        }
                        .frame(width: designWidth)

                        HomeCommunitySection(
                            onOpenCommunity: onOpenCommunity,
                            onPostVisibilityChanged: updateCommunityPostVisibility
                        )
                            .frame(width: designWidth)

                        BeginnerStrip()
                            .frame(width: designWidth)
                            .padding(.bottom, 8)
                    }
                    .frame(maxWidth: .infinity)
                }

                Spacer(minLength: 0)

                BottomTabBar(selectedTab: $selectedTab, onSelect: onSelectTab)
                    .frame(width: designWidth)
            }

            if showsCommunityFloatingButton {
                HomeCommunityFloatingButton {
                    isComposerPresented = true
                }
                    .padding(.trailing, AppTheme.screenPadding + 8)
                    .padding(.bottom, 88)
                    .transition(.opacity.combined(with: .scale(scale: 0.92)))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 14)
        .animation(.easeInOut(duration: 0.16), value: showsCommunityFloatingButton)
        .sheet(isPresented: $isComposerPresented) {
            CommunityComposerView()
        }
    }

    private var showsCommunityFloatingButton: Bool {
        visibleCommunityPostIDs.contains { $0 != CommunityPost.featuredFeed.first?.id }
    }

    private func updateCommunityPostVisibility(id: String, isVisible: Bool) {
        if isVisible {
            visibleCommunityPostIDs.insert(id)
        } else {
            visibleCommunityPostIDs.remove(id)
        }
    }

    private var featureRows: [[HomeFeatureDisplay]] {
        stride(from: 0, to: profile.homeFeatureOrder.count, by: 2).map { index in
            Array(profile.homeFeatureOrder[index..<min(index + 2, profile.homeFeatureOrder.count)])
        }
    }

    private func action(for kind: HomeFeatureKind) -> () -> Void {
        switch kind {
        case .aiBuild:
            return onOpenAI
        case .configReview:
            return onOpenConfigReview
        case .guide:
            return onOpenGuide
        case .builds:
            return onOpenBuilds
        case .upgrade:
            return onOpenUpgrade
        case .compatibility:
            return onOpenCompatibility
        case .diy:
            return onOpenDIY
        }
    }
}

private struct HomeCommunitySection: View {
    let onOpenCommunity: () -> Void
    let onPostVisibilityChanged: (String, Bool) -> Void

    private let posts = CommunityPost.featuredFeed

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("硬件讨论社区")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(AppTheme.primaryText)
                    Text("交流心得 · 分享配置 · 解决问题")
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.secondaryText)
                }

                Spacer()

                Button(action: onOpenCommunity) {
                    HStack(spacing: 4) {
                        Text("进入社区")
                        Image(systemName: "chevron.right")
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppTheme.primaryText)
                }
                .buttonStyle(.plain)
            }

            LazyVStack(spacing: 0) {
                ForEach(Array(posts.enumerated()), id: \.element.id) { index, post in
                    Button(action: onOpenCommunity) {
                        CommunityForumRow(post: post, style: .home)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.plain)
                    .onAppear {
                        onPostVisibilityChanged(post.id, true)
                    }
                    .onDisappear {
                        onPostVisibilityChanged(post.id, false)
                    }

                    if index != posts.count - 1 {
                        Divider()
                            .padding(.leading, 42)
                            .padding(.vertical, 2)
                    }
                }
            }
        }
    }
}

private struct HomeCommunityFloatingButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 52, height: 52)
                .background(AppTheme.primaryButton, in: Circle())
                .shadow(color: Color.black.opacity(0.18), radius: 16, x: 0, y: 8)
        }
        .buttonStyle(.plain)
    }
}

private struct BeginnerStrip: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkle")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppTheme.secondaryText)

            Text(AppMockData.beginnerTopics.joined(separator: " · "))
                .font(.system(size: 10))
                .foregroundStyle(AppTheme.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(AppTheme.secondaryText)
        }
        .padding(.horizontal, 12)
        .frame(height: 36)
        .background(AppTheme.softSurface, in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct HeroBuildCard: View {
    let subtitle: String
    let buttonTitle: String

    var body: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 22)
                .fill(LinearGradient(
                    colors: [Color(red: 0.07, green: 0.10, blue: 0.15), Color(red: 0.13, green: 0.16, blue: 0.24)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))

            VStack(alignment: .leading, spacing: 12) {
                Text("AI 一键装机")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.62))
                    .lineLimit(2)
                    .frame(width: 178, alignment: .leading)
                HStack(spacing: 8) {
                    Text(buttonTitle)
                    Image(systemName: "arrow.right")
                }
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(AppTheme.primaryText)
                .padding(.horizontal, 18)
                .frame(height: 42)
                .background(.white, in: Capsule())
                .padding(.top, 10)
            }
            .padding(.leading, 24)

            Image("RobotMascot")
                .resizable()
                .scaledToFit()
                .frame(width: 126, height: 126)
                .shadow(color: Color(red: 0.50, green: 0.56, blue: 0.82).opacity(0.35), radius: 18, y: 12)
                .offset(x: 198, y: 8)
        }
        .frame(height: 172)
        .clipShape(RoundedRectangle(cornerRadius: 22))
    }
}

private struct HomeFeatureCard: View {
    let feature: HomeFeatureDisplay
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            SoftCard(radius: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(feature.title)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(AppTheme.primaryText)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(feature.subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.secondaryText)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer()

                    HStack {
                        Spacer()
                        Image(systemName: feature.icon)
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(AppTheme.primaryText)
                            .frame(width: 58, height: 58)
                            .background(
                                LinearGradient(
                                    colors: [Color.white, AppTheme.softSurface],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                in: RoundedRectangle(cornerRadius: 16)
                            )
                            .shadow(color: Color.black.opacity(0.08), radius: 18, x: 0, y: 10)
                    }
                }
                .padding(18)
                .frame(width: 156, height: 156, alignment: .topLeading)
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    HomeView(
        profile: OnboardingProfile(preference: .balanced),
        selectedTab: .constant(.home),
        onSelectTab: { _ in },
        onOpenAI: {},
        onOpenUpgrade: {},
        onOpenGuide: {},
        onOpenDIY: {},
        onOpenConfigReview: {},
        onOpenCommunity: {},
        onOpenBuilds: {},
        onOpenCompatibility: {}
    )
}
