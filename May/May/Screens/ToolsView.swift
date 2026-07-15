import SwiftUI

struct ToolsView: View {
    let profile: OnboardingProfile
    let onOpenUpgrade: () -> Void
    let onOpenDIY: () -> Void
    let onOpenConfigReview: () -> Void
    let onOpenCompatibility: () -> Void

    var body: some View {
        GeometryReader { proxy in
            let contentWidth = AppTheme.responsiveContentWidth(for: proxy.size.width)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    ScreenHeader(title: "工具", trailingIcon: nil, onBack: nil)
                        .padding(.top, 8)

                    ToolsIntroCard()

                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(), spacing: 14),
                            GridItem(.flexible(), spacing: 14)
                        ],
                        alignment: .center,
                        spacing: 14
                    ) {
                        ForEach(profile.toolFeatureOrder, id: \.kind) { feature in
                            ToolFeatureCard(feature: feature, action: action(for: feature.kind))
                        }
                    }
                }
                .frame(width: contentWidth, alignment: .leading)
                .padding(.bottom, 104)
                .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity)
            .background(AppTheme.background.ignoresSafeArea())
        }
    }

    private func action(for kind: HomeFeatureKind) -> () -> Void {
        switch kind {
        case .aiBuild:
            return {}
        case .configReview:
            return onOpenConfigReview
        case .builds:
            return {}
        case .upgrade:
            return onOpenUpgrade
        case .compatibility:
            return onOpenCompatibility
        case .diy:
            return onOpenDIY
        }
    }
}

private struct ToolsIntroCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("常用工具")
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(AppTheme.primaryText)

            Text("性能测试、配置排雷、升级建议和兼容性检查都放在这里。")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AppTheme.secondaryText)
                .lineSpacing(3)
        }
        .padding(.top, 10)
    }
}

private struct ToolFeatureCard: View {
    let feature: HomeFeatureDisplay
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            SoftCard(radius: 20) {
                VStack(alignment: .leading, spacing: 10) {
                    Image(systemName: feature.icon)
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(.black)
                        .frame(width: 48, height: 48)
                        .background(
                            LinearGradient(
                                colors: [Color.white, AppTheme.softSurface],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            in: RoundedRectangle(cornerRadius: 15)
                        )

                    Spacer(minLength: 0)

                    Text(feature.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppTheme.primaryText)
                        .lineLimit(2)

                    Text(feature.subtitle)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(AppTheme.secondaryText)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(16)
                .frame(height: 150, alignment: .topLeading)
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(feature.title)，\(feature.subtitle)")
    }
}

#Preview {
    ToolsView(
        profile: OnboardingProfile(),
        onOpenUpgrade: {},
        onOpenDIY: {},
        onOpenConfigReview: {},
        onOpenCompatibility: {}
    )
}
