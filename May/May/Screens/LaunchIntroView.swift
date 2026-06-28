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

        withAnimation(.snappy(duration: 0.35)) {
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
            let content = page.content

            VStack(spacing: 0) {
                ZStack(alignment: .top) {
                    Image(content.back)
                        .resizable()
                        .scaledToFit()
                        .frame(width: heroWidth, height: heroHeight)
                        .modifier(LayerMotion(parallax: 24, scaleDrop: 0.04, breatheY: bBack ? -2 : 2))

                    Image(content.front)
                        .resizable()
                        .scaledToFit()
                        .frame(width: heroWidth, height: heroHeight)
                        .modifier(LayerMotion(parallax: 56, scaleDrop: 0.07, breatheY: bFront ? -4 : 4))
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
                        .offset(y: phase.value * 10)
                }

                Spacer(minLength: 24)

                Button(action: advance) {
                    Text(content.cta)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.black, in: Capsule())
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 24)
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
    let breatheY: CGFloat

    func body(content: Content) -> some View {
        content
            .scrollTransition(.interactive, axis: .horizontal) { content, phase in
                content
                    .offset(x: phase.value * parallax)
                    .scaleEffect(1 - abs(phase.value) * scaleDrop)
                    .blur(radius: abs(phase.value) * 6)
                    .opacity(1 - abs(phase.value) * 0.3)
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
