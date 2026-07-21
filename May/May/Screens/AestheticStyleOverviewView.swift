import SwiftUI

struct AestheticStyleOverviewView: View {
    let styleID: String
    let onClose: () -> Void
    let onStartBuild: () -> Void

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
                            originalPrice: part.originalPrice(for: selectedColor),
                            selectedAlternativeID: selectedAlternatives[part.id],
                            onClose: dismissAlternatives,
                            onSelect: { alternative in
                                if let alternative {
                                    selectedAlternatives[part.id] = alternative.id
                                } else {
                                    selectedAlternatives.removeValue(forKey: part.id)
                                }
                                dismissAlternatives()
                            }
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
            .scaleEffect(CGFloat(style.heroScale(for: selectedColor)))
            .contentTransition(.opacity)
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
                Text("当前方案预算")
                    .font(.system(size: 10, weight: .regular))
                    .foregroundStyle(AppTheme.secondaryText)

                Text("¥\(totalPrice.formatted())")
                    .font(.system(size: 22, weight: .heavy))
                    .foregroundStyle(AppTheme.primaryText)
            }

            Spacer(minLength: 8)

            Button(action: onStartBuild) {
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
        guard let alternativeID = selectedAlternatives[part.id],
              let alternative = part.alternatives.first(where: { $0.id == alternativeID })
        else {
            return part.originalPrice(for: selectedColor)
        }

        return alternative.price
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
                Text("¥\(price.formatted())")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.primaryText)

                Button(action: action) {
                    Text("平替")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 54, height: 28)
                        .background(Color.black, in: RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(hasReplacement ? "更换平替，已选择" : "选择平替")
            }
        }
        .padding(.vertical, 12)
    }

    private var iconName: String {
        switch part.name {
        case "机箱": return "rectangle.inset.filled"
        case "一体式水冷": return "drop"
        case "风扇套装", "风扇与控制器", "LCD 风扇", "LED 风扇": return "fanblades"
        case "副屏": return "display"
        case "定制线材", "霓虹线": return "cable.connector"
        default: return "square.stack.3d.up"
        }
    }
}

private struct AestheticAlternativeModal: View {
    let part: AestheticStylePart
    let originalPrice: Int
    let selectedAlternativeID: String?
    let onClose: () -> Void
    let onSelect: (AestheticStyleAlternative?) -> Void

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

                        Text("请选择一个替代配件，价格会实时同步到方案预算。")
                            .font(.appBody)
                            .foregroundStyle(AppTheme.secondaryText)
                    }

                    replacementRow(
                        title: "当前方案配件",
                        detail: part.detail,
                        price: originalPrice,
                        isSelected: selectedAlternativeID == nil
                    ) {
                        onSelect(nil)
                    }

                    ForEach(part.alternatives) { alternative in
                        replacementRow(
                            title: alternative.name,
                            detail: alternative.detail,
                            price: alternative.price,
                            isSelected: selectedAlternativeID == alternative.id
                        ) {
                            onSelect(alternative)
                        }
                    }
                }
                .padding(20)
            }
        }
        .background(Color.white, in: RoundedRectangle(cornerRadius: 26))
        .clipShape(RoundedRectangle(cornerRadius: 26))
        .shadow(color: .black.opacity(0.2), radius: 30, y: 16)
    }

    private func replacementRow(
        title: String,
        detail: String,
        price: Int,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: "shippingbox")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(isSelected ? .white : AppTheme.primaryText)
                    .frame(width: 64, height: 64)
                    .background(
                        isSelected ? Color.white.opacity(0.12) : Color(white: 0.96),
                        in: RoundedRectangle(cornerRadius: 14)
                    )

                VStack(alignment: .leading, spacing: 5) {
                    Text(title)
                        .font(.appSubheadline)
                        .foregroundStyle(isSelected ? .white : AppTheme.primaryText)
                    Text(detail)
                        .font(.appCaption)
                        .foregroundStyle(isSelected ? .white.opacity(0.7) : AppTheme.secondaryText)
                }

                Spacer()

                Text("¥\(price.formatted())")
                    .font(.appSubheadline)
                    .foregroundStyle(isSelected ? .white : AppTheme.primaryText)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? .white : AppTheme.border)
            }
            .padding(14)
            .background(isSelected ? AppTheme.primaryText : AppTheme.surface, in: RoundedRectangle(cornerRadius: 16))
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? AppTheme.primaryText : AppTheme.border, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    AestheticStyleOverviewView(styleID: "blackKnight", onClose: {}, onStartBuild: {})
}
