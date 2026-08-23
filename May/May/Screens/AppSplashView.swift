import SwiftUI

struct AppSplashView: View {
    let onReveal: () -> Void
    let onFinish: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isVisible = false
    @State private var phase: SplashPhase = .holding
    @State private var coverOpacity = 1.0

    init(
        onReveal: @escaping () -> Void = {},
        onFinish: @escaping () -> Void
    ) {
        self.onReveal = onReveal
        self.onFinish = onFinish
    }

    var body: some View {
        GeometryReader { proxy in
            let compact = proxy.size.height < 730

            ZStack {
                Color.white
                    .opacity(coverOpacity)

                splashMark(compact: compact)
                    .scaleEffect(x: markHorizontalScale, y: markVerticalScale)
                    .scaleEffect(isVisible ? 1 : 0.90)
                    .offset(y: markVerticalOffset + (isVisible ? 0 : 12))
                    .opacity(isVisible ? markOpacity : 0)
                    .blur(radius: markBlur)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .ignoresSafeArea()
        .preferredColorScheme(.light)
        .task {
            if reduceMotion {
                isVisible = true
                phase = .settled
                onReveal()
                onFinish()
                return
            }

            withAnimation(.easeOut(duration: 0.30)) {
                isVisible = true
            }

            // 保留完整展示和用户认可的轻微收缩蓄力。
            try? await Task.sleep(for: .seconds(1.10))
            withAnimation(.easeInOut(duration: 0.32)) {
                phase = .compressed
            }

            try? await Task.sleep(for: .seconds(0.32))
            withAnimation(.spring(response: 0.52, dampingFraction: 0.82, blendDuration: 0.08)) {
                phase = .settled
            }

            // 回弹稳定后，把视觉焦点从字母交给主页。
            try? await Task.sleep(for: .seconds(0.62))
            onReveal()
            withAnimation(.timingCurve(0.22, 0.72, 0.18, 1, duration: 0.68)) {
                phase = .exiting
                coverOpacity = 0
            }

            try? await Task.sleep(for: .seconds(0.68))
            onFinish()
        }
    }

    private func splashMark(compact: Bool) -> some View {
        HStack(spacing: compact ? -10 : -14) {
            Text("U")
                .modifier(SplashLetterCompression(direction: -1, phase: phase))
            Text("z")
                .modifier(SplashLetterCompression(direction: 1, phase: phase))
        }
        .font(.system(size: compact ? 116 : 154, weight: .black, design: .rounded))
        .tracking(compact ? -12 : -16)
        .foregroundStyle(.black)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Uz")
    }

    private var markHorizontalScale: CGFloat {
        switch phase {
        case .holding:
            1
        case .compressed:
            0.91
        case .settled:
            1
        case .exiting:
            0.97
        }
    }

    private var markVerticalScale: CGFloat {
        phase == .compressed ? 1.04 : 1
    }

    private var markVerticalOffset: CGFloat {
        phase == .exiting ? -3 : 0
    }

    private var markOpacity: Double {
        phase == .exiting ? 0 : 1
    }

    private var markBlur: CGFloat {
        phase == .exiting ? 5 : 0
    }
}

private enum SplashPhase: Equatable {
    case holding
    case compressed
    case settled
    case exiting
}

private struct SplashLetterCompression: ViewModifier {
    let direction: CGFloat
    let phase: SplashPhase

    func body(content: Content) -> some View {
        content
            .offset(x: phase == .compressed ? direction * -6 : 0)
            .rotationEffect(.degrees(phase == .compressed ? Double(direction * 1.5) : 0))
    }
}

#Preview {
    AppSplashView(onFinish: {})
}
