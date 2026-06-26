import SwiftUI
import UIKit

struct HomeView: View {
    let onOpenAI: () -> Void
    let onOpenDIY: () -> Void
    let onOpenConfigReview: () -> Void
    let onOpenUpgrade: () -> Void
    let onOpenGuide: () -> Void
    let onOpenCommunity: () -> Void
    let onOpenBuildRecords: () -> Void

    @State private var selectedFeatureID = HomeDashboardFeature.aiBuild.id
    @State private var heroTransitionDirection = 1

    private var features: [HomeDashboardFeature] {
        [
            HomeDashboardFeature(
                id: "aiBuild",
                title: "AI 一键装机",
                subtitle: "智能推荐适合你的装机方案",
                buttonTitle: "开始装机",
                heroImage: "HomeGPUHeroCard",
                icon: "wrench.and.screwdriver",
                bullets: ["智能推荐配置", "自动检测兼容性", "优化预算方案"],
                action: onOpenAI
            ),
            HomeDashboardFeature(
                id: "performance",
                title: "游戏性能测试",
                subtitle: "检测游戏帧率表现",
                buttonTitle: "开始测试",
                heroImage: "HomeHeroPerformanceGPU",
                icon: "gamecontroller",
                bullets: ["帧率表现评估", "硬件瓶颈分析", "游戏场景建议"],
                action: onOpenDIY
            ),
            HomeDashboardFeature(
                id: "configReview",
                title: "配置排雷",
                subtitle: "判断配置能不能买",
                buttonTitle: "开始排雷",
                heroImage: "HomeHeroConfigReviewBoard",
                icon: "checkmark.shield",
                bullets: ["识别搭配风险", "检查兼容问题", "提示预算浪费"],
                action: onOpenConfigReview
            ),
            HomeDashboardFeature(
                id: "upgrade",
                title: "升级建议",
                subtitle: "按预算给出升级顺序",
                buttonTitle: "查看建议",
                heroImage: "HomeHeroUpgradeParts",
                icon: "arrow.up.right",
                bullets: ["定位升级短板", "排序更换优先级", "匹配预算方案"],
                action: onOpenUpgrade
            ),
            HomeDashboardFeature(
                id: "guide",
                title: "装机指南",
                subtitle: "按步骤了解装机流程",
                buttonTitle: "查看指南",
                heroImage: "HomeHeroGuideBook",
                icon: "book.closed",
                bullets: ["装机前准备", "八大件认识", "常见问题答疑"],
                action: onOpenGuide
            )
        ]
    }

    var body: some View {
        GeometryReader { proxy in
            let contentWidth = AppTheme.responsiveContentWidth(for: proxy.size.width, compactWidth: 344, expandedWidth: 406, sideMargin: 34)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    homeHeader
                        .padding(.top, 0)
                        .padding(.horizontal, 4)

                    HomeHeroCard(
                        feature: selectedFeature,
                        activeIndex: selectedFeatureIndex,
                        totalCount: features.count,
                        transitionDirection: heroTransitionDirection,
                        onSwipeFeature: selectFeature
                    )
                    .padding(.top, 18)

                    HomeFeatureSelector(
                        features: features,
                        selectedID: selectedFeatureID,
                        onSelect: { feature in
                            let currentIndex = selectedFeatureIndex
                            let targetIndex = features.firstIndex { $0.id == feature.id } ?? currentIndex
                            heroTransitionDirection = targetIndex >= currentIndex ? 1 : -1
                            withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                                selectedFeatureID = feature.id
                            }
                        }
                    )
                    .padding(.top, 44)

                    HomeCommunityPreviewSection(
                        posts: Array(CommunityPost.featuredFeed.prefix(3)),
                        onOpenCommunity: onOpenCommunity
                    )
                    .padding(.top, 32)
                }
                .frame(width: contentWidth, alignment: .leading)
                .padding(.bottom, 112)
                .frame(maxWidth: .infinity)
            }
            .background(HomeBackgroundColor.ignoresSafeArea())
        }
    }

    private var selectedFeature: HomeDashboardFeature {
        features.first { $0.id == selectedFeatureID } ?? features[0]
    }

    private var selectedFeatureIndex: Int {
        features.firstIndex { $0.id == selectedFeatureID } ?? 0
    }

    private func selectFeature(offset: Int) {
        guard !features.isEmpty else { return }
        let nextIndex = (selectedFeatureIndex + offset + features.count) % features.count
        heroTransitionDirection = offset >= 0 ? 1 : -1
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
            selectedFeatureID = features[nextIndex].id
        }
    }

    private var homeHeader: some View {
        HStack(alignment: .center) {
            Text("AI 装机助手")
                .font(.system(size: 28, weight: .heavy))
                .foregroundStyle(.black)

            Spacer()

            Image(systemName: "bell")
                .font(.system(size: 22, weight: .regular))
                .foregroundStyle(.black)
                .frame(width: 38, height: 38)
        }
    }
}

private struct HomeDashboardFeature: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let buttonTitle: String
    let heroImage: String
    let icon: String
    let bullets: [String]
    let action: () -> Void

    static let aiBuild = HomeDashboardFeature(
        id: "aiBuild",
        title: "AI 一键装机",
        subtitle: "智能推荐适合你的装机方案",
        buttonTitle: "开始装机",
        heroImage: "HomeGPUHeroCard",
        icon: "wrench.and.screwdriver",
        bullets: [],
        action: {}
    )
}

private struct HomeHeroCard: View {
    let feature: HomeDashboardFeature
    let activeIndex: Int
    let totalCount: Int
    let transitionDirection: Int
    let onSwipeFeature: (Int) -> Void

    var body: some View {
        VStack(spacing: 10) {
            GeometryReader { proxy in
                let cardWidth = proxy.size.width
                let cardHeight: CGFloat = 316

                ZStack(alignment: .topLeading) {
                    heroSlide(cardWidth: cardWidth, cardHeight: cardHeight)
                        .id(feature.id)
                        .transition(heroTransition)
                }
                .frame(height: cardHeight)
                .animation(.spring(response: 0.36, dampingFraction: 0.88), value: feature.id)
                .clipped()
            }
            .frame(height: 316)

            heroPageDots
        }
        .frame(height: 338)
        .contentShape(Rectangle())
        .simultaneousGesture(heroSwipeGesture)
    }

    private var heroTransition: AnyTransition {
        .asymmetric(
            insertion: .move(edge: transitionDirection >= 0 ? .trailing : .leading).combined(with: .opacity),
            removal: .move(edge: transitionDirection >= 0 ? .leading : .trailing).combined(with: .opacity)
        )
    }

    private func heroImageSize(cardWidth: CGFloat) -> (width: CGFloat, height: CGFloat) {
        switch feature.id {
        case "performance":
            return (cardWidth * 0.58, 300)
        case "configReview":
            return (cardWidth * 0.36, 236)
        case "upgrade":
            return (cardWidth * 0.40, 232)
        case "guide":
            return (cardWidth * 0.34, 236)
        default:
            return (cardWidth * 0.42, 242)
        }
    }

    @ViewBuilder
    private func heroSlide(cardWidth: CGFloat, cardHeight: CGFloat) -> some View {
        let imageSize = heroImageSize(cardWidth: cardWidth)
        let horizontalInset: CGFloat = 26
        let contentWidth = cardWidth - horizontalInset
        let textWidth = contentWidth * (feature.id == "performance" ? 0.42 : 0.56)
        let imageWidth = contentWidth - textWidth

        HStack(alignment: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                Text("当前功能")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.black.opacity(0.50))
                    .padding(.bottom, 16)

                Text(feature.title)
                    .font(.system(size: 34, weight: .heavy))
                    .foregroundStyle(.black)
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)
                    .padding(.bottom, 9)

                Text(feature.subtitle)
                    .font(.system(size: 15, weight: .medium))
                    .tracking(1.8)
                    .foregroundStyle(Color.black.opacity(0.70))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .padding(.bottom, 30)

                VStack(alignment: .leading, spacing: 9) {
                    ForEach(feature.bullets, id: \.self) { bullet in
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle")
                                .font(.system(size: 12, weight: .medium))
                            Text(bullet)
                                .font(.system(size: 13, weight: .regular))
                        }
                        .foregroundStyle(Color.black.opacity(0.48))
                    }
                }

                Spacer(minLength: 0)

                Button(action: feature.action) {
                    HStack(spacing: 18) {
                        Text(feature.buttonTitle)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 18, weight: .semibold))
                    }
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 136, height: 44)
                    .background(Color.black, in: Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 31)
            .padding(.bottom, 20)
            .frame(width: textWidth, alignment: .leading)

            ZStack(alignment: .topTrailing) {
                Image(feature.heroImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: min(imageSize.width, imageWidth), height: imageSize.height)
                    .padding(.top, 50)
            }
            .frame(width: imageWidth, height: cardHeight, alignment: .topTrailing)
        }
        .padding(.leading, 20)
        .padding(.trailing, 6)
        .frame(width: cardWidth, height: cardHeight, alignment: .leading)
    }

    private var heroSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 28, coordinateSpace: .local)
            .onEnded { value in
                let horizontal = value.translation.width
                let vertical = value.translation.height

                guard abs(horizontal) > 44, abs(horizontal) > abs(vertical) * 1.25 else {
                    return
                }

                onSwipeFeature(horizontal < 0 ? 1 : -1)
            }
    }

    private var heroPageDots: some View {
        HStack(spacing: 6) {
            ForEach(0..<totalCount, id: \.self) { index in
                Circle()
                    .fill(index == activeIndex ? Color.black : Color.black.opacity(0.12))
                    .frame(width: 6, height: 6)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

private struct HomeFeatureSelector: View {
    let features: [HomeDashboardFeature]
    let selectedID: String
    let onSelect: (HomeDashboardFeature) -> Void

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(Color.white.opacity(0.88))
                .shadow(color: Color.black.opacity(0.045), radius: 24, x: 0, y: 14)

            HStack(spacing: 0) {
                ForEach(features) { feature in
                    Button {
                        onSelect(feature)
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: feature.icon)
                                .font(.system(size: 22, weight: .regular))
                                .foregroundStyle(selectedID == feature.id ? .white : .black)
                                .frame(width: 44, height: 44)
                                .background(selectedID == feature.id ? Color.black : Color.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .shadow(color: Color.black.opacity(selectedID == feature.id ? 0.14 : 0.04), radius: 12, x: 0, y: 8)

                            Text(selectorTitle(for: feature))
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.black)
                                .lineLimit(1)
                                .minimumScaleFactor(0.72)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)

                    if feature.id != features.last?.id {
                        Rectangle()
                            .fill(Color.black.opacity(0.06))
                            .frame(width: 1, height: 58)
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 15)
        }
        .frame(height: 94)
    }

    private func selectorTitle(for feature: HomeDashboardFeature) -> String {
        switch feature.id {
        case "aiBuild":
            return "AI 装机"
        case "performance":
            return "性能测试"
        case "configReview":
            return "配置排雷"
        case "upgrade":
            return "升级建议"
        default:
            return "装机指南"
        }
    }
}

private struct HomeCommunityPreviewSection: View {
    let posts: [CommunityPost]
    let onOpenCommunity: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(alignment: .center) {
                Text("社区精选")
                    .font(.system(size: 20, weight: .heavy))
                    .foregroundStyle(.black)

                Spacer()

                Button(action: onOpenCommunity) {
                    HStack(spacing: 4) {
                        Text("更多")
                        Image(systemName: "chevron.right")
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.black.opacity(0.58))
                }
                .buttonStyle(.plain)
            }

            VStack(spacing: 0) {
                ForEach(Array(posts.enumerated()), id: \.element.id) { index, post in
                    HomeCommunityPreviewRow(post: post, action: onOpenCommunity)

                    if index < posts.count - 1 {
                        Divider()
                            .padding(.leading, 2)
                    }
                }
            }
        }
    }
}

private struct HomeCommunityPreviewRow: View {
    let post: CommunityPost
    let action: () -> Void

    private var metadataText: String {
        let tagText = Array(post.tags.prefix(2)).joined(separator: " · ")
        return "\(tagText) · \(post.stats.comments) 回复"
    }

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(post.summary)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppTheme.primaryText)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(metadataText)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(AppTheme.secondaryText)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.black.opacity(0.24))
            }
            .padding(.vertical, 13)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(post.summary)，\(metadataText)")
    }
}

private let HomeBackgroundColor = Color(red: 0.972, green: 0.978, blue: 0.978)

#Preview {
    HomeView(
        onOpenAI: {},
        onOpenDIY: {},
        onOpenConfigReview: {},
        onOpenUpgrade: {},
        onOpenGuide: {},
        onOpenCommunity: {},
        onOpenBuildRecords: {}
    )
}
