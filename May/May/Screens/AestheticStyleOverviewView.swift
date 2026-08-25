import SwiftUI

struct AestheticStyleOverviewView: View {
    let styleID: String
    let onClose: () -> Void
    let onStartBuild: (AestheticBuildSelection) -> Void

    @State private var selectedColor: AestheticStyleColor = .black
    @State private var selectedAlternatives: [String: String] = [:]
    @State private var presentedPart: AestheticStylePart?
    @Namespace private var colorSelectionAnimation

    private var style: AestheticBuildStyle {
        AestheticBuildStyle.all.first { $0.id == styleID } ?? AestheticBuildStyle.all[0]
    }

    private var totalPrice: Int {
        style.overviewParts.reduce(style.overviewTotal(for: selectedColor)) { total, part in
            total + currentPrice(for: part) - part.originalPrice(for: selectedColor)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    overviewHeader
                    heroSection
                    titleSection
                    partsSection
                }
                .padding(.bottom, 24)
            }

            totalBar
        }
        .background(Color.white.ignoresSafeArea())
        .overlay {
            if let part = presentedPart {
                GeometryReader { proxy in
                    ZStack {
                        Color.black.opacity(0.28)
                            .ignoresSafeArea()
                            .onTapGesture { dismissAlternatives() }
                            .transition(.opacity)

                        AestheticAlternativeModal(
                            part: part,
                            caseImageName: style.heroImage(for: selectedColor),
                            originalPrice: part.originalPrice(for: selectedColor),
                            selectedColor: selectedColor,
                            selectedAlternativeID: selectedAlternatives[part.id],
                            onClose: dismissAlternatives,
                            onSelect: { alternative in
                                if let alternative {
                                    selectedAlternatives[part.id] = alternative.id
                                } else {
                                    selectedAlternatives.removeValue(forKey: part.id)
                                }
                            },
                            onConfirm: dismissAlternatives
                        )
                        .frame(
                            width: min(proxy.size.width - 32, 400),
                            height: min(proxy.size.height * 0.72, 600)
                        )
                        .transition(
                            .asymmetric(
                                insertion: .opacity
                                    .combined(with: .scale(scale: 0.92))
                                    .combined(with: .offset(y: 18)),
                                removal: .opacity
                                    .combined(with: .scale(scale: 0.98))
                                    .combined(with: .offset(y: 8))
                            )
                        )
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
    }

    private var overviewHeader: some View {
        HStack(spacing: 8) {
            Button(action: onClose) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(AppTheme.primaryText)
                    .frame(width: 28, height: 32)
            }
            .buttonStyle(.plain)

            Text("方案介绍")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(AppTheme.primaryText)

            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.top, 10)
    }

    private var heroSection: some View {
        Image(style.heroImage(for: selectedColor))
            .resizable()
            .scaledToFit()
            .frame(maxWidth: .infinity)
            .frame(height: 244)
            .padding(.top, 4)
            .scaleEffect(heroImageScale)
            .contentTransition(.opacity)
    }

    private var heroImageScale: CGFloat {
        let selectedImageName = style.heroImage(for: selectedColor)
        let selectedVisibleHeight = visibleHeight(for: selectedImageName)
        let targetVisibleHeight = AestheticStyleColor.allCases
            .map { visibleHeight(for: style.heroImage(for: $0)) }
            .max() ?? selectedVisibleHeight

        guard selectedVisibleHeight > 0 else {
            return CGFloat(style.heroScale(for: selectedColor))
        }

        return CGFloat(style.heroScale(for: selectedColor))
            * targetVisibleHeight
            / selectedVisibleHeight
    }

    private func visibleHeight(for imageName: String) -> CGFloat {
        AestheticExplorerAssetCatalog.visibleBounds(for: imageName)?.height ?? 1
    }

    private var titleSection: some View {
        HStack(spacing: 14) {
            Text(style.title)
                .font(.system(size: 22, weight: .heavy))
                .foregroundStyle(AppTheme.primaryText)

            Spacer()

            colorPicker
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
    }

    private var colorPicker: some View {
        HStack(spacing: 0) {
            ForEach(AestheticStyleColor.allCases) { color in
                Button {
                    withAnimation(.spring(response: 0.36, dampingFraction: 0.82)) {
                        selectedColor = color
                    }
                } label: {
                    ZStack {
                        if selectedColor == color {
                            Capsule()
                                .fill(Color.white)
                                .matchedGeometryEffect(
                                    id: "selected-color",
                                    in: colorSelectionAnimation
                                )
                                .shadow(color: .black.opacity(0.10), radius: 4, y: 2)
                        }

                        HStack(spacing: 6) {
                            Circle()
                                .fill(color == .black ? Color.black : Color.white)
                                .frame(width: 8, height: 8)
                                .overlay {
                                    if color == .white {
                                        Circle()
                                            .stroke(Color.black.opacity(0.22), lineWidth: 0.8)
                                    }
                                }

                            Text(color.title)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(
                                    selectedColor == color
                                        ? AppTheme.primaryText
                                        : AppTheme.secondaryText
                                )
                        }
                    }
                    .frame(width: 57, height: 26)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(Color(white: 0.95), in: Capsule())
    }

    private var partsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("方案配件")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(AppTheme.primaryText)

            VStack(spacing: 0) {
                ForEach(Array(style.overviewParts.enumerated()), id: \.element.id) { index, part in
                    AestheticStylePartRow(
                        part: part,
                        price: currentPrice(for: part),
                        hasReplacement: selectedAlternatives[part.id] != nil,
                        action: { presentAlternatives(part) }
                    )

                    if index < style.overviewParts.count - 1 {
                        Divider()
                    }
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 26)
    }

    private var totalBar: some View {
        HStack(alignment: .bottom, spacing: 18) {
            VStack(alignment: .leading, spacing: 3) {
                Text("外观配件费用")
                    .font(.system(size: 10, weight: .regular))
                    .foregroundStyle(AppTheme.secondaryText)

                Text("¥\(totalPrice.formatted())")
                    .font(.system(size: 22, weight: .heavy))
                    .foregroundStyle(AppTheme.primaryText)
            }

            Spacer(minLength: 8)

            Button {
                onStartBuild(
                    style.buildSelection(
                        color: selectedColor,
                        selectedAlternativeIDs: selectedAlternatives
                    )
                )
            } label: {
                HStack(spacing: 14) {
                    Text("按这个方案装机")
                    Image(systemName: "arrow.right")
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 184, height: 40)
                .background(Color.black, in: RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 28)
        .padding(.top, 12)
        .padding(.bottom, 10)
        .background(Color.white)
        .overlay(alignment: .top) {
            Divider()
        }
    }

    private func currentPrice(for part: AestheticStylePart) -> Int {
        if part.usesAICooler {
            return 0
        }
        guard let alternativeID = selectedAlternatives[part.id],
              let alternative = part.alternatives.first(where: { $0.id == alternativeID })
        else {
            return part.originalPrice(for: selectedColor)
        }

        return alternative.price(for: selectedColor)
    }

    private func dismissAlternatives() {
        withAnimation(.easeOut(duration: 0.22)) {
            presentedPart = nil
        }
    }

    private func presentAlternatives(_ part: AestheticStylePart) {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.88, blendDuration: 0.12)) {
            presentedPart = part
        }
    }
}

private struct AestheticStylePartRow: View {
    let part: AestheticStylePart
    let price: Int
    let hasReplacement: Bool
    let action: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AppTheme.primaryText)
                .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 4) {
                Text(part.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.primaryText)

                Text(part.detail)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(Color.black.opacity(0.4))
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            HStack(spacing: 18) {
                Text(part.usesAICooler ? "AI 匹配" : "¥\(price.formatted())")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.primaryText)

                if !part.usesAICooler {
                    Button(action: action) {
                        Text("替换")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 54, height: 28)
                            .background(Color.black, in: RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(hasReplacement ? "更换平替，已选择" : "选择平替")
                }
            }
        }
        .padding(.vertical, 12)
    }

    private var iconName: String {
        aestheticPartIconName(for: part.name)
    }
}

private struct AestheticAlternativeModal: View {
    let part: AestheticStylePart
    let caseImageName: String
    let originalPrice: Int
    let selectedColor: AestheticStyleColor
    let selectedAlternativeID: String?
    let onClose: () -> Void
    let onSelect: (AestheticStyleAlternative?) -> Void
    let onConfirm: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("选择平替")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(AppTheme.primaryText)

                Spacer()

                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(AppTheme.primaryText)
                        .frame(width: 30, height: 30)
                        .background(Color(white: 0.95), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("关闭平替选择")
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 12)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(part.name)
                            .font(.system(size: 21, weight: .heavy))
                            .foregroundStyle(AppTheme.primaryText)

                        Text("请选择一个替代配件，价格会实时同步到外观配件费用。")
                            .font(.appBody)
                            .foregroundStyle(AppTheme.secondaryText)
                    }

                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(), spacing: 12),
                            GridItem(.flexible(), spacing: 12)
                        ],
                        spacing: 12
                    ) {
                        replacementCard(
                            title: "当前方案配件",
                            detail: part.detail,
                            price: originalPrice,
                            isSelected: selectedAlternativeID == nil,
                            action: { onSelect(nil) }
                        )

                        ForEach(part.alternatives) { alternative in
                            replacementCard(
                                title: alternative.name,
                                detail: alternative.detail,
                                price: alternative.price(for: selectedColor),
                                isSelected: selectedAlternativeID == alternative.id,
                                action: { onSelect(alternative) }
                            )
                        }
                    }
                }
                .padding(20)
            }

            HStack {
                Spacer()

                Button("确定", action: onConfirm)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 92, height: 40)
                    .background(Color.black, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 16)
            .overlay(alignment: .top) {
                Divider()
            }
        }
        .background(Color.white, in: RoundedRectangle(cornerRadius: 26))
        .clipShape(RoundedRectangle(cornerRadius: 26))
        .shadow(color: .black.opacity(0.2), radius: 30, y: 16)
    }

    private func replacementCard(
        title: String,
        detail: String,
        price: Int,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        let imageKey = title == "当前方案配件" ? detail : title
        let imageName = part.name == "机箱"
            ? caseImageName
            : AestheticAccessoryImageCatalog.imageName(for: imageKey)

        return Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(white: 0.96))

                    if let imageName {
                        Image(imageName)
                            .resizable()
                            .scaledToFit()
                            .padding(12)
                    } else {
                        Image(systemName: aestheticPartIconName(for: part.name))
                            .font(.system(size: 48, weight: .medium))
                            .foregroundStyle(.black)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 156)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(isSelected ? .white : .black)
                        .lineLimit(2)
                        .minimumScaleFactor(0.78)

                    Text(detail)
                        .font(.system(size: 10, weight: .regular))
                        .foregroundStyle(isSelected ? .white.opacity(0.7) : Color.black.opacity(0.45))
                        .lineLimit(2)
                        .minimumScaleFactor(0.76)

                    HStack(spacing: 4) {
                        Text("¥\(price.formatted())")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(isSelected ? .white : .black)

                        Spacer(minLength: 4)

                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(isSelected ? .white : Color.black.opacity(0.14))
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .frame(minHeight: 252, alignment: .top)
            .background {
                VStack(spacing: 0) {
                    Color.white.frame(height: 156 - 14)
                    isSelected ? Color.black : Color.white
                }
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(isSelected ? Color.black : Color.black.opacity(0.12), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

private func aestheticPartIconName(for partName: String) -> String {
    switch partName {
    case "机箱": return "rectangle.inset.filled"
    case "一体式水冷": return "drop"
    case "风扇套装", "风扇与控制器", "LCD 风扇", "LED 风扇": return "fanblades"
    case "副屏": return "display"
    case "定制线材", "霓虹线": return "cable.connector"
    default: return "square.stack.3d.up"
    }
}

#Preview {
    AestheticStyleOverviewView(styleID: "blackKnight", onClose: {}, onStartBuild: { _ in })
}
