import SwiftUI

struct HomeView: View {
    @Binding var selectedTab: AppTab
    let onSelectTab: (AppTab) -> Void
    let onOpenAI: () -> Void
    let onOpenCompatibility: () -> Void
    let onOpenGuide: () -> Void
    let onOpenDIY: () -> Void
    private let designWidth: CGFloat = 328
    private let cardWidth: CGFloat = 156

    var body: some View {
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
                        HeroBuildCard()
                    }
                    .buttonStyle(.plain)
                    .frame(width: designWidth)

                    VStack(spacing: 14) {
                        HStack(spacing: 14) {
                            HomeFeatureCard(title: "配件兼容性检测", subtitle: "检测硬件兼容性", systemImage: "cpu", action: onOpenCompatibility)
                            HomeFeatureCard(title: "装机指南", subtitle: "从入门到精通", systemImage: "book.closed", action: onOpenGuide)
                        }

                        HStack(spacing: 14) {
                            HomeFeatureCard(title: "自由 DIY 装机", subtitle: "自定义专属配置", systemImage: "screwdriver", action: onOpenDIY)

                            SoftCard(radius: 18) {
                                ZStack {
                                    LinearGradient(
                                        colors: [Color(red: 0.97, green: 0.98, blue: 1.0), Color(red: 0.90, green: 0.93, blue: 0.96)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )

                                    Image("PCTower")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 132, height: 132)
                                        .offset(x: 5, y: 2)
                                }
                                .frame(width: cardWidth, height: cardWidth)
                                .clipShape(RoundedRectangle(cornerRadius: 18))
                            }
                        }
                    }
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
        .frame(maxWidth: .infinity)
        .padding(.bottom, 14)
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
                Text("智能推荐最佳配置方案")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.62))
                HStack(spacing: 8) {
                    Text("开始装机")
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
    let title: String
    let subtitle: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            SoftCard(radius: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(title)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(AppTheme.primaryText)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.secondaryText)

                    Spacer()

                    HStack {
                        Spacer()
                        Image(systemName: systemImage)
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
    HomeView(selectedTab: .constant(.home), onSelectTab: { _ in }, onOpenAI: {}, onOpenCompatibility: {}, onOpenGuide: {}, onOpenDIY: {})
}
