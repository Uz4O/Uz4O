import SwiftUI

struct OnboardingChoiceView: View {
    let onFinish: (OnboardingProfile) -> Void

    @State private var selectedPreference: BuildPreference = .balanced
    @State private var hardwareProfile: HardwareProfile
    @State private var computerOwnership: ComputerOwnershipChoice = .noComputer
    @State private var step: OnboardingStep = .computerOwnership

    init(initialHardwareProfile: HardwareProfile = .skipped, onFinish: @escaping (OnboardingProfile) -> Void) {
        self.onFinish = onFinish
        _hardwareProfile = State(initialValue: initialHardwareProfile)
    }

    var body: some View {
        GeometryReader { proxy in
            let contentWidth = AppTheme.responsiveContentWidth(for: proxy.size.width)

            ZStack {
                OnboardingBackground()

                VStack(spacing: 0) {
                    HStack(spacing: 8) {
                        ProgressPill(isActive: step == .computerOwnership)
                        ProgressPill(isActive: step == .hardwareProfile)
                        ProgressPill(isActive: step == .preference)
                        Spacer()
                        Button {
                            onFinish(.skipped)
                        } label: {
                            HStack(spacing: 4) {
                                Text("先跳过，进入 App")
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 11, weight: .bold))
                            }
                        }
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(AppTheme.secondaryText)
                    }
                    .frame(width: contentWidth)
                    .padding(.top, 20)

                    TabView(selection: $step) {
                        ComputerOwnershipStep(
                            contentWidth: contentWidth,
                            onHasComputer: {
                                computerOwnership = .hasComputer
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    step = .hardwareProfile
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

                        HardwareProfileStep(
                            contentWidth: contentWidth,
                            hardwareProfile: $hardwareProfile,
                            onBack: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    step = .computerOwnership
                                }
                            },
                            onSkip: {
                                hardwareProfile = .skipped
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    step = .preference
                                }
                            },
                            onFinish: {
                                hardwareProfile = savedHardwareProfile()
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    step = .preference
                                }
                            }
                        )
                        .tag(OnboardingStep.hardwareProfile)

                        PreferenceStep(
                            contentWidth: contentWidth,
                            selectedPreference: $selectedPreference,
                            primaryButtonTitle: "进入 App",
                            onBack: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    step = computerOwnership.shouldCollectHardwareBeforePreference ? .hardwareProfile : .computerOwnership
                                }
                            },
                            onFinish: {
                                onFinish(OnboardingProfile(preference: selectedPreference, hardwareProfile: hardwareProfile))
                            }
                        )
                        .tag(OnboardingStep.preference)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func savedHardwareProfile() -> HardwareProfile {
        HardwareProfile(
            cpu: hardwareProfile.cpu,
            gpu: hardwareProfile.gpu,
            motherboard: hardwareProfile.motherboard,
            memory: hardwareProfile.memory,
            storage: hardwareProfile.storage,
            powerSupply: hardwareProfile.powerSupply
        )
    }
}

private enum OnboardingStep {
    case computerOwnership
    case hardwareProfile
    case preference
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
    let contentWidth: CGFloat
    let onHasComputer: () -> Void
    let onNoComputer: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 86)

            VStack(spacing: 14) {
                Text("你现在有没有一台电脑？")
                    .font(.appLargeTitle)
                    .foregroundStyle(AppTheme.primaryText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Text("如果有现有电脑，可以先记录配置；\n如果没有，可以直接跳过。")
                    .font(.appBody)
                    .foregroundStyle(AppTheme.secondaryText)
                    .lineSpacing(6)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            OnboardingComputerIllustration()
                .frame(width: contentWidth, height: 172)
                .padding(.top, 42)

            VStack(spacing: 12) {
                OnboardingRouteCard(
                    title: "有，记录现有电脑",
                    subtitle: "之后看升级建议时，\n可以参考这台电脑的配置。",
                    icon: "desktopcomputer",
                    action: onHasComputer
                )

                OnboardingRouteCard(
                    title: "没有电脑，先跳过",
                    subtitle: "先进入偏好选择，\n不需要填写或选择硬件配置。",
                    icon: "forward.end",
                    action: onNoComputer
                )
            }
            .padding(.top, 22)

            Spacer(minLength: 28)

            HStack(spacing: 8) {
                Image(systemName: "lightbulb")
                    .font(.system(size: 12, weight: .regular))
                Text("后续在「我的」页面随时可以补充配置")
                    .font(.appCaption)
            }
            .foregroundStyle(AppTheme.mutedText)
            .padding(.bottom, 88)
        }
        .frame(width: contentWidth)
        .frame(maxWidth: .infinity)
    }
}

private struct PreferenceStep: View {
    let contentWidth: CGFloat
    @Binding var selectedPreference: BuildPreference
    let primaryButtonTitle: String
    let onBack: () -> Void
    let onFinish: () -> Void

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
        .frame(width: contentWidth)
        .frame(maxWidth: .infinity)
    }
}

private struct HardwareProfileStep: View {
    let contentWidth: CGFloat
    @Binding var hardwareProfile: HardwareProfile
    let onBack: () -> Void
    let onSkip: () -> Void
    let onFinish: () -> Void

    @State private var selectedCategory: HardwareOptionCategory?

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
        .frame(width: contentWidth)
        .frame(maxWidth: .infinity)
        .sheet(item: $selectedCategory) { category in
            HardwarePickerSheet(
                title: category.title,
                icon: category.icon,
                filters: filters(for: category),
                contextMessage: contextMessage(for: category),
                selectedValue: binding(for: category.title)
            )
            .presentationDetents([.large])
        }
    }

    private func binding(for title: String) -> Binding<String> {
        Binding(
            get: { hardwareProfile.value(for: title) },
            set: { hardwareProfile.setValue($0, for: title) }
        )
    }

    private func filters(for category: HardwareOptionCategory) -> [HardwareCatalogFilter] {
        category.title == "主板"
            ? HardwareCatalog.motherboardFilters(compatibleWithCPU: hardwareProfile.cpu)
            : HardwareCatalog.filters(for: category.title)
    }

    private func contextMessage(for category: HardwareOptionCategory) -> String? {
        guard category.title == "主板", let socket = HardwareCatalog.cpuSocket(for: hardwareProfile.cpu) else { return nil }
        return "已根据 \(hardwareProfile.cpu) 筛选 \(socket) 兼容主板"
    }
}

private struct HardwareChoiceRow: View {
    let category: HardwareOptionCategory
    let selectedValue: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
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
            .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(AppTheme.border.opacity(0.45), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
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

private struct OnboardingBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.981, green: 0.989, blue: 0.990),
                    Color(red: 0.951, green: 0.968, blue: 0.972)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            BottomWave(offset: 18, opacity: 0.34)
            BottomWave(offset: 54, opacity: 0.18)
        }
        .ignoresSafeArea()
    }
}

private struct BottomWave: View {
    let offset: CGFloat
    let opacity: Double

    var body: some View {
        GeometryReader { proxy in
            Path { path in
                let width = proxy.size.width
                let height = proxy.size.height
                let baseY = height - 104 + offset

                path.move(to: CGPoint(x: 0, y: baseY))
                path.addCurve(
                    to: CGPoint(x: width, y: baseY - 28),
                    control1: CGPoint(x: width * 0.28, y: baseY + 74),
                    control2: CGPoint(x: width * 0.64, y: baseY - 86)
                )
                path.addLine(to: CGPoint(x: width, y: height))
                path.addLine(to: CGPoint(x: 0, y: height))
                path.closeSubpath()
            }
            .fill(Color(red: 0.886, green: 0.916, blue: 0.938).opacity(opacity))
            .blur(radius: 18)
        }
    }
}

private struct OnboardingComputerIllustration: View {
    var body: some View {
        Image("OnboardingComputerIllustration")
            .resizable()
            .scaledToFit()
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
