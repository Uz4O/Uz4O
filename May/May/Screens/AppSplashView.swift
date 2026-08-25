import SwiftUI

struct AppSplashView: View {
    let onReveal: () -> Void
    let onFinish: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isMarkVisible = false
    @State private var phase: SplashPhase = .holding
    @State private var uPathEnd: CGFloat = 1
    @State private var zPathEnd: CGFloat = 1
    @State private var strokeWidth: CGFloat = 30
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
                    .ignoresSafeArea()

                splashMark(compact: compact)
                    .opacity(isMarkVisible ? 1 : 0)
                    .offset(y: isMarkVisible ? 0 : 10)
                    .blur(radius: isMarkVisible ? 0 : 2)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .ignoresSafeArea()
        .preferredColorScheme(.light)
        .task {
            if reduceMotion {
                onReveal()
                onFinish()
                return
            }

            withAnimation(.easeOut(duration: 0.24)) {
                isMarkVisible = true
            }

            // 完整展示后做很小的收缩，再让 z 向左下卡扣。
            try? await Task.sleep(for: .seconds(0.98))
            withAnimation(.easeInOut(duration: 0.30)) {
                phase = .compressed
            }

            try? await Task.sleep(for: .seconds(0.30))
            withAnimation(.spring(response: 0.52, dampingFraction: 0.84, blendDuration: 0.06)) {
                phase = .latched
            }

            // 卡扣后停留，再把粗笔画收成品牌化细线。
            try? await Task.sleep(for: .seconds(0.50))
            withAnimation(.timingCurve(0.26, 0.70, 0.20, 1, duration: 0.42)) {
                phase = .refining
                strokeWidth = 3.2
            }

            try? await Task.sleep(for: .seconds(0.42))
            onReveal()
            phase = .retracting
            withAnimation(.timingCurve(0.38, 0.02, 0.18, 1, duration: 0.54)) {
                zPathEnd = 0.001
                coverOpacity = 0.22
            }

            try? await Task.sleep(for: .seconds(0.05))
            withAnimation(.timingCurve(0.38, 0.02, 0.18, 1, duration: 0.58)) {
                uPathEnd = 0.001
                coverOpacity = 0
            }

            try? await Task.sleep(for: .seconds(0.58))
            withAnimation(.easeOut(duration: 0.12)) {
                isMarkVisible = false
            }
            try? await Task.sleep(for: .seconds(0.12))
            onFinish()
        }
    }

    private func splashMark(compact: Bool) -> some View {
        let scale = compact ? 0.82 : 1.0
        let seamWidth: CGFloat = 2

        return ZStack {
            SplashUShape()
                .trim(from: 0, to: uPathEnd)
                .stroke(
                    Color.black,
                    style: StrokeStyle(
                        lineWidth: strokeWidth,
                        lineCap: .round,
                        lineJoin: .round
                    )
                )
                .frame(width: 92, height: 122)
                .offset(x: -34)

            // 白色底描边始终留出精确接缝，避免 U 与 z 真正接触。
            SplashZShape()
                .trim(from: 0, to: zPathEnd)
                .stroke(
                    Color.white,
                    style: StrokeStyle(
                        lineWidth: strokeWidth + seamWidth * 2,
                        lineCap: .round,
                        lineJoin: .round
                    )
                )
                .frame(width: 70, height: 70)
                .offset(x: zOffset.width, y: zOffset.height)

            SplashZShape()
                .trim(from: 0, to: zPathEnd)
                .stroke(
                    Color.black,
                    style: StrokeStyle(
                        lineWidth: strokeWidth,
                        lineCap: .round,
                        lineJoin: .round
                    )
                )
                .frame(width: 70, height: 70)
                .offset(x: zOffset.width, y: zOffset.height)
        }
        .frame(width: 190, height: 170)
        .scaleEffect(x: markHorizontalScale * scale, y: markVerticalScale * scale)
        .rotationEffect(.degrees(zRotation))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Uz")
    }

    private var zOffset: CGSize {
        switch phase {
        case .holding:
            CGSize(width: 45, height: 18)
        case .compressed:
            CGSize(width: 39, height: 20)
        case .latched, .refining, .retracting:
            CGSize(width: 31, height: 30)
        }
    }

    private var markHorizontalScale: CGFloat {
        phase == .compressed ? 0.92 : 1
    }

    private var markVerticalScale: CGFloat {
        phase == .compressed ? 1.035 : 1
    }

    private var zRotation: Double {
        phase == .compressed ? -0.8 : 0
    }
}

private enum SplashPhase: Equatable {
    case holding
    case compressed
    case latched
    case refining
    case retracting
}

private struct SplashUShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.width * 0.16, y: rect.height * 0.06))
        path.addLine(to: CGPoint(x: rect.width * 0.16, y: rect.height * 0.62))
        path.addCurve(
            to: CGPoint(x: rect.width * 0.84, y: rect.height * 0.62),
            control1: CGPoint(x: rect.width * 0.16, y: rect.height * 1.03),
            control2: CGPoint(x: rect.width * 0.84, y: rect.height * 1.03)
        )
        path.addLine(to: CGPoint(x: rect.width * 0.84, y: rect.height * 0.06))
        return path
    }
}

private struct SplashZShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.width * 0.08, y: rect.height * 0.12))
        path.addLine(to: CGPoint(x: rect.width * 0.92, y: rect.height * 0.12))
        path.addLine(to: CGPoint(x: rect.width * 0.08, y: rect.height * 0.88))
        path.addLine(to: CGPoint(x: rect.width * 0.92, y: rect.height * 0.88))
        return path
    }
}

#Preview {
    AppSplashView(onFinish: {})
}
