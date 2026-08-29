import SwiftUI

struct ToolsView: View {
    let onOpenPerformanceTest: () -> Void
    let onOpenBudget: () -> Void

    @State private var comparisonMode: ComparisonMode = .gpu
    @State private var ladderMode: LadderMode = .gpu

    var body: some View {
        GeometryReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(spacing: 10) {
                    comparisonCard
                    ladderCard

                    HStack(alignment: .top, spacing: 10) {
                        displayMatchCard
                        budgetCard
                    }
                }
                .frame(width: min(proxy.size.width - 40, 400), alignment: .leading)
                .padding(.top, 90)
                .padding(.bottom, 112)
                .frame(width: proxy.size.width, alignment: .center)
            }
            .background(AppTheme.background.ignoresSafeArea())
        }
    }

    private var comparisonCard: some View {
        ToolPanel {
            ToolPanelHeader(title: "对比工具") {
                ToolSegmentedControl(
                    options: ComparisonMode.allCases,
                    selection: $comparisonMode
                )
            }

            HStack(spacing: 10) {
                HardwarePlaceholder(title: comparisonMode.title)

                ZStack {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 48, weight: .thin))
                        .foregroundStyle(Color.black.opacity(0.035))
                        .rotationEffect(.degrees(12))

                    Text("VS")
                        .font(.system(size: 38, weight: .heavy, design: .rounded))
                        .foregroundStyle(AppTheme.primaryText)
                }
                .frame(width: 62)

                HardwarePlaceholder(title: comparisonMode.title)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 22)

            Button("开始比较  →") {}
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 160, height: 34)
                .background(Color.black, in: Capsule())
                .frame(maxWidth: .infinity)
                .padding(.top, 14)
        }
        .frame(height: 267)
    }

    private var ladderCard: some View {
        ToolPanel {
            ToolPanelHeader(title: "性能天梯") {
                Button("查看全部  ›") {}
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppTheme.primaryText)
            }

            ToolSegmentedControl(options: LadderMode.allCases, selection: $ladderMode)
                .frame(maxWidth: .infinity)
                .padding(.top, 12)

            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(LadderTier.allCases) { tier in
                        HStack(spacing: 9) {
                            Image(systemName: tier.icon)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Color.black.opacity(0.24))
                                .frame(width: 18)
                            Text(tier.title)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(AppTheme.primaryText)
                                .frame(width: 42, alignment: .leading)
                        }
                        .frame(height: 16)
                    }
                }

                VStack(spacing: 10) {
                    ForEach(LadderTier.allCases) { tier in
                        GeometryReader { proxy in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.black.opacity(0.08))
                                Capsule()
                                    .fill(Color.black)
                                    .frame(width: proxy.size.width * tier.progress)
                            }
                        }
                        .frame(height: 4)
                    }
                }
                .frame(maxWidth: .infinity)

                VStack(alignment: .leading, spacing: 10) {
                    ForEach(LadderTier.allCases) { tier in
                        Text(tier.model(for: ladderMode))
                            .font(.system(size: 13, weight: .regular))
                            .foregroundStyle(AppTheme.primaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                            .frame(height: 16, alignment: .leading)
                    }
                }
                .frame(width: 112, alignment: .leading)

                VStack(spacing: 0) {
                    Text("强")
                    Spacer(minLength: 8)
                    Capsule()
                        .fill(Color.black.opacity(0.07))
                        .frame(width: 4, height: 72)
                    Spacer(minLength: 8)
                    Text("弱")
                }
                .frame(height: 120)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AppTheme.primaryText)
            }
            .padding(.top, 12)
        }
        .frame(height: 226)
    }

    private var displayMatchCard: some View {
        ToolPanel {
            ToolPanelHeader(title: "显卡 × 显示器匹配", showsMarker: false) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 15, weight: .semibold))
            }

            HStack(spacing: 8) {
                GPUDisplayMatchGraphic()

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 17, weight: .bold))

                VStack(spacing: 1) {
                    Text("2K")
                        .font(.system(size: 21, weight: .bold))
                    Text("180Hz")
                        .font(.system(size: 12, weight: .bold))
                }
                .frame(width: 60, height: 50)
                .overlay(Rectangle().stroke(AppTheme.primaryText.opacity(0.7), lineWidth: 1.5))
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 12)

            ToolScale(labels: ["1080P", "2K", "4K"], selectedIndex: 1)
                .padding(.top, 5)

            HStack(spacing: 5) {
                Text("匹配度")
                Text("92%")
                    .fontWeight(.bold)
                Spacer(minLength: 0)
            }
            .font(.system(size: 14, weight: .medium))
            .padding(.top, 7)

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.black.opacity(0.08))
                    Capsule().fill(Color.black).frame(width: proxy.size.width * 0.92)
                }
            }
            .frame(height: 4)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 205)
        .contentShape(Rectangle())
        .onTapGesture(perform: onOpenPerformanceTest)
    }

    private var budgetCard: some View {
        ToolPanel {
            ToolPanelHeader(title: "装机预算测算", showsMarker: false) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 15, weight: .semibold))
            }

            Text("¥8,000")
                .font(.system(size: 29, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.primaryText)
                .frame(maxWidth: .infinity)
                .padding(.top, 20)

            ToolBudgetScale()
                .padding(.top, 10)

            HStack(spacing: 7) {
                BudgetPill(title: "游戏", isSelected: true)
                BudgetPill(title: "设计", isSelected: false)
                BudgetPill(title: "办公", isSelected: false)
                BudgetPill(title: "全能", isSelected: false)
            }
            .padding(.top, 14)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 205)
        .contentShape(Rectangle())
        .onTapGesture(perform: onOpenBudget)
    }
}

private enum ComparisonMode: String, CaseIterable, Identifiable {
    case gpu = "显卡比较"
    case cpu = "CPU比较"

    var id: String { rawValue }
    var title: String { self == .gpu ? "选择显卡" : "选择 CPU" }
}

private enum LadderMode: String, CaseIterable, Identifiable {
    case gpu = "显卡"
    case cpu = "CPU"

    var id: String { rawValue }
}

private enum LadderTier: String, CaseIterable, Identifiable {
    case flagship = "旗舰"
    case high = "高端"
    case upperMid = "中高端"
    case mainstream = "主流"
    case entry = "入门"

    var id: String { rawValue }

    var title: String { rawValue }

    var icon: String {
        switch self {
        case .flagship: "crown.fill"
        case .high: "hexagon.fill"
        case .upperMid: "square.stack.3d.up.fill"
        case .mainstream: "star.fill"
        case .entry: "circle.fill"
        }
    }

    var progress: CGFloat {
        switch self {
        case .flagship: 1
        case .high: 0.72
        case .upperMid: 0.56
        case .mainstream: 0.4
        case .entry: 0.28
        }
    }

    func model(for mode: LadderMode) -> String {
        switch mode {
        case .gpu:
            switch self {
            case .flagship: "RTX 4090"
            case .high: "RTX 4080 SUPER"
            case .upperMid: "RTX 4070 Ti SUPER"
            case .mainstream: "RTX 4060 Ti"
            case .entry: "RTX 4060"
            }
        case .cpu:
            switch self {
            case .flagship: "Ryzen 9 9950X3D"
            case .high: "Core i9-14900K"
            case .upperMid: "Ryzen 7 7800X3D"
            case .mainstream: "Core i5-14600KF"
            case .entry: "Ryzen 5 7500F"
            }
        }
    }
}

private struct ToolPanel<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
        }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: Color.black.opacity(0.045), radius: 16, x: 0, y: 7)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ToolPanelHeader<Trailing: View>: View {
    let title: String
    let showsMarker: Bool
    let trailing: Trailing

    init(title: String, showsMarker: Bool = true, @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.showsMarker = showsMarker
        self.trailing = trailing()
    }

    var body: some View {
        HStack(spacing: 10) {
            if showsMarker {
                Capsule()
                    .fill(Color.black)
                    .frame(width: 4, height: 18)
            }

            Text(title)
                .font(.system(size: showsMarker ? 16 : 14, weight: .bold))
                .foregroundStyle(AppTheme.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Spacer(minLength: 0)
            trailing
        }
    }
}

private struct ToolSegmentedControl<Option: Hashable & Identifiable & RawRepresentable>: View where Option.RawValue == String {
    let options: [Option]
    @Binding var selection: Option

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options) { option in
                Button(option.rawValue) {
                    selection = option
                }
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(selection == option ? Color.white : AppTheme.primaryText)
                .frame(width: 62, height: 22)
                .background(selection == option ? Color.black : Color.black.opacity(0.035), in: Capsule())
            }
        }
    }
}

private struct HardwarePlaceholder: View {
    let title: String

    var body: some View {
        VStack(spacing: 11) {
            Image(systemName: "plus")
                .font(.system(size: 24, weight: .medium))
                .frame(width: 38, height: 38)
                .background(Color.black.opacity(0.035), in: Circle())

            Text(title)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(AppTheme.primaryText)
                .lineLimit(1)

            Text("支持 NVIDIA / AMD")
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(AppTheme.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(width: 114)
        .frame(height: 139)
        .background(Color.black.opacity(0.018), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct GPUDisplayMatchGraphic: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(Color.black.opacity(0.86))
                .frame(width: 52, height: 24)

            HStack(spacing: 2) {
                ForEach(0..<3, id: \.self) { _ in
                    Circle()
                        .stroke(Color.white.opacity(0.82), lineWidth: 1.5)
                        .frame(width: 13, height: 13)
                }
            }

            Rectangle()
                .fill(Color.black)
                .frame(width: 3, height: 30)
                .offset(x: -27)
        }
        .frame(width: 56, height: 50)
    }
}

private struct ToolScale: View {
    let labels: [String]
    let selectedIndex: Int

    var body: some View {
        VStack(spacing: 8) {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.black.opacity(0.08)).frame(height: 4)
                    Circle()
                        .fill(Color.black)
                        .frame(width: 16, height: 16)
                        .offset(x: proxy.size.width * CGFloat(selectedIndex) / CGFloat(labels.count - 1) - 8)
                }
            }
            .frame(height: 16)

            HStack {
                ForEach(Array(labels.enumerated()), id: \.offset) { index, label in
                    Text(label)
                        .font(.system(size: 11, weight: index == selectedIndex ? .bold : .regular))
                        .foregroundStyle(index == selectedIndex ? AppTheme.primaryText : AppTheme.secondaryText)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }
}

private struct ToolBudgetScale: View {
    var body: some View {
        VStack(spacing: 7) {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.black.opacity(0.08)).frame(height: 4)
                    Capsule().fill(Color.black).frame(width: proxy.size.width * 0.48, height: 4)
                    Circle()
                        .fill(Color.black)
                        .frame(width: 16, height: 16)
                        .offset(x: proxy.size.width * 0.48 - 8)
                }
            }
            .frame(height: 16)

            HStack {
                Text("¥4K")
                Spacer()
                Text("¥30K+")
            }
            .font(.system(size: 11, weight: .regular))
            .foregroundStyle(AppTheme.secondaryText)
        }
    }
}

private struct BudgetPill: View {
    let title: String
    let isSelected: Bool

    var body: some View {
        Text(title)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(isSelected ? Color.white : AppTheme.secondaryText)
            .frame(maxWidth: .infinity)
            .frame(height: 34)
            .background(isSelected ? Color.black : Color.black.opacity(0.025), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
    }
}

#Preview {
    ToolsView(onOpenPerformanceTest: {}, onOpenBudget: {})
}
