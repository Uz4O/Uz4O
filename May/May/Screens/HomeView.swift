import SwiftUI

struct HomeView: View {
    let profile: OnboardingProfile
    @Binding var selectedTab: AppTab
    let onSelectTab: (AppTab) -> Void
    let onComposePost: () -> Void
    let onOpenAI: () -> Void
    let onOpenUpgrade: () -> Void
    let onOpenGuide: () -> Void
    let onOpenDIY: () -> Void
    let onOpenConfigReview: () -> Void
    let onOpenCommunity: () -> Void
    let onOpenBuilds: () -> Void
    let onOpenCompatibility: () -> Void

    var body: some View {
        GeometryReader { proxy in
            let contentWidth = AppTheme.responsiveContentWidth(for: proxy.size.width)

            ZStack(alignment: .bottom) {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        HStack {
                            Text("AI 装机助手")
                                .font(.system(size: 25, weight: .heavy))
                                .foregroundStyle(AppTheme.primaryText)
                            Spacer()
                            Image(systemName: "bell")
                                .font(.system(size: 21, weight: .medium))
                                .foregroundStyle(AppTheme.primaryText)
                        }
                        .frame(width: contentWidth)
                        .padding(.top, 8)

                        Button(action: onOpenAI) {
                            HeroBuildCard(subtitle: profile.homeHeroSubtitle, buttonTitle: profile.homeHeroButtonTitle)
                        }
                        .buttonStyle(.plain)
                        .frame(width: contentWidth)

                        VStack(spacing: 16) {
                            ForEach(Array(featureRows.enumerated()), id: \.offset) { _, row in
                                HStack(spacing: 14) {
                                    ForEach(row, id: \.kind) { feature in
                                        HomeFeatureCard(
                                            feature: feature,
                                            width: featureCardWidth(for: contentWidth),
                                            action: action(for: feature.kind)
                                        )
                                    }
                                }
                            }
                        }
                        .frame(width: contentWidth)

                        HomeCommunitySection(onOpenCommunity: onOpenCommunity)
                            .frame(width: contentWidth)

                        Color.clear.frame(height: 2)
                    }
                    .padding(.bottom, 104)
                    .frame(maxWidth: .infinity)
                }

                BottomTabBar(selectedTab: $selectedTab, onSelect: onSelectTab, onComposePost: onComposePost)
                    .frame(width: contentWidth)
            }
            .frame(maxWidth: .infinity)
            .background(AppTheme.background.ignoresSafeArea())
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

    private func featureCardWidth(for contentWidth: CGFloat) -> CGFloat {
        (contentWidth - 14) / 2
    }
}

private struct HomeCommunitySection: View {
    let onOpenCommunity: () -> Void

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

            if let post = posts.first {
                Button(action: onOpenCommunity) {
                    CommunityForumRow(post: post, style: .home)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
            }
        }
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
            Image("HomeHeroCharacter")
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: 184)

            VStack(alignment: .leading, spacing: 12) {
                Text("AI 一键装机")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.82))
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

        }
        .frame(height: 184)
        .clipShape(RoundedRectangle(cornerRadius: 22))
    }
}

private struct HomeFeatureCard: View {
    let feature: HomeFeatureDisplay
    let width: CGFloat
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
                .frame(width: width, height: 164, alignment: .topLeading)
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
        onComposePost: {},
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
