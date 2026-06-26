import SwiftUI
import SceneKit

private enum GuidePage: Equatable {
    case overview
    case componentShowcase
    case components
    case section(GuideSection)
}

struct GuideView: View {
    let onBack: () -> Void

    @State private var availableWidth: CGFloat = UIScreen.main.bounds.width
    @State private var page: GuidePage = .overview

    private var contentWidth: CGFloat {
        AppTheme.responsiveContentWidth(for: availableWidth)
    }

    private var headerTitle: String {
        switch page {
        case .overview:
            return "装机指南"
        case .componentShowcase:
            return "电脑八大件展示"
        case .components:
            return "全部配件"
        case .section(let section):
            return section.title
        }
    }

    var body: some View {
        VStack(spacing: 14) {
            ScreenHeader(title: headerTitle, trailingIcon: nil, onBack: handleBack)
                .padding(.top, 44)

            currentPage
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 18)
        .background(widthReader)
        .animation(.easeInOut(duration: 0.2), value: page)
    }

    @ViewBuilder
    private var currentPage: some View {
        switch page {
        case .overview:
            GuideHomePage(contentWidth: contentWidth, onOpen: openHomeEntry)
                .transition(.opacity)
        case .componentShowcase:
            ComponentIntroPage(
                contentWidth: contentWidth,
                onOpenComponentCatalogue: {
                    page = .components
                }
            )
            .transition(.opacity)
        case .components:
            ComponentCataloguePage(contentWidth: contentWidth)
                .transition(.opacity)
        case .section(let section):
            GuideSectionDetailPage(section: section, contentWidth: contentWidth)
                .transition(.opacity)
        }
    }

    private func handleBack() {
        if page == .overview {
            onBack()
        } else {
            page = .overview
        }
    }

    private func openHomeEntry(_ entry: GuideHomeEntry) {
        if entry.id == "components" {
            page = .componentShowcase
            return
        }

        guard let section = GuideFlow.guideSections.first(where: { $0.id == entry.id }) else {
            return
        }
        page = .section(section)
    }

    private var widthReader: some View {
        GeometryReader { proxy in
            Color.clear
                .onAppear {
                    availableWidth = proxy.size.width
                }
                .onChange(of: proxy.size.width) { _, width in
                    availableWidth = width
                }
        }
    }

}

private struct GuideHomePage: View {
    let contentWidth: CGFloat
    let onOpen: (GuideHomeEntry) -> Void

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                GuideHomeIntro()

                FeaturedGuideHomeCard(entry: GuideFlow.featuredGuideHomeEntry) {
                    onOpen(GuideFlow.featuredGuideHomeEntry)
                }

                GuideHomeListCard(entries: GuideFlow.secondaryGuideHomeEntries, onOpen: onOpen)

                GuideHomeTip()
            }
            .frame(width: contentWidth, alignment: .leading)
            .padding(.top, 8)
            .padding(.bottom, 10)
            .frame(maxWidth: .infinity)
        }
    }
}

private struct GuideHomeIntro: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("你想先了解哪一部分？")
                .font(.system(size: 21, weight: .semibold))
                .foregroundStyle(AppTheme.primaryText)
                .fixedSize(horizontal: false, vertical: true)

            Text("从排查、认识到准备，帮你一步到位完成装机。")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(AppTheme.secondaryText)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct FeaturedGuideHomeCard: View {
    let entry: GuideHomeEntry
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("推荐优先")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(AppTheme.secondaryText)
                        .padding(.horizontal, 9)
                        .frame(height: 24)
                        .background(AppTheme.softSurface, in: RoundedRectangle(cornerRadius: 8))

                    VStack(alignment: .leading, spacing: 7) {
                        Text(entry.title)
                            .font(.system(size: 19, weight: .semibold))
                            .foregroundStyle(AppTheme.primaryText)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(entry.subtitle)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(AppTheme.secondaryText)
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    HStack(spacing: 7) {
                        Text("进入")
                        Image(systemName: "chevron.right")
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.primaryText)
                    .padding(.top, 2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 15)
            .frame(height: 146)
            .background {
                Image("GuideTroubleshootingCardBackground")
                    .resizable()
                    .scaledToFill()
            }
            .clipShape(RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(entry.title)，\(entry.subtitle)")
    }
}

private struct GuideHomeListCard: View {
    let entries: [GuideHomeEntry]
    let onOpen: (GuideHomeEntry) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                GuideHomeListRow(entry: entry) {
                    onOpen(entry)
                }

                if index < entries.count - 1 {
                    Divider()
                        .padding(.leading, 70)
                }
            }
        }
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(AppTheme.border, lineWidth: 1)
        }
    }
}

private struct GuideHomeListRow: View {
    let entry: GuideHomeEntry
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 13) {
                Image(systemName: entry.symbol)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.black)
                    .frame(width: 46, height: 46)
                    .background(AppTheme.softSurface, in: RoundedRectangle(cornerRadius: 14))

                VStack(alignment: .leading, spacing: 5) {
                    Text(entry.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppTheme.primaryText)
                        .lineLimit(2)
                        .minimumScaleFactor(0.86)

                    Text(entry.subtitle)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(AppTheme.secondaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.86)
                }

                Spacer(minLength: 8)

                HStack(spacing: 7) {
                    Text("进入")
                    Image(systemName: "chevron.right")
                }
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AppTheme.primaryText)
            }
            .padding(.horizontal, 14)
            .frame(height: 82)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(entry.title)，\(entry.subtitle)")
    }
}

private struct GuideHomeTip: View {
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "lightbulb")
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(AppTheme.primaryText)
                .frame(width: 28, height: 28)

            Text("建议先从「准备」和「八大件认识」开始，事半功倍。")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AppTheme.secondaryText)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 56)
        .background(AppTheme.softSurface.opacity(0.72), in: RoundedRectangle(cornerRadius: 16))
    }
}

private struct ComponentIntroPage: View {
    let contentWidth: CGFloat
    let onOpenComponentCatalogue: () -> Void

    @State private var selectedComponentID = GuideFlow.componentIntroItems[0].id

    private let pickerSpacing: CGFloat = 16

    private var selectedComponent: GuideComponentIntroItem {
        GuideFlow.componentIntroItems.first { $0.id == selectedComponentID } ?? GuideFlow.componentIntroItems[0]
    }

    var body: some View {
        VStack(spacing: 14) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .center, spacing: 14) {
                    introHero
                    componentPicker
                    ComponentIntroFeatureCard(item: selectedComponent, contentWidth: contentWidth)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 8)
                .padding(.bottom, 6)
            }

            componentActions
        }
    }

    private var componentPicker: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                pickerRow
            }
            .onChange(of: selectedComponentID) { _, componentID in
                withAnimation(.easeInOut(duration: 0.2)) {
                    proxy.scrollTo(componentID, anchor: .center)
                }
            }
        }
        .frame(width: contentWidth, height: 82)
    }

    private var pickerRow: some View {
        HStack(spacing: pickerSpacing) {
            ForEach(GuideFlow.componentIntroItems) { item in
                ComponentIntroPickerCard(
                    item: item,
                    isSelected: item.id == selectedComponentID
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedComponentID = item.id
                    }
                }
                .id(item.id)
            }
        }
        .padding(.horizontal, 2)
    }

    private var introHero: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("先认识这些配件")
                .font(.system(size: 26, weight: .black))
                .foregroundStyle(AppTheme.primaryText)
                .fixedSize(horizontal: false, vertical: true)

            Text("了解常见配件的外观和作用，为接下来的装机步骤打好基础。")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(AppTheme.secondaryText)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(width: contentWidth, alignment: .leading)
    }

    private var componentActions: some View {
        HStack(spacing: 12) {
            Button {
                onOpenComponentCatalogue()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "square.grid.2x2")
                    Text("查看全部配件")
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppTheme.primaryText)
                .frame(maxWidth: .infinity)
                .frame(height: 42)
                .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: AppTheme.controlRadius))
                .overlay {
                    RoundedRectangle(cornerRadius: AppTheme.controlRadius)
                        .stroke(AppTheme.border, lineWidth: 1)
                }
            }
            .buttonStyle(.plain)
        }
        .frame(width: contentWidth)
    }
}

private struct GuideSectionDetailPage: View {
    let section: GuideSection
    let contentWidth: CGFloat

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                GuideDetailHero(section: section)

                VStack(spacing: 10) {
                    ForEach(Array(section.items.enumerated()), id: \.element.id) { index, item in
                        GuideDetailItemRow(index: index + 1, item: item)
                    }
                }

                GuideDetailNote(section: section)
            }
            .frame(width: contentWidth, alignment: .leading)
            .padding(.top, 8)
            .padding(.bottom, 10)
            .frame(maxWidth: .infinity)
        }
    }
}

private struct GuideDetailHero: View {
    let section: GuideSection

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 13) {
                Image(systemName: section.symbol)
                    .font(.system(size: 24, weight: .black))
                    .foregroundStyle(.white)
                    .frame(width: 58, height: 58)
                    .background(AppTheme.primaryText, in: RoundedRectangle(cornerRadius: 18))

                VStack(alignment: .leading, spacing: 6) {
                    Text(section.badge)
                        .font(.system(size: 10, weight: .black))
                        .foregroundStyle(AppTheme.primaryText)
                        .padding(.horizontal, 8)
                        .frame(height: 22)
                        .background(AppTheme.softSurface, in: Capsule())

                    Text(section.title)
                        .font(.system(size: 24, weight: .black))
                        .foregroundStyle(AppTheme.primaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Text(section.subtitle)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AppTheme.secondaryText)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 20))
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .stroke(AppTheme.border, lineWidth: 1)
        }
    }
}

private struct GuideDetailItemRow: View {
    let index: Int
    let item: GuideSectionItem

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                Image(systemName: item.symbol)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(AppTheme.primaryText)
                    .frame(width: 42, height: 42)
                    .background(AppTheme.softSurface, in: RoundedRectangle(cornerRadius: 13))

                Text("\(index)")
                    .font(.system(size: 9, weight: .black))
                    .foregroundStyle(.white)
                    .frame(width: 17, height: 17)
                    .background(AppTheme.primaryText, in: Circle())
                    .offset(x: 4, y: 4)
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(item.title)
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(AppTheme.primaryText)

                Text(item.text)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppTheme.secondaryText)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(AppTheme.border, lineWidth: 1)
        }
    }
}

private struct GuideDetailNote: View {
    let section: GuideSection

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "sparkles")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(AppTheme.warning)
                .frame(width: 28, height: 28)
                .background(AppTheme.warning.opacity(0.14), in: RoundedRectangle(cornerRadius: 9))

            VStack(alignment: .leading, spacing: 4) {
                Text("内容占位中")
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(AppTheme.primaryText)

                Text("这里先放了可读的示例内容，后续可以继续补充更完整的 \(section.title) 流程。")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AppTheme.secondaryText)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .background(AppTheme.softSurface, in: RoundedRectangle(cornerRadius: 16))
    }
}

private struct ComponentCataloguePage: View {
    let contentWidth: CGFloat

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("八大件速览")
                        .font(.system(size: 24, weight: .black))
                        .foregroundStyle(AppTheme.primaryText)

                    Text("先记住它们长什么样、负责什么、装在哪里。后续步骤就不会像在认亲。")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppTheme.secondaryText)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 8)

                LazyVStack(spacing: 10) {
                    ForEach(GuideFlow.componentIntroItems) { item in
                        ComponentCatalogueRow(item: item)
                    }
                }
            }
            .frame(width: contentWidth, alignment: .leading)
            .padding(.bottom, 10)
            .frame(maxWidth: .infinity)
        }
    }
}

private struct ComponentCatalogueRow: View {
    let item: GuideComponentIntroItem

    var body: some View {
        HStack(spacing: 12) {
            Image(item.imageName)
                .resizable()
                .scaledToFit()
                .frame(width: 48, height: 48)
                .background(AppTheme.softSurface, in: RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text(item.title)
                        .font(.system(size: 15, weight: .black))
                        .foregroundStyle(AppTheme.primaryText)

                    Text(item.subtitle)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(AppTheme.secondaryText)
                        .lineLimit(1)
                }

                Text(item.detailPoints.map(\.text).joined(separator: " "))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AppTheme.secondaryText)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(AppTheme.border, lineWidth: 1)
        }
    }
}

private struct ComponentIntroPickerCard: View {
    let item: GuideComponentIntroItem
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(item.imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 50, height: 46)

                Text(item.title)
                    .font(.system(size: 12, weight: isSelected ? .bold : .semibold))
                    .foregroundStyle(isSelected ? AppTheme.primaryText : AppTheme.secondaryText)

                Capsule()
                    .fill(isSelected ? AppTheme.primaryText : .clear)
                    .frame(width: 22, height: 3)
            }
            .frame(width: 58, height: 80)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.title)，\(item.subtitle)")
    }
}

private struct ComponentIntroFeatureCard: View {
    let item: GuideComponentIntroItem
    let contentWidth: CGFloat

    private var componentDescription: String {
        "\(item.subtitle)。\(item.detailPoints[0].text)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(item.title)
                .font(.system(size: 20, weight: .black))
                .foregroundStyle(AppTheme.primaryText)

            Text(componentDescription)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(AppTheme.secondaryText)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 220, alignment: .leading)

            ComponentIntroModelStage(item: item, contentWidth: contentWidth)
        }
        .frame(width: contentWidth, alignment: .leading)
        .animation(.easeInOut(duration: 0.22), value: item.id)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.title)，\(item.subtitle)")
    }
}

private struct ComponentIntroModelStage: View {
    let item: GuideComponentIntroItem
    let contentWidth: CGFloat

    var body: some View {
        ZStack {
            Ellipse()
                .stroke(AppTheme.border.opacity(0.55), lineWidth: 1)
                .frame(width: contentWidth - 6, height: 148)

            Ellipse()
                .stroke(AppTheme.border.opacity(0.36), lineWidth: 1)
                .frame(width: contentWidth - 60, height: 104)

            if let modelName = item.modelName,
               Bundle.main.url(forResource: modelName, withExtension: "usdc") != nil {
                ComponentModelSceneView(modelName: modelName)
                    .frame(width: contentWidth + 28, height: 420)
                    .id(modelName)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            } else {
                Image(item.imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: contentWidth - 52, height: 384)
                    .shadow(color: Color.black.opacity(0.13), radius: 16, x: 0, y: 14)
                    .id(item.id)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
        }
        .frame(width: contentWidth, height: 432)
        .accessibilityLabel("\(item.title) 配件展示")
    }
}

private struct ComponentModelSceneView: UIViewRepresentable {
    let modelName: String

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView(frame: .zero)
        view.backgroundColor = .clear
        let scene = ComponentModelSceneFactory.makeScene(modelName: modelName)
        view.scene = scene
        view.pointOfView = scene.rootNode.childNode(withName: "component-camera", recursively: true)
        view.allowsCameraControl = true
        view.autoenablesDefaultLighting = false
        view.preferredFramesPerSecond = 30
        view.antialiasingMode = .multisampling4X
        view.defaultCameraController.inertiaEnabled = true
        view.defaultCameraController.minimumVerticalAngle = -70
        view.defaultCameraController.maximumVerticalAngle = 70
        return view
    }

    func updateUIView(_ view: SCNView, context: Context) {
        guard view.scene?.rootNode.childNode(withName: modelName, recursively: true) == nil else {
            return
        }
        let scene = ComponentModelSceneFactory.makeScene(modelName: modelName)
        view.scene = scene
        view.pointOfView = scene.rootNode.childNode(withName: "component-camera", recursively: true)
    }
}

private enum ComponentModelSceneFactory {
    static func makeScene(modelName: String) -> SCNScene {
        let scene = SCNScene()
        scene.background.contents = UIColor.clear

        let modelRoot = SCNNode()
        modelRoot.name = modelName

        if let url = Bundle.main.url(forResource: modelName, withExtension: "usdc"),
           let sourceScene = try? SCNScene(url: url, options: nil) {
            sourceScene.rootNode.childNodes.forEach {
                modelRoot.addChildNode($0.clone())
            }
            applyModelOverrides(to: modelRoot, modelName: modelName)
            normalize(modelRoot, modelName: modelName)
        }

        scene.rootNode.addChildNode(modelRoot)
        installCamera(in: scene, modelName: modelName)
        installLighting(in: scene, modelName: modelName)
        return scene
    }

    private static func applyModelOverrides(to node: SCNNode, modelName: String) {
        guard modelName == "desktop-cpu-mobile" else { return }

        let ihsMaterial = SCNMaterial()
        ihsMaterial.name = "CPU_IHS_Bright_Brushed_Metal"
        ihsMaterial.lightingModel = .physicallyBased
        ihsMaterial.diffuse.contents = UIColor(red: 0.56, green: 0.58, blue: 0.57, alpha: 1)
        ihsMaterial.metalness.contents = 0.92
        ihsMaterial.roughness.contents = 0.32
        ihsMaterial.specular.contents = UIColor.white
        ihsMaterial.transparency = 1
        ihsMaterial.transparencyMode = .aOne
        ihsMaterial.blendMode = .replace
        ihsMaterial.isDoubleSided = true
        ihsMaterial.writesToDepthBuffer = true
        ihsMaterial.readsFromDepthBuffer = true
        ihsMaterial.fresnelExponent = 0.9

        node.enumerateChildNodes { child, _ in
            if child.name?.contains("Brushed_Highlight") == true {
                child.isHidden = true
                return
            }
            guard child.name?.contains("IHS") == true else { return }
            child.geometry?.materials = [ihsMaterial]
        }
    }

    private static func normalize(_ node: SCNNode, modelName: String) {
        let (minimum, maximum) = node.boundingBox
        let width = maximum.x - minimum.x
        let height = maximum.y - minimum.y
        let depth = maximum.z - minimum.z
        let longestSide = max(width, height, depth)
        guard longestSide > 0 else { return }

        let targetLongestSide: Float
        if modelName == "modern-atx-motherboard-mobile" {
            targetLongestSide = 3.75
        } else if modelName == "tower-cpu-air-cooler-mobile" {
            targetLongestSide = 3.45
        } else {
            targetLongestSide = 4.05
        }
        let scale = targetLongestSide / longestSide
        node.scale = SCNVector3(scale, scale, scale)
        node.position = SCNVector3(
            -(minimum.x + maximum.x) * 0.5 * scale,
            -(minimum.y + maximum.y) * 0.5 * scale,
            -(minimum.z + maximum.z) * 0.5 * scale
        )
        if modelName == "desktop-dimm-ram-mobile" {
            node.position.x += 0.26
        } else if modelName == "tower-cpu-air-cooler-mobile" {
            node.position.x += 0.38
            node.position.y -= 0.18
        }
        if modelName == "modern-atx-motherboard-mobile" {
            node.eulerAngles = SCNVector3(-0.34, -0.46, 0.07)
        } else if modelName == "desktop-dimm-ram-mobile" {
            node.eulerAngles = SCNVector3(-0.28, -0.34, 0.1)
        } else if modelName == "m2-2280-nvme-ssd-mobile" {
            node.eulerAngles = SCNVector3(-0.22, -0.38, 0.08)
        } else if modelName == "atx-psu-mobile" {
            node.eulerAngles = SCNVector3(-0.28, -0.58, 0.06)
        } else if modelName == "tower-cpu-air-cooler-mobile" {
            node.eulerAngles = SCNVector3(-0.16, -0.34, 0.02)
        } else {
            node.eulerAngles = SCNVector3(-0.14, -0.42, 0)
        }
    }

    private static func installCamera(in scene: SCNScene, modelName: String) {
        let cameraNode = SCNNode()
        cameraNode.name = "component-camera"
        let camera = SCNCamera()
        camera.fieldOfView = 34
        camera.zNear = 0.1
        camera.zFar = 100
        cameraNode.camera = camera
        let cameraDistance: Float
        switch modelName {
        case "desktop-cpu-mobile":
            cameraDistance = 11.4
        case "modern-atx-motherboard-mobile":
            cameraDistance = 9.0
        case "desktop-dimm-ram-mobile":
            cameraDistance = 8.2
        case "m2-2280-nvme-ssd-mobile":
            cameraDistance = 8.4
        case "atx-psu-mobile":
            cameraDistance = 10.0
        case "tower-cpu-air-cooler-mobile":
            cameraDistance = 10.2
        default:
            cameraDistance = 7.7
        }
        cameraNode.position = SCNVector3(0, 0, cameraDistance)
        scene.rootNode.addChildNode(cameraNode)
    }

    private static func installLighting(in scene: SCNScene, modelName: String) {
        let isCPU = modelName == "desktop-cpu-mobile"
        let isBoard = modelName == "modern-atx-motherboard-mobile"
        let isSSD = modelName == "m2-2280-nvme-ssd-mobile"
        scene.lightingEnvironment.contents = UIColor(white: isCPU || isBoard || isSSD ? 1.0 : 0.9, alpha: 1)
        scene.lightingEnvironment.intensity = isCPU ? 1.08 : (isBoard ? 0.9 : (isSSD ? 1.0 : 0.8))

        addLight(
            to: scene,
            type: .directional,
            intensity: isCPU ? 1_280 : (isBoard ? 880 : (isSSD ? 1_220 : 1_100)),
            color: UIColor.white,
            eulerAngles: isBoard ? SCNVector3(-0.95, 0.75, 0.15) : (isSSD ? SCNVector3(-0.62, 0.42, 0.08) : SCNVector3(-0.7, 0.55, 0))
        )
        addLight(
            to: scene,
            type: .directional,
            intensity: isBoard ? 360 : (isSSD ? 640 : 520),
            color: UIColor(red: 0.75, green: 0.84, blue: 1, alpha: 1),
            eulerAngles: SCNVector3(0.35, -1.9, 0)
        )
        addLight(
            to: scene,
            type: .ambient,
            intensity: isBoard ? 320 : (isSSD ? 420 : 260),
            color: UIColor(white: 0.72, alpha: 1),
            eulerAngles: SCNVector3(0, 0, 0)
        )
        if isSSD {
            addLight(
                to: scene,
                type: .directional,
                intensity: 360,
                color: UIColor(white: 0.95, alpha: 1),
                eulerAngles: SCNVector3(0.05, 0.05, 0)
            )
            addLight(
                to: scene,
                type: .directional,
                intensity: 220,
                color: UIColor(red: 0.82, green: 0.88, blue: 1, alpha: 1),
                eulerAngles: SCNVector3(-0.1, 2.35, 0)
            )
            return
        }
        if isBoard {
            addLight(
                to: scene,
                type: .directional,
                intensity: 260,
                color: UIColor(white: 0.94, alpha: 1),
                eulerAngles: SCNVector3(0, 0, 0)
            )
            return
        }
        guard isCPU else { return }

        addLight(
            to: scene,
            type: .omni,
            intensity: 520,
            color: UIColor(white: 1, alpha: 1),
            eulerAngles: SCNVector3(-0.35, -0.35, 0)
        )
    }

    private static func addLight(
        to scene: SCNScene,
        type: SCNLight.LightType,
        intensity: CGFloat,
        color: UIColor,
        eulerAngles: SCNVector3
    ) {
        let node = SCNNode()
        let light = SCNLight()
        light.type = type
        light.intensity = intensity
        light.color = color
        node.light = light
        node.eulerAngles = eulerAngles
        scene.rootNode.addChildNode(node)
    }
}

#Preview {
    GuideView(onBack: {})
}
