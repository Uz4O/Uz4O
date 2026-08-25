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
                            HStack(spacing: 7) {
                                Text("全景浏览")
                                    .font(.system(size: 12, weight: .semibold))
                                    .overlay(alignment: .bottom) {
                                        Rectangle()
                                            .fill(AppTheme.primaryText)
                                            .frame(height: 0.8)
                                            .offset(y: 3)
                                    }

                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            .foregroundStyle(AppTheme.primaryText)
                            .frame(minHeight: 44)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("进入沉浸风格全景")
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

                    Text("为颜值花费约")
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
        case "visionMin": 150
        case "hangjiaS960": 150
        case "lianliV150INF": 150
        case "jonsboTK1": 150
        case "jonsboD33Wood": 150
        case "jonsboD34": 150
        case "aigoXuanYingG20": 150
        case "valkyrieVK3": 150
        case "lianliO11EVORGB": 150
        case "phanteksEvolvS2": 150
        case "phanteksEvolvX2Matrix": 150
        case "jonsboTK4": 150
        case "xingcanChenAir": 150
        case "phanteksNV7": 166
        case "lianliO11DMiniV2": 150
        case "asusTUF502Ammo": 150
        case "rogGR801": 172
        case "msiVIXTA300R": 150
        case "hangjiaS960V2": 150
        case "hangjiaGX750C": 150
        case "coolermasterMF400Mesh": 150
        case "sugonCiyuanCangPX": 166
        case "titanStarship": 166
        case "fangtangC34Pro": 166
        case "cougarV235": 166
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
        case "visionMin": 1.00
        case "hangjiaS960": 0.92
        case "lianliV150INF": 1.08
        case "jonsboTK1": 1.00
        case "jonsboD33Wood": 1.00
        case "jonsboD34": 0.94
        case "aigoXuanYingG20": 0.96
        case "valkyrieVK3": 0.96
        case "lianliO11EVORGB": 0.94
        case "phanteksEvolvS2": 0.88
        case "phanteksEvolvX2Matrix": 0.88
        case "jonsboTK4": 0.94
        case "xingcanChenAir": 0.94
        case "phanteksNV7": 0.84
        case "lianliO11DMiniV2": 0.96
        case "asusTUF502Ammo": 0.88
        case "rogGR801": 1.00
        case "msiVIXTA300R": 0.92
        case "hangjiaS960V2": 0.92
        case "hangjiaGX750C": 0.92
        case "coolermasterMF400Mesh": 0.92
        case "sugonCiyuanCangPX": 0.78
        case "titanStarship": 0.90
        case "fangtangC34Pro": 0.88
        case "cougarV235": 0.88
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
        case "visionMin": -4
        case "hangjiaS960": -4
        case "lianliV150INF": -4
        case "jonsboTK1": -4
        case "jonsboD33Wood": -4
        case "jonsboD34": -4
        case "aigoXuanYingG20": -4
        case "valkyrieVK3": -4
        case "lianliO11EVORGB": -4
        case "phanteksEvolvS2": -4
        case "phanteksEvolvX2Matrix": -4
        case "jonsboTK4": -4
        case "xingcanChenAir": -4
        case "phanteksNV7": -5
        case "lianliO11DMiniV2": -4
        case "asusTUF502Ammo": -4
        case "rogGR801": -6
        case "msiVIXTA300R": -4
        case "hangjiaS960V2": -4
        case "hangjiaGX750C": -4
        case "coolermasterMF400Mesh": -4
        case "sugonCiyuanCangPX": -4
        case "titanStarship": -4
        case "fangtangC34Pro": -4
        case "cougarV235": -4
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
                VStack(alignment: .leading, spacing: 7) {
                    Text(style.title)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.black)

                    Text(style.startingCostLabel)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.black.opacity(0.72))

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
