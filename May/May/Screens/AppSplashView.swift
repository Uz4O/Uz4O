import SwiftUI

struct AppSplashView: View {
    let targetWordmarkFrame: CGRect?
    let connectsToHome: Bool
    let onFinish: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isVisible = false
    @State private var hidesSupportingContent = false
    @State private var wordmarkIsAtHome = false
    @State private var isExiting = false
    @State private var sourceWordmarkFrame: CGRect?

    init(
        targetWordmarkFrame: CGRect? = nil,
        connectsToHome: Bool = false,
        onFinish: @escaping () -> Void
    ) {
        self.targetWordmarkFrame = targetWordmarkFrame
        self.connectsToHome = connectsToHome
        self.onFinish = onFinish
    }

    var body: some View {
        GeometryReader { proxy in
            let compact = proxy.size.height < 730

            ZStack(alignment: .topLeading) {
                VStack(spacing: 0) {
                    Spacer(minLength: compact ? 70 : 110)

                    VStack(spacing: 0) {
                        Text("Uz")
                            .font(.system(size: compact ? 116 : 154, weight: .black, design: .rounded))
                            .tracking(compact ? -12 : -16)
                            .accessibilityLabel("UzBox")
                            .modifier(SplashSupportingExit(isHidden: hidesSupportingContent, style: .hero))

                        Text("UzBox")
                            .font(.system(size: compact ? 32 : 38, weight: .heavy))
                            .hidden()
                            .background {
                                GeometryReader { wordmarkProxy in
                                    Color.clear.preference(
                                        key: SplashWordmarkFramePreferenceKey.self,
                                        value: wordmarkProxy.frame(in: .global)
                                    )
                                }
                            }
                            .padding(.top, compact ? 18 : 28)

                        Text("AI 装机助手")
                            .font(.system(size: compact ? 17 : 19, weight: .medium))
                            .foregroundStyle(Color(white: 0.28))
                            .padding(.top, 8)
                            .modifier(SplashSupportingExit(isHidden: hidesSupportingContent, style: .subtitle))

                        Text("智能推荐最佳配置方案，让装机更简单")
                            .font(.system(size: compact ? 12 : 14))
                            .foregroundStyle(Color(white: 0.62))
                            .multilineTextAlignment(.center)
                            .padding(.top, 10)
                            .modifier(SplashSupportingExit(isHidden: hidesSupportingContent, style: .tagline))
                    }

                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                Text("UzBox")
                    .font(.system(size: 28, weight: .heavy))
                    .scaleEffect(wordmarkIsAtHome ? 1 : (compact ? 32.0 / 28.0 : 38.0 / 28.0))
                    .position(wordmarkPosition(in: proxy))
            }
            .onPreferenceChange(SplashWordmarkFramePreferenceKey.self) { frame in
                guard frame != .zero else { return }
                sourceWordmarkFrame = frame
            }
            .opacity(isVisible ? 1 : 0)
            .scaleEffect(isVisible ? 1 : 0.88)
            .offset(y: isVisible ? 0 : 12)

            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color.white.ignoresSafeArea())
        .preferredColorScheme(.light)
        .opacity(isExiting ? 0 : 1)
        .scaleEffect(isExiting ? 1.035 : 1)
        .task {
            if reduceMotion {
                isVisible = true
            } else {
                withAnimation(.smooth(duration: 0.55)) {
                    isVisible = true
                }
            }

            if reduceMotion {
                try? await Task.sleep(for: .seconds(1.1))
                onFinish()
                return
            }

            if connectsToHome {
                try? await Task.sleep(for: .seconds(1.05))

                hidesSupportingContent = true
                try? await Task.sleep(for: .seconds(0.78))

                withAnimation(.timingCurve(0.20, 0.72, 0.16, 1, duration: 1.12)) {
                    wordmarkIsAtHome = true
                }
                try? await Task.sleep(for: .seconds(1.16))

                onFinish()
            } else {
                try? await Task.sleep(for: .seconds(1.25))
                withAnimation(.easeInOut(duration: 0.3)) {
                    isExiting = true
                }
                try? await Task.sleep(for: .seconds(0.3))
                onFinish()
            }
        }
    }

    private func wordmarkPosition(in proxy: GeometryProxy) -> CGPoint {
        let globalFrame = proxy.frame(in: .global)
        let frame = wordmarkIsAtHome ? targetWordmarkFrame : sourceWordmarkFrame

        if let frame, frame != .zero {
            return CGPoint(
                x: frame.midX - globalFrame.minX,
                y: frame.midY - globalFrame.minY
            )
        }

        if !wordmarkIsAtHome {
            return CGPoint(x: proxy.size.width / 2, y: proxy.size.height * 0.56)
        }

        return CGPoint(
            x: proxy.size.width > 400 ? 62 : 54,
            y: proxy.safeAreaInsets.top + 20
        )
    }
}

private struct SplashWordmarkFramePreferenceKey: PreferenceKey {
    static var defaultValue: CGRect = .zero

    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        let nextFrame = nextValue()
        if nextFrame != .zero {
            value = nextFrame
        }
    }
}

private enum SplashSupportingExitStyle {
    case hero
    case subtitle
    case tagline

    var delay: Double {
        switch self {
        case .hero: 0
        case .subtitle: 0.06
        case .tagline: 0.12
        }
    }
}

private struct SplashSupportingExit: ViewModifier {
    let isHidden: Bool
    let style: SplashSupportingExitStyle

    func body(content: Content) -> some View {
        content
            .opacity(isHidden ? 0 : 1)
            .blur(radius: isHidden ? blurRadius : 0)
            .scaleEffect(isHidden ? hiddenScale : 1)
            .offset(y: isHidden ? verticalOffset : 0)
            .rotationEffect(isHidden ? hiddenRotation : .zero)
            .rotation3DEffect(
                isHidden ? hiddenTilt : .zero,
                axis: (x: 1, y: 0, z: 0),
                perspective: 0.55
            )
            .animation(
                .timingCurve(0.18, 0.78, 0.24, 1, duration: 0.62).delay(style.delay),
                value: isHidden
            )
    }

    private var blurRadius: CGFloat {
        switch style {
        case .hero: 18
        case .subtitle: 9
        case .tagline: 14
        }
    }

    private var hiddenScale: CGFloat {
        switch style {
        case .hero: 1.72
        case .subtitle: 0.80
        case .tagline: 0.70
        }
    }

    private var verticalOffset: CGFloat {
        switch style {
        case .hero: -92
        case .subtitle: 54
        case .tagline: 96
        }
    }

    private var hiddenRotation: Angle {
        switch style {
        case .hero: .degrees(-5)
        case .subtitle: .degrees(2)
        case .tagline: .degrees(-2)
        }
    }

    private var hiddenTilt: Angle {
        switch style {
        case .hero: .degrees(16)
        case .subtitle: .degrees(-8)
        case .tagline: .degrees(-12)
        }
    }
}

#Preview {
    AppSplashView(onFinish: {})
}
