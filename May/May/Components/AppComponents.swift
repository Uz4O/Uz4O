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
            .background(AppTheme.primaryButton, in: RoundedRectangle(cornerRadius: AppTheme.controlRadius))
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
        .accessibilityLabel("发布帖子")
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

enum AppTab: String, CaseIterable {
    case home = "首页"
    case community = "社区"
    case builds = "配置"
    case profile = "我的"

    func icon(isSelected: Bool) -> String {
        switch self {
        case .home:
            return isSelected ? "house.fill" : "house"
        case .community:
            return isSelected ? "bubble.left.and.bubble.right.fill" : "bubble.left.and.bubble.right"
        case .builds:
            return isSelected ? "doc.text.fill" : "doc.text"
        case .profile:
            return isSelected ? "person.fill" : "person"
        }
    }
}

struct BottomTabBar: View {
    @Binding var selectedTab: AppTab
    var onSelect: ((AppTab) -> Void)?
    var onComposePost: (() -> Void)?

    var body: some View {
        HStack {
            ForEach([AppTab.home, .community], id: \.self) { tab in
                tabButton(tab)
            }

            PostComposerButton(size: 48, iconSize: 22) {
                onComposePost?()
            }
            .frame(maxWidth: .infinity)
            .offset(y: -10)

            ForEach([AppTab.builds, .profile], id: \.self) { tab in
                tabButton(tab)
            }
        }
        .padding(.horizontal, 8)
        .frame(height: 64)
        .background(.white, in: RoundedRectangle(cornerRadius: 32))
        .modifier(AppTheme.cardShadow)
    }

    private func tabButton(_ tab: AppTab) -> some View {
        Button {
            selectedTab = tab
            onSelect?(tab)
        } label: {
            VStack(spacing: 4) {
                Image(systemName: tab.icon(isSelected: selectedTab == tab))
                    .font(.system(size: 17, weight: .semibold))
                    .frame(width: 24, height: 20)
                Text(tab.rawValue)
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundStyle(selectedTab == tab ? AppTheme.primaryText : AppTheme.secondaryText)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }
}

struct MascotAvatar: View {
    var size: CGFloat = 42

    var body: some View {
        Image("RobotMascot")
            .resizable()
            .scaledToFill()
            .frame(width: size, height: size)
            .background(Color.white)
            .clipShape(Circle())
            .overlay(Circle().stroke(AppTheme.border, lineWidth: 0.8))
    }
}

struct DetailedPartRow: View {
    let part: PCPart

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            PartRow(part: part)

            if !part.reason.isEmpty {
                Text(part.reason)
                    .font(.appCaption)
                    .foregroundStyle(AppTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !part.alternative.isEmpty {
                HStack(spacing: 6) {
                    Text("可替代")
                        .font(.appCaption.weight(.semibold))
                        .foregroundStyle(AppTheme.secondaryText)
                    Text(part.alternative)
                        .font(.appCaption.weight(.semibold))
                        .foregroundStyle(AppTheme.primaryText)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(AppTheme.softSurface, in: Capsule())
            }
        }
        .padding(.vertical, 4)
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
