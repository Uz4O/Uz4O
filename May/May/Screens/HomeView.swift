import SwiftUI
import UIKit

struct HomeView: View {
    let onOpenAI: () -> Void
    let onOpenPerformanceTest: () -> Void
    let onOpenConfigReview: () -> Void
    let onOpenUpgrade: () -> Void
    let onOpenAestheticStyle: (String) -> Void

    @State private var selectedFeatureID = HomeDashboardFeature.aiBuild.id
    private var features: [HomeDashboardFeature] {
        [
            HomeDashboardFeature(
                id: "aiBuild",
                title: "AI 一键装机",
                subtitle: "智能推荐适合你的装机方案",
                buttonTitle: "开始装机",
                heroImage: "HomeStyleBlackKnight",
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
                action: onOpenPerformanceTest
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
                        onSwipeFeature: selectFeature
                    )
                    .padding(.top, 18)

                    HomeFeatureSelector(
                        features: features,
                        selectedID: selectedFeatureID,
                        onSelect: { feature in
                            withAnimation(.easeOut(duration: 0.26)) {
                                selectedFeatureID = feature.id
                            }
                        }
                    )
                    .padding(.top, 44)

                    HomeBuildStyleSection(
                        styles: AestheticBuildStyle.featured,
                        onOpen: { style in
                            onOpenAestheticStyle(style.id)
                        }
                    )
                    .padding(.top, 34)
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
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation(.easeOut(duration: 0.26)) {
            selectedFeatureID = features[nextIndex].id
        }
    }

    private var homeHeader: some View {
        HStack(alignment: .center) {
            Text("UzBox")
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
                .animation(.easeOut(duration: 0.26), value: feature.id)
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
        .homeDepthFocus
    }

    private func heroImageSize(cardWidth: CGFloat) -> (width: CGFloat, height: CGFloat) {
        switch feature.id {
        case "aiBuild":
            return (cardWidth * 0.50, 266)
        case "performance":
            return (cardWidth * 0.58, 300)
        case "configReview":
            return (cardWidth * 0.36, 236)
        case "upgrade":
            return (cardWidth * 0.40, 232)
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

private struct HomeDepthFocusTransitionModifier: ViewModifier {
    let opacity: Double
    let scale: CGFloat
    let blurRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .opacity(opacity)
            .scaleEffect(scale)
            .blur(radius: blurRadius)
    }
}

private extension AnyTransition {
    static var homeDepthFocus: AnyTransition {
        .modifier(
            active: HomeDepthFocusTransitionModifier(opacity: 0, scale: 0.985, blurRadius: 5),
            identity: HomeDepthFocusTransitionModifier(opacity: 1, scale: 1, blurRadius: 0)
        )
    }
}

private struct HomeFeatureSelector: View {
    let features: [HomeDashboardFeature]
    let selectedID: String
    let onSelect: (HomeDashboardFeature) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(features) { feature in
                Button {
                    onSelect(feature)
                } label: {
                    VStack(spacing: 8) {
                        Image(systemName: feature.icon)
                            .font(.system(size: 22, weight: .regular))
                            .foregroundStyle(selectedID == feature.id ? .white : .black)
                            .frame(width: 50, height: 50)
                            .background(
                                selectedID == feature.id ? Color.black : Color.white.opacity(0.62),
                                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                            )
                            .shadow(color: Color.black.opacity(selectedID == feature.id ? 0.14 : 0.035), radius: 12, x: 0, y: 8)

                        Text(selectorTitle(for: feature))
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.black)
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .frame(height: 78)
    }

    private func selectorTitle(for feature: HomeDashboardFeature) -> String {
        switch feature.id {
        case "aiBuild":
            return "AI 装机"
        case "performance":
            return "性能测试"
        case "configReview":
            return "配置排雷"
        default:
            return feature.title
        }
    }
}

private struct HomeBuildStyleSection: View {
    let styles: [AestheticBuildStyle]
    let onOpen: (AestheticBuildStyle) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("精选装机风格")
                        .font(.system(size: 18, weight: .heavy))
                        .foregroundStyle(.black)

                    Text("找到你喜欢的主机外观与氛围")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(.black.opacity(0.52))
                }
            }

            VStack(spacing: 0) {
                ForEach(Array(styles.enumerated()), id: \.element.id) { index, style in
                    AestheticStyleRow(style: style) {
                        onOpen(style)
                    }

                    if index < styles.count - 1 {
                        Rectangle()
                            .fill(Color.black.opacity(0.07))
                            .frame(height: 1)
                    }
                }
            }
        }
    }
}

private let HomeBackgroundColor = Color(red: 0.972, green: 0.978, blue: 0.978)

#Preview {
    HomeView(
        onOpenAI: {},
        onOpenPerformanceTest: {},
        onOpenConfigReview: {},
        onOpenUpgrade: {},
        onOpenAestheticStyle: { _ in }
    )
}
