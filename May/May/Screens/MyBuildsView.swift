import SwiftUI

struct MyBuildsView: View {
    let hardwareProfile: HardwareProfile
    @Binding var selectedTab: AppTab
    let onSelectTab: (AppTab) -> Void
    let onOpenPlan: () -> Void
    let onCreate: () -> Void
    let onOpenComputerProfile: () -> Void

    @State private var selectedSection = ConfigHubSection.defaultSelection

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("配置")
                        .font(.system(size: 28, weight: .heavy))
                        .foregroundStyle(AppTheme.primaryText)
                    Text("管理 AI 生成的配置和现在自己的配置")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(AppTheme.secondaryText)
                }

                Spacer()

                Button(action: onCreate) {
                    Image(systemName: "plus")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(AppTheme.primaryText)
                        .frame(width: 42, height: 42)
                        .background(AppTheme.surface, in: Circle())
                        .modifier(AppTheme.cardShadow)
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 10)

            ConfigHubSegmentedPicker(selectedSection: $selectedSection)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    switch selectedSection {
                    case .aiBuilds:
                        AIBuildsSection(
                            plans: AppMockData.savedPlans,
                            onOpenPlan: onOpenPlan,
                            onCreate: onCreate
                        )
                    case .currentComputer:
                        CurrentComputerSection(
                            hardwareProfile: hardwareProfile,
                            onEdit: onOpenComputerProfile,
                            onCreate: onCreate
                        )
                    }
                }
                .padding(.bottom, 4)
                .transaction { transaction in
                    transaction.animation = nil
                }
            }

            Spacer(minLength: 0)

            BottomTabBar(selectedTab: $selectedTab, onSelect: onSelectTab)
        }
        .padding(.horizontal, AppTheme.screenPadding)
        .padding(.bottom, 12)
    }
}

private struct ConfigHubSegmentedPicker: View {
    @Binding var selectedSection: ConfigHubSection
    @Namespace private var animation

    var body: some View {
        HStack(spacing: 0) {
            ForEach(ConfigHubSection.allCases) { section in
                Button {
                    selectedSection = section
                } label: {
                    ZStack {
                        if selectedSection == section {
                            Capsule()
                                .fill(AppTheme.surface)
                                .matchedGeometryEffect(id: "configHubSectionSelection", in: animation)
                                .shadow(color: Color.black.opacity(0.08), radius: 18, x: 0, y: 10)
                        }

                        Text(section.title)
                            .font(.system(size: 15, weight: selectedSection == section ? .bold : .semibold))
                            .foregroundStyle(selectedSection == section ? AppTheme.primaryText : AppTheme.secondaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.68)
                            .padding(.horizontal, 5)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 42)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(AppTheme.softSurface.opacity(0.72), in: Capsule())
        .overlay(
            Capsule()
                .stroke(AppTheme.border.opacity(0.75), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.03), radius: 14, x: 0, y: 8)
        .animation(.spring(response: 0.34, dampingFraction: 0.86), value: selectedSection)
    }
}

private struct AIBuildsSection: View {
    let plans: [BuildPlan]
    let onOpenPlan: () -> Void
    let onCreate: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            if plans.isEmpty {
                EmptyBuildState(onCreate: onCreate)
            } else {
                ConfigPlanList(plans: plans, onOpenPlan: onOpenPlan)
            }
        }
    }
}

private struct ConfigPlanList: View {
    let plans: [BuildPlan]
    let onOpenPlan: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 7) {
                    Text("AI 配置单")
                        .font(.system(size: 20, weight: .heavy))
                        .foregroundStyle(AppTheme.primaryText)
                    Text(ConfigHubSection.aiBuilds.subtitle)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(AppTheme.secondaryText)
                }

                Spacer()

                Text("\(plans.count) 个")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(AppTheme.primaryText)
                    .padding(.horizontal, 14)
                    .frame(height: 28)
                    .background(AppTheme.softSurface, in: Capsule())
            }
            .padding(.bottom, 12)

            ForEach(Array(plans.enumerated()), id: \.element.id) { index, plan in
                SavedPlanRow(plan: plan, onOpen: onOpenPlan)

                if index != plans.count - 1 {
                    ConfigDivider(leftPadding: 50)
                }
            }
        }
    }
}

private struct EmptyBuildState: View {
    let onCreate: () -> Void

    var body: some View {
        SoftCard(radius: 22) {
            VStack(spacing: 14) {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(AppTheme.secondaryText)
                Text("当前没有 AI 配置")
                    .font(.appHeadline)
                    .foregroundStyle(AppTheme.primaryText)
                Text("生成完配置后，可以在这里回来查看、对比和继续优化。")
                    .font(.appBody)
                    .foregroundStyle(AppTheme.secondaryText)
                    .multilineTextAlignment(.center)
                PrimaryButton(title: "生成第一张配置", icon: "sparkles", action: onCreate)
            }
            .padding(24)
        }
    }
}

private struct SavedPlanRow: View {
    let plan: BuildPlan
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: "doc.text")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(AppTheme.primaryText)
                    .frame(width: 34, height: 34)
                    .background(AppTheme.softSurface, in: RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 7) {
                    Text(plan.name)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(AppTheme.primaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.76)

                    Text("\(plan.budget) · \(plan.useCase)")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(AppTheme.secondaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.76)
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 7) {
                    Text(plan.totalPrice)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(AppTheme.primaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)

                    Text(plan.createdAt)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(AppTheme.secondaryText)
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(AppTheme.secondaryText)
            }
            .contentShape(Rectangle())
            .padding(.vertical, 14)
        }
        .buttonStyle(.plain)
    }
}

private struct CurrentComputerSection: View {
    let hardwareProfile: HardwareProfile
    let onEdit: () -> Void
    let onCreate: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 0) {
                ComputerConfigRow(title: "CPU", value: hardwareProfile.cpu, icon: "cpu", action: onEdit)
                ConfigDivider(leftPadding: 50)
                ComputerConfigRow(title: "显卡", value: hardwareProfile.gpu, icon: "display", action: onEdit)
                ConfigDivider(leftPadding: 50)
                ComputerConfigRow(title: "内存", value: hardwareProfile.memory, icon: "rectangle.stack", action: onEdit)
                ConfigDivider(leftPadding: 50)
                ComputerConfigRow(title: "电源", value: hardwareProfile.powerSupply, icon: "bolt", action: onEdit)
            }

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color(red: 0.36, green: 0.47, blue: 0.78))
                    Text("可以用它做什么")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(AppTheme.primaryText)
                }

                VStack(spacing: 0) {
                    ConfigUseCaseRow(icon: "chart.bar.xaxis", title: "看升级短板", subtitle: "判断当前电脑最该先换什么")
                    ConfigDivider(leftPadding: 50)
                    ConfigUseCaseRow(icon: "gamecontroller", title: "测游戏表现", subtitle: "结合分辨率和游戏估算体验")
                    ConfigDivider(leftPadding: 50)
                    ConfigUseCaseRow(icon: "arrow.left.arrow.right", title: "对比 AI 配置", subtitle: "看新配置相比当前电脑提升在哪")
                }
            }

            PrimaryButton(title: "生成一张可对比的 AI 配置", icon: "sparkles", action: onCreate)
        }
    }
}

private struct ComputerConfigRow: View {
    let title: String
    let value: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppTheme.primaryText)
                    .frame(width: 34, height: 34)
                    .background(AppTheme.softSurface, in: RoundedRectangle(cornerRadius: 10))

                Text(title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(AppTheme.primaryText)

                Spacer()

                Text(value)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(AppTheme.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(AppTheme.secondaryText)
            }
            .contentShape(Rectangle())
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
    }
}

private struct ConfigUseCaseRow: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(AppTheme.primaryText)
                .frame(width: 34, height: 34)
                .background(AppTheme.softSurface, in: RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(AppTheme.primaryText)
                Text(subtitle)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(AppTheme.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(AppTheme.secondaryText)
        }
        .padding(.vertical, 10)
    }
}

private struct ConfigDivider: View {
    var leftPadding: CGFloat = 0

    var body: some View {
        Rectangle()
            .fill(AppTheme.border.opacity(0.8))
            .frame(height: 1)
            .padding(.leading, leftPadding)
    }
}

#Preview {
    MyBuildsView(
        hardwareProfile: HardwareProfile(
            cpu: "Intel i7 / Ryzen 7",
            gpu: "RTX 4060 Ti / RTX 4070",
            memory: "32GB",
            storage: "1TB SSD",
            powerSupply: "650W"
        ),
        selectedTab: .constant(.builds),
        onSelectTab: { _ in },
        onOpenPlan: {},
        onCreate: {},
        onOpenComputerProfile: {}
    )
}
