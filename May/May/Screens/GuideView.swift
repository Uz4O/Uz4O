import SwiftUI
import SceneKit

struct GuideView: View {
    let onBack: () -> Void

    @State private var flow = GuideFlow()
    @State private var availableWidth: CGFloat = UIScreen.main.bounds.width

    private let canvasWidth: CGFloat = 276
    private var contentWidth: CGFloat {
        AppTheme.responsiveContentWidth(for: availableWidth)
    }

    var body: some View {
        VStack(spacing: 14) {
            ScreenHeader(title: "装机指南", trailingIcon: nil, onBack: handleBack)
                .padding(.top, 44)

            if flow.isShowingComponentIntro {
                ComponentIntroPage(flow: $flow, contentWidth: contentWidth)
            } else {
                stepHeader
                    .frame(width: contentWidth)

                ProgressTrack(flow: $flow)
                    .frame(width: contentWidth)

                AssemblyStage(step: flow.currentStep, canvasWidth: max(canvasWidth, min(contentWidth - 28, 320)))
                    .frame(maxWidth: .infinity)

                Spacer(minLength: 0)

                bottomControls
                    .frame(width: contentWidth)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 18)
        .background(widthReader)
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

    private var stepHeader: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 5) {
                Text(String(format: "%02d / %02d", flow.currentStep.number, GuideFlow.steps.count))
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(AppTheme.secondaryText)

                Text(flow.currentStep.title)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(AppTheme.primaryText)
            }

            Spacer()

            Text(flow.currentStep.summary)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AppTheme.secondaryText)
                .lineLimit(2)
                .multilineTextAlignment(.trailing)
                .frame(width: 116, alignment: .trailing)
        }
    }

    private func handleBack() {
        guard !flow.isShowingComponentIntro else {
            onBack()
            return
        }

        withAnimation(.easeInOut(duration: 0.22)) {
            flow.showComponentIntro()
        }
    }

    private var bottomControls: some View {
        HStack(spacing: 12) {
            Button {
                withAnimation(.easeInOut(duration: 0.22)) {
                    flow.goPrevious()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "chevron.left")
                    Text("上一步")
                }
                .font(.appSubheadline)
                .foregroundStyle(flow.canGoPrevious ? AppTheme.primaryText : AppTheme.secondaryText)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: AppTheme.controlRadius))
                .overlay {
                    RoundedRectangle(cornerRadius: AppTheme.controlRadius)
                        .stroke(AppTheme.border, lineWidth: 1)
                }
            }
            .buttonStyle(.plain)
            .disabled(!flow.canGoPrevious)

            Button {
                withAnimation(.easeInOut(duration: 0.22)) {
                    flow.goNext()
                }
            } label: {
                HStack(spacing: 8) {
                    Text(flow.canGoNext ? "下一步" : "已到最后")
                    Image(systemName: flow.canGoNext ? "chevron.right" : "checkmark")
                }
                .font(.appSubheadline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(AppTheme.primaryButton, in: RoundedRectangle(cornerRadius: AppTheme.controlRadius))
            }
            .buttonStyle(.plain)
            .disabled(!flow.canGoNext)
        }
    }
}

private struct ComponentIntroPage: View {
    @Binding var flow: GuideFlow
    let contentWidth: CGFloat
    @State private var isShowingAllComponents = false
    @State private var isShowingAssemblyInstructions = false
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

            bottomActions
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

    private var bottomActions: some View {
        HStack(spacing: 12) {
            Button {
                isShowingAllComponents = true
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
            .sheet(isPresented: $isShowingAllComponents) {
                ComponentIntroDetailSheet()
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }

            Button {
                isShowingAssemblyInstructions = true
            } label: {
                HStack(spacing: 8) {
                    Text("开始正式装机")
                    Image(systemName: "chevron.right")
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 42)
                .background(AppTheme.primaryButton, in: RoundedRectangle(cornerRadius: AppTheme.controlRadius))
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $isShowingAssemblyInstructions) {
                AssemblyInstructionSheet {
                    isShowingAssemblyInstructions = false
                    withAnimation(.easeInOut(duration: 0.22)) {
                        flow.startAssembly()
                    }
                }
                .presentationDetents([.height(300)])
                .presentationBackground(.white)
                .presentationDragIndicator(.visible)
            }
        }
        .frame(width: contentWidth)
    }
}

private struct AssemblyInstructionSheet: View {
    let onStart: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: "hand.tap.fill")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(AppTheme.primaryButton, in: Circle())

                VStack(alignment: .leading, spacing: 5) {
                    Text("正式装机教程说明")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(AppTheme.primaryText)

                    Text("每个 3D 教学步骤都需要你手动推进")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(AppTheme.secondaryText)
                }
            }
            .padding(.top, 2)

            VStack(alignment: .leading, spacing: 14) {
                instructionRow(symbol: "1.circle.fill", text: "点击 3D 画面，会播放当前步骤的一小段动画。")
                instructionRow(symbol: "pause.circle.fill", text: "动画播完会停住，方便你看清动作和配件位置。")
                instructionRow(symbol: "hand.tap.fill", text: "再次点击画面，会进入下一小段动画。")
            }
            .padding(.top, 2)

            Button(action: onStart) {
                HStack(spacing: 8) {
                    Text("知道了，开始装机")
                    Image(systemName: "chevron.right")
                }
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .background(AppTheme.primaryButton, in: RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
        .padding(.top, 22)
        .padding(.bottom, 18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.white.ignoresSafeArea())
    }

    private func instructionRow(symbol: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(AppTheme.primaryText)
                .frame(width: 18)
                .padding(.top, 1)

            Text(text)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppTheme.primaryText)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct ComponentIntroDetailSheet: View {
    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(GuideFlow.componentIntroItems) { item in
                        HStack(spacing: 12) {
                            Image(item.imageName)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 44, height: 44)
                                .background(AppTheme.softSurface, in: RoundedRectangle(cornerRadius: 10))

                            VStack(alignment: .leading, spacing: 3) {
                                Text(item.title)
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundStyle(AppTheme.primaryText)

                                Text(item.subtitle)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(AppTheme.secondaryText)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                } footer: {
                    Text("正式装机时会按步骤高亮当前要安装或连接的配件。")
                }
            }
            .navigationTitle("全部配件")
            .navigationBarTitleDisplayMode(.inline)
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

private struct ProgressTrack: View {
    @Binding var flow: GuideFlow

    var body: some View {
        VStack(spacing: 10) {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(AppTheme.border)
                        .frame(height: 3)
                        .padding(.horizontal, 11)

                    Capsule()
                        .fill(AppTheme.primaryText)
                        .frame(width: trackFillWidth(totalWidth: proxy.size.width), height: 3)
                        .padding(.leading, 11)

                    HStack(spacing: 0) {
                        ForEach(Array(GuideFlow.steps.enumerated()), id: \.element.id) { index, step in
                            Button {
                                withAnimation(.easeInOut(duration: 0.22)) {
                                    flow.jump(to: index)
                                }
                            } label: {
                                TrackNode(
                                    number: step.number,
                                    isPast: index < flow.currentIndex,
                                    isCurrent: index == flow.currentIndex
                                )
                            }
                            .buttonStyle(.plain)
                            .frame(maxWidth: .infinity)
                            .accessibilityLabel("跳转到第 \(step.number) 步，\(step.title)")
                        }
                    }
                }
            }
            .frame(height: 34)

            HStack(spacing: 8) {
                Text("当前步骤")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(AppTheme.secondaryText)

                Text(flow.currentStep.title)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(AppTheme.primaryText)

                Spacer()

                Text("\(Int((flow.progressFraction * 100).rounded()))%")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(AppTheme.secondaryText)
            }
        }
        .padding(.horizontal, 2)
    }

    private func trackFillWidth(totalWidth: CGFloat) -> CGFloat {
        let availableWidth = max(totalWidth - 22, 0)
        return availableWidth * CGFloat(flow.progressFraction)
    }
}

private struct TrackNode: View {
    let number: Int
    let isPast: Bool
    let isCurrent: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(backgroundColor)
                .frame(width: isCurrent ? 23 : 14, height: isCurrent ? 23 : 14)
                .shadow(color: isCurrent ? AppTheme.primaryText.opacity(0.20) : .clear, radius: 8, x: 0, y: 4)

            Circle()
                .stroke(borderColor, lineWidth: isCurrent ? 2 : 1)
                .frame(width: isCurrent ? 23 : 14, height: isCurrent ? 23 : 14)

            if isCurrent {
                Text(String(format: "%02d", number))
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.white)
            } else if isPast {
                Circle()
                    .fill(.white)
                    .frame(width: 4, height: 4)
            }
        }
        .frame(height: 34)
    }

    private var backgroundColor: Color {
        if isCurrent { return AppTheme.primaryText }
        if isPast { return AppTheme.primaryText }
        return AppTheme.surface
    }

    private var borderColor: Color {
        if isCurrent || isPast { return AppTheme.primaryText }
        return AppTheme.border
    }
}

private struct AssemblyStage: View {
    let step: GuideStepContent
    let canvasWidth: CGFloat
    private let pseudo3DStageHeight: CGFloat = 470

    var body: some View {
        if step.id == "cpu" {
            cpuAssemblyStage
                .frame(maxWidth: .infinity)
        } else if step.id == "memory" {
            memoryAssemblyStage
                .frame(maxWidth: .infinity)
        } else if step.id == "ssd" {
            ssdAssemblyStage
                .frame(maxWidth: .infinity)
        } else {
            defaultAssemblyStage
        }
    }

    private var defaultAssemblyStage: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 24)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.92, green: 0.95, blue: 0.96),
                            Color(red: 0.80, green: 0.85, blue: 0.88)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color.white.opacity(0.9), lineWidth: 1)
                }

            HardwareAnimationMock(step: step)
                .padding(.top, 114)
                .frame(maxWidth: .infinity, alignment: .center)

            StepOverlayCard(step: step)
                .padding(14)
        }
        .frame(width: canvasWidth, height: 438)
        .shadow(color: Color.black.opacity(0.08), radius: 24, x: 0, y: 14)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(step.title)，\(step.action)，注意：\(step.caution)")
    }

    private var cpuAssemblyStage: some View {
        GeometryReader { proxy in
            let stageWidth = max(proxy.size.width, canvasWidth)
            VStack(alignment: .leading, spacing: 8) {
                CPUInstallPseudo3DStage(stageWidth: stageWidth, caution: step.caution)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(.top, 0)
        }
        .frame(height: pseudo3DStageHeight)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(step.title)，\(step.action)，注意：\(step.caution)")
    }

    private var memoryAssemblyStage: some View {
        GeometryReader { proxy in
            let stageWidth = max(proxy.size.width, canvasWidth)
            VStack(alignment: .leading, spacing: 8) {
                MemoryInstallPseudo3DStage(stageWidth: stageWidth, caution: step.caution)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(.top, 0)
        }
        .frame(height: pseudo3DStageHeight)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(step.title)，\(step.action)，注意：\(step.caution)")
    }

    private var ssdAssemblyStage: some View {
        GeometryReader { proxy in
            let stageWidth = max(proxy.size.width, canvasWidth)
            VStack(alignment: .leading, spacing: 8) {
                SSDInstallPseudo3DStage(stageWidth: stageWidth, caution: step.caution)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(.top, 0)
        }
        .frame(height: pseudo3DStageHeight)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(step.title)，\(step.action)，注意：\(step.caution)")
    }
}

private struct StepOverlayCard: View {
    let step: GuideStepContent

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 7) {
                Text(String(format: "%02d", step.number))
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 24, height: 24)
                    .background(AppTheme.primaryText, in: Circle())

                Text(step.title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(AppTheme.primaryText)
            }

            Text(step.action)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AppTheme.primaryText)
                .fixedSize(horizontal: false, vertical: true)

            HStack(alignment: .top, spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(AppTheme.warning)
                Text(step.caution)
                    .font(.system(size: 10))
                    .foregroundStyle(AppTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .frame(width: 218, alignment: .leading)
        .background(.white.opacity(0.92), in: RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(.white, lineWidth: 1)
        }
    }
}

private struct HardwareAnimationMock: View {
    let step: GuideStepContent

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(red: 0.14, green: 0.17, blue: 0.20))
                .frame(width: 208, height: 232)
                .overlay {
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color.white.opacity(0.18), lineWidth: 1)
                }

            VStack(spacing: 12) {
                HStack(spacing: 14) {
                    ChipBlock(width: 72, height: 58)
                    ChipBlock(width: 46, height: 58)
                }

                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.14))
                        .frame(width: 102, height: 82)
                    Image(systemName: step.symbol)
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(.white)
                        .symbolEffect(.pulse, options: .repeating.speed(0.8), value: step.id)
                }

                VStack(spacing: 7) {
                    ForEach(0..<4) { index in
                        Capsule()
                            .fill(index == step.number % 4 ? Color.white.opacity(0.75) : Color.white.opacity(0.24))
                            .frame(width: 148, height: 7)
                    }
                }
            }

            MovingPart(step: step)
                .offset(x: 64, y: -94)
        }
    }
}

private struct TutorialSceneChrome<Scene: View>: View {
    let phase: CPUInstallPhase
    let phaseIndex: Int
    let width: CGFloat
    let height: CGFloat
    let sceneOffsetY: CGFloat
    let caution: String
    @ViewBuilder let scene: () -> Scene

    var body: some View {
        ZStack(alignment: .topLeading) {
            scene()
                .frame(width: width, height: height)
                .offset(x: 12, y: sceneOffsetY)
                .shadow(color: Color.black.opacity(0.12), radius: 16, x: 0, y: 12)

            VStack(alignment: .leading, spacing: 4) {
                Text(phase.title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(AppTheme.primaryText)
                Text(phase.subtitle)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(AppTheme.primaryText)

                if !caution.isEmpty {
                    Text(caution)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(AppTheme.primaryText)
                        .padding(.top, 2)
                }
            }
            .frame(width: 178, alignment: .leading)
            .padding(.leading, 18)
            .padding(.top, 14)
        }
        .frame(width: width, height: height + sceneOffsetY)
        .clipped()
    }
}

private struct TutorialPhaseProgress: View {
    let phaseIndex: Int
    let phaseCount: Int
    let localProgress: Double

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<phaseCount, id: \.self) { index in
                Capsule()
                    .fill(index == phaseIndex ? AppTheme.primaryText : AppTheme.border)
                    .frame(width: index == phaseIndex ? 32 : 14, height: 3)
                    .opacity(index == phaseIndex ? 0.9 + 0.1 * localProgress : 1)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.white, in: RoundedRectangle(cornerRadius: 13))
        .overlay {
            RoundedRectangle(cornerRadius: 13)
                .stroke(Color.black.opacity(0.04), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 4)
    }
}

private struct CPUInstallPseudo3DStage: View {
    let stageWidth: CGFloat
    let caution: String
    @State private var phaseIndex = 0
    @State private var phaseStartDate: Date?
    @State private var completedProgress: Double = 0
    @State private var isResettingLoop = false
    private let stepDuration: TimeInterval = 1.15

    private var sceneWidth: CGFloat {
        min(max(stageWidth, 300), 346)
    }

    private var sceneHeight: CGFloat {
        min(sceneWidth * 0.80, 276)
    }

    private let sceneOffsetY: CGFloat = 72

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            let localProgress = currentProgress(at: timeline.date)
            let visiblePhaseIndex = min(phaseIndex, GuideFlow.cpuInstallPhases.count - 1)
            let phase = GuideFlow.cpuInstallPhases[visiblePhaseIndex]
            let scenePhaseIndex = isResettingLoop ? GuideFlow.cpuInstallResetScenePhaseIndex : phaseIndex

            VStack(spacing: 30) {
                TutorialSceneChrome(
                    phase: phase,
                    phaseIndex: visiblePhaseIndex,
                    width: sceneWidth,
                    height: sceneHeight,
                    sceneOffsetY: sceneOffsetY,
                    caution: caution
                ) {
                    CPUInstallSceneView(phaseIndex: scenePhaseIndex, localProgress: localProgress)
                }

                TutorialPhaseProgress(
                    phaseIndex: visiblePhaseIndex,
                    phaseCount: GuideFlow.cpuInstallPhases.count,
                    localProgress: localProgress
                )
            }
            .frame(width: sceneWidth, height: sceneHeight + sceneOffsetY + 70)
            .contentShape(Rectangle())
            .onTapGesture {
                advancePhase()
            }
            .onChange(of: localProgress) { _, progress in
                if phaseStartDate != nil, progress >= 1 {
                    phaseStartDate = nil
                    if isResettingLoop {
                        isResettingLoop = false
                        phaseIndex = 0
                        completedProgress = 0
                    } else {
                        completedProgress = 1
                    }
                }
            }
        }
    }

    private func currentProgress(at date: Date) -> Double {
        guard let phaseStartDate else {
            return completedProgress
        }

        let raw = min(max(date.timeIntervalSince(phaseStartDate) / stepDuration, 0), 1)
        return raw * raw * (3 - 2 * raw)
    }

    private func advancePhase() {
        guard phaseStartDate == nil else { return }

        if completedProgress >= 1 {
            if isResettingLoop {
                isResettingLoop = false
                phaseIndex = 0
            } else if phaseIndex == GuideFlow.cpuInstallPhases.count - 1 {
                isResettingLoop = true
            } else {
                phaseIndex += 1
            }
            completedProgress = 0
        }

        phaseStartDate = Date()
    }
}

private struct CPUInstallSceneView: UIViewRepresentable {
    let phaseIndex: Int
    let localProgress: Double

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView(frame: .zero)
        view.backgroundColor = .clear
        view.scene = CPUInstallSceneFactory.makeScene()
        view.allowsCameraControl = false
        view.autoenablesDefaultLighting = false
        view.isUserInteractionEnabled = false
        view.preferredFramesPerSecond = 30
        view.antialiasingMode = .multisampling4X
        return view
    }

    func updateUIView(_ view: SCNView, context: Context) {
        CPUInstallSceneFactory.updateScene(view.scene, phaseIndex: phaseIndex, localProgress: localProgress)
    }
}

private struct MemoryInstallPseudo3DStage: View {
    let stageWidth: CGFloat
    let caution: String
    @State private var phaseIndex = 0
    @State private var phaseStartDate: Date?
    @State private var completedProgress: Double = 0
    @State private var isResettingLoop = false
    private let stepDuration: TimeInterval = 1.15

    private var sceneWidth: CGFloat {
        min(max(stageWidth, 300), 346)
    }

    private var sceneHeight: CGFloat {
        min(sceneWidth * 0.80, 276)
    }

    private let sceneOffsetY: CGFloat = 72

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            let localProgress = currentProgress(at: timeline.date)
            let visiblePhaseIndex = min(phaseIndex, GuideFlow.memoryInstallPhases.count - 1)
            let phase = GuideFlow.memoryInstallPhases[visiblePhaseIndex]
            let scenePhaseIndex = isResettingLoop ? GuideFlow.memoryInstallPhases.count : phaseIndex

            VStack(spacing: 34) {
                TutorialSceneChrome(
                    phase: phase,
                    phaseIndex: visiblePhaseIndex,
                    width: sceneWidth,
                    height: sceneHeight,
                    sceneOffsetY: sceneOffsetY,
                    caution: caution
                ) {
                    MemoryInstallSceneView(phaseIndex: scenePhaseIndex, localProgress: localProgress)
                }

                TutorialPhaseProgress(
                    phaseIndex: visiblePhaseIndex,
                    phaseCount: GuideFlow.memoryInstallPhases.count,
                    localProgress: localProgress
                )
            }
            .frame(width: sceneWidth, height: sceneHeight + sceneOffsetY + 78)
            .contentShape(Rectangle())
            .onTapGesture {
                advancePhase()
            }
            .onChange(of: localProgress) { _, progress in
                if phaseStartDate != nil, progress >= 1 {
                    phaseStartDate = nil
                    completedProgress = 1
                }
            }
        }
    }

    private func currentProgress(at date: Date) -> Double {
        guard let phaseStartDate else {
            return completedProgress
        }

        let raw = min(max(date.timeIntervalSince(phaseStartDate) / stepDuration, 0), 1)
        return raw * raw * (3 - 2 * raw)
    }

    private func advancePhase() {
        guard phaseStartDate == nil else { return }

        if completedProgress >= 1 {
            if isResettingLoop {
                isResettingLoop = false
                phaseIndex = 0
            } else if phaseIndex == GuideFlow.memoryInstallPhases.count - 1 {
                isResettingLoop = true
            } else {
                phaseIndex += 1
            }
            completedProgress = 0
        }

        phaseStartDate = Date()
    }
}

private struct MemoryInstallSceneView: UIViewRepresentable {
    let phaseIndex: Int
    let localProgress: Double

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView(frame: .zero)
        view.backgroundColor = .clear
        view.scene = MemoryInstallSceneFactory.makeScene()
        view.allowsCameraControl = false
        view.autoenablesDefaultLighting = false
        view.isUserInteractionEnabled = false
        view.preferredFramesPerSecond = 30
        view.antialiasingMode = .multisampling4X
        return view
    }

    func updateUIView(_ view: SCNView, context: Context) {
        MemoryInstallSceneFactory.updateScene(view.scene, phaseIndex: phaseIndex, localProgress: localProgress)
    }
}

private struct SSDInstallPseudo3DStage: View {
    let stageWidth: CGFloat
    let caution: String
    @State private var phaseIndex = 0
    @State private var phaseStartDate: Date?
    @State private var completedProgress: Double = 0
    private let stepDuration: TimeInterval = 1.35

    private var sceneWidth: CGFloat {
        min(max(stageWidth, 300), 346)
    }

    private var sceneHeight: CGFloat {
        min(sceneWidth * 0.80, 276)
    }

    private let sceneOffsetY: CGFloat = 72

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            let localProgress = currentProgress(at: timeline.date)
            let phase = GuideFlow.ssdInstallPhases[phaseIndex]

            VStack(spacing: 34) {
                TutorialSceneChrome(
                    phase: phase,
                    phaseIndex: phaseIndex,
                    width: sceneWidth,
                    height: sceneHeight,
                    sceneOffsetY: sceneOffsetY,
                    caution: caution
                ) {
                    SSDInstallSceneView(phaseIndex: phaseIndex, localProgress: localProgress)
                }

                TutorialPhaseProgress(
                    phaseIndex: phaseIndex,
                    phaseCount: GuideFlow.ssdInstallPhases.count,
                    localProgress: localProgress
                )
            }
            .frame(width: sceneWidth, height: sceneHeight + sceneOffsetY + 78)
            .contentShape(Rectangle())
            .onTapGesture {
                advancePhase()
            }
            .onChange(of: localProgress) { _, progress in
                if phaseStartDate != nil, progress >= 1 {
                    phaseStartDate = nil
                    completedProgress = 1
                }
            }
        }
    }

    private func currentProgress(at date: Date) -> Double {
        guard let phaseStartDate else {
            return completedProgress
        }

        let raw = min(max(date.timeIntervalSince(phaseStartDate) / stepDuration, 0), 1)
        return raw * raw * (3 - 2 * raw)
    }

    private func advancePhase() {
        guard phaseStartDate == nil else { return }

        if completedProgress >= 1 {
            phaseIndex = (phaseIndex + 1) % GuideFlow.ssdInstallPhases.count
            completedProgress = 0
        }

        phaseStartDate = Date()
    }
}

private struct SSDInstallSceneView: UIViewRepresentable {
    let phaseIndex: Int
    let localProgress: Double

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView(frame: .zero)
        view.backgroundColor = .clear
        view.scene = SSDInstallSceneFactory.makeScene()
        view.allowsCameraControl = false
        view.autoenablesDefaultLighting = false
        view.isUserInteractionEnabled = false
        view.preferredFramesPerSecond = 30
        view.antialiasingMode = .multisampling4X
        return view
    }

    func updateUIView(_ view: SCNView, context: Context) {
        SSDInstallSceneFactory.updateScene(view.scene, phaseIndex: phaseIndex, localProgress: localProgress)
    }
}

private enum TutorialSceneLighting {
    static func install(in scene: SCNScene, keyIntensity: CGFloat, keyAngles: SCNVector3) {
        scene.lightingEnvironment.contents = UIColor(white: 0.82, alpha: 1)
        scene.lightingEnvironment.intensity = 0.56

        let ambient = SCNNode()
        let ambientLight = SCNLight()
        ambientLight.type = .ambient
        ambientLight.intensity = 210
        ambientLight.color = UIColor(red: 0.82, green: 0.87, blue: 0.92, alpha: 1)
        ambient.light = ambientLight
        scene.rootNode.addChildNode(ambient)

        let key = SCNNode()
        let keyLight = SCNLight()
        keyLight.type = .directional
        keyLight.intensity = keyIntensity
        keyLight.color = UIColor(red: 1.0, green: 0.96, blue: 0.90, alpha: 1)
        keyLight.castsShadow = true
        keyLight.shadowRadius = 10
        keyLight.shadowSampleCount = 16
        keyLight.shadowMapSize = CGSize(width: 1024, height: 1024)
        keyLight.shadowColor = UIColor.black.withAlphaComponent(0.34)
        key.light = keyLight
        key.eulerAngles = keyAngles
        scene.rootNode.addChildNode(key)

        let fill = SCNNode()
        let fillLight = SCNLight()
        fillLight.type = .omni
        fillLight.intensity = 260
        fillLight.color = UIColor(red: 0.62, green: 0.78, blue: 1.0, alpha: 1)
        fill.light = fillLight
        fill.position = SCNVector3(-2.8, 2.8, 2.4)
        scene.rootNode.addChildNode(fill)

        let rim = SCNNode()
        let rimLight = SCNLight()
        rimLight.type = .omni
        rimLight.intensity = 190
        rimLight.color = UIColor(red: 1.0, green: 0.78, blue: 0.58, alpha: 1)
        rim.light = rimLight
        rim.position = SCNVector3(2.8, 1.8, -2.6)
        scene.rootNode.addChildNode(rim)
    }

    static func configure(
        _ material: SCNMaterial,
        color: UIColor,
        roughness: CGFloat,
        metalness: CGFloat,
        emission: UIColor? = nil
    ) {
        material.lightingModel = .physicallyBased
        material.diffuse.contents = color
        material.roughness.contents = roughness
        material.metalness.contents = metalness
        material.ambientOcclusion.contents = UIColor(white: 0.72, alpha: 1)
        material.clearCoat.contents = metalness > 0.25 ? 0.16 : 0.05
        material.clearCoatRoughness.contents = min(roughness + 0.12, 1)
        material.isDoubleSided = true

        if let emission {
            material.emission.contents = emission
            material.emission.intensity = 0.35
        }
    }
}

private enum SSDInstallSceneFactory {
    private static let cameraName = "ssd-camera"
    private static let cameraTargetName = "ssd-camera-target"
    private static let ssdName = "ssd-module"
    private static let installedCPUName = "ssd-installed-cpu"
    private static let firstMemoryName = "ssd-installed-memory-a2"
    private static let secondMemoryName = "ssd-installed-memory-b2"
    private static let heatsinkGroupName = "ssd-m2-heatsink-group"
    private static let alignCueName = "ssd-align-cue"
    private static let pressCueName = "ssd-press-cue"
    private static let boardModelName = "modern-atx-motherboard-mobile"
    private static let cpuModelName = "desktop-cpu-mobile"
    private static let memoryModelName = "desktop-dimm-ram-mobile"
    private static let ssdModelName = "m2-2280-nvme-ssd-mobile"
    private static let memoryBaseEuler = SCNVector3(-Float.pi / 2, Float.pi / 2, 0)
    private static let ssdFlatEuler = SCNVector3(-Float.pi / 2, 0, 0)
    private static let ssdAngledEuler = SCNVector3(-Float.pi / 2, 0, -0.46)
    private static let m2HeatsinkNodeNames = ["MB_M2_Lower_Heatsink", "MB_M2_Lower_Cut"]
    private static let heatsinkBasePositionKey = "ssdHeatsinkBasePosition"

    static func makeScene() -> SCNScene {
        let scene = SCNScene()
        scene.background.contents = UIColor.clear

        let cameraTarget = SCNNode()
        cameraTarget.name = cameraTargetName
        cameraTarget.position = SCNVector3(0.35, 0.18, -0.18)
        scene.rootNode.addChildNode(cameraTarget)

        let cameraNode = SCNNode()
        let camera = SCNCamera()
        camera.fieldOfView = 30
        camera.zNear = 0.1
        camera.zFar = 100
        cameraNode.name = cameraName
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(0.42, 2.68, 2.82)
        let lookAt = SCNLookAtConstraint(target: cameraTarget)
        lookAt.isGimbalLockEnabled = true
        cameraNode.constraints = [lookAt]
        scene.rootNode.addChildNode(cameraNode)

        TutorialSceneLighting.install(in: scene, keyIntensity: 980, keyAngles: SCNVector3(-0.72, 0.32, -0.24))

        scene.rootNode.addChildNode(makeModelNode(name: boardModelName))
        installCPUSocketAnchor(in: scene)
        installDIMMSlotAnchor(named: GuideFlow.memoryInstallAnchorNames[0], slotNumber: 2, in: scene)
        installDIMMSlotAnchor(named: GuideFlow.memoryInstallAnchorNames[1], slotNumber: 4, in: scene)
        installM2SlotAnchor(in: scene)
        configureM2HeatsinkGroup(in: scene)

        let installedCPU = makeInstalledCPU()
        scene.rootNode.addChildNode(installedCPU)
        installedCPU.position = cpuInstalledPosition(in: scene, cpuNode: installedCPU)

        let firstMemory = makeInstalledMemory(name: firstMemoryName, anchorName: GuideFlow.memoryInstallAnchorNames[0], slotNumber: 2, in: scene)
        let secondMemory = makeInstalledMemory(name: secondMemoryName, anchorName: GuideFlow.memoryInstallAnchorNames[1], slotNumber: 4, in: scene)
        scene.rootNode.addChildNode(firstMemory)
        scene.rootNode.addChildNode(secondMemory)

        scene.rootNode.addChildNode(makeSSD())
        scene.rootNode.addChildNode(makeAlignCue())
        scene.rootNode.addChildNode(makePressCue())

        return scene
    }

    static func updateScene(_ scene: SCNScene?, phaseIndex: Int, localProgress: Double) {
        guard let scene else { return }
        let progress = CGFloat(localProgress)

        updateCamera(in: scene, phaseIndex: phaseIndex, progress: progress)

        let ssd = scene.rootNode.childNode(withName: ssdName, recursively: true)
        ssd?.eulerAngles = ssdAngles(phaseIndex: phaseIndex, progress: progress)
        ssd?.position = ssdPosition(phaseIndex: phaseIndex, progress: progress, in: scene, ssdNode: ssd)
        ssd?.opacity = ssdOpacity(phaseIndex: phaseIndex, progress: progress)

        updateM2Heatsink(in: scene, phaseIndex: phaseIndex, progress: progress)

        scene.rootNode.childNode(withName: alignCueName, recursively: true)?.opacity = phaseIndex == 1 ? Double(0.45 + 0.45 * sin(progress * .pi)) : 0
        scene.rootNode.childNode(withName: pressCueName, recursively: true)?.opacity = phaseIndex == 3 ? Double(0.35 + 0.45 * sin(progress * .pi)) : 0
    }

    private static func makeSSD() -> SCNNode {
        let ssd = makeModelNode(name: ssdModelName)
        ssd.name = ssdName
        ssd.position = ssdInitialPosition()
        ssd.eulerAngles = ssdAngles(phaseIndex: 0, progress: 0)
        return ssd
    }

    private static func makeAlignCue() -> SCNNode {
        let group = SCNNode()
        group.name = alignCueName
        group.opacity = 0
        let cueMaterial = material(UIColor(red: 1.0, green: 0.55, blue: 0.12, alpha: 1), roughness: 0.34, metalness: 0.08)

        let slotCue = boxNode(width: 0.16, height: 0.025, length: 0.42, radius: 0.012, material: cueMaterial)
        slotCue.position = SCNVector3(0.70, 0.34, -0.18)
        group.addChildNode(slotCue)

        let ssdCue = boxNode(width: 0.16, height: 0.025, length: 0.26, radius: 0.012, material: cueMaterial)
        ssdCue.position = SCNVector3(0.18, 0.78, -0.26)
        group.addChildNode(ssdCue)

        let connector = cylinderNode(radius: 0.012, height: 0.50, material: cueMaterial)
        connector.position = SCNVector3(0.44, 0.56, -0.22)
        group.addChildNode(connector)

        return group
    }

    private static func makePressCue() -> SCNNode {
        let group = SCNNode()
        group.name = pressCueName
        group.opacity = 0
        let cueMaterial = material(UIColor(red: 0.20, green: 0.58, blue: 1.0, alpha: 1), roughness: 0.36, metalness: 0)

        let highlight = boxNode(width: 0.30, height: 0.025, length: 0.34, radius: 0.018, material: cueMaterial)
        highlight.position = SCNVector3(-0.42, 0.52, -0.18)
        group.addChildNode(highlight)

        let arrow = coneNode(topRadius: 0, bottomRadius: 0.08, height: 0.18, material: cueMaterial)
        arrow.eulerAngles = SCNVector3(Float.pi, 0, 0)
        arrow.position = SCNVector3(-0.42, 0.80, -0.18)
        group.addChildNode(arrow)

        return group
    }

    private static func updateCamera(in scene: SCNScene, phaseIndex: Int, progress: CGFloat) {
        guard let cameraNode = scene.rootNode.childNode(withName: cameraName, recursively: true),
              let camera = cameraNode.camera,
              let target = scene.rootNode.childNode(withName: cameraTargetName, recursively: true) else {
            return
        }

        let overviewPosition = SCNVector3(0.05, 4.50, 4.95)
        let overviewTarget = SCNVector3(0.0, 0.04, -0.12)
        let slotPosition = SCNVector3(0.52, 2.48, 2.36)
        let slotTarget = SCNVector3(0.68, 0.22, -0.18)
        let insertPosition = SCNVector3(0.42, 2.70, 2.75)
        let insertTarget = SCNVector3(0.34, 0.20, -0.18)
        let finishPosition = SCNVector3(0.24, 3.35, 3.55)
        let finishTarget = SCNVector3(0.06, 0.16, -0.18)

        let position: SCNVector3
        let targetPosition: SCNVector3
        switch phaseIndex {
        case 0:
            let cameraProgress = easeHold(progress, startHold: 0.06, endHold: 0.12)
            position = mix(overviewPosition, slotPosition, cameraProgress)
            targetPosition = mix(overviewTarget, slotTarget, cameraProgress)
        case 1:
            let cameraProgress = easeHold(progress, startHold: 0.10, endHold: 0.10)
            position = mix(slotPosition, insertPosition, cameraProgress)
            targetPosition = mix(slotTarget, insertTarget, cameraProgress)
        case 2:
            position = insertPosition
            targetPosition = insertTarget
        case 3:
            let cameraProgress = easeHold(progress, startHold: 0.14, endHold: 0.08)
            position = mix(insertPosition, finishPosition, cameraProgress)
            targetPosition = mix(insertTarget, finishTarget, cameraProgress)
        case 4:
            let cameraProgress = easeHold(progress, startHold: 0.12, endHold: 0.16)
            position = mix(finishPosition, overviewPosition, cameraProgress * 0.35)
            targetPosition = mix(finishTarget, overviewTarget, cameraProgress * 0.20)
        default:
            position = slotPosition
            targetPosition = slotTarget
        }

        cameraNode.position = position
        target.position = targetPosition
        camera.fieldOfView = 28 + Double(max(0, position.y - 2.4)) * 3.2
    }

    private static func ssdPosition(phaseIndex: Int, progress: CGFloat, in scene: SCNScene, ssdNode: SCNNode?) -> SCNVector3 {
        let installed = ssdInstalledPosition(in: scene, ssdNode: ssdNode)
        let angledReady = SCNVector3(installed.x - 0.64, installed.y + 0.42, installed.z - 0.05)
        let angledInserted = SCNVector3(installed.x - 0.18, installed.y + 0.26, installed.z)
        switch phaseIndex {
        case 0:
            return angledReady
        case 1:
            let eased = easeHold(progress, startHold: 0.08, endHold: 0.14)
            return mix(SCNVector3(installed.x - 0.90, installed.y + 0.62, installed.z - 0.20), angledReady, eased)
        case 2:
            let eased = easeHold(progress, startHold: 0.14, endHold: 0.18)
            return mix(angledReady, angledInserted, eased)
        case 3:
            let eased = easeHold(progress, startHold: 0.10, endHold: 0.12)
            return mix(angledInserted, installed, eased)
        default:
            return installed
        }
    }

    private static func ssdInitialPosition() -> SCNVector3 {
        let installed = ssdInstalledFallback()
        return SCNVector3(installed.x - 0.64, installed.y + 0.42, installed.z - 0.05)
    }

    private static func ssdAngles(phaseIndex: Int, progress: CGFloat) -> SCNVector3 {
        switch phaseIndex {
        case 0, 1, 2:
            return ssdAngledEuler
        case 3:
            let eased = easeHold(progress, startHold: 0.10, endHold: 0.12)
            return mix(ssdAngledEuler, ssdFlatEuler, eased)
        default:
            return ssdFlatEuler
        }
    }

    private static func ssdOpacity(phaseIndex: Int, progress: CGFloat) -> Double {
        if phaseIndex == 0 {
            return 0
        }
        if phaseIndex == 1 {
            return Double(min(max(progress * 1.8, 0), 1))
        }
        return 1
    }

    private static func updateM2Heatsink(in scene: SCNScene, phaseIndex: Int, progress: CGFloat) {
        guard let group = scene.rootNode.childNode(withName: heatsinkGroupName, recursively: true),
              let basePosition = (group.value(forKey: heatsinkBasePositionKey) as? NSValue)?.scnVector3Value else {
            return
        }
        group.position = heatsinkPosition(basePosition: basePosition, phaseIndex: phaseIndex, progress: progress)
        group.opacity = heatsinkOpacity(phaseIndex: phaseIndex)
    }

    private static func heatsinkPosition(basePosition: SCNVector3, phaseIndex: Int, progress: CGFloat) -> SCNVector3 {
        let removed = SCNVector3(basePosition.x - 0.52, basePosition.y + 0.72, basePosition.z - 0.58)
        switch phaseIndex {
        case 0:
            return mix(basePosition, removed, easeHold(progress, startHold: 0.08, endHold: 0.12))
        case 4:
            let delayed = easeHold(progress, startHold: 0.28, endHold: 0.10)
            return mix(removed, basePosition, delayed)
        default:
            return removed
        }
    }

    private static func heatsinkOpacity(phaseIndex: Int) -> Double {
        if phaseIndex == 0 || phaseIndex == 4 { return 1 }
        return 0.72
    }

    private static func mix(_ start: SCNVector3, _ end: SCNVector3, _ progress: CGFloat) -> SCNVector3 {
        let t = Float(progress)
        return SCNVector3(start.x + (end.x - start.x) * t, start.y + (end.y - start.y) * t, start.z + (end.z - start.z) * t)
    }

    private static func smoothStep(_ value: CGFloat) -> CGFloat {
        value * value * (3 - 2 * value)
    }

    private static func easeHold(_ value: CGFloat, startHold: CGFloat, endHold: CGFloat) -> CGFloat {
        let available = max(1 - startHold - endHold, 0.001)
        let normalized = min(max((value - startHold) / available, 0), 1)
        return normalized * normalized * normalized * (normalized * (normalized * 6 - 15) + 10)
    }

    private static func makeModelNode(name: String) -> SCNNode {
        let node = SCNNode()
        node.name = name

        guard let url = Bundle.main.url(forResource: name, withExtension: "usdc"),
              let scene = try? SCNScene(url: url, options: nil) else {
            return node
        }

        scene.rootNode.childNodes.forEach {
            node.addChildNode($0.clone())
        }
        normalize(node, modelName: name)
        applyModelOverrides(to: node, modelName: name)
        return node
    }

    private static func normalize(_ node: SCNNode, modelName: String) {
        let (minimum, maximum) = node.boundingBox
        let width = maximum.x - minimum.x
        let height = maximum.y - minimum.y
        let depth = maximum.z - minimum.z
        let longestSide = max(width, height, depth)
        guard longestSide > 0 else { return }

        let targetLongestSide: Float
        if modelName == boardModelName {
            targetLongestSide = 4.65
        } else if modelName == cpuModelName {
            targetLongestSide = 0.74
        } else if modelName == memoryModelName {
            targetLongestSide = 1.50
        } else {
            targetLongestSide = 2.02
        }

        let scale = targetLongestSide / longestSide
        node.scale = SCNVector3(scale, scale, scale)
        node.position = SCNVector3(
            -(minimum.x + maximum.x) * 0.5 * scale,
            -(minimum.y + maximum.y) * 0.5 * scale,
            -(minimum.z + maximum.z) * 0.5 * scale
        )

        if modelName == boardModelName {
            node.eulerAngles = SCNVector3(-Float.pi / 2, 0, 0)
            node.position = SCNVector3(0, 0.02, 0)
        } else if modelName == memoryModelName {
            node.eulerAngles = memoryBaseEuler
        } else if modelName == ssdModelName {
            node.eulerAngles = ssdFlatEuler
        } else {
            node.eulerAngles = SCNVector3Zero
        }
    }

    private static func applyModelOverrides(to node: SCNNode, modelName: String) {
        guard modelName == cpuModelName else { return }

        let ihsMaterial = SCNMaterial()
        ihsMaterial.name = "CPU_IHS_Bright_Brushed_Metal"
        ihsMaterial.lightingModel = .physicallyBased
        ihsMaterial.diffuse.contents = UIColor(red: 0.56, green: 0.58, blue: 0.57, alpha: 1)
        ihsMaterial.metalness.contents = 0.92
        ihsMaterial.roughness.contents = 0.32
        ihsMaterial.specular.contents = UIColor.white
        ihsMaterial.isDoubleSided = true

        node.enumerateChildNodes { child, _ in
            if child.name?.contains("Brushed_Highlight") == true {
                child.isHidden = true
                return
            }
            guard child.name?.contains("IHS") == true else { return }
            child.geometry?.materials = [ihsMaterial]
        }
    }

    private static func installM2SlotAnchor(in scene: SCNScene) {
        guard scene.rootNode.childNode(withName: GuideFlow.ssdInstallAnchorName, recursively: true) == nil else {
            return
        }

        let slotNode = scene.rootNode.childNode(withName: "MB_M2_Slot_Mouth_Clearance", recursively: true)
            ?? scene.rootNode.childNode(withName: "MB_M2_Slot_Channel_Shadow", recursively: true)
            ?? scene.rootNode.childNode(withName: "MB_M2_Slot", recursively: true)
        guard let slotNode,
              let slotBounds = sceneBounds(of: slotNode, in: scene.rootNode) else {
            installAnchor(named: GuideFlow.ssdInstallAnchorName, at: SCNVector3(0.62, 0.23, -0.18), in: scene.rootNode)
            return
        }

        installAnchor(
            named: GuideFlow.ssdInstallAnchorName,
            at: SCNVector3(slotBounds.center.x, slotBounds.center.y, slotBounds.center.z),
            in: scene.rootNode
        )
    }

    private static func configureM2HeatsinkGroup(in scene: SCNScene) {
        guard let firstNode = scene.rootNode.childNode(withName: m2HeatsinkNodeNames[0], recursively: true),
              let firstParent = firstNode.parent else {
            return
        }

        let pivot = scene.rootNode.convertPosition(firstNode.position, from: firstParent)
        groupBoardNodes(named: heatsinkGroupName, childNames: m2HeatsinkNodeNames, pivotPosition: pivot, in: scene.rootNode)
    }

    private static func groupBoardNodes(named groupName: String, childNames: [String], pivotPosition: SCNVector3, in root: SCNNode) {
        let group = SCNNode()
        group.name = groupName
        group.position = pivotPosition
        root.addChildNode(group)

        for childName in childNames {
            guard let node = root.childNode(withName: childName, recursively: true),
                  let parent = node.parent else {
                continue
            }

            let rootTransform = root.convertTransform(node.transform, from: parent)
            node.removeFromParentNode()
            node.transform = group.convertTransform(rootTransform, from: root)
            group.addChildNode(node)
        }

        group.setValue(NSValue(scnVector3: group.position), forKey: heatsinkBasePositionKey)
    }

    private static func makeInstalledCPU() -> SCNNode {
        let cpu = makeModelNode(name: cpuModelName)
        cpu.name = installedCPUName
        return cpu
    }

    private static func cpuInstalledPosition(in scene: SCNScene, cpuNode: SCNNode) -> SCNVector3 {
        guard let anchor = scene.rootNode.childNode(withName: GuideFlow.cpuInstallAnchorName, recursively: true),
              let alignedPosition = alignedInstallPosition(
                  anchor: anchor,
                  componentNode: cpuNode,
                  in: scene.rootNode,
                  matchingName: { $0.contains("PCB") }
              ) else {
            return SCNVector3(-0.19, 0.27, -1.00)
        }

        return alignedPosition
    }

    private static func makeInstalledMemory(name: String, anchorName: String, slotNumber: Int, in scene: SCNScene) -> SCNNode {
        let module = makeModelNode(name: memoryModelName)
        module.name = name
        module.eulerAngles = memoryBaseEuler
        module.position = memoryInstalledPosition(module: module, anchorName: anchorName, slotNumber: slotNumber, in: scene)
        return module
    }

    private static func memoryInstalledPosition(module: SCNNode, anchorName: String, slotNumber: Int, in scene: SCNScene) -> SCNVector3 {
        guard let anchor = scene.rootNode.childNode(withName: anchorName, recursively: true),
              let contactBounds = installBoundsOffset(
                  for: module,
                  in: scene.rootNode,
                  matchingName: { $0.contains("Gold_Finger") }
              ),
              let slotBounds = dimmSlotBounds(slotNumber: slotNumber, in: scene) else {
            return slotNumber == 2 ? SCNVector3(0.768, 0.28, -0.892) : SCNVector3(1.114, 0.28, -0.892)
        }

        let slotDepth = max(slotBounds.maximum.y - slotBounds.minimum.y, 0.001)
        let coveredContactTopY = slotBounds.maximum.y - slotDepth * 0.18
        return SCNVector3(
            anchor.position.x - contactBounds.center.x,
            coveredContactTopY - contactBounds.maximum.y,
            anchor.position.z - contactBounds.center.z
        )
    }

    private static func ssdInstalledFallback() -> SCNVector3 {
        SCNVector3(0.26, 0.225, -0.18)
    }

    private static func ssdInstalledPosition(in scene: SCNScene, ssdNode: SCNNode?) -> SCNVector3 {
        guard let ssdNode,
              let anchor = scene.rootNode.childNode(withName: GuideFlow.ssdInstallAnchorName, recursively: true) else {
            return ssdInstalledFallback()
        }

        let originalEuler = ssdNode.eulerAngles
        ssdNode.eulerAngles = ssdFlatEuler
        defer { ssdNode.eulerAngles = originalEuler }

        guard let contactBounds = installBoundsOffset(
            for: ssdNode,
            in: scene.rootNode,
            matchingName: { $0.contains("Gold_Finger") }
        ) else {
            return ssdInstalledFallback()
        }

        return SCNVector3(
            anchor.position.x - contactBounds.center.x,
            anchor.position.y - contactBounds.center.y,
            anchor.position.z - contactBounds.center.z
        )
    }

    private static func boxNode(width: CGFloat, height: CGFloat, length: CGFloat, radius: CGFloat, material: SCNMaterial) -> SCNNode {
        let box = SCNBox(width: width, height: height, length: length, chamferRadius: radius)
        box.materials = [material]
        return SCNNode(geometry: box)
    }

    private static func cylinderNode(radius: CGFloat, height: CGFloat, material: SCNMaterial) -> SCNNode {
        let cylinder = SCNCylinder(radius: radius, height: height)
        cylinder.radialSegmentCount = 18
        cylinder.materials = [material]
        return SCNNode(geometry: cylinder)
    }

    private static func coneNode(topRadius: CGFloat, bottomRadius: CGFloat, height: CGFloat, material: SCNMaterial) -> SCNNode {
        let cone = SCNCone(topRadius: topRadius, bottomRadius: bottomRadius, height: height)
        cone.radialSegmentCount = 18
        cone.materials = [material]
        return SCNNode(geometry: cone)
    }

    private static func material(_ color: UIColor, roughness: CGFloat = 0.6, metalness: CGFloat = 0.0) -> SCNMaterial {
        let material = SCNMaterial()
        TutorialSceneLighting.configure(material, color: color, roughness: roughness, metalness: metalness)
        return material
    }
}

private struct SceneNodeBounds {
    var minimum: SCNVector3
    var maximum: SCNVector3

    var center: SCNVector3 {
        SCNVector3(
            (minimum.x + maximum.x) * 0.5,
            (minimum.y + maximum.y) * 0.5,
            (minimum.z + maximum.z) * 0.5
        )
    }

    mutating func include(_ point: SCNVector3) {
        minimum = SCNVector3(
            min(minimum.x, point.x),
            min(minimum.y, point.y),
            min(minimum.z, point.z)
        )
        maximum = SCNVector3(
            max(maximum.x, point.x),
            max(maximum.y, point.y),
            max(maximum.z, point.z)
        )
    }

    mutating func include(_ bounds: SceneNodeBounds) {
        include(bounds.minimum)
        include(bounds.maximum)
    }
}

private func sceneBounds(of node: SCNNode, in coordinateRoot: SCNNode) -> SceneNodeBounds? {
    let localBounds = node.boundingBox
    let minimum = localBounds.min
    let maximum = localBounds.max
    guard minimum.x.isFinite, minimum.y.isFinite, minimum.z.isFinite,
          maximum.x.isFinite, maximum.y.isFinite, maximum.z.isFinite,
          minimum.x <= maximum.x, minimum.y <= maximum.y, minimum.z <= maximum.z else {
        return nil
    }

    let corners = [
        SCNVector3(minimum.x, minimum.y, minimum.z),
        SCNVector3(minimum.x, minimum.y, maximum.z),
        SCNVector3(minimum.x, maximum.y, minimum.z),
        SCNVector3(minimum.x, maximum.y, maximum.z),
        SCNVector3(maximum.x, minimum.y, minimum.z),
        SCNVector3(maximum.x, minimum.y, maximum.z),
        SCNVector3(maximum.x, maximum.y, minimum.z),
        SCNVector3(maximum.x, maximum.y, maximum.z)
    ]

    var bounds = SceneNodeBounds(
        minimum: SCNVector3(Float.greatestFiniteMagnitude, Float.greatestFiniteMagnitude, Float.greatestFiniteMagnitude),
        maximum: SCNVector3(-Float.greatestFiniteMagnitude, -Float.greatestFiniteMagnitude, -Float.greatestFiniteMagnitude)
    )
    for corner in corners {
        bounds.include(coordinateRoot.convertPosition(corner, from: node))
    }
    return bounds
}

private func combinedSceneBounds(
    under rootNode: SCNNode,
    in coordinateRoot: SCNNode,
    matchingName nameMatcher: (String) -> Bool
) -> SceneNodeBounds? {
    var combinedBounds: SceneNodeBounds?

    rootNode.enumerateChildNodes { child, _ in
        guard let name = child.name, nameMatcher(name),
              let childBounds = sceneBounds(of: child, in: coordinateRoot) else {
            return
        }

        if var existingBounds = combinedBounds {
            existingBounds.include(childBounds)
            combinedBounds = existingBounds
        } else {
            combinedBounds = childBounds
        }
    }

    return combinedBounds
}

private func installBaselineOffset(
    for componentNode: SCNNode,
    in coordinateRoot: SCNNode,
    matchingName nameMatcher: ((String) -> Bool)? = nil
) -> SCNVector3? {
    guard let bounds = installBoundsOffset(for: componentNode, in: coordinateRoot, matchingName: nameMatcher) else {
        return nil
    }

    return SCNVector3(bounds.center.x, bounds.minimum.y, bounds.center.z)
}

private func installBoundsOffset(
    for componentNode: SCNNode,
    in coordinateRoot: SCNNode,
    matchingName nameMatcher: ((String) -> Bool)? = nil
) -> SceneNodeBounds? {
    let originalPosition = componentNode.position
    componentNode.position = SCNVector3Zero
    defer { componentNode.position = originalPosition }

    let bounds: SceneNodeBounds?
    if let nameMatcher {
        bounds = combinedSceneBounds(under: componentNode, in: coordinateRoot, matchingName: nameMatcher)
            ?? sceneBounds(of: componentNode, in: coordinateRoot)
    } else {
        bounds = sceneBounds(of: componentNode, in: coordinateRoot)
    }

    return bounds
}

private func alignedInstallPosition(
    anchor: SCNNode,
    componentNode: SCNNode,
    in coordinateRoot: SCNNode,
    matchingName nameMatcher: ((String) -> Bool)? = nil
) -> SCNVector3? {
    guard let baselineOffset = installBaselineOffset(for: componentNode, in: coordinateRoot, matchingName: nameMatcher) else {
        return nil
    }

    return SCNVector3(
        anchor.position.x - baselineOffset.x,
        anchor.position.y - baselineOffset.y,
        anchor.position.z - baselineOffset.z
    )
}

private func installAnchor(named name: String, at position: SCNVector3, in root: SCNNode) {
    let anchor = SCNNode()
    anchor.name = name
    anchor.position = position
    anchor.isHidden = true
    root.addChildNode(anchor)
}

private func installCPUSocketAnchor(in scene: SCNScene) {
    guard scene.rootNode.childNode(withName: GuideFlow.cpuInstallAnchorName, recursively: true) == nil,
          let socketSupport = scene.rootNode.childNode(withName: "MB_CPU_LGA_Field", recursively: true),
          let socketBounds = sceneBounds(of: socketSupport, in: scene.rootNode) else {
        return
    }

    installAnchor(
        named: GuideFlow.cpuInstallAnchorName,
        at: SCNVector3(socketBounds.center.x, socketBounds.maximum.y, socketBounds.center.z),
        in: scene.rootNode
    )
}

private func installDIMMSlotAnchor(named name: String, slotNumber: Int, in scene: SCNScene) {
    guard scene.rootNode.childNode(withName: name, recursively: true) == nil else { return }

    let slotNode = scene.rootNode.childNode(withName: "MB_RAM_Slot_Groove_\(slotNumber)", recursively: true)
        ?? scene.rootNode.childNode(withName: "MB_RAM_Slot_Inner_Well_\(slotNumber)", recursively: true)
        ?? scene.rootNode.childNode(withName: "MB_RAM_Slot_\(slotNumber)", recursively: true)
    guard let slotNode,
          let slotBounds = sceneBounds(of: slotNode, in: scene.rootNode) else {
        return
    }

    installAnchor(
        named: name,
        at: SCNVector3(slotBounds.center.x, slotBounds.minimum.y, slotBounds.center.z),
        in: scene.rootNode
    )
}

private func dimmSlotBounds(slotNumber: Int, in scene: SCNScene) -> SceneNodeBounds? {
    let slotNode = scene.rootNode.childNode(withName: "MB_RAM_Slot_Groove_\(slotNumber)", recursively: true)
        ?? scene.rootNode.childNode(withName: "MB_RAM_Slot_Inner_Well_\(slotNumber)", recursively: true)
        ?? scene.rootNode.childNode(withName: "MB_RAM_Slot_\(slotNumber)", recursively: true)
    guard let slotNode else { return nil }
    return sceneBounds(of: slotNode, in: scene.rootNode)
}

private enum MemoryInstallSceneFactory {
    private static let cameraName = "memory-camera"
    private static let installedCPUName = "memory-installed-cpu"
    private static let firstStickName = "first-memory-stick"
    private static let secondStickName = "second-memory-stick"
    private static let targetGlowName = "memory-target-glow"
    private static let ramNotchCueName = "memory-ram-notch-cue"
    private static let slotNotchCueName = "memory-slot-notch-cue"
    private static let pressCueName = "memory-press-cue"
    private static let boardModelName = "modern-atx-motherboard-mobile"
    private static let cpuModelName = "desktop-cpu-mobile"
    private static let memoryModelName = "desktop-dimm-ram-mobile"
    private static let selectedSlotNumbers = [2, 4]
    private static let latchPartSuffixes = ["Latch", "Latch_Lever", "Latch_Hook", "Latch_Notch"]
    private static let memoryLatchBaseEulerKey = "memoryInstallBaseEuler"
    private static let firstSlotX: Float = 0.768
    private static let secondSlotX: Float = 1.114
    private static let slotCenterZ: Float = -0.892
    private static let slotKeyZ: Float = -0.692
    private static let memoryBaseEuler = SCNVector3(-Float.pi / 2, Float.pi / 2, 0)

    static func makeScene() -> SCNScene {
        let scene = SCNScene()
        scene.background.contents = UIColor.clear

        let cameraNode = SCNNode()
        let camera = SCNCamera()
        camera.zNear = 0.1
        camera.zFar = 100
        camera.fieldOfView = 26
        cameraNode.name = cameraName
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(1.10, 2.20, 2.58)
        cameraNode.eulerAngles = SCNVector3(-0.56, 0.10, 0.0)
        scene.rootNode.addChildNode(cameraNode)

        TutorialSceneLighting.install(in: scene, keyIntensity: 1_000, keyAngles: SCNVector3(-0.72, 0.30, -0.25))

        scene.rootNode.addChildNode(makeModelNode(name: boardModelName))
        installCPUSocketAnchor(in: scene)
        installDIMMSlotAnchor(named: GuideFlow.memoryInstallAnchorNames[0], slotNumber: selectedSlotNumbers[0], in: scene)
        installDIMMSlotAnchor(named: GuideFlow.memoryInstallAnchorNames[1], slotNumber: selectedSlotNumbers[1], in: scene)

        let installedCPU = makeInstalledCPU()
        scene.rootNode.addChildNode(installedCPU)
        installedCPU.position = cpuInstalledPosition(in: scene, cpuNode: installedCPU)

        scene.rootNode.addChildNode(makeMemoryModule(name: firstStickName))
        scene.rootNode.addChildNode(makeMemoryModule(name: secondStickName))
        scene.rootNode.addChildNode(makeTargetSlotCues())
        scene.rootNode.addChildNode(makeRamNotchCues())
        scene.rootNode.addChildNode(makeSlotNotchCues())
        scene.rootNode.addChildNode(makePressCues())
        configureMemoryLatchGroups(in: scene)

        return scene
    }

    static func updateScene(_ scene: SCNScene?, phaseIndex: Int, localProgress: Double) {
        guard let scene else { return }
        let progress = CGFloat(localProgress)
        updateCamera(in: scene, phaseIndex: phaseIndex, progress: progress)
        scene.rootNode.childNode(withName: firstStickName, recursively: true)?.position = firstStickPosition(phaseIndex: phaseIndex, progress: progress, in: scene)
        scene.rootNode.childNode(withName: secondStickName, recursively: true)?.position = secondStickPosition(phaseIndex: phaseIndex, progress: progress, in: scene)
        scene.rootNode.childNode(withName: ramNotchCueName, recursively: true)?.opacity = phaseIndex == 1 ? Double(0.50 + 0.36 * sin(progress * .pi)) : 0
        scene.rootNode.childNode(withName: slotNotchCueName, recursively: true)?.opacity = phaseIndex == 2 ? Double(0.48 + 0.40 * sin(progress * .pi)) : 0
        updateRamNotchCue(in: scene, phaseIndex: phaseIndex, progress: progress)
        updatePressCue(in: scene, phaseIndex: phaseIndex, progress: progress)
        updateMemoryLatches(in: scene, phaseIndex: phaseIndex, progress: progress)

        scene.rootNode.childNode(withName: firstStickName, recursively: true)?.eulerAngles = firstStickAngles(phaseIndex: phaseIndex, progress: progress)
        scene.rootNode.childNode(withName: secondStickName, recursively: true)?.eulerAngles = secondStickAngles(phaseIndex: phaseIndex, progress: progress)

        scene.rootNode.childNode(withName: targetGlowName, recursively: true)?.opacity = phaseIndex == 0 ? 0.55 + 0.25 * Double(sin(progress * .pi)) : 0
    }

    private static func updateCamera(in scene: SCNScene, phaseIndex: Int, progress: CGFloat) {
        guard let cameraNode = scene.rootNode.childNode(withName: cameraName, recursively: true) else { return }

        let inspectPosition = SCNVector3(1.02, 2.02, 2.22)
        let inspectAngles = SCNVector3(-0.48, 0.04, 0.0)
        let alignPosition = SCNVector3(0.96, 2.10, 2.42)
        let alignAngles = SCNVector3(-0.54, 0.07, 0.0)
        let installPosition = SCNVector3(1.02, 2.16, 2.64)
        let installAngles = SCNVector3(-0.57, 0.08, 0.0)
        let completedPosition = SCNVector3(1.10, 2.20, 2.58)
        let completedAngles = SCNVector3(-0.56, 0.10, 0.0)
        let closePosition: SCNVector3
        let closeAngles: SCNVector3
        if phaseIndex == 1 {
            let startPosition = SCNVector3(1.10, 2.20, 2.58)
            let startAngles = SCNVector3(-0.56, 0.10, 0.0)
            let blendIn = min(progress * 0.8, 1)
            closePosition = mix(startPosition, inspectPosition, blendIn)
            closeAngles = mix(startAngles, inspectAngles, blendIn)
        } else if phaseIndex == 2 {
            closePosition = mix(inspectPosition, alignPosition, 0.35 + progress * 0.65)
            closeAngles = mix(inspectAngles, alignAngles, 0.35 + progress * 0.65)
        } else if phaseIndex == 3 {
            closePosition = mix(alignPosition, installPosition, min(progress * 1.2, 1))
            closeAngles = mix(alignAngles, installAngles, min(progress * 1.2, 1))
        } else if phaseIndex == 4 {
            let cameraProgress = smoothStep(min(max((progress - 0.18) / 0.74, 0), 1))
            closePosition = mix(installPosition, completedPosition, cameraProgress)
            closeAngles = mix(installAngles, completedAngles, cameraProgress)
        } else if phaseIndex == 5 {
            let resetProgress = smoothStep(progress)
            closePosition = mix(completedPosition, completedPosition, resetProgress)
            closeAngles = mix(completedAngles, completedAngles, resetProgress)
        } else {
            closePosition = completedPosition
            closeAngles = completedAngles
        }
        let widePosition = SCNVector3(0.0, 4.65, 5.35)
        let wideAngles = SCNVector3(-0.72, 0.0, 0.0)

        let blend: CGFloat
        if phaseIndex <= 2 {
            blend = 0
        } else if phaseIndex == 3 {
            blend = min(max((progress - 0.28) * 1.15, 0), 1)
        } else if phaseIndex == 4 {
            blend = 1 - 0.22 * (1 - smoothStep(min(max((progress - 0.18) / 0.74, 0), 1)))
        } else if phaseIndex == 5 {
            blend = 1 - smoothStep(progress)
        } else {
            blend = 1
        }

        cameraNode.position = mix(closePosition, widePosition, blend)
        cameraNode.eulerAngles = mix(closeAngles, wideAngles, blend)
        cameraNode.camera?.fieldOfView = 26 + Double(blend) * 14
    }

    private static func updatePressCue(in scene: SCNScene, phaseIndex: Int, progress: CGFloat) {
        guard let pressCue = scene.rootNode.childNode(withName: pressCueName, recursively: true) else { return }
        guard phaseIndex == 4 else {
            pressCue.opacity = 0
            pressCue.position = SCNVector3Zero
            return
        }

        let fadeIn = min(progress / 0.18, 1)
        let fadeOut = min(max((0.72 - progress) / 0.24, 0), 1)
        let opacity = max(min(fadeIn, fadeOut), 0)
        pressCue.opacity = Double(opacity)
        let pressProgress = smoothStep(min(max(progress / 0.72, 0), 1))
        pressCue.position = SCNVector3(0, -0.16 * Float(pressProgress), 0)
    }

    private static func updateRamNotchCue(in scene: SCNScene, phaseIndex: Int, progress: CGFloat) {
        let positions = [
            firstStickPosition(phaseIndex: phaseIndex, progress: progress, in: scene),
            secondStickPosition(phaseIndex: phaseIndex, progress: progress, in: scene)
        ]

        for index in 0..<2 {
            let cue = scene.rootNode.childNode(withName: "\(ramNotchCueName)-\(index)", recursively: true)
            cue?.position = SCNVector3(positions[index].x, positions[index].y - 0.24, positions[index].z - 0.13)
        }
    }

    private static func makeModelNode(name: String) -> SCNNode {
        let node = SCNNode()
        node.name = name

        guard let url = Bundle.main.url(forResource: name, withExtension: "usdc"),
              let scene = try? SCNScene(url: url, options: nil) else {
            return node
        }

        scene.rootNode.childNodes.forEach {
            node.addChildNode($0.clone())
        }
        normalize(node, modelName: name)
        return node
    }

    private static func makeMemoryModule(name: String) -> SCNNode {
        let module = makeModelNode(name: memoryModelName)
        module.name = name
        module.position = name == firstStickName ? initialFirstStickPosition(progress: 0) : initialSecondStickPosition(progress: 0)
        module.eulerAngles = name == firstStickName ? firstStickAngles(phaseIndex: 0, progress: 0) : secondStickAngles(phaseIndex: 0, progress: 0)
        return module
    }

    private static func makeInstalledCPU() -> SCNNode {
        let cpu = makeModelNode(name: cpuModelName)
        cpu.name = installedCPUName
        return cpu
    }

    private static func cpuInstalledPosition(in scene: SCNScene, cpuNode: SCNNode) -> SCNVector3 {
        guard let anchor = scene.rootNode.childNode(withName: GuideFlow.cpuInstallAnchorName, recursively: true),
              let alignedPosition = alignedInstallPosition(
                  anchor: anchor,
                  componentNode: cpuNode,
                  in: scene.rootNode,
                  matchingName: { $0.contains("PCB") }
              ) else {
            return SCNVector3(-0.19, 0.27, -1.00)
        }

        return alignedPosition
    }

    private static func makeTargetSlotCues() -> SCNNode {
        let targetGlow = SCNNode()
        targetGlow.name = targetGlowName
        let glowMaterial = material(UIColor(red: 0.40, green: 0.72, blue: 1.0, alpha: 1), roughness: 0.4, metalness: 0)
        for x in [firstSlotX, secondSlotX] {
            let glow = boxNode(width: 0.075, height: 0.012, length: 1.54, radius: 0.008, material: glowMaterial)
            glow.position = SCNVector3(x, 0.205, slotCenterZ)
            targetGlow.addChildNode(glow)
        }
        return targetGlow
    }

    private static func normalize(_ node: SCNNode, modelName: String) {
        let (minimum, maximum) = node.boundingBox
        let width = maximum.x - minimum.x
        let height = maximum.y - minimum.y
        let depth = maximum.z - minimum.z
        let longestSide = max(width, height, depth)
        guard longestSide > 0 else { return }

        let targetLongestSide: Float
        if modelName == boardModelName {
            targetLongestSide = 4.65
        } else if modelName == cpuModelName {
            targetLongestSide = 0.74
        } else {
            targetLongestSide = 1.50
        }
        let scale = targetLongestSide / Float(longestSide)
        node.scale = SCNVector3(scale, scale, scale)
        node.position = SCNVector3(
            -Float(minimum.x + maximum.x) * 0.5 * scale,
            -Float(minimum.y + maximum.y) * 0.5 * scale,
            -Float(minimum.z + maximum.z) * 0.5 * scale
        )

        if modelName == boardModelName {
            node.eulerAngles = SCNVector3(-Float.pi / 2, 0, 0)
            node.position = SCNVector3(0, 0.02, 0)
        } else if modelName == cpuModelName {
            node.eulerAngles = SCNVector3Zero
        } else {
            node.eulerAngles = memoryBaseEuler
        }
    }

    private static func makePressCues() -> SCNNode {
        let group = SCNNode()
        group.name = pressCueName
        group.opacity = 0

        for x in [firstSlotX, secondSlotX] {
            for z in [slotCenterZ - 0.44, slotCenterZ + 0.44] {
                let highlight = boxNode(width: 0.22, height: 0.02, length: 0.34, radius: 0.018, material: material(UIColor(red: 0.20, green: 0.58, blue: 1.0, alpha: 1), roughness: 0.36, metalness: 0.0))
                highlight.position = SCNVector3(x, 0.75, z)
                group.addChildNode(highlight)

                let arrow = arrowNode()
                arrow.position = SCNVector3(x, 1.22, z)
                group.addChildNode(arrow)
            }
        }

        return group
    }

    private static func configureMemoryLatchGroups(in scene: SCNScene) {
        for slotNumber in selectedSlotNumbers {
            for endName in ["Top", "Bottom"] {
                let hingeName = "MB_RAM_\(endName)_Latch_Hinge_\(slotNumber)"
                guard let hinge = scene.rootNode.childNode(withName: hingeName, recursively: true),
                      let hingeParent = hinge.parent else {
                    continue
                }

                groupBoardNodes(
                    named: memoryLatchGroupName(endName: endName, slotNumber: slotNumber),
                    childNames: latchPartNames(endName: endName, slotNumber: slotNumber),
                    pivotPosition: scene.rootNode.convertPosition(hinge.position, from: hingeParent),
                    in: scene.rootNode
                )
            }
        }
    }

    private static func updateMemoryLatches(in scene: SCNScene, phaseIndex: Int, progress: CGFloat) {
        let openAmount = memoryLatchOpenAmount(phaseIndex: phaseIndex, progress: progress)

        for slotNumber in selectedSlotNumbers {
            updateMemoryLatchGroup(
                named: memoryLatchGroupName(endName: "Top", slotNumber: slotNumber),
                in: scene,
                progress: openAmount,
                xRotation: -0.66
            )
            updateMemoryLatchGroup(
                named: memoryLatchGroupName(endName: "Bottom", slotNumber: slotNumber),
                in: scene,
                progress: openAmount,
                xRotation: 0.66
            )
        }
    }

    private static func memoryLatchOpenAmount(phaseIndex: Int, progress: CGFloat) -> Float {
        switch phaseIndex {
        case 0:
            return Float(smoothStep(progress))
        case 1, 2, 3:
            return 1
        case 4:
            return Float(1 - smoothStep(min(max((progress - 0.54) / 0.34, 0), 1)))
        default:
            return 0
        }
    }

    private static func updateMemoryLatchGroup(
        named groupName: String,
        in scene: SCNScene,
        progress: Float,
        xRotation: Float
    ) {
        guard let group = scene.rootNode.childNode(withName: groupName, recursively: true),
              let baseEuler = baseMemoryLatchEulerAngles(for: group) else {
            return
        }

        group.eulerAngles = SCNVector3(
            baseEuler.x + xRotation * progress,
            baseEuler.y,
            baseEuler.z
        )
    }

    private static func groupBoardNodes(named groupName: String, childNames: [String], pivotPosition: SCNVector3, in root: SCNNode) {
        let group = SCNNode()
        group.name = groupName
        group.position = pivotPosition
        root.addChildNode(group)

        for childName in childNames {
            guard let node = root.childNode(withName: childName, recursively: true),
                  let parent = node.parent else {
                continue
            }

            let rootTransform = root.convertTransform(node.transform, from: parent)
            node.removeFromParentNode()
            node.transform = group.convertTransform(rootTransform, from: root)
            group.addChildNode(node)
        }

        group.setValue(NSValue(scnVector3: group.eulerAngles), forKey: memoryLatchBaseEulerKey)
    }

    private static func baseMemoryLatchEulerAngles(for node: SCNNode) -> SCNVector3? {
        (node.value(forKey: memoryLatchBaseEulerKey) as? NSValue)?.scnVector3Value
    }

    private static func memoryLatchGroupName(endName: String, slotNumber: Int) -> String {
        "memory-\(endName.lowercased())-latch-group-\(slotNumber)"
    }

    private static func latchPartNames(endName: String, slotNumber: Int) -> [String] {
        latchPartSuffixes.map { "MB_RAM_\(endName)_\($0)_\(slotNumber)" }
    }

    private static func makeRamNotchCues() -> SCNNode {
        let group = SCNNode()
        group.name = ramNotchCueName
        group.opacity = 0
        let cueMaterial = material(UIColor(red: 1.0, green: 0.55, blue: 0.12, alpha: 1), roughness: 0.34, metalness: 0.08)

        for index in 0..<2 {
            let stickCue = boxNode(width: 0.24, height: 0.026, length: 0.24, radius: 0.012, material: cueMaterial)
            stickCue.name = "\(ramNotchCueName)-\(index)"
            group.addChildNode(stickCue)
        }

        return group
    }

    private static func makeSlotNotchCues() -> SCNNode {
        let group = SCNNode()
        group.name = slotNotchCueName
        group.opacity = 0
        let cueMaterial = material(UIColor(red: 1.0, green: 0.55, blue: 0.12, alpha: 1), roughness: 0.34, metalness: 0.08)

        for x in [firstSlotX, secondSlotX] {
            let slotCue = boxNode(width: 0.20, height: 0.03, length: 0.18, radius: 0.01, material: cueMaterial)
            slotCue.position = SCNVector3(x, 0.31, slotKeyZ)
            group.addChildNode(slotCue)

            let connector = cylinderNode(radius: 0.012, height: 0.44, material: cueMaterial)
            connector.position = SCNVector3(x, 0.55, slotKeyZ)
            group.addChildNode(connector)
        }

        return group
    }

    private static func firstStickPosition(phaseIndex: Int, progress: CGFloat, in scene: SCNScene) -> SCNVector3 {
        let installedPosition = memoryInstalledPosition(
            stickName: firstStickName,
            anchorName: GuideFlow.memoryInstallAnchorNames[0],
            slotNumber: selectedSlotNumbers[0],
            fallback: SCNVector3(firstSlotX, 0.28, slotCenterZ),
            in: scene
        )

        switch phaseIndex {
        case 0:
            return initialFirstStickPosition(progress: 0)
        case 1:
            let eased = progress * progress * (3 - 2 * progress)
            return initialFirstStickPosition(progress: eased)
        case 2:
            let eased = progress * progress * (3 - 2 * progress)
            return SCNVector3(firstSlotX, 1.18 - Float(eased) * 0.26, slotCenterZ - 0.40 + Float(eased) * 0.40)
        case 3:
            let rawProgress = min(max((progress - 0.10) / 0.68, 0), 1)
            let firstProgress = rawProgress * rawProgress * (3 - 2 * rawProgress)
            return mix(SCNVector3(firstSlotX, 0.92, slotCenterZ), installedPosition, firstProgress)
        case 4:
            let pressProgress = smoothStep(min(max(progress / 0.72, 0), 1))
            return SCNVector3(installedPosition.x, installedPosition.y - 0.018 * Float(sin(pressProgress * .pi)), installedPosition.z)
        case 5:
            let resetProgress = smoothStep(progress)
            return mix(installedPosition, SCNVector3(firstSlotX, 1.34, slotCenterZ - 0.58), resetProgress)
        default:
            return installedPosition
        }
    }

    private static func secondStickPosition(phaseIndex: Int, progress: CGFloat, in scene: SCNScene) -> SCNVector3 {
        let installedPosition = memoryInstalledPosition(
            stickName: secondStickName,
            anchorName: GuideFlow.memoryInstallAnchorNames[1],
            slotNumber: selectedSlotNumbers[1],
            fallback: SCNVector3(secondSlotX, 0.28, slotCenterZ),
            in: scene
        )

        switch phaseIndex {
        case 0:
            return initialSecondStickPosition(progress: 0)
        case 1:
            let eased = progress * progress * (3 - 2 * progress)
            return initialSecondStickPosition(progress: eased)
        case 2:
            let eased = progress * progress * (3 - 2 * progress)
            return SCNVector3(secondSlotX, 1.26 - Float(eased) * 0.34, slotCenterZ - 0.40 + Float(eased) * 0.40)
        case 3:
            let rawProgress = min(max((progress - 0.34) / 0.66, 0), 1)
            let secondProgress = rawProgress * rawProgress * (3 - 2 * rawProgress)
            return mix(SCNVector3(secondSlotX, 0.92, slotCenterZ), installedPosition, secondProgress)
        case 4:
            let pressProgress = smoothStep(min(max(progress / 0.72, 0), 1))
            return SCNVector3(installedPosition.x, installedPosition.y - 0.018 * Float(sin(pressProgress * .pi)), installedPosition.z)
        case 5:
            let resetProgress = smoothStep(progress)
            return mix(installedPosition, SCNVector3(secondSlotX, 1.46, slotCenterZ - 0.60), resetProgress)
        default:
            return installedPosition
        }
    }

    private static func initialFirstStickPosition(progress: CGFloat) -> SCNVector3 {
        let eased = Float(progress)
        return SCNVector3(firstSlotX, 1.34 - eased * 0.16, slotCenterZ - 0.58 + eased * 0.18)
    }

    private static func initialSecondStickPosition(progress: CGFloat) -> SCNVector3 {
        let eased = Float(progress)
        return SCNVector3(secondSlotX, 1.46 - eased * 0.20, slotCenterZ - 0.60 + eased * 0.20)
    }

    private static func memoryInstalledPosition(
        stickName: String,
        anchorName: String,
        slotNumber: Int,
        fallback: SCNVector3,
        in scene: SCNScene
    ) -> SCNVector3 {
        guard let stick = scene.rootNode.childNode(withName: stickName, recursively: true),
              let anchor = scene.rootNode.childNode(withName: anchorName, recursively: true),
              let contactBounds = installBoundsOffset(
                  for: stick,
                  in: scene.rootNode,
                  matchingName: { $0.contains("Gold_Finger") }
              ),
              let slotBounds = dimmSlotBounds(slotNumber: slotNumber, in: scene) else {
            return fallback
        }

        let slotDepth = max(slotBounds.maximum.y - slotBounds.minimum.y, 0.001)
        let coveredContactTopY = slotBounds.maximum.y - slotDepth * 0.18
        return SCNVector3(
            anchor.position.x - contactBounds.center.x,
            coveredContactTopY - contactBounds.maximum.y,
            anchor.position.z - contactBounds.center.z
        )
    }

    private static func firstStickAngles(phaseIndex: Int, progress: CGFloat) -> SCNVector3 {
        if phaseIndex == 3 {
            let rawProgress = min(max((progress - 0.10) / 0.68, 0), 1)
            return memoryEuler(tilt: -0.10 + Float(smoothStep(rawProgress)) * 0.10)
        }
        if phaseIndex == 4 {
            return memoryEuler(tilt: 0)
        }
        if phaseIndex == 5 {
            return memoryEuler(tilt: -Float(smoothStep(progress)) * 0.10)
        }
        return memoryEuler(tilt: -0.10)
    }

    private static func secondStickAngles(phaseIndex: Int, progress: CGFloat) -> SCNVector3 {
        if phaseIndex == 3 {
            let rawProgress = min(max((progress - 0.34) / 0.66, 0), 1)
            return memoryEuler(tilt: -0.10 + Float(smoothStep(rawProgress)) * 0.10)
        }
        if phaseIndex == 4 {
            return memoryEuler(tilt: 0)
        }
        if phaseIndex == 5 {
            return memoryEuler(tilt: -Float(smoothStep(progress)) * 0.10)
        }
        return memoryEuler(tilt: -0.10)
    }

    private static func memoryEuler(tilt: Float) -> SCNVector3 {
        SCNVector3(memoryBaseEuler.x + tilt, memoryBaseEuler.y, memoryBaseEuler.z)
    }

    private static func mix(_ start: SCNVector3, _ end: SCNVector3, _ progress: CGFloat) -> SCNVector3 {
        let t = Float(progress)
        return SCNVector3(
            start.x + (end.x - start.x) * t,
            start.y + (end.y - start.y) * t,
            start.z + (end.z - start.z) * t
        )
    }

    private static func smoothStep(_ value: CGFloat) -> CGFloat {
        value * value * (3 - 2 * value)
    }

    private static func boxNode(width: CGFloat, height: CGFloat, length: CGFloat, radius: CGFloat, material: SCNMaterial) -> SCNNode {
        let box = SCNBox(width: width, height: height, length: length, chamferRadius: radius)
        box.materials = [material]
        return SCNNode(geometry: box)
    }

    private static func cylinderNode(radius: CGFloat, height: CGFloat, material: SCNMaterial) -> SCNNode {
        let cylinder = SCNCylinder(radius: radius, height: height)
        cylinder.radialSegmentCount = 18
        cylinder.materials = [material]
        return SCNNode(geometry: cylinder)
    }

    private static func coneNode(topRadius: CGFloat, bottomRadius: CGFloat, height: CGFloat, material: SCNMaterial) -> SCNNode {
        let cone = SCNCone(topRadius: topRadius, bottomRadius: bottomRadius, height: height)
        cone.radialSegmentCount = 18
        cone.materials = [material]
        return SCNNode(geometry: cone)
    }

    private static func arrowNode() -> SCNNode {
        let group = SCNNode()
        let arrowMaterial = material(UIColor(red: 0.18, green: 0.50, blue: 1.0, alpha: 1), roughness: 0.34, metalness: 0.08)

        let shaft = cylinderNode(radius: 0.024, height: 0.34, material: arrowMaterial)
        shaft.position = SCNVector3(0, 0.10, 0)
        group.addChildNode(shaft)

        let head = coneNode(topRadius: 0, bottomRadius: 0.075, height: 0.15, material: arrowMaterial)
        head.eulerAngles = SCNVector3(Float.pi, 0, 0)
        head.position = SCNVector3(0, -0.12, 0)
        group.addChildNode(head)

        return group
    }

    private static func material(_ color: UIColor, roughness: CGFloat = 0.6, metalness: CGFloat = 0.0) -> SCNMaterial {
        let material = SCNMaterial()
        TutorialSceneLighting.configure(material, color: color, roughness: roughness, metalness: metalness)
        return material
    }
}

private enum CPUInstallSceneFactory {
    private static let cameraName = "cpu-install-camera"
    private static let cameraTargetName = "cpu-install-camera-target"
    private static let cpuNodeName = "cpu-node"
    private static let cpuMarkerName = "cpu-marker"
    private static let leverGroupName = "cpu-install-lever-group"
    private static let frameGroupName = "cpu-install-frame-group"
    private static let boardModelName = "modern-atx-motherboard-mobile"
    private static let cpuModelName = "desktop-cpu-mobile"
    private static let socketCenter = SCNVector3(-0.19, 0.16, -1.00)
    private static let leverNodeNames = ["MB_CPU_Load_Lever", "MB_CPU_Lever_Handle"]
    private static let frameNodeNames = ["MB_CPU_Metal_Frame_Top", "MB_CPU_Metal_Frame_Bottom", "MB_CPU_Metal_Frame_Left", "MB_CPU_Metal_Frame_Right"]
    private static let leverOpenAngle: Float = -70 * .pi / 180
    private static let frameOpenAngle: Float = -70 * .pi / 180
    private static let boardOverviewTarget = SCNVector3(0, 0.04, -0.05)
    private static let boardOverviewCameraPosition = SCNVector3(0, 4.35, 3.95)
    private static let socketCloseCameraPosition = SCNVector3(-0.24, 2.35, 1.25)

    static func makeScene() -> SCNScene {
        let scene = SCNScene()
        scene.background.contents = UIColor.clear

        let cameraTarget = SCNNode()
        cameraTarget.name = cameraTargetName
        cameraTarget.position = socketCenter
        scene.rootNode.addChildNode(cameraTarget)

        let cameraNode = SCNNode()
        let camera = SCNCamera()
        camera.fieldOfView = 28
        camera.zNear = 0.1
        camera.zFar = 100
        cameraNode.name = cameraName
        cameraNode.camera = camera
        cameraNode.position = boardOverviewCameraPosition
        let lookAt = SCNLookAtConstraint(target: cameraTarget)
        lookAt.isGimbalLockEnabled = true
        cameraNode.constraints = [lookAt]
        scene.rootNode.addChildNode(cameraNode)

        TutorialSceneLighting.install(in: scene, keyIntensity: 1_120, keyAngles: SCNVector3(-0.80, 0.36, -0.30))

        scene.rootNode.addChildNode(makeBoard())
        installCPUSocketAnchor(in: scene)
        configureBoardLatchGroups(in: scene)
        scene.rootNode.addChildNode(makeCPU())

        return scene
    }

    static func updateScene(_ scene: SCNScene?, phaseIndex: Int, localProgress: Double) {
        guard let scene else { return }
        let progress = CGFloat(localProgress)
        let cpuNode = scene.rootNode.childNode(withName: cpuNodeName, recursively: true)
        let cpuMarker = scene.rootNode.childNode(withName: cpuMarkerName, recursively: true)

        updateCamera(in: scene, phaseIndex: phaseIndex, progress: progress)
        updateBoardLatch(in: scene, phaseIndex: phaseIndex, progress: progress)

        let installedPosition = cpuInstalledPosition(in: scene, cpuNode: cpuNode)
        let cpuPosition = cpuPosition(phaseIndex: phaseIndex, progress: progress, installedPosition: installedPosition)
        cpuNode?.position = cpuPosition
        cpuNode?.eulerAngles = SCNVector3(0, cpuYaw(phaseIndex: phaseIndex, progress: progress), 0)
        cpuNode?.opacity = cpuOpacity(phaseIndex: phaseIndex, progress: progress)

        let isAligning = phaseIndex == 0 || phaseIndex == 3
        let glowOpacity: CGFloat = isAligning ? 0.75 + 0.25 * sin(progress * .pi) : 0.22
        cpuMarker?.opacity = Double(glowOpacity)
    }

    private static func makeBoard() -> SCNNode {
        makeModelNode(name: boardModelName)
    }

    private static func makeCPU() -> SCNNode {
        let cpu = makeModelNode(name: cpuModelName)
        cpu.name = cpuNodeName

        let marker = markerNode(size: 0.07)
        marker.name = cpuMarkerName
        marker.position = SCNVector3(-0.30, 0.04, -0.30)
        cpu.addChildNode(marker)

        return cpu
    }

    private static func cpuInstalledPosition(in scene: SCNScene, cpuNode: SCNNode?) -> SCNVector3 {
        guard let cpuNode,
              let anchor = scene.rootNode.childNode(withName: GuideFlow.cpuInstallAnchorName, recursively: true),
              let alignedPosition = alignedInstallPosition(
                  anchor: anchor,
                  componentNode: cpuNode,
                  in: scene.rootNode
              ) else {
            return SCNVector3(-0.19, 0.27, -1.00)
        }

        return alignedPosition
    }

    private static func cpuPosition(phaseIndex: Int, progress: CGFloat, installedPosition: SCNVector3) -> SCNVector3 {
        let cpuHoverPosition = SCNVector3(installedPosition.x, installedPosition.y + 0.49, installedPosition.z)
        switch phaseIndex {
        case 0:
            return SCNVector3(-0.64, 1.12 + Float(sin(progress * .pi)) * 0.03, -0.54)
        case 1:
            return SCNVector3(-0.64, 1.12, -0.54)
        case 2:
            return SCNVector3(-0.64, 1.08, -0.54)
        case 3:
            let eased = smoothStep(progress)
            return mix(SCNVector3(-0.64, 1.08, -0.54), cpuHoverPosition, eased)
        case 4:
            let easedDrop = smoothStep(min(max(progress / 0.62, 0), 1))
            return mix(cpuHoverPosition, installedPosition, easedDrop)
        case 5:
            return installedPosition
        default:
            return installedPosition
        }
    }

    private static func cpuYaw(phaseIndex: Int, progress: CGFloat) -> Float {
        switch phaseIndex {
        case 0:
            return -0.08
        case 3:
            return -0.08 + Float(progress) * 0.08
        case 5:
            return 0
        default:
            return 0
        }
    }

    private static func cpuOpacity(phaseIndex: Int, progress: CGFloat) -> Double {
        if phaseIndex == 0 {
            return 0.48 + 0.18 * Double(sin(progress * .pi))
        }
        if phaseIndex == 5 {
            return 1
        }
        return 1
    }

    private static func updateCamera(in scene: SCNScene, phaseIndex: Int, progress: CGFloat) {
        guard let cameraNode = scene.rootNode.childNode(withName: cameraName, recursively: true),
              let camera = cameraNode.camera,
              let target = scene.rootNode.childNode(withName: cameraTargetName, recursively: true) else {
            return
        }

        let closePosition = socketCloseCameraPosition
        let insertPosition = SCNVector3(-0.26, 2.05, 0.88)
        let finishPosition = SCNVector3(-0.22, 2.42, 1.58)

        switch phaseIndex {
        case 0:
            cameraNode.position = boardOverviewCameraPosition
            camera.fieldOfView = 44
            target.position = boardOverviewTarget
        case 1:
            let eased = smoothStep(progress)
            cameraNode.position = mix(boardOverviewCameraPosition, closePosition, eased)
            camera.fieldOfView = 44 - 16 * Double(eased)
            target.position = mix(boardOverviewTarget, socketCenter, eased)
        case 3:
            let eased = smoothStep(progress)
            cameraNode.position = mix(closePosition, insertPosition, eased)
            camera.fieldOfView = 28 - 3 * Double(eased)
            target.position = mix(socketCenter, SCNVector3(socketCenter.x, socketCenter.y + 0.06, socketCenter.z), eased)
        case 4:
            let eased = smoothStep(progress)
            cameraNode.position = mix(insertPosition, finishPosition, eased)
            camera.fieldOfView = 25 + 3 * Double(eased)
            target.position = mix(SCNVector3(socketCenter.x, socketCenter.y + 0.06, socketCenter.z), socketCenter, eased)
        case GuideFlow.cpuInstallResetScenePhaseIndex:
            let eased = smoothStep(min(max((progress - 0.18) / 0.82, 0), 1))
            cameraNode.position = mix(finishPosition, boardOverviewCameraPosition, eased)
            camera.fieldOfView = 28 + 16 * Double(eased)
            target.position = mix(socketCenter, boardOverviewTarget, eased)
        default:
            cameraNode.position = closePosition
            camera.fieldOfView = 28
            target.position = socketCenter
        }
    }

    private static func updateBoardLatch(in scene: SCNScene, phaseIndex: Int, progress: CGFloat) {
        let leverProgress = latchOpenAmount(phaseIndex: phaseIndex, progress: progress)
        let frameProgress = frameOpenAmount(phaseIndex: phaseIndex, progress: progress)

        updateLatchGroup(
            named: leverGroupName,
            in: scene,
            progress: leverProgress,
            xRotation: leverOpenAngle
        )
        updateLatchGroup(
            named: frameGroupName,
            in: scene,
            progress: frameProgress,
            xRotation: frameOpenAngle
        )
    }

    private static func updateLatchGroup(
        named groupName: String,
        in scene: SCNScene,
        progress: Float,
        xRotation: Float
    ) {
        guard let group = scene.rootNode.childNode(withName: groupName, recursively: true),
              let baseEuler = baseEulerAngles(for: group) else {
            return
        }

        group.eulerAngles = SCNVector3(
            baseEuler.x + xRotation * progress,
            baseEuler.y,
            baseEuler.z
        )
    }

    private static func latchOpenAmount(phaseIndex: Int, progress: CGFloat) -> Float {
        switch phaseIndex {
        case 1:
            return Float(smoothStep(progress))
        case 2, 3:
            return 1
        case 4:
            return Float(1 - smoothStep(min(max((progress - 0.70) / 0.30, 0), 1)))
        case 5:
            return 0
        default:
            return 0
        }
    }

    private static func frameOpenAmount(phaseIndex: Int, progress: CGFloat) -> Float {
        switch phaseIndex {
        case 2:
            return Float(smoothStep(progress))
        case 3:
            return 1
        case 4:
            return Float(1 - smoothStep(min(max((progress - 0.58) / 0.28, 0), 1)))
        case 5:
            return 0
        default:
            return 0
        }
    }

    private static func mix(_ start: SCNVector3, _ end: SCNVector3, _ progress: CGFloat) -> SCNVector3 {
        let t = Float(progress)
        return SCNVector3(
            start.x + (end.x - start.x) * t,
            start.y + (end.y - start.y) * t,
            start.z + (end.z - start.z) * t
        )
    }

    private static func smoothStep(_ value: CGFloat) -> CGFloat {
        value * value * (3 - 2 * value)
    }

    private static func markerNode(size: CGFloat) -> SCNNode {
        let cone = SCNCone(topRadius: 0, bottomRadius: size * 0.55, height: size)
        cone.radialSegmentCount = 3
        cone.materials = [material(UIColor(red: 1.0, green: 0.43, blue: 0.11, alpha: 1), emission: UIColor(red: 0.58, green: 0.18, blue: 0.02, alpha: 1))]
        let node = SCNNode(geometry: cone)
        node.eulerAngles = SCNVector3(Float.pi / 2, 0, Float.pi / 3)
        return node
    }

    private static func makeModelNode(name: String) -> SCNNode {
        let node = SCNNode()
        node.name = name

        guard let url = Bundle.main.url(forResource: name, withExtension: "usdc"),
              let scene = try? SCNScene(url: url, options: nil) else {
            return node
        }

        scene.rootNode.childNodes.forEach {
            node.addChildNode($0.clone())
        }
        normalize(node, modelName: name)
        applyModelOverrides(to: node, modelName: name)
        return node
    }

    private static func configureBoardLatchGroups(in scene: SCNScene) {
        groupBoardNodes(
            named: leverGroupName,
            childNames: leverNodeNames,
            pivotPosition: SCNVector3(0.346, 0.231, -1.444),
            in: scene.rootNode
        )
        groupBoardNodes(
            named: frameGroupName,
            childNames: frameNodeNames,
            pivotPosition: SCNVector3(-0.189, 0.185, -1.395),
            in: scene.rootNode
        )
    }

    private static func groupBoardNodes(named groupName: String, childNames: [String], pivotPosition: SCNVector3, in root: SCNNode) {
        let group = SCNNode()
        group.name = groupName
        group.position = pivotPosition
        root.addChildNode(group)

        for childName in childNames {
            guard let node = root.childNode(withName: childName, recursively: true),
                  let parent = node.parent else {
                continue
            }

            let rootTransform = root.convertTransform(node.transform, from: parent)
            node.removeFromParentNode()
            node.transform = group.convertTransform(rootTransform, from: root)
            group.addChildNode(node)
        }

        group.setValue(NSValue(scnVector3: group.position), forKey: "cpuInstallBasePosition")
        group.setValue(NSValue(scnVector3: group.eulerAngles), forKey: "cpuInstallBaseEuler")
    }

    private static func basePosition(for node: SCNNode) -> SCNVector3? {
        (node.value(forKey: "cpuInstallBasePosition") as? NSValue)?.scnVector3Value
    }

    private static func baseEulerAngles(for node: SCNNode) -> SCNVector3? {
        (node.value(forKey: "cpuInstallBaseEuler") as? NSValue)?.scnVector3Value
    }

    private static func normalize(_ node: SCNNode, modelName: String) {
        let (minimum, maximum) = node.boundingBox
        let width = maximum.x - minimum.x
        let height = maximum.y - minimum.y
        let depth = maximum.z - minimum.z
        let longestSide = max(width, height, depth)
        guard longestSide > 0 else { return }

        let targetLongestSide: Float = modelName == boardModelName ? 4.65 : 0.74
        let scale = targetLongestSide / longestSide
        node.scale = SCNVector3(scale, scale, scale)
        node.position = SCNVector3(
            -(minimum.x + maximum.x) * 0.5 * scale,
            -(minimum.y + maximum.y) * 0.5 * scale,
            -(minimum.z + maximum.z) * 0.5 * scale
        )

        if modelName == boardModelName {
            node.eulerAngles = SCNVector3(-Float.pi / 2, 0, 0)
            node.position = SCNVector3(0, 0.02, 0)
        } else {
            node.eulerAngles = SCNVector3Zero
        }
    }

    private static func applyModelOverrides(to node: SCNNode, modelName: String) {
        guard modelName == cpuModelName else { return }

        let ihsMaterial = SCNMaterial()
        ihsMaterial.name = "CPU_IHS_Bright_Brushed_Metal"
        ihsMaterial.lightingModel = .physicallyBased
        ihsMaterial.diffuse.contents = UIColor(red: 0.56, green: 0.58, blue: 0.57, alpha: 1)
        ihsMaterial.metalness.contents = 0.92
        ihsMaterial.roughness.contents = 0.32
        ihsMaterial.specular.contents = UIColor.white
        ihsMaterial.isDoubleSided = true

        node.enumerateChildNodes { child, _ in
            if child.name?.contains("Brushed_Highlight") == true {
                child.isHidden = true
                return
            }
            guard child.name?.contains("IHS") == true else { return }
            child.geometry?.materials = [ihsMaterial]
        }
    }

    private static func material(_ color: UIColor, roughness: CGFloat = 0.6, metalness: CGFloat = 0.0, emission: UIColor? = nil) -> SCNMaterial {
        let material = SCNMaterial()
        TutorialSceneLighting.configure(material, color: color, roughness: roughness, metalness: metalness, emission: emission)
        return material
    }
}

private struct ChipBlock: View {
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(Color.white.opacity(0.18))
            .frame(width: width, height: height)
            .overlay {
                VStack(spacing: 5) {
                    ForEach(0..<3) { _ in
                        Capsule()
                            .fill(Color.white.opacity(0.25))
                            .frame(width: max(width - 18, 12), height: 4)
                    }
                }
            }
    }
}

private struct MovingPart: View {
    let step: GuideStepContent

    var body: some View {
        VStack(spacing: 7) {
            Image(systemName: step.symbol)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(AppTheme.primaryText)
                .frame(width: 48, height: 48)
                .background(.white, in: RoundedRectangle(cornerRadius: 14))
                .shadow(color: Color.black.opacity(0.15), radius: 12, x: 0, y: 8)

            Image(systemName: "arrow.down")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)
                .symbolEffect(.bounce, options: .repeating.speed(0.7), value: step.id)
        }
    }
}

#Preview {
    GuideView(onBack: {})
}
