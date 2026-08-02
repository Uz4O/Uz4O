import SwiftUI

struct MyBuildsView: View {
    let hardwareProfile: HardwareProfile
    let onOpenPlan: () -> Void
    let onCreate: () -> Void
    let onOpenComputerProfile: () -> Void
    let onOpenUpgrade: () -> Void
    let onOpenPerformanceTest: () -> Void
    var onBack: (() -> Void)? = nil

    @Binding var selectedSection: ConfigHubSection
    @State private var diyBuilds = DIYBuildStore.load()

    var body: some View {
        GeometryReader { proxy in
            let contentWidth = AppTheme.responsiveContentWidth(for: proxy.size.width, compactWidth: 344, expandedWidth: 368)

            ZStack(alignment: .bottom) {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        HStack(spacing: 10) {
                            if let onBack {
                                Button(action: onBack) {
                                    Image(systemName: "chevron.left")
                                        .font(.system(size: 17, weight: .semibold))
                                        .foregroundStyle(AppTheme.primaryText)
                                        .frame(width: 28, height: 28)
                                }
                                .buttonStyle(.plain)
                            }

                            VStack(alignment: .leading, spacing: 5) {
                                Text("配置")
                                    .font(.system(size: 29, weight: .heavy))
                                    .foregroundStyle(AppTheme.primaryText)
                                Text("管理 AI 生成的配置和现在自己的配置")
                                    .font(.system(size: 12, weight: .regular))
                                    .foregroundStyle(AppTheme.secondaryText)
                            }

                            Spacer()
                        }
                        .padding(.top, 12)

                        ConfigHubSegmentedPicker(selectedSection: $selectedSection)

                        switch selectedSection {
                        case .aiBuilds:
                            AIBuildsSection(
                                plans: AppMockData.savedPlans + diyBuilds.map(\.asBuildPlan),
                                onOpenPlan: onOpenPlan,
                                onCreate: onCreate
                            )
                        case .currentComputer:
                            CurrentComputerSection(
                                hardwareProfile: hardwareProfile,
                                onEdit: onOpenComputerProfile,
                                onCreate: onCreate,
                                onOpenUpgrade: onOpenUpgrade,
                                onOpenPerformanceTest: onOpenPerformanceTest
                            )
                        }
                    }
                    .padding(.bottom, 148)
                    .frame(width: contentWidth)
                    .frame(maxWidth: .infinity)
                    .transaction { transaction in
                        transaction.animation = nil
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .background(AppTheme.background.ignoresSafeArea())
            .onAppear { diyBuilds = DIYBuildStore.load() }
        }
    }
}

private struct ConfigHubSegmentedPicker: View {
    @Binding var selectedSection: ConfigHubSection

    var body: some View {
        LiquidGlassSegmentedPicker(
            options: ConfigHubSection.allCases,
            selection: $selectedSection,
            height: 38,
            padding: 3,
            title: { $0.title }
        )
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
        .padding(.top, 22)
    }
}

private struct ConfigPlanList: View {
    let plans: [BuildPlan]
    let onOpenPlan: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ConfigSectionHeader(
                title: "我的配置单",
                subtitle: nil,
                trailing: "\(plans.count) 个"
            )
            .padding(.bottom, 22)

            ForEach(Array(plans.enumerated()), id: \.element.id) { index, plan in
                SavedPlanRow(plan: plan, onOpen: onOpenPlan)

                if index != plans.count - 1 {
                    ConfigDivider(leftPadding: 48)
                }
            }
        }
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
        VStack(spacing: 16) {
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
        .padding(.top, 24)
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
            .padding(.vertical, 15)
        }
        .buttonStyle(.plain)
    }
}

private struct CurrentComputerSection: View {
    let hardwareProfile: HardwareProfile
    let onEdit: () -> Void
    let onCreate: () -> Void
    let onOpenUpgrade: () -> Void
    let onOpenPerformanceTest: () -> Void

    var body: some View {
        VStack(spacing: 28) {
            VStack(spacing: 0) {
                ConfigSectionHeader(title: "当前电脑", subtitle: nil, trailing: hardwareProfile.completionLabel)
                    .padding(.bottom, 20)

                ComputerConfigRow(title: "CPU", value: hardwareProfile.cpu, icon: "cpu", action: onEdit)
                ConfigDivider(leftPadding: 48)
                ComputerConfigRow(title: "显卡", value: hardwareProfile.gpu, icon: "display", action: onEdit)
                ConfigDivider(leftPadding: 48)
                ComputerConfigRow(title: "主板", value: hardwareProfile.motherboard, icon: "menucard", action: onEdit)
                ConfigDivider(leftPadding: 48)
                ComputerConfigRow(title: "内存", value: hardwareProfile.memory, icon: "rectangle.stack", action: onEdit)
                ConfigDivider(leftPadding: 48)
                ComputerConfigRow(title: "硬盘", value: hardwareProfile.storage, icon: "externaldrive", action: onEdit)
                ConfigDivider(leftPadding: 48)
                ComputerConfigRow(title: "电源", value: hardwareProfile.powerSupply, icon: "bolt", action: onEdit)
            }

            if !hardwareProfile.isComplete {
                PrimaryButton(title: "继续补充电脑配置", icon: "plus", action: onEdit)
            }

            VStack(spacing: 0) {
                ConfigSectionHeader(title: "可以用它做什么", subtitle: nil, trailing: nil)
                    .padding(.bottom, 20)

                ConfigUseCaseRow(icon: "chart.bar.xaxis", title: "看升级短板", subtitle: "判断当前电脑最该先换什么", action: onOpenUpgrade)
                ConfigDivider(leftPadding: 48)
                ConfigUseCaseRow(icon: "gamecontroller", title: "测游戏表现", subtitle: "结合分辨率和游戏估算体验", action: onOpenPerformanceTest)
                ConfigDivider(leftPadding: 48)
                ConfigUseCaseRow(icon: "arrow.left.arrow.right", title: "对比 AI 配置", subtitle: "看新配置相比当前电脑提升在哪", action: onCreate)
            }

        }
        .padding(.top, 22)
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
            .padding(.vertical, 13)
        }
        .buttonStyle(.plain)
    }
}

private struct ConfigUseCaseRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
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
            .contentShape(Rectangle())
            .padding(.vertical, 13)
        }
        .buttonStyle(.plain)
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

private extension DIYStoredBuild {
    var asBuildPlan: BuildPlan {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "zh_CN")
        dateFormatter.dateFormat = "M月d日 HH:mm"

        return BuildPlan(
            name: "DIY 自定义配置",
            budget: "自定义",
            totalPrice: totalPrice > 0 ? "¥\(totalPrice)" : "待选择",
            useCase: estimatedPower.map { "预计功耗 \($0)W" } ?? "自定义装机",
            createdAt: dateFormatter.string(from: createdAt),
            parts: parts.map { part in
                PCPart(
                    category: part.category,
                    model: "\(part.brand) \(part.name)",
                    price: part.price.map { "¥\($0)" } ?? "待定",
                    condition: "DIY",
                    icon: icon(for: part.category),
                    accent: AppTheme.primaryText
                )
            }
        )
    }

    private func icon(for category: String) -> String {
        switch category {
        case "CPU": return "cpu"
        case "显卡": return "display"
        case "主板": return "memorychip"
        case "内存": return "rectangle.stack"
        case "固态硬盘": return "externaldrive"
        case "电源": return "bolt"
        case "散热器": return "fan"
        case "机箱": return "shippingbox"
        default: return "desktopcomputer"
        }
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
        onOpenPlan: {},
        onCreate: {},
        onOpenComputerProfile: {},
        onOpenUpgrade: {},
        onOpenPerformanceTest: {},
        selectedSection: .constant(.currentComputer)
    )
}
