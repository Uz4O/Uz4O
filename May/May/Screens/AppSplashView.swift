import SwiftUI

struct AppSplashView: View {
    let onFinish: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isVisible = false
    @State private var isExiting = false

    var body: some View {
        GeometryReader { proxy in
            let compact = proxy.size.height < 730

            VStack(spacing: 0) {
                Spacer(minLength: compact ? 70 : 110)

                VStack(spacing: 0) {
                    Text("Uz")
                        .font(.system(size: compact ? 116 : 154, weight: .black, design: .rounded))
                        .tracking(compact ? -12 : -16)
                        .accessibilityLabel("UzBox")

                    Text("UzBox")
                        .font(.system(size: compact ? 32 : 38, weight: .heavy))
                        .padding(.top, compact ? 18 : 28)

                    Text("AI 装机助手")
                        .font(.system(size: compact ? 17 : 19, weight: .medium))
                        .foregroundStyle(Color(white: 0.28))
                        .padding(.top, 8)

                    Text("智能推荐最佳配置方案，让装机更简单")
                        .font(.system(size: compact ? 12 : 14))
                        .foregroundStyle(Color(white: 0.62))
                        .multilineTextAlignment(.center)
                        .padding(.top, 10)
                }
                .opacity(isVisible ? 1 : 0)
                .scaleEffect(isVisible ? 1 : 0.88)
                .offset(y: isVisible ? 0 : 12)

                Spacer()
            }
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

            try? await Task.sleep(for: .seconds(1.25))

            if reduceMotion {
                onFinish()
            } else {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isExiting = true
                }
                try? await Task.sleep(for: .seconds(0.3))
                onFinish()
            }
        }
    }
}

#Preview {
    AppSplashView(onFinish: {})
}
