import SwiftUI

struct LaunchIntroView: View {
    let onFinish: () -> Void

    @State private var selectedPageID: Int? = LaunchIntroPage.build.id

    private var selectedPage: LaunchIntroPage {
        LaunchIntroPage(rawValue: selectedPageID ?? LaunchIntroPage.build.id) ?? .build
    }

    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 0) {
                ForEach(LaunchIntroPage.allCases) { page in
                    LaunchIntroPageView(
                        page: page,
                        selectedPageID: selectedPageID ?? LaunchIntroPage.build.id,
                        advance: advance
                    )
                    .containerRelativeFrame(.horizontal)
                    .id(page.id)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: $selectedPageID)
        .scrollIndicators(.hidden)
        .background(Color(white: 0.95).ignoresSafeArea())
    }

    private func advance() {
        if selectedPage == .save {
            onFinish()
            return
        }

        withAnimation(.smooth(duration: 0.42)) {
            selectedPageID = min((selectedPageID ?? LaunchIntroPage.build.id) + 1, LaunchIntroPage.save.id)
        }
    }
}

private struct LaunchIntroPageView: View {
    let page: LaunchIntroPage
    let selectedPageID: Int
    let advance: () -> Void

    @State private var bBack = false
    @State private var bFront = false

    var body: some View {
        GeometryReader { proxy in
            let heroHeight = proxy.size.height * 0.58
            let heroWidth = min(proxy.size.width * 1.08, 430)
            let buttonWidth = max(0, min(proxy.size.width - 48, 390))
            let content = page.content

            VStack(spacing: 0) {
                ZStack(alignment: .top) {
                    Image(content.back)
                        .resizable()
                        .scaledToFit()
                        .frame(width: heroWidth, height: heroHeight)
                        .modifier(LayerMotion(parallax: 24, scaleDrop: 0.04, rotation: -4, breatheY: bBack ? -2 : 2))

                    Image(content.front)
                        .resizable()
                        .scaledToFit()
                        .frame(width: heroWidth, height: heroHeight)
                        .modifier(LayerMotion(parallax: 66, scaleDrop: 0.08, rotation: 9, breatheY: bFront ? -4 : 4))
                }
                .frame(maxWidth: .infinity)
                .frame(height: heroHeight)
                .clipped()
                .padding(.top, max(proxy.safeAreaInsets.top - 4, 8))
                .onAppear {
                    withAnimation(.easeInOut(duration: 3.2).repeatForever(autoreverses: true)) {
                        bBack = true
                    }
                    withAnimation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true)) {
                        bFront = true
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text(content.title)
                        .font(.system(size: 32, weight: .heavy))
                        .foregroundStyle(.black)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)

                    Text(content.subtitle)
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(Color(white: 0.5))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.top, 28)
                .scrollTransition(.interactive, axis: .horizontal) { content, phase in
                    content
                        .blur(radius: abs(phase.value) * 8)
                        .opacity(1 - abs(phase.value))
                        .scaleEffect(1 - abs(phase.value) * 0.035, anchor: .leading)
                        .offset(x: phase.value * -18, y: abs(phase.value) * 18)
                }

                Spacer(minLength: 24)

                Button(action: advance) {
                    Text(content.cta)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: buttonWidth, height: 56)
                        .background(Color.black, in: Capsule())
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, alignment: .center)
                .offset(x: -10)
                .padding(.bottom, 16)

                LaunchIntroDots(selectedPageID: selectedPageID)
                    .padding(.bottom, max(proxy.safeAreaInsets.bottom, 12))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

private struct LayerMotion: ViewModifier {
    let parallax: CGFloat
    let scaleDrop: CGFloat
    let rotation: CGFloat
    let breatheY: CGFloat

    func body(content: Content) -> some View {
        content
            .scrollTransition(.interactive, axis: .horizontal) { content, phase in
                content
                    .offset(x: phase.value * parallax, y: abs(phase.value) * 16)
                    .scaleEffect(1 - abs(phase.value) * scaleDrop)
                    .rotation3DEffect(
                        .degrees(phase.value * rotation),
                        axis: (x: 0, y: 1, z: 0),
                        anchor: phase.value > 0 ? .leading : .trailing,
                        perspective: 0.68
                    )
                    .blur(radius: abs(phase.value) * 4)
                    .opacity(1 - abs(phase.value) * 0.28)
            }
            .offset(y: breatheY)
    }
}

private struct LaunchIntroDots: View {
    let selectedPageID: Int

    var body: some View {
        HStack(spacing: 10) {
            ForEach(LaunchIntroPage.allCases) { page in
                Capsule()
                    .fill(page.id == selectedPageID ? Color.black : Color(white: 0.8))
                    .frame(width: page.id == selectedPageID ? 24 : 8, height: 8)
                    .animation(.snappy(duration: 0.25), value: selectedPageID)
            }
        }
    }
}
