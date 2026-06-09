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
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text("配置")
                        .font(.system(size: 29, weight: .heavy))
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
                        .frame(width: 40, height: 40)
                        .background(AppTheme.surface.opacity(0.92), in: RoundedRectangle(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(AppTheme.border.opacity(0.9), lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(0.06), radius: 14, x: 0, y: 8)
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 12)

            ConfigHubSegmentedPicker(selectedSection: $selectedSection)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
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
                            RoundedRectangle(cornerRadius: 13)
                                .fill(AppTheme.surface)
                                .matchedGeometryEffect(id: "configHubSectionSelection", in: animation)
                                .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 6)
                        }

                        Text(section.title)
                            .font(.system(size: 15, weight: selectedSection == section ? .bold : .semibold))
                            .foregroundStyle(selectedSection == section ? AppTheme.primaryText : AppTheme.secondaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.68)
                            .padding(.horizontal, 5)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 38)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(AppTheme.softSurface.opacity(0.74), in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(AppTheme.border.opacity(0.75), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.025), radius: 10, x: 0, y: 6)
        .animation(.spring(response: 0.34, dampingFraction: 0.86), value: selectedSection)
    }
}

private struct AIBuildsSection: View {
    let plans: [BuildPlan]
    let onOpenPlan: () -> Void
    let onCreate: () -> Void

    var body: some View {
        VStack(spacing: 12) {
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
        ConfigPanel {
            VStack(spacing: 0) {
                ConfigSectionHeader(
                    title: "AI 配置单",
                    subtitle: ConfigHubSection.aiBuilds.subtitle,
                    trailing: "\(plans.count) 个"
                )
                .padding(.bottom, 6)

                ForEach(Array(plans.enumerated()), id: \.element.id) { index, plan in
                    SavedPlanRow(plan: plan, onOpen: onOpenPlan)

                    if index != plans.count - 1 {
                        ConfigDivider(leftPadding: 48)
                    }
                }
            }
        }
    }
}

private struct ConfigPanel<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(14)
            .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 18))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(AppTheme.border.opacity(0.8), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.04), radius: 18, x: 0, y: 10)
    }
}

private struct ConfigSectionHeader: View {
    let title: String
    let subtitle: String?
    var trailing: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(AppTheme.primaryText)

                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(AppTheme.secondaryText)
                }
            }

            Spacer()

            if let trailing {
                Text(trailing)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(AppTheme.secondaryText)
                    .padding(.horizontal, 9)
                    .frame(height: 24)
                    .background(AppTheme.softSurface, in: Capsule())
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
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppTheme.primaryText)
                    .frame(width: 32, height: 32)
                    .background(AppTheme.softSurface, in: RoundedRectangle(cornerRadius: 9))

                VStack(alignment: .leading, spacing: 5) {
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

                VStack(alignment: .trailing, spacing: 5) {
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
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }
}

private struct CurrentComputerSection: View {
    let hardwareProfile: HardwareProfile
    let onEdit: () -> Void
    let onCreate: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            ConfigPanel {
                VStack(spacing: 0) {
                    ConfigSectionHeader(title: "当前电脑", subtitle: nil, trailing: hardwareProfile.wasSkipped ? "待补充" : "已记录")
                        .padding(.bottom, 6)

                    ComputerConfigRow(title: "CPU", value: hardwareProfile.cpu, icon: "cpu", action: onEdit)
                    ConfigDivider(leftPadding: 48)
                    ComputerConfigRow(title: "显卡", value: hardwareProfile.gpu, icon: "display", action: onEdit)
                    ConfigDivider(leftPadding: 48)
                    ComputerConfigRow(title: "主板", value: hardwareProfile.motherboard, icon: "menucard", action: onEdit)
                    ConfigDivider(leftPadding: 48)
                    ComputerConfigRow(title: "内存", value: hardwareProfile.memory, icon: "rectangle.stack", action: onEdit)
                    ConfigDivider(leftPadding: 48)
                    ComputerConfigRow(title: "电源", value: hardwareProfile.powerSupply, icon: "bolt", action: onEdit)
                }
            }

            ConfigPanel {
                VStack(spacing: 0) {
                    ConfigSectionHeader(title: "可以用它做什么", subtitle: nil, trailing: nil)
                        .padding(.bottom, 6)

                    ConfigUseCaseRow(icon: "chart.bar.xaxis", title: "看升级短板", subtitle: "判断当前电脑最该先换什么")
                    ConfigDivider(leftPadding: 48)
                    ConfigUseCaseRow(icon: "gamecontroller", title: "测游戏表现", subtitle: "结合分辨率和游戏估算体验")
                    ConfigDivider(leftPadding: 48)
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
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.primaryText)
                    .frame(width: 30, height: 30)
                    .background(AppTheme.softSurface.opacity(0.9), in: RoundedRectangle(cornerRadius: 8))

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
            .padding(.vertical, 9)
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
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppTheme.primaryText)
                .frame(width: 30, height: 30)
                .background(AppTheme.softSurface.opacity(0.9), in: RoundedRectangle(cornerRadius: 8))

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
        .padding(.vertical, 9)
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
            cpu: "i7-14700K",
            gpu: "RTX 4070",
            motherboard: "B760M AORUS ELITE GEN5",
            memory: "32GB",
            storage: "Samsung 990 PRO · 1TB · PCIe 4.0",
            powerSupply: "Corsair RM750e · 750W · 80+ Gold"
        ),
        selectedTab: .constant(.builds),
        onSelectTab: { _ in },
        onOpenPlan: {},
        onCreate: {},
        onOpenComputerProfile: {}
    )
}
