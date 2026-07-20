import SwiftUI

struct ScreenHeader: View {
    let title: String
    var trailingIcon: String? = "slider.horizontal.3"
    let onBack: (() -> Void)?

    var body: some View {
        HStack(spacing: 14) {
            if let onBack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(AppTheme.primaryText)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
            }

            Text(title)
                .font(.appHeadline)
                .foregroundStyle(AppTheme.primaryText)

            Spacer()

            if let trailingIcon {
                Image(systemName: trailingIcon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppTheme.primaryText)
            }
        }
    }
}

struct PrimaryButton: View {
    let title: String
    var icon: String?
    let action: () -> Void
    var backgroundColor: Color = AppTheme.primaryButton

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(title)
                if let icon {
                    Image(systemName: icon)
                }
            }
            .font(.appSubheadline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(backgroundColor, in: RoundedRectangle(cornerRadius: AppTheme.controlRadius))
        }
        .buttonStyle(.plain)
    }
}

struct PostComposerButton: View {
    var size: CGFloat = 40
    var iconSize: CGFloat = 19
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: size, height: size)
                .background(Color.black, in: Circle())
                .shadow(color: Color.black.opacity(0.16), radius: 14, x: 0, y: 8)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("发布")
    }
}

struct ApplySavedProfileButton: View {
    let hasSavedProfile: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: hasSavedProfile ? "person.crop.circle.badge.checkmark" : "person.crop.circle.badge.questionmark")
                    .font(.system(size: 15, weight: .semibold))

                Text(hasSavedProfile ? "套用我的电脑配置" : "还没有电脑档案")
                    .font(.appSubheadline)

                Spacer()

                if hasSavedProfile {
                    Image(systemName: "arrow.down.to.line.compact")
                        .font(.system(size: 12, weight: .bold))
                }
            }
            .foregroundStyle(hasSavedProfile ? AppTheme.primaryText : AppTheme.secondaryText)
            .padding(.horizontal, 14)
            .frame(height: 44)
            .background(AppTheme.softSurface, in: RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(hasSavedProfile ? AppTheme.primaryText.opacity(0.18) : AppTheme.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(!hasSavedProfile)
    }
}

struct FlowStepIndicator: View {
    let currentStep: Int
    let totalSteps: Int
    let currentTitle: String

    var body: some View {
        HStack(spacing: 18) {
            Text("\(currentStep)/\(totalSteps)")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(AppTheme.primaryText)
                .frame(width: 48, alignment: .leading)

            HStack(spacing: 0) {
                ForEach(1...totalSteps, id: \.self) { index in
                    Circle()
                        .fill(index <= currentStep ? AppTheme.primaryText : AppTheme.border)
                        .frame(width: 8, height: 8)

                    if index < totalSteps {
                        Rectangle()
                            .fill(index < currentStep ? AppTheme.primaryText : AppTheme.border)
                            .frame(height: 1)
                    }
                }
            }

            Text(currentTitle)
                .font(.appBody.weight(.semibold))
                .foregroundStyle(AppTheme.secondaryText)
                .lineLimit(2)
                .multilineTextAlignment(.trailing)
                .frame(width: 68, alignment: .trailing)
        }
        .frame(maxWidth: .infinity)
    }
}

struct FlowIntroCard: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        SoftCard(radius: 18) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(AppTheme.primaryText)
                    .frame(width: 52, height: 52)
                    .background(AppTheme.softSurface, in: RoundedRectangle(cornerRadius: 16))

                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.appHeadline)
                        .foregroundStyle(AppTheme.primaryText)
                    Text(subtitle)
                        .font(.appBody)
                        .foregroundStyle(AppTheme.secondaryText)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(16)
        }
    }
}

struct HardwareSelectionRow: View {
    let category: HardwareOptionCategory
    let selectedValue: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            SoftCard(radius: 16) {
                HStack(spacing: 12) {
                    Image(systemName: category.icon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppTheme.primaryText)
                        .frame(width: 34, height: 34)
                        .background(AppTheme.softSurface, in: RoundedRectangle(cornerRadius: 10))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(category.title)
                            .font(.appSubheadline)
                            .foregroundStyle(AppTheme.primaryText)
                        Text(selectedValue)
                            .font(.appBody)
                            .foregroundStyle(AppTheme.secondaryText)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 8)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(AppTheme.secondaryText)
                }
                .padding(14)
            }
        }
        .buttonStyle(.plain)
    }
}

struct HardwareConfigIntro: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(alignment: .center, spacing: 24) {
            Image(systemName: icon)
                .font(.system(size: 25, weight: .regular))
                .foregroundStyle(AppTheme.primaryText)
                .frame(width: 56, height: 56)
                .background(AppTheme.softSurface, in: RoundedRectangle(cornerRadius: 16))

            VStack(alignment: .leading, spacing: 7) {
                Text(title)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(AppTheme.primaryText)

                Text(subtitle)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(AppTheme.secondaryText)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(.top, 12)
    }
}

struct HardwareProfileImportRow: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 15) {
                ZStack {
                    Image(systemName: "folder")
                        .font(.system(size: 24, weight: .regular))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 11, weight: .bold))
                        .offset(x: -1, y: 1)
                }
                .foregroundStyle(AppTheme.primaryText)
                .frame(width: 30, height: 34)

                Text("从电脑档案导入")
                    .font(.appSubheadline)
                    .foregroundStyle(AppTheme.primaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "chevron.right")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(AppTheme.primaryText)
            }
            .padding(.horizontal, 16)
            .frame(height: 50)
            .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(AppTheme.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

struct HardwareConfigurationList: View {
    let categories: [HardwareOptionCategory]
    let selectedValue: (String) -> String
    let onSelect: (HardwareOptionCategory) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(categories.enumerated()), id: \.element.id) { index, category in
                Button {
                    onSelect(category)
                } label: {
                    HardwareConfigurationRow(
                        category: category,
                        selectedValue: selectedValue(category.title)
                    )
                }
                .buttonStyle(.plain)

                if index != categories.count - 1 {
                    Divider()
                        .padding(.leading, 58)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(AppTheme.border.opacity(0.8), lineWidth: 1)
        )
    }
}

private struct HardwareConfigurationRow: View {
    let category: HardwareOptionCategory
    let selectedValue: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: category.icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AppTheme.primaryText)
                .frame(width: 34, height: 34)
                .background(AppTheme.softSurface, in: RoundedRectangle(cornerRadius: 9))

            VStack(alignment: .leading, spacing: 4) {
                Text(category.title)
                    .font(.appSubheadline)
                    .foregroundStyle(AppTheme.primaryText)
                Text(selectedValue)
                    .font(.appBody)
                    .foregroundStyle(AppTheme.secondaryText)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(AppTheme.secondaryText)
        }
        .frame(height: 58)
        .contentShape(Rectangle())
    }
}

struct FlowFeedbackBanner: View {
    let message: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(AppTheme.success)
            Text(message)
                .font(.appBody.weight(.semibold))
                .foregroundStyle(AppTheme.primaryText)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(AppTheme.softSurface, in: RoundedRectangle(cornerRadius: 12))
        .transition(.opacity.combined(with: .move(edge: .top)))
    }
}

struct SoftCard<Content: View>: View {
    let radius: CGFloat
    @ViewBuilder var content: Content

    init(radius: CGFloat = AppTheme.cardRadius, @ViewBuilder content: () -> Content) {
        self.radius = radius
        self.content = content()
    }

    var body: some View {
        content
            .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: radius))
            .modifier(AppTheme.cardShadow)
    }
}

struct FeatureCard: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            SoftCard(radius: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(title)
                        .font(.appHeadline)
                        .foregroundStyle(AppTheme.primaryText)
                        .lineLimit(2)

                    Text(subtitle)
                        .font(.appCaption)
                        .foregroundStyle(AppTheme.secondaryText)

                    Spacer()

                    HStack {
                        Spacer()
                        Image(systemName: systemImage)
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(AppTheme.primaryText)
                            .frame(width: 54, height: 54)
                            .background(AppTheme.softSurface, in: RoundedRectangle(cornerRadius: 16))
                    }
                }
                .padding(18)
                .frame(maxWidth: .infinity, minHeight: 154, alignment: .topLeading)
            }
        }
        .buttonStyle(.plain)
    }
}

struct PartRow: View {
    let part: PCPart
    var showsCheckmark = false

    var body: some View {
        HStack(spacing: 13) {
            Image(systemName: part.icon)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(part.accent, in: RoundedRectangle(cornerRadius: 7))

            VStack(alignment: .leading, spacing: 3) {
                Text(part.category)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.primaryText)
                Text(part.model)
                    .font(.appCaption)
                    .foregroundStyle(AppTheme.secondaryText)
                    .lineLimit(2)
            }

            Spacer()

            if showsCheckmark {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(AppTheme.success)
                    .font(.system(size: 15))
            } else {
                Text(part.price)
                    .font(.appCaption.weight(.bold))
                    .foregroundStyle(AppTheme.primaryText)
            }
        }
    }
}

struct LiquidGlassSegmentedPicker<Option: Hashable>: View {
    let options: [Option]
    @Binding var selection: Option
    var height: CGFloat = 42
    var spacing: CGFloat = 4
    var padding: CGFloat = 5
    var showsSelectionDot = false
    var title: (Option) -> String

    @State private var liquidStretch: CGFloat = 0
    @State private var liquidDirection: CGFloat = 1

    var body: some View {
        ZStack(alignment: .leading) {
            GeometryReader { geometry in
                selectionLayer(in: geometry.size)
            }
            .allowsHitTesting(false)

            HStack(spacing: spacing) {
                ForEach(options, id: \.self) { option in
                    optionButton(option)
                }
            }
        }
        .frame(height: height)
        .padding(padding)
        .background(.ultraThinMaterial, in: Capsule())
        .background(AppTheme.softSurface.opacity(0.82), in: Capsule())
        .overlay(
            Capsule()
                .stroke(AppTheme.border.opacity(0.82), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.035), radius: 14, x: 0, y: 8)
    }

    private func selectionLayer(in size: CGSize) -> some View {
        let count = max(options.count, 1)
        let totalSpacing = spacing * CGFloat(max(count - 1, 0))
        let pillWidth = max((size.width - totalSpacing) / CGFloat(count), 0)
        let selectedIndex = options.firstIndex(of: selection) ?? 0

        return LiquidGlassSegmentedSelection(
            stretch: liquidStretch,
            direction: liquidDirection,
            cornerRadius: height / 2
        )
        .frame(width: pillWidth, height: height)
        .offset(x: CGFloat(selectedIndex) * (pillWidth + spacing))
        .animation(.spring(response: 0.52, dampingFraction: 0.70), value: selectedIndex)
    }

    private func optionButton(_ option: Option) -> some View {
        let isSelected = selection == option

        return Button {
            select(option)
        } label: {
            HStack(spacing: 8) {
                if showsSelectionDot {
                    Circle()
                        .fill(isSelected ? AppTheme.primaryText : Color.clear)
                        .frame(width: 15, height: 15)
                        .overlay(
                            Circle()
                                .stroke(isSelected ? Color.clear : AppTheme.secondaryText, lineWidth: 2)
                        )
                }

                Text(title(option))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .font(.system(size: 13, weight: isSelected ? .bold : .semibold))
            .foregroundStyle(isSelected ? AppTheme.primaryText : AppTheme.secondaryText)
            .padding(.horizontal, 6)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func select(_ option: Option) {
        guard option != selection else { return }
        let oldIndex = options.firstIndex(of: selection) ?? 0
        let newIndex = options.firstIndex(of: option) ?? oldIndex

        liquidDirection = newIndex >= oldIndex ? 1 : -1
        withAnimation(.spring(response: 0.42, dampingFraction: 0.62)) {
            liquidStretch = 1
            selection = option
        }
        withAnimation(.spring(response: 0.62, dampingFraction: 0.56).delay(0.16)) {
            liquidStretch = 0
        }
    }
}

private struct LiquidGlassSegmentedSelection: View {
    let stretch: CGFloat
    let direction: CGFloat
    let cornerRadius: CGFloat

    var body: some View {
        ZStack {
            Capsule()
                .fill(Color.white.opacity(0.24))
                .scaleEffect(x: 1 + progress * 0.72, y: 1 - progress * 0.16, anchor: stretchAnchor)
                .offset(x: -direction * progress * 18)
                .blur(radius: progress * 3)
                .opacity(Double(progress) * 0.48)

            LiquidGlassSelection(
                stretch: stretch,
                direction: direction,
                cornerRadius: cornerRadius
            )
            .scaleEffect(x: 1 + progress * 0.22, y: 1 - progress * 0.08, anchor: stretchAnchor)

            Capsule()
                .stroke(Color.white.opacity(0.72), lineWidth: 1)
                .scaleEffect(x: 1 + progress * 0.2, y: 1 - progress * 0.06, anchor: stretchAnchor)
                .blur(radius: 0.5)
                .opacity(Double(progress) * 0.36)
        }
    }

    private var progress: CGFloat {
        min(max(stretch, 0), 1)
    }

    private var stretchAnchor: UnitPoint {
        direction > 0 ? .leading : .trailing
    }
}

private struct LiquidGlassSelection: View {
    let stretch: CGFloat
    let direction: CGFloat
    let cornerRadius: CGFloat

    var body: some View {
        LightLiquidGlassSelection(stretch: stretch, direction: direction)
    }
}

private struct LightLiquidGlassSelection: View {
    let stretch: CGFloat
    let direction: CGFloat

    var body: some View {
        ZStack {
            Capsule()
                .fill(Color.white.opacity(0.86))

            Capsule()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.92),
                            Color.white.opacity(0.56),
                            AppTheme.softSurface.opacity(0.32)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Capsule()
                .stroke(Color.white.opacity(0.92), lineWidth: 1)

            ripple
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: rippleAlignment)
        }
        .scaleEffect(x: 1 + stretch * 0.13, y: 1 - stretch * 0.035)
        .shadow(color: Color.black.opacity(0.08), radius: 14, x: 0, y: 8)
        .shadow(color: Color.white.opacity(0.72), radius: 10, x: 0, y: -3)
    }

    private var rippleAlignment: Alignment {
        direction > 0 ? .trailing : .leading
    }

    private var ripple: some View {
        Circle()
            .fill(Color.white.opacity(0.62))
            .frame(width: 22 + stretch * 12, height: 22 + stretch * 5)
            .blur(radius: 0.6)
            .offset(x: direction * (8 + stretch * 7))
            .opacity(0.28 + stretch * 0.34)
    }
}

struct MascotAvatar: View {
    var size: CGFloat = 42

    var body: some View {
        Image(systemName: "person.fill")
            .font(.system(size: size * 0.42, weight: .medium))
            .foregroundStyle(Color.white)
            .frame(width: size, height: size)
            .background(Color.black)
            .clipShape(Circle())
            .overlay(Circle().stroke(AppTheme.border, lineWidth: 0.8))
    }
}

struct PCIllustration: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.30))
                .frame(width: 112, height: 132)

            RoundedRectangle(cornerRadius: 8)
                .fill(LinearGradient(
                    colors: [Color(red: 0.96, green: 0.98, blue: 1.0), Color(red: 0.72, green: 0.78, blue: 0.86)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .frame(width: 88, height: 114)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(red: 0.82, green: 0.86, blue: 0.91), lineWidth: 1)
                )
                .shadow(color: Color(red: 0.54, green: 0.62, blue: 0.75).opacity(0.25), radius: 18, x: 0, y: 12)

            VStack(spacing: 7) {
                ForEach(0..<3) { _ in
                    Circle()
                        .fill(.white)
                        .frame(width: 22, height: 22)
                        .overlay(Circle().stroke(Color(red: 0.70, green: 0.76, blue: 0.84), lineWidth: 3))
                }
            }
            .offset(x: 20)

            RoundedRectangle(cornerRadius: 4)
                .fill(Color(red: 0.85, green: 0.90, blue: 0.96).opacity(0.62))
                .frame(width: 48, height: 92)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.white.opacity(0.65), lineWidth: 1)
                )
                .offset(x: -16)

            VStack(spacing: 13) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color(red: 0.45, green: 0.56, blue: 0.72).opacity(0.42))
                    .frame(width: 28, height: 10)
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color(red: 0.45, green: 0.56, blue: 0.72).opacity(0.35))
                    .frame(width: 34, height: 12)
            }
            .offset(x: -18, y: 10)
        }
    }
}
