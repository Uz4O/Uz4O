import SwiftUI

struct OnboardingChoiceView: View {
    let onFinish: (OnboardingProfile) -> Void

    @State private var selectedPreference: BuildPreference = .balanced
    @State private var hardwareProfile = HardwareProfile.skipped
    @State private var computerOwnership: ComputerOwnershipChoice = .noComputer
    @State private var step: OnboardingStep = .computerOwnership

    private let designWidth: CGFloat = 328

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                ProgressPill(isActive: step == .computerOwnership)
                ProgressPill(isActive: step == .preference)
                ProgressPill(isActive: step == .hardwareProfile)
                Spacer()
                Button("先跳过，进入 App") {
                    onFinish(.skipped)
                }
                .font(.appCaption)
                .foregroundStyle(AppTheme.secondaryText)
            }
            .frame(width: designWidth)
            .padding(.top, 20)

            TabView(selection: $step) {
                ComputerOwnershipStep(
                    onHasComputer: {
                        computerOwnership = .hasComputer
                        withAnimation(.easeInOut(duration: 0.2)) {
                            step = .preference
                        }
                    },
                    onNoComputer: {
                        computerOwnership = .noComputer
                        hardwareProfile = .skipped
                        withAnimation(.easeInOut(duration: 0.2)) {
                            step = .preference
                        }
                    }
                )
                .tag(OnboardingStep.computerOwnership)

                PreferenceStep(
                    selectedPreference: $selectedPreference,
                    primaryButtonTitle: computerOwnership.shouldCollectHardwareAfterPreference ? "继续" : "进入 App",
                    onBack: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            step = .computerOwnership
                        }
                    },
                    onFinish: {
                        if computerOwnership.shouldCollectHardwareAfterPreference {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                step = .hardwareProfile
                            }
                        } else {
                            onFinish(OnboardingProfile(preference: selectedPreference, hardwareProfile: .skipped))
                        }
                    }
                )
                .tag(OnboardingStep.preference)

                HardwareProfileStep(
                    hardwareProfile: $hardwareProfile,
                    onBack: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            step = .preference
                        }
                    },
                    onSkip: {
                        hardwareProfile = .skipped
                        onFinish(OnboardingProfile(preference: selectedPreference, hardwareProfile: .skipped))
                    },
                    onFinish: {
                        let savedProfile = HardwareProfile(
                            cpu: hardwareProfile.cpu,
                            gpu: hardwareProfile.gpu,
                            memory: hardwareProfile.memory,
                            storage: hardwareProfile.storage,
                            powerSupply: hardwareProfile.powerSupply
                        )

                        onFinish(OnboardingProfile(preference: selectedPreference, hardwareProfile: savedProfile))
                    }
                )
                .tag(OnboardingStep.hardwareProfile)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private enum OnboardingStep {
    case computerOwnership
    case preference
    case hardwareProfile
}

private struct ProgressPill: View {
    let isActive: Bool

    var body: some View {
        Capsule()
            .fill(isActive ? AppTheme.primaryText : AppTheme.border)
            .frame(width: isActive ? 28 : 10, height: 5)
            .animation(.easeInOut(duration: 0.2), value: isActive)
    }
}

private struct ComputerOwnershipStep: View {
    let onHasComputer: () -> Void
    let onNoComputer: () -> Void

    private let designWidth: CGFloat = 328

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            Spacer(minLength: 40)

            VStack(alignment: .leading, spacing: 10) {
                Text("你现在有没有一台电脑？")
                    .font(.appLargeTitle)
                    .foregroundStyle(AppTheme.primaryText)
                    .fixedSize(horizontal: false, vertical: true)

                Text("如果有现有电脑，可以先记录配置；如果没有，可以直接跳过。")
                    .font(.appBody)
                    .foregroundStyle(AppTheme.secondaryText)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: 10) {
                OnboardingRouteCard(
                    title: "有，记录现有电脑",
                    subtitle: "之后看升级建议时，可以参考这台电脑的配置。",
                    icon: "desktopcomputer",
                    action: onHasComputer
                )

                OnboardingRouteCard(
                    title: "没有电脑，先跳过",
                    subtitle: "先进入偏好选择，不需要填写或选择硬件配置。",
                    icon: "forward.end",
                    action: onNoComputer
                )
            }

            Spacer()
        }
        .frame(width: designWidth)
        .frame(maxWidth: .infinity)
    }
}

private struct PreferenceStep: View {
    @Binding var selectedPreference: BuildPreference
    let primaryButtonTitle: String
    let onBack: () -> Void
    let onFinish: () -> Void

    private let designWidth: CGFloat = 328

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack {
                Button(action: onBack) {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                        Text("返回")
                    }
                    .font(.appSubheadline)
                    .foregroundStyle(AppTheme.secondaryText)
                }
                .buttonStyle(.plain)

                Spacer()
            }
            .padding(.top, 24)

            VStack(alignment: .leading, spacing: 10) {
                Text("你希望电脑更偏哪种风格？")
                    .font(.appLargeTitle)
                    .foregroundStyle(AppTheme.primaryText)
                    .fixedSize(horizontal: false, vertical: true)

                Text("这个偏好会影响后续配置建议，你也可以之后再修改。")
                    .font(.appBody)
                    .foregroundStyle(AppTheme.secondaryText)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: 10) {
                ForEach(BuildPreference.allCases) { preference in
                    OnboardingOptionCard(
                        title: preference.title,
                        subtitle: preference.subtitle,
                        icon: preference.icon,
                        isSelected: selectedPreference == preference
                    ) {
                        selectedPreference = preference
                    }
                }
            }

            Spacer()

            PrimaryButton(title: primaryButtonTitle, icon: "arrow.right", action: onFinish)
                .padding(.bottom, 28)
        }
        .frame(width: designWidth)
        .frame(maxWidth: .infinity)
    }
}

private struct HardwareProfileStep: View {
    @Binding var hardwareProfile: HardwareProfile
    let onBack: () -> Void
    let onSkip: () -> Void
    let onFinish: () -> Void

    @State private var selectedCategory: HardwareOptionCategory?

    private let designWidth: CGFloat = 328

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Button(action: onBack) {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                        Text("返回")
                    }
                    .font(.appSubheadline)
                    .foregroundStyle(AppTheme.secondaryText)
                }
                .buttonStyle(.plain)

                Spacer()

                Button("直接跳过") {
                    onSkip()
                }
                .font(.appCaption)
                .foregroundStyle(AppTheme.secondaryText)
            }
            .padding(.top, 24)

            VStack(alignment: .leading, spacing: 8) {
                Text("记录你的电脑配置")
                    .font(.appTitle)
                    .foregroundStyle(AppTheme.primaryText)

                Text("选择你知道的配置，不确定的地方选“不知道”。")
                    .font(.appBody)
                    .foregroundStyle(AppTheme.secondaryText)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }

            ScrollView(showsIndicators: false) {
                VStack(spacing: 12) {
                    ForEach(HardwareProfileOptions.categories, id: \.title) { category in
                        HardwareChoiceRow(
                            category: category,
                            selectedValue: binding(for: category.title).wrappedValue
                        ) {
                            selectedCategory = category
                        }
                    }
                }
                .padding(.bottom, 10)
            }

            PrimaryButton(title: "保存并继续", icon: "arrow.right", action: onFinish)
                .padding(.bottom, 28)
        }
        .frame(width: designWidth)
        .frame(maxWidth: .infinity)
        .sheet(item: $selectedCategory) { category in
            HardwareOptionSheet(
                category: category,
                selectedValue: binding(for: category.title)
            )
            .presentationDetents([.medium])
        }
    }

    private func binding(for title: String) -> Binding<String> {
        switch title {
        case "CPU":
            return $hardwareProfile.cpu
        case "显卡":
            return $hardwareProfile.gpu
        case "内存":
            return $hardwareProfile.memory
        case "硬盘":
            return $hardwareProfile.storage
        default:
            return $hardwareProfile.powerSupply
        }
    }
}

private struct HardwareChoiceRow: View {
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
                        .frame(width: 32, height: 32)
                        .background(AppTheme.softSurface, in: RoundedRectangle(cornerRadius: 9))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(category.title)
                            .font(.appSubheadline)
                            .foregroundStyle(AppTheme.primaryText)
                        Text(selectedValue)
                            .font(.appCaption)
                            .foregroundStyle(AppTheme.secondaryText)
                            .lineLimit(1)
                    }

                    Spacer()

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

private struct HardwareOptionSheet: View {
    let category: HardwareOptionCategory
    @Binding var selectedValue: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Capsule()
                .fill(AppTheme.border)
                .frame(width: 42, height: 5)
                .frame(maxWidth: .infinity)
                .padding(.top, 10)

            HStack(spacing: 10) {
                Image(systemName: category.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppTheme.primaryText)
                    .frame(width: 34, height: 34)
                    .background(AppTheme.softSurface, in: RoundedRectangle(cornerRadius: 10))

                Text("选择\(category.title)")
                    .font(.appHeadline)
                    .foregroundStyle(AppTheme.primaryText)

                Spacer()
            }

            VStack(spacing: 10) {
                ForEach(category.options, id: \.self) { option in
                    Button {
                        selectedValue = option
                        dismiss()
                    } label: {
                        HStack(spacing: 12) {
                            Text(option)
                                .font(.appBody)
                                .foregroundStyle(AppTheme.primaryText)

                            Spacer()

                            if selectedValue == option {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(AppTheme.success)
                            }
                        }
                        .padding(.horizontal, 14)
                        .frame(height: 44)
                        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(selectedValue == option ? AppTheme.primaryText : AppTheme.border, lineWidth: selectedValue == option ? 1.4 : 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 20)
        .background(AppTheme.background)
    }
}

private struct OnboardingRouteCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(AppTheme.primaryText, in: RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 5) {
                    Text(title)
                        .font(.appHeadline)
                        .foregroundStyle(AppTheme.primaryText)
                    Text(subtitle)
                        .font(.appBody)
                        .foregroundStyle(AppTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(AppTheme.secondaryText)
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 92, alignment: .leading)
            .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 18))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(AppTheme.border, lineWidth: 1)
            )
            .modifier(AppTheme.cardShadow)
        }
        .buttonStyle(.plain)
    }
}

private struct OnboardingOptionCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(isSelected ? .white : AppTheme.primaryText)
                    .frame(width: 42, height: 42)
                    .background(isSelected ? AppTheme.primaryText : AppTheme.softSurface, in: RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 5) {
                    Text(title)
                        .font(.appHeadline)
                        .foregroundStyle(AppTheme.primaryText)
                    Text(subtitle)
                        .font(.appBody)
                        .foregroundStyle(AppTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(isSelected ? AppTheme.success : AppTheme.border)
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 92, alignment: .leading)
            .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 18))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(isSelected ? AppTheme.primaryText : AppTheme.border, lineWidth: isSelected ? 1.5 : 1)
            )
            .modifier(AppTheme.cardShadow)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    OnboardingChoiceView(onFinish: { _ in })
}
