import SwiftUI

struct AestheticStylesView: View {
    let onOpenStyle: (String) -> Void

    @State private var showsExplorer = false
    @State private var pendingStyleID: String?

    var body: some View {
        GeometryReader { proxy in
            let contentWidth = min(proxy.size.width - 40, 430)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("装机风格")
                                .font(.system(size: 29, weight: .heavy))
                                .foregroundStyle(Color(red: 0.035, green: 0.051, blue: 0.067))

                            Text("多种高性能整机设计，找到属于你的风格")
                                .font(.system(size: 11, weight: .regular))
                                .foregroundStyle(Color(red: 0.48, green: 0.51, blue: 0.56))
                        }

                        Spacer()

                        Button {
                            showsExplorer = true
                        } label: {
                            Image(systemName: "cube.transparent")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(AppTheme.primaryText)
                                .frame(width: 42, height: 42)
                                .background(.ultraThinMaterial, in: Circle())
                                .overlay {
                                    Circle()
                                        .stroke(Color.white.opacity(0.7), lineWidth: 1)
                                }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("进入沉浸风格浏览")
                    }
                    .padding(.top, 12)

                    LazyVStack(spacing: 0) {
                        ForEach(AestheticBuildStyle.all.indices, id: \.self) { index in
                            let style = AestheticBuildStyle.all[index]

                            AestheticStyleShowcaseRow(
                                index: index,
                                style: style,
                                contentWidth: contentWidth
                            ) {
                                onOpenStyle(style.id)
                            }
                        }
                    }
                    .padding(.top, 14)
                }
                .frame(width: contentWidth, alignment: .leading)
                .padding(.bottom, 88)
                .frame(maxWidth: .infinity)
            }
            .background {
                RadialGradient(
                    colors: [
                        Color.white,
                        Color(red: 0.94, green: 0.96, blue: 0.98).opacity(0.72)
                    ],
                    center: .center,
                    startRadius: 80,
                    endRadius: 520
                )
                .ignoresSafeArea()
            }
        }
        .fullScreenCover(isPresented: $showsExplorer, onDismiss: openPendingStyle) {
            AestheticStyleExplorerView(
                styles: AestheticBuildStyle.all,
                onClose: { showsExplorer = false },
                onOpenStyle: { styleID in
                    pendingStyleID = styleID
                    showsExplorer = false
                }
            )
        }
    }

    private func openPendingStyle() {
        guard let styleID = pendingStyleID else { return }
        pendingStyleID = nil
        onOpenStyle(styleID)
    }
}

private struct AestheticStyleShowcaseRow: View {
    let index: Int
    let style: AestheticBuildStyle
    let contentWidth: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topLeading) {
                Ellipse()
                    .fill(Color.black.opacity(0.09))
                    .frame(width: 156, height: 7)
                    .blur(radius: 5)
                    .offset(x: contentWidth * 0.57, y: rowHeight - 22)

                caseImage
                    .scaleEffect(x: 1, y: -1)
                    .frame(height: 25, alignment: .top)
                    .clipped()
                    .mask(
                        LinearGradient(
                            colors: [.white.opacity(0.22), .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .opacity(0.32)
                    .blur(radius: 1.2)
                    .offset(x: contentWidth * 0.40, y: rowHeight - 21)

                caseImage
                    .offset(x: contentWidth * 0.40, y: imageYOffset)

                HStack(spacing: 12) {
                    Text(String(format: "%02d", index + 1))
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .monospacedDigit()

                    Text("/")
                        .font(.system(size: 18, weight: .light))
                }
                .foregroundStyle(Color(red: 0.67, green: 0.70, blue: 0.75))

                VStack(alignment: .leading, spacing: 6) {
                    Text(displayTitle)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color(red: 0.035, green: 0.051, blue: 0.067))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("外观方案约")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color(red: 0.50, green: 0.53, blue: 0.58))

                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("¥ \(style.minimumOverviewCost.formatted())")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color(red: 0.035, green: 0.051, blue: 0.067))

                        Text("起")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Color(red: 0.50, green: 0.53, blue: 0.58))
                    }

                    Image(systemName: "arrow.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 19, height: 19)
                        .background(Color(red: 0.035, green: 0.051, blue: 0.067), in: Circle())
                        .padding(.top, 5)
                }
                .frame(width: 154, alignment: .leading)
                .offset(y: 42)
            }
            .frame(width: contentWidth, height: rowHeight, alignment: .topLeading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(style.title)，\(style.startingCostLabel)")
    }

    private var caseImage: some View {
        Image(style.image)
            .resizable()
            .scaledToFit()
            .frame(width: contentWidth * 0.69, height: 156)
            .scaleEffect(imageScale)
    }

    private var displayTitle: String {
        style.id == "blackKnight" ? "联立 VISION\nCOMPACT" : style.title
    }

    private var rowHeight: CGFloat {
        switch style.id {
        case "blackKnight": 178
        case "panorama": 172
        case "whiteMinimal": 172
        case "bo400": 142
        case "asusAP202": 150
        case "hyteY70": 166
        case "aocShockingBow": 166
        case "bo400cg": 150
        default: 140
        }
    }

    private var imageScale: CGFloat {
        switch style.id {
        case "blackKnight": 1.10
        case "panorama": 1.04
        case "whiteMinimal": 1.03
        case "bo400": 1.04
        case "asusAP202": 0.88
        case "hyteY70": 0.91
        case "aocShockingBow": 0.82
        case "bo400cg": 0.94
        default: 0.78
        }
    }

    private var imageYOffset: CGFloat {
        switch style.id {
        case "blackKnight": 0
        case "panorama": -6
        case "whiteMinimal": -8
        case "bo400": -4
        case "asusAP202": -3
        case "hyteY70": -5
        case "aocShockingBow": -4
        case "bo400cg": -4
        default: -2
        }
    }
}

struct AestheticStyleRow: View {
    let style: AestheticBuildStyle
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 9) {
                    Text(style.title)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.black)

                    Text("按这个风格装机  →")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppTheme.secondaryText)
                }

                Spacer(minLength: 6)

                Image(style.image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 148, height: 106)
                    .offset(x: 12)
            }
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    AestheticStylesView(onOpenStyle: { _ in })
}
