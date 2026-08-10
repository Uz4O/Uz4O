import SceneKit
import SwiftUI
import UIKit
import Foundation

private struct StyleExplorerTuning: Equatable {
    var tileSize = 1.65
    var spacingX = 2.45
    var spacingY = 2.45
    var overviewZoom = 34.0
    var focusZoom = 12.0
    var fieldOfView = 45.0
    var curvatureStrength = 0.14
    var dragSpeed = 2.2
    var positionDamping = 0.2
    var zoomDamping = 0.25
    var tiltStrength = 0.08
    var dragResistance = 0.25
    var focusScale = 1.5
    var dimScale = 0.52
    var dimOpacity = 0.14

    static let defaults = StyleExplorerTuning()
}

struct AestheticStyleExplorerView: View {
    let styles: [AestheticBuildStyle]
    let onClose: () -> Void
    let onOpenStyle: (String) -> Void

    @State private var selectedStyle: AestheticBuildStyle?
    @State private var selectedColor = AestheticStyleColor.black
    @State private var isZoomedIn = false
    @State private var panoramaRequestID = 0
    @State private var zoomInRequestID = 0
    @State private var tuning = StyleExplorerTuning.defaults
    @State private var showsTuning = false
    @Namespace private var controlBarAnimation

    private var items: [StyleExplorerItem] {
        guard !styles.isEmpty else { return [] }
        let orderedStyles = balancedStyleOrder
        return (0..<42).map { index in
            let styleIndex = index % orderedStyles.count
            let style = orderedStyles[styleIndex]
            return StyleExplorerItem(
                id: index,
                style: style,
                imageName: AestheticExplorerAssetCatalog.imageName(
                    for: style.heroImage(for: selectedColor)
                )
            )
        }
    }

    private var balancedStyleOrder: [AestheticBuildStyle] {
        let sorted = styles.sorted {
            let left = styleImageGeometry(
                imageName: AestheticExplorerAssetCatalog.imageName(
                    for: $0.heroImage(for: .black)
                ),
                tileSize: tuning.tileSize
            )
            let right = styleImageGeometry(
                imageName: AestheticExplorerAssetCatalog.imageName(
                    for: $1.heroImage(for: .black)
                ),
                tileSize: tuning.tileSize
            )
            return left.visibleSize.width * left.visibleSize.height
                < right.visibleSize.width * right.visibleSize.height
        }
        var result: [AestheticBuildStyle] = []
        var low = 0
        var high = sorted.count - 1
        while low <= high {
            result.append(sorted[high])
            high -= 1
            if low <= high {
                result.append(sorted[low])
                low += 1
            }
        }
        return result
    }

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            TopologyLayerBackground(isZoomedIn: isZoomedIn)
            .ignoresSafeArea()

            StyleExplorerSceneView(
                items: items,
                tuning: tuning,
                panoramaRequestID: panoramaRequestID,
                zoomInRequestID: zoomInRequestID,
                selectedStyle: $selectedStyle,
                isZoomedIn: $isZoomedIn
            )
                .ignoresSafeArea()

            VStack(spacing: 0) {
                if selectedStyle == nil {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("沉浸风格")
                                .font(.system(size: 22, weight: .heavy))
                                .foregroundStyle(AppTheme.primaryText)

                            Text("风格全景")
                                .font(.appCaption)
                                .foregroundStyle(AppTheme.secondaryText)
                        }

                        Spacer()

                        Button {
                            showsTuning.toggle()
                        } label: {
                            Image(systemName: "slider.horizontal.3")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(AppTheme.primaryText)
                                .frame(width: 40, height: 40)
                                .background(.ultraThinMaterial, in: Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("调整沉浸风格参数")

                        Button(action: onClose) {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(AppTheme.primaryText)
                                .frame(width: 40, height: 40)
                                .background(.ultraThinMaterial, in: Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("退出沉浸风格浏览")
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                }

                Spacer()

                if let selectedStyle {
                    openStyleButton(for: selectedStyle)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                } else {
                    explorerControlBar
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }

            if let selectedStyle {
                focusOverlay(for: selectedStyle)
            } else if showsTuning {
                VStack {
                    HStack {
                        Spacer()
                        StyleExplorerTuningPanel(
                            tuning: $tuning
                        ) {
                            tuning = .defaults
                        }
                    }
                    Spacer()
                }
                .padding(.top, 62)
                .padding(.trailing, 16)
                .transition(
                    .scale(scale: 0.94, anchor: .topTrailing)
                        .combined(with: .opacity)
                )
            }
        }
        .animation(.spring(response: 0.42, dampingFraction: 0.86), value: selectedStyle?.id)
        .animation(.easeInOut(duration: 0.2), value: showsTuning)
        .onChange(of: selectedStyle?.id) { _, newValue in
            if newValue != nil {
                showsTuning = false
            }
        }
        .statusBarHidden()
    }

    private func openStyleButton(for style: AestheticBuildStyle) -> some View {
        HStack {
            Spacer()
            Button {
                onOpenStyle(style.id)
            } label: {
                HStack(spacing: 6) {
                    Text("查看风格")
                    Image(systemName: "arrow.right")
                }
                .font(.appSubheadline)
                .foregroundStyle(.white)
                .padding(.horizontal, 28)
                .frame(height: 52)
                .background(AppTheme.primaryButton, in: Capsule())
            }
            .buttonStyle(.plain)
            Spacer()
        }
        .padding(.bottom, 22)
    }

    private var explorerControlBar: some View {
        ZStack {
            if isZoomedIn {
                Button {
                    withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
                        isZoomedIn = false
                        panoramaRequestID += 1
                    }
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(AppTheme.primaryText)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                        .matchedGeometryEffect(id: "zoom-control", in: controlBarAnimation)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("返回风格全景")
                .transition(.scale(scale: 0.72).combined(with: .opacity))
            } else {
                HStack(spacing: 0) {
                    Button {
                        withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
                            isZoomedIn = true
                            zoomInRequestID += 1
                        }
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 23, weight: .bold))
                            .foregroundStyle(AppTheme.primaryText)
                            .frame(width: 52, height: 44)
                            .matchedGeometryEffect(id: "zoom-control", in: controlBarAnimation)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("放大风格画布")

                    Rectangle()
                        .fill(AppTheme.primaryText.opacity(0.12))
                        .frame(width: 1, height: 32)
                        .padding(.trailing, 8)

                    colorButton(.black)
                    colorButton(.white)
                }
                .padding(6)
                .transition(.scale(scale: 0.92).combined(with: .opacity))
            }
        }
        .frame(width: isZoomedIn ? 60 : 266, height: 56)
        .background(
            .ultraThinMaterial,
            in: RoundedRectangle(
                cornerRadius: isZoomedIn ? 20 : 28,
                style: .continuous
            )
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: isZoomedIn ? 20 : 28,
                style: .continuous
            )
                .stroke(Color.white.opacity(0.55), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.1), radius: 20, y: 8)
        .animation(.spring(response: 0.42, dampingFraction: 0.82), value: isZoomedIn)
        .scaleEffect(0.9)
        .padding(.bottom, 38)
    }

    private func colorButton(_ color: AestheticStyleColor) -> some View {
        Button {
            guard selectedColor != color else { return }
            withAnimation(.spring(response: 0.38, dampingFraction: 0.78)) {
                selectedColor = color
            }
        } label: {
            Text(color.title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(
                    selectedColor == color ? AppTheme.primaryText : AppTheme.secondaryText
                )
                .frame(width: 96, height: 44)
                .background {
                    if selectedColor == color {
                        Capsule()
                            .fill(.white.opacity(0.82))
                            .shadow(color: .black.opacity(0.08), radius: 10, y: 4)
                            .matchedGeometryEffect(
                                id: "selected-color",
                                in: controlBarAnimation
                            )
                    }
                }
                .scaleEffect(selectedColor == color ? 1 : 0.98)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selectedColor == color ? .isSelected : [])
    }

    private func focusOverlay(for style: AestheticBuildStyle) -> some View {
        GeometryReader { proxy in
            let layout = focusedImageLayout(for: style, in: proxy.size)
            let center = CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)
            let visibleFrame = layout.visibleFrame.offsetBy(dx: center.x, dy: center.y)
            let closeButtonSize: CGFloat = 34
            let closeButtonHitSize: CGFloat = 44
            let closeButtonHorizontalOffset: CGFloat = 32
            let closeButtonVerticalOffset: CGFloat = 32

            Button {
                selectedStyle = nil
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(AppTheme.primaryText)
                    .frame(width: closeButtonSize, height: closeButtonSize)
                    .background(.ultraThinMaterial, in: Rectangle())
                    .overlay {
                        Rectangle()
                            .stroke(AppTheme.primaryText.opacity(0.55), lineWidth: 1)
                    }
            }
            .frame(width: closeButtonHitSize, height: closeButtonHitSize)
            .buttonStyle(.plain)
            .accessibilityLabel("关闭当前风格")
            .position(
                x: min(
                    proxy.size.width - closeButtonHitSize / 2,
                    max(
                        closeButtonHitSize / 2,
                        visibleFrame.maxX - closeButtonSize / 2 + closeButtonHorizontalOffset
                    )
                ),
                y: min(
                    proxy.size.height - closeButtonHitSize / 2,
                    max(
                        closeButtonHitSize / 2,
                        visibleFrame.minY - closeButtonSize / 2 - closeButtonVerticalOffset
                    )
                )
            )

            VStack(spacing: 7) {
                Text(style.title)
                    .font(.appHeadline)
                    .foregroundStyle(AppTheme.primaryText)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)

                Text(style.startingCostLabel)
                    .font(.appSubheadline)
                    .foregroundStyle(AppTheme.secondaryText)
            }
            .frame(width: min(proxy.size.width - 48, 360))
            .position(
                x: center.x,
                y: min(proxy.size.height - 150, visibleFrame.maxY + 52)
            )
            .allowsHitTesting(false)
        }
    }

    private func focusedImageLayout(for style: AestheticBuildStyle, in viewSize: CGSize) -> FocusedImageLayout {
        let imageName = style.heroImage(for: selectedColor)
        let geometry = styleImageGeometry(imageName: imageName, tileSize: tuning.tileSize)
        let distance = max(tuning.focusZoom - 2, 1)
        let visibleHeight = 2 * tan(tuning.fieldOfView * .pi / 360) * distance
        let pointsPerWorldUnit = viewSize.height / visibleHeight
        let scale = tuning.focusScale * pointsPerWorldUnit
        let size = CGSize(
            width: geometry.visibleSize.width * scale,
            height: geometry.visibleSize.height * scale
        )
        let baseline = geometry.baseline * scale

        return FocusedImageLayout(
            visibleFrame: CGRect(
                x: -size.width / 2,
                y: baseline - size.height,
                width: size.width,
                height: size.height
            )
        )
    }
}

private struct FocusedImageLayout {
    let visibleFrame: CGRect
}

private struct StyleImageGeometry {
    let planeSize: CGSize
    let visibleSize: CGSize
    let pivot: CGPoint
    let baseline: CGFloat
}

private struct TopologyLayerBackground: UIViewRepresentable {
    let isZoomedIn: Bool

    func makeUIView(context: Context) -> TopologyBackgroundUIView {
        let view = TopologyBackgroundUIView()
        view.setZoomedIn(isZoomedIn, animated: false)
        return view
    }

    func updateUIView(_ view: TopologyBackgroundUIView, context: Context) {
        view.setZoomedIn(isZoomedIn, animated: true)
    }
}

private final class TopologyBackgroundUIView: UIView {
    private static let tileSize = CGSize(width: 440, height: 820)
    private static let animationDuration: CFTimeInterval = 42
    private let tilesLayer = CALayer()
    private var laidOutSize = CGSize.zero

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        isAccessibilityElement = false
        layer.masksToBounds = true
        layer.addSublayer(tilesLayer)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.size != laidOutSize else { return }
        laidOutSize = bounds.size
        rebuildTiles()
    }

    func setZoomedIn(_ isZoomedIn: Bool, animated: Bool) {
        let targetOpacity: Float = isZoomedIn ? 0.55 : 1
        guard tilesLayer.opacity != targetOpacity else { return }
        let currentOpacity = tilesLayer.presentation()?.opacity ?? tilesLayer.opacity
        tilesLayer.opacity = targetOpacity
        guard animated else { return }

        let animation = CABasicAnimation(keyPath: "opacity")
        animation.fromValue = currentOpacity
        animation.toValue = targetOpacity
        animation.duration = 0.3
        tilesLayer.add(animation, forKey: "opacity")
    }

    private func rebuildTiles() {
        let tileSize = Self.tileSize
        let columns = max(3, Int(ceil(bounds.width / tileSize.width)) + 2)
        let rows = max(3, Int(ceil(bounds.height / tileSize.height)) + 2)
        let image = UIImage(named: "TopologyContourTexture")

        tilesLayer.removeAllAnimations()
        tilesLayer.sublayers?.forEach { $0.removeFromSuperlayer() }
        tilesLayer.frame = CGRect(
            origin: .zero,
            size: CGSize(
                width: CGFloat(columns) * tileSize.width,
                height: CGFloat(rows) * tileSize.height
            )
        )

        for row in 0..<rows {
            for column in 0..<columns {
                let tile = CALayer()
                tile.frame = CGRect(
                    x: CGFloat(column) * tileSize.width,
                    y: CGFloat(row) * tileSize.height,
                    width: tileSize.width,
                    height: tileSize.height
                )
                tile.contents = image?.cgImage
                tile.contentsScale = image?.scale ?? 2
                tile.contentsGravity = .resize
                tilesLayer.addSublayer(tile)
            }
        }

        let animation = CABasicAnimation(keyPath: "transform")
        animation.fromValue = CATransform3DMakeTranslation(0, -tileSize.height, 0)
        animation.toValue = CATransform3DMakeTranslation(-tileSize.width, 0, 0)
        animation.duration = Self.animationDuration
        animation.repeatCount = .infinity
        animation.timingFunction = CAMediaTimingFunction(name: .linear)
        animation.isRemovedOnCompletion = false
        tilesLayer.add(animation, forKey: "topology-drift")
    }
}

@MainActor
private func styleImageGeometry(imageName: String, tileSize: Double) -> StyleImageGeometry {
    guard let image = UIImage(named: imageName) else {
        let size = CGFloat(tileSize) * 0.88
        return StyleImageGeometry(
            planeSize: CGSize(width: size, height: size),
            visibleSize: CGSize(width: size, height: size),
            pivot: .zero,
            baseline: size * 0.44
        )
    }

    let bounds = StyleImageVisibleBoundsCache.bounds(for: image, named: imageName)
    let canvasAspect = image.size.width / image.size.height
    let targetVisibleSize = CGFloat(tileSize) * 0.88
    let baseWidth = canvasAspect
    let baseHeight: CGFloat = 1
    let scale = targetVisibleSize / max(
        baseWidth * bounds.width,
        baseHeight * bounds.height
    )
    let planeSize = CGSize(width: baseWidth * scale, height: baseHeight * scale)
    let visibleSize = CGSize(
        width: planeSize.width * bounds.width,
        height: planeSize.height * bounds.height
    )
    let baseline = targetVisibleSize * 0.44
    let visibleBottom = (0.5 - bounds.maxY) * planeSize.height

    return StyleImageGeometry(
        planeSize: planeSize,
        visibleSize: visibleSize,
        pivot: CGPoint(
            x: (bounds.midX - 0.5) * planeSize.width,
            y: visibleBottom + baseline
        ),
        baseline: baseline
    )
}

@MainActor
private enum StyleImageVisibleBoundsCache {
    private static var cachedBounds: [String: CGRect] = [:]

    static func bounds(for image: UIImage, named name: String) -> CGRect {
        if let bounds = AestheticExplorerAssetCatalog.visibleBounds(for: name) {
            return bounds
        }
        if let cached = cachedBounds[name] {
            return cached
        }

        let bounds = opaqueBounds(for: image) ?? CGRect(x: 0, y: 0, width: 1, height: 1)
        cachedBounds[name] = bounds
        return bounds
    }

    private static func opaqueBounds(for image: UIImage) -> CGRect? {
        guard let cgImage = image.cgImage else { return nil }

        let scale = min(1, 256 / CGFloat(max(cgImage.width, cgImage.height)))
        let width = max(1, Int((CGFloat(cgImage.width) * scale).rounded(.up)))
        let height = max(1, Int((CGFloat(cgImage.height) * scale).rounded(.up)))
        let bytesPerRow = width * 4
        var pixels = [UInt8](repeating: 0, count: height * bytesPerRow)
        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                | CGBitmapInfo.byteOrder32Big.rawValue
        ) else { return nil }

        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1, y: -1)
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        var minX = width
        var minY = height
        var maxX = -1
        var maxY = -1
        for y in 0..<height {
            for x in 0..<width where pixels[y * bytesPerRow + x * 4 + 3] > 8 {
                minX = min(minX, x)
                minY = min(minY, y)
                maxX = max(maxX, x)
                maxY = max(maxY, y)
            }
        }

        guard maxX >= minX, maxY >= minY else { return nil }
        return CGRect(
            x: CGFloat(minX) / CGFloat(width),
            y: CGFloat(minY) / CGFloat(height),
            width: CGFloat(maxX - minX + 1) / CGFloat(width),
            height: CGFloat(maxY - minY + 1) / CGFloat(height)
        )
    }
}

private struct StyleExplorerTuningPanel: View {
    @Binding var tuning: StyleExplorerTuning
    let onReset: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                HStack {
                    Text("风格画布参数")
                        .font(.system(size: 15, weight: .bold, design: .monospaced))

                    Spacer()

                    Button("重置", action: onReset)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.72))
                }
                .padding(16)

                Divider().overlay(Color.white.opacity(0.12))

                tuningSection("网格") {
                    tuningSlider("项目尺寸", value: $tuning.tileSize, range: 1.2...2.2, step: 0.05)
                    tuningSlider("水平间距", value: $tuning.spacingX, range: 1.8...3.2, step: 0.05)
                    tuningSlider("垂直间距", value: $tuning.spacingY, range: 1.8...3.2, step: 0.05)
                    tuningSlider("全景距离", value: $tuning.overviewZoom, range: 26...48, step: 1)
                    tuningSlider("视野角度", value: $tuning.fieldOfView, range: 35...60, step: 1)
                    tuningSlider("曲率", value: $tuning.curvatureStrength, range: 0...0.16, step: 0.005, digits: 3)
                }

                Divider().overlay(Color.white.opacity(0.12))

                tuningSection("交互") {
                    tuningSlider("拖动速度", value: $tuning.dragSpeed, range: 0.8...3.5, step: 0.1)
                    tuningSlider("位置阻尼", value: $tuning.positionDamping, range: 0.08...0.5, step: 0.01)
                    tuningSlider("镜头阻尼", value: $tuning.zoomDamping, range: 0.08...0.6, step: 0.01)
                    tuningSlider("倾斜强度", value: $tuning.tiltStrength, range: 0...0.2, step: 0.01)
                    tuningSlider("越界阻力", value: $tuning.dragResistance, range: 0.05...0.8, step: 0.05)
                }
            }
        }
        .frame(width: 300)
        .frame(maxHeight: 480)
        .foregroundStyle(.white)
        .background(Color(red: 0.07, green: 0.09, blue: 0.11).opacity(0.96))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.22), radius: 18, y: 8)
    }

    private func tuningSection<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 14, weight: .bold, design: .monospaced))
            content()
        }
        .padding(16)
    }

    private func tuningSlider(
        _ title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double,
        digits: Int = 2
    ) -> some View {
        VStack(spacing: 4) {
            HStack {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.82))
                Spacer()
                Text(value.wrappedValue.formatted(.number.precision(.fractionLength(digits))))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.58))
            }

            Slider(value: value, in: range, step: step)
                .tint(.white)
        }
    }
}

private struct StyleExplorerItem: Equatable, Identifiable {
    let id: Int
    let style: AestheticBuildStyle
    let imageName: String
}

private struct StyleExplorerSceneView: UIViewRepresentable {
    let items: [StyleExplorerItem]
    let tuning: StyleExplorerTuning
    let panoramaRequestID: Int
    let zoomInRequestID: Int
    @Binding var selectedStyle: AestheticBuildStyle?
    @Binding var isZoomedIn: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(
            items: items,
            tuning: tuning,
            panoramaRequestID: panoramaRequestID,
            zoomInRequestID: zoomInRequestID,
            selectedStyle: $selectedStyle,
            isZoomedIn: $isZoomedIn
        )
    }

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        context.coordinator.configure(view)
        return view
    }

    func updateUIView(_ view: SCNView, context: Context) {
        context.coordinator.selectedStyle = $selectedStyle
        context.coordinator.isZoomedIn = $isZoomedIn
        context.coordinator.update(items)
        context.coordinator.update(tuning)
        context.coordinator.applyPanoramaRequest(panoramaRequestID)
        context.coordinator.applyZoomInRequest(zoomInRequestID)
        if selectedStyle == nil, context.coordinator.activeItemID != nil {
            context.coordinator.clearSelection(notify: false)
        }
    }

    static func dismantleUIView(_ view: SCNView, coordinator: Coordinator) {
        coordinator.stop()
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        private let columns = 6
        private let overviewCenterY: Float = 1.2

        private var items: [StyleExplorerItem]
        private var tuning: StyleExplorerTuning
        private let scene = SCNScene()
        private let contentNode = SCNNode()
        private let cameraNode = SCNNode()
        private var nodes: [Int: SCNNode] = [:]
        private var basePositions: [Int: SCNVector3] = [:]
        private var gridHalfWidth: Float = 0
        private var gridHalfHeight: Float = 0
        private var targetPosition: SCNVector3
        private var targetZoom: Float
        private var panStart = SCNVector3Zero
        private var pinchStartZoom: Float
        private var displayLink: CADisplayLink?
        private var alternateWarmupWorkItem: DispatchWorkItem?
        private var pendingItemIDs: [Int] = []
        private var renderUntil: CFTimeInterval = 0
        private var panoramaRequestID: Int
        private var zoomInRequestID: Int
        private var preparedImages: [String: UIImage] = [:]
        private var outgoingNodes: [Int: SCNNode] = [:]
        private var incomingNodes: [Int: SCNNode] = [:]

        weak var sceneView: SCNView?
        var selectedStyle: Binding<AestheticBuildStyle?>
        var isZoomedIn: Binding<Bool>
        private(set) var activeItemID: Int?

        private var spacingX: Float { Float(tuning.spacingX) }
        private var spacingY: Float { Float(tuning.spacingY) }
        private var dragSpeed: Float { Float(tuning.dragSpeed) }
        private var dragResistance: Float { Float(tuning.dragResistance) }
        private var curvatureStrength: Float { Float(tuning.curvatureStrength) }
        private var minimumZoom: Float { Float(tuning.focusZoom) }
        private var maximumZoom: Float { Float(tuning.overviewZoom) }

        init(
            items: [StyleExplorerItem],
            tuning: StyleExplorerTuning,
            panoramaRequestID: Int,
            zoomInRequestID: Int,
            selectedStyle: Binding<AestheticBuildStyle?>,
            isZoomedIn: Binding<Bool>
        ) {
            self.items = items
            self.tuning = tuning
            self.panoramaRequestID = panoramaRequestID
            self.zoomInRequestID = zoomInRequestID
            self.selectedStyle = selectedStyle
            self.isZoomedIn = isZoomedIn
            targetPosition = SCNVector3(0, 1.2, 0)
            targetZoom = Float(tuning.overviewZoom)
            pinchStartZoom = Float(tuning.overviewZoom)
        }

        func configure(_ view: SCNView) {
            sceneView = view
            view.scene = scene
            view.backgroundColor = .clear
            view.isOpaque = false
            view.layer.isOpaque = false
            view.layer.backgroundColor = UIColor.clear.cgColor
            scene.background.contents = UIColor.clear
            view.allowsCameraControl = false
            view.autoenablesDefaultLighting = false
            view.antialiasingMode = .multisampling2X
            view.preferredFramesPerSecond = 60
            view.rendersContinuously = false

            let camera = SCNCamera()
            camera.fieldOfView = tuning.fieldOfView
            camera.zNear = 0.1
            camera.zFar = 150
            cameraNode.camera = camera
            cameraNode.position = SCNVector3(0, 0, maximumZoom)
            contentNode.position = targetPosition
            scene.rootNode.addChildNode(cameraNode)
            scene.rootNode.addChildNode(contentNode)
            view.pointOfView = cameraNode

            addItems()
            let currentNames = Set(items.map(\.imageName))
            let alternateNames = Set(items.flatMap { item in
                [
                    AestheticExplorerAssetCatalog.imageName(
                        for: item.style.heroImage(for: .black)
                    ),
                    AestheticExplorerAssetCatalog.imageName(
                        for: item.style.heroImage(for: .white)
                    )
                ]
            }).subtracting(currentNames)
            let warmupWorkItem = DispatchWorkItem { [weak self] in
                self?.warmImages(named: alternateNames)
            }
            alternateWarmupWorkItem = warmupWorkItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: warmupWorkItem)
            addGestures(to: view)

            let displayLink = CADisplayLink(target: self, selector: #selector(updateScene))
            displayLink.preferredFrameRateRange = CAFrameRateRange(
                minimum: 30,
                maximum: 60,
                preferred: 60
            )
            displayLink.add(to: .main, forMode: .common)
            self.displayLink = displayLink
            requestRendering(for: 1.2)
        }

        func stop() {
            alternateWarmupWorkItem?.cancel()
            alternateWarmupWorkItem = nil
            pendingItemIDs.removeAll()
            displayLink?.invalidate()
            displayLink = nil
        }

        func update(_ newTuning: StyleExplorerTuning) {
            guard newTuning != tuning else { return }
            let wasZoomedOut = activeItemID == nil && targetZoom > minimumZoom + 2
            tuning = newTuning
            cameraNode.camera?.fieldOfView = tuning.fieldOfView

            if activeItemID != nil {
                targetZoom = minimumZoom
            } else if wasZoomedOut {
                targetZoom = maximumZoom
            }
            pinchStartZoom = targetZoom

            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0.12
            updateLayout()
            updateSelectionAppearance()
            SCNTransaction.commit()
            requestRendering(for: 0.6)
        }

        func update(_ newItems: [StyleExplorerItem]) {
            guard newItems != items else { return }
            items = newItems
            warmImages(named: Set(newItems.map(\.imageName)))

            for item in items {
                guard let node = nodes[item.id] else { continue }
                let enterDelay = Double.random(in: 0...0.4)
                let exitDelay = Double.random(in: 0...0.3)
                let normalizedY = gridHalfHeight > 0
                    ? node.position.y / gridHalfHeight
                    : 0

                outgoingNodes[item.id]?.removeFromParentNode()
                incomingNodes[item.id]?.removeFromParentNode()
                node.opacity = 1

                let outgoing = node.clone()
                outgoing.name = "style-\(item.id)-outgoing"
                outgoing.renderingOrder = node.renderingOrder + 1
                node.parent?.addChildNode(outgoing)
                outgoingNodes[item.id] = outgoing

                node.geometry?.firstMaterial?.diffuse.contents = image(for: item.imageName)
                resizePlane(of: node, for: item)
                node.opacity = 0

                let incoming = node.clone()
                incoming.name = "style-\(item.id)-incoming"
                incoming.position.y += normalizedY
                incoming.position.z -= 18
                incoming.opacity = 0
                incoming.renderingOrder = node.renderingOrder
                node.parent?.addChildNode(incoming)
                incomingNodes[item.id] = incoming

                let enterMove = SCNAction.move(to: node.position, duration: 0.68)
                enterMove.timingMode = .easeOut
                incoming.runAction(
                    .sequence([
                        .wait(duration: enterDelay),
                        .group([
                            .fadeIn(duration: 0.58),
                            enterMove
                        ]),
                        .removeFromParentNode(),
                        .run { [weak self, weak node, weak incoming] _ in
                            guard let self, let node, let incoming,
                                  self.incomingNodes[item.id] === incoming else { return }
                            node.opacity = 1
                            self.incomingNodes[item.id] = nil
                        }
                    ]),
                    forKey: "color-enter"
                )

                let exitTarget = SCNVector3(
                    outgoing.position.x,
                    outgoing.position.y + normalizedY * 0.5,
                    outgoing.position.z + 12
                )
                let exitMove = SCNAction.move(to: exitTarget, duration: 0.5)
                exitMove.timingMode = .easeIn
                outgoing.runAction(
                    .sequence([
                        .wait(duration: exitDelay),
                        .group([
                            .fadeOut(duration: 0.28),
                            exitMove
                        ]),
                        .removeFromParentNode(),
                        .run { [weak self, weak outgoing] _ in
                            guard let outgoing,
                                  self?.outgoingNodes[item.id] === outgoing else { return }
                            self?.outgoingNodes[item.id] = nil
                        }
                    ]),
                    forKey: "color-outgoing"
                )
            }
            requestRendering(for: 1.2)
        }

        private func image(for name: String) -> UIImage? {
            preparedImages[name] ?? UIImage(named: name)
        }

        private func warmImages(named names: Set<String>) {
            let pendingNames = names.filter { preparedImages[$0] == nil }
            guard !pendingNames.isEmpty else { return }

            DispatchQueue.global(qos: .utility).async { [weak self] in
                let images = pendingNames.reduce(into: [String: UIImage]()) { result, name in
                    guard let image = UIImage(named: name) else { return }
                    result[name] = Self.preparedImage(image)
                }

                DispatchQueue.main.async {
                    guard let self else { return }
                    self.preparedImages.merge(images) { _, new in new }
                    for item in self.items {
                        guard let node = self.nodes[item.id],
                              let image = self.preparedImages[item.imageName] else { continue }
                        node.geometry?.firstMaterial?.diffuse.contents = image
                        self.resizePlane(of: node, for: item)
                    }
                    self.requestRendering(for: 0.2)
                }
            }
        }

        private static func preparedImage(_ image: UIImage) -> UIImage {
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1
            format.opaque = false
            return UIGraphicsImageRenderer(size: image.size, format: format).image { _ in
                image.draw(in: CGRect(origin: .zero, size: image.size))
            }
        }

        func applyPanoramaRequest(_ requestID: Int) {
            guard requestID != panoramaRequestID else { return }
            panoramaRequestID = requestID
            clearSelection(notify: false)
            targetPosition = SCNVector3(0, overviewCenterY, 0)
            targetZoom = maximumZoom
            pinchStartZoom = maximumZoom
            isZoomedIn.wrappedValue = false
            requestRendering(for: 0.8)
        }

        func applyZoomInRequest(_ requestID: Int) {
            guard requestID != zoomInRequestID else { return }
            zoomInRequestID = requestID
            targetZoom = minimumZoom
            pinchStartZoom = minimumZoom
            if let sceneView {
                clampTarget(in: sceneView)
            }
            isZoomedIn.wrappedValue = true
            requestRendering(for: 0.8)
        }

        private func updateLayout() {
            let rows = Int(ceil(Double(items.count) / Double(columns)))
            let totalWidth = Float(columns - 1) * spacingX
            let totalHeight = Float(max(rows - 1, 0)) * spacingY
            gridHalfWidth = totalWidth / 2 + spacingX / 2
            gridHalfHeight = totalHeight / 2 + spacingY / 2

            for item in items {
                guard let node = nodes[item.id] else { continue }
                let column = item.id % columns
                let row = item.id / columns
                let position = SCNVector3(
                    Float(column) * spacingX - totalWidth / 2,
                    totalHeight / 2 - Float(row) * spacingY,
                    node.position.z
                )
                basePositions[item.id] = SCNVector3(position.x, position.y, 0)
                node.position.x = position.x
                node.position.y = position.y
                resizePlane(of: node, for: item)
            }

            if let activeItemID, let position = basePositions[activeItemID] {
                targetPosition = SCNVector3(-position.x, -position.y, 0)
            }
        }

        private func updateSelectionAppearance() {
            for (id, node) in nodes {
                if let activeItemID {
                    if id == activeItemID {
                        let scale = Float(tuning.focusScale)
                        node.scale = SCNVector3(scale, scale, scale)
                        node.opacity = 1
                        node.renderingOrder = 100
                    } else {
                        let scale = Float(tuning.dimScale)
                        node.scale = SCNVector3(scale, scale, scale)
                        node.opacity = CGFloat(tuning.dimOpacity)
                        node.renderingOrder = 0
                    }
                } else {
                    node.scale = SCNVector3(1, 1, 1)
                    node.opacity = 1
                    node.renderingOrder = 0
                }
            }
        }

        private func addItems() {
            let rows = Int(ceil(Double(items.count) / Double(columns)))
            let totalWidth = Float(columns - 1) * spacingX
            let totalHeight = Float(max(rows - 1, 0)) * spacingY
            gridHalfWidth = totalWidth / 2 + spacingX / 2
            gridHalfHeight = totalHeight / 2 + spacingY / 2
            pendingItemIDs = items.map(\.id)
        }

        @discardableResult
        private func mountNextItems(limit: Int = 5) -> Bool {
            let count = min(limit, pendingItemIDs.count)
            guard count > 0 else { return false }
            let ids = pendingItemIDs.prefix(count)
            pendingItemIDs.removeFirst(count)
            let rows = Int(ceil(Double(items.count) / Double(columns)))
            let totalWidth = Float(columns - 1) * spacingX
            let totalHeight = Float(max(rows - 1, 0)) * spacingY

            for (batchIndex, id) in ids.enumerated() {
                guard nodes[id] == nil,
                      let item = items.first(where: { $0.id == id }) else { continue }
                let column = item.id % columns
                let row = item.id / columns
                let x = Float(column) * spacingX - totalWidth / 2
                let y = totalHeight / 2 - Float(row) * spacingY
                let basePosition = SCNVector3(x, y, 0)
                let node = makeNode(for: item)

                node.position = SCNVector3(x, y, -10)
                node.scale = SCNVector3(0.64, 0.64, 0.64)
                node.opacity = 0
                contentNode.addChildNode(node)
                nodes[item.id] = node
                basePositions[item.id] = basePosition

                let delay = Double(batchIndex) * 0.014
                let move = SCNAction.move(to: basePosition, duration: 0.58)
                move.timingMode = .easeOut
                let scale = SCNAction.scale(to: 1, duration: 0.5)
                scale.timingMode = .easeOut
                let fade = SCNAction.fadeOpacity(to: 1, duration: 0.36)
                node.runAction(.sequence([
                    .wait(duration: delay),
                    .group([move, scale, fade])
                ]))
            }
            return true
        }

        private func makeNode(for item: StyleExplorerItem) -> SCNNode {
            let image = UIImage(named: item.imageName)
            let plane = SCNPlane()
            let material = SCNMaterial()
            material.diffuse.contents = image
            material.lightingModel = .constant
            material.isDoubleSided = false
            material.transparencyMode = .singleLayer
            material.writesToDepthBuffer = true
            plane.materials = [material]

            let node = SCNNode(geometry: plane)
            node.name = "style-\(item.id)"
            resizePlane(of: node, for: item)
            return node
        }

        private func resizePlane(of node: SCNNode, for item: StyleExplorerItem) {
            guard let plane = node.geometry as? SCNPlane else { return }
            let geometry = styleImageGeometry(
                imageName: item.imageName,
                tileSize: tuning.tileSize
            )
            plane.width = geometry.planeSize.width
            plane.height = geometry.planeSize.height
            node.pivot = SCNMatrix4MakeTranslation(
                Float(geometry.pivot.x),
                Float(geometry.pivot.y),
                0
            )
        }

        private func addGestures(to view: SCNView) {
            let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan))
            let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch))
            let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
            pan.delegate = self
            pinch.delegate = self
            tap.require(toFail: pan)
            view.addGestureRecognizer(pan)
            view.addGestureRecognizer(pinch)
            view.addGestureRecognizer(tap)
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            (gestureRecognizer is UIPanGestureRecognizer && otherGestureRecognizer is UIPinchGestureRecognizer)
                || (gestureRecognizer is UIPinchGestureRecognizer && otherGestureRecognizer is UIPanGestureRecognizer)
        }

        @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
            guard let view = sceneView else { return }
            requestRendering(for: 0.5)

            switch gesture.state {
            case .began:
                if activeItemID != nil {
                    clearSelection(notify: true)
                }
                panStart = targetPosition
            case .changed:
                let translation = gesture.translation(in: view)
                let worldPerPoint = visibleHeight(in: view, zoom: targetZoom)
                    / Float(max(view.bounds.height, 1)) * dragSpeed
                let limits = dragLimits(in: view)
                targetPosition.x = resisted(panStart.x + Float(translation.x) * worldPerPoint, limit: limits.x)
                targetPosition.y = resisted(panStart.y - Float(translation.y) * worldPerPoint, limit: limits.y)
            case .ended, .cancelled:
                if targetZoom > minimumZoom + 2 {
                    targetPosition = SCNVector3(0, overviewCenterY, 0)
                } else {
                    clampTarget(in: view)
                }
            default:
                break
            }
        }

        @objc private func handlePinch(_ gesture: UIPinchGestureRecognizer) {
            guard let view = sceneView else { return }
            requestRendering(for: 0.5)

            switch gesture.state {
            case .began:
                pinchStartZoom = targetZoom
            case .changed, .ended:
                targetZoom = min(maximumZoom, max(minimumZoom, pinchStartZoom / Float(gesture.scale)))
                clampTarget(in: view)
                updateZoomedInState()
            default:
                break
            }
        }

        @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let view = sceneView else { return }
            let location = gesture.location(in: view)
            guard let result = view.hitTest(location, options: nil).first,
                  let name = result.node.name,
                  let itemID = Int(name.replacingOccurrences(of: "style-", with: "")),
                  nodes[itemID] != nil else {
                clearSelection(notify: true)
                return
            }

            if activeItemID == itemID {
                clearSelection(notify: true)
            } else {
                select(itemID)
            }
        }

        private func select(_ itemID: Int) {
            guard let basePosition = basePositions[itemID],
                  let style = items.first(where: { $0.id == itemID })?.style else { return }

            activeItemID = itemID
            targetPosition.x = -basePosition.x
            targetPosition.y = -basePosition.y
            targetZoom = minimumZoom
            updateZoomedInState()

            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0.48
            SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            for (id, node) in nodes {
                guard let original = basePositions[id] else { continue }
                if id == itemID {
                    node.position = SCNVector3(original.x, original.y, 2)
                    node.eulerAngles = SCNVector3Zero
                    let focusScale = Float(tuning.focusScale)
                    node.scale = SCNVector3(focusScale, focusScale, focusScale)
                    node.opacity = 1
                    node.renderingOrder = 100
                } else {
                    node.position = SCNVector3(original.x, original.y, original.z - 0.5)
                    let dimScale = Float(tuning.dimScale)
                    node.scale = SCNVector3(dimScale, dimScale, dimScale)
                    node.opacity = CGFloat(tuning.dimOpacity)
                    node.renderingOrder = 0
                }
            }
            SCNTransaction.commit()
            selectedStyle.wrappedValue = style
            requestRendering(for: 0.7)
        }

        func clearSelection(notify: Bool) {
            guard activeItemID != nil else { return }
            activeItemID = nil

            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0.38
            SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            for (id, node) in nodes {
                guard let original = basePositions[id] else { continue }
                node.position = original
                node.eulerAngles = SCNVector3Zero
                node.scale = SCNVector3(1, 1, 1)
                node.opacity = 1
                node.renderingOrder = 0
            }
            SCNTransaction.commit()
            requestRendering(for: 0.6)

            if notify {
                selectedStyle.wrappedValue = nil
            }
        }

        private func requestRendering(for duration: CFTimeInterval) {
            renderUntil = max(renderUntil, CACurrentMediaTime() + duration)
            displayLink?.isPaused = false
            sceneView?.setNeedsDisplay()
        }

        @objc private func updateScene(_ displayLink: CADisplayLink) {
            guard let view = sceneView else { return }
            let mountedItems = mountNextItems()
            let delta = min(max(displayLink.targetTimestamp - displayLink.timestamp, 1.0 / 120.0), 1.0 / 30.0)
            let positionBlend = Float(1 - exp(-delta / tuning.positionDamping))
            let zoomBlend = Float(1 - exp(-delta / tuning.zoomDamping))
            let oldPosition = contentNode.position

            contentNode.position.x += (targetPosition.x - contentNode.position.x) * positionBlend
            contentNode.position.y += (targetPosition.y - contentNode.position.y) * positionBlend
            cameraNode.position.z += (targetZoom - cameraNode.position.z) * zoomBlend
            let zoomProgress = max(0, min(1, (cameraNode.position.z - minimumZoom) / (maximumZoom - minimumZoom)))
            let curveBlend = zoomProgress * zoomProgress * (3 - 2 * zoomProgress)
            var maximumDepthError: Float = 0
            for (id, node) in nodes {
                guard let original = basePositions[id] else { continue }
                let visibleX = original.x + contentNode.position.x
                let visibleY = original.y + contentNode.position.y
                let curvedZ = -(visibleX * visibleX + visibleY * visibleY) * curvatureStrength * curveBlend
                let focusOffset: Float
                if let activeItemID {
                    focusOffset = id == activeItemID ? 2 : -0.5
                } else {
                    focusOffset = 0
                }
                let targetDepth = curvedZ + focusOffset
                let depthError = targetDepth - node.position.z
                maximumDepthError = max(maximumDepthError, abs(depthError))
                node.position.z += depthError * positionBlend
            }

            let movementX = contentNode.position.x - oldPosition.x
            let movementY = contentNode.position.y - oldPosition.y
            let tiltScale = min(1, minimumZoom / cameraNode.position.z)
            let tiltX = movementY * Float(tuning.tiltStrength) * tiltScale
            let tiltY = -movementX * Float(tuning.tiltStrength) * tiltScale
            cameraNode.eulerAngles.x += (tiltX - cameraNode.eulerAngles.x) * positionBlend
            cameraNode.eulerAngles.y += (tiltY - cameraNode.eulerAngles.y) * positionBlend

            view.setNeedsDisplay()

            let positionError = max(
                abs(targetPosition.x - contentNode.position.x),
                abs(targetPosition.y - contentNode.position.y)
            )
            let zoomError = abs(targetZoom - cameraNode.position.z)
            let tiltError = max(abs(cameraNode.eulerAngles.x), abs(cameraNode.eulerAngles.y))
            let isSettled = positionError < 0.001
                && zoomError < 0.001
                && tiltError < 0.001
                && maximumDepthError < 0.001
            if !mountedItems,
               pendingItemIDs.isEmpty,
               isSettled,
               CACurrentMediaTime() >= renderUntil {
                displayLink.isPaused = true
            }
        }

        private func visibleHeight(in view: SCNView, zoom: Float) -> Float {
            let fieldOfView = Float(cameraNode.camera?.fieldOfView ?? 45) * .pi / 180
            return 2 * tan(fieldOfView / 2) * zoom
        }

        private func clampTarget(in view: SCNView) {
            let limits = dragLimits(in: view)
            targetPosition.x = min(limits.x, max(-limits.x, targetPosition.x))
            targetPosition.y = min(limits.y, max(-limits.y, targetPosition.y))
        }

        private func dragLimits(in view: SCNView) -> (x: Float, y: Float) {
            let height = visibleHeight(in: view, zoom: targetZoom)
            let width = height * Float(view.bounds.width / max(view.bounds.height, 1))
            return (
                max(0, gridHalfWidth - width / 2 + 2),
                max(0, gridHalfHeight - height / 2 + 2)
            )
        }

        private func resisted(_ value: Float, limit: Float) -> Float {
            let resistedValue: Float
            if value > limit {
                resistedValue = limit + (value - limit) * dragResistance
            } else if value < -limit {
                resistedValue = -limit + (value + limit) * dragResistance
            } else {
                resistedValue = value
            }
            return min(limit + 3, max(-limit - 3, resistedValue))
        }

        private func updateZoomedInState() {
            let newValue = targetZoom <= minimumZoom + 2
            if isZoomedIn.wrappedValue != newValue {
                isZoomedIn.wrappedValue = newValue
            }
        }

    }
}

#Preview {
    AestheticStyleExplorerView(
        styles: AestheticBuildStyle.all,
        onClose: {},
        onOpenStyle: { _ in }
    )
}
