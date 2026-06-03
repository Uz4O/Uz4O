import SwiftUI

private enum DetectionState {
    case empty
    case loading
    case result
}

struct ToolsView: View {
    @Binding var selectedTab: AppTab
    let onSelectTab: (AppTab) -> Void
    @State private var inputText = "i7-14700F + RTX4060 + H610 主板 + 500W 电源，商家报价 6999"
    @State private var state: DetectionState = .empty

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("配置排雷")
                    .font(.appTitle)
                    .foregroundStyle(AppTheme.primaryText)
                Spacer()
            }
            .padding(.top, 8)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    ToolIntroGrid()

                    SoftCard(radius: 22) {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("粘贴商家配置单或手动输入")
                                .font(.appHeadline)
                                .foregroundStyle(AppTheme.primaryText)
                            TextEditor(text: $inputText)
                                .font(.appBody)
                                .frame(minHeight: 96)
                                .padding(10)
                                .scrollContentBackground(.hidden)
                                .background(AppTheme.softSurface, in: RoundedRectangle(cornerRadius: 12))

                            PrimaryButton(title: "开始检测", icon: "magnifyingglass") {
                                state = .loading
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                                    state = .result
                                }
                            }
                        }
                        .padding(18)
                    }

                    switch state {
                    case .empty:
                        EmptyDetectionView()
                    case .loading:
                        LoadingDetectionView()
                    case .result:
                        DetectionResultView()
                    }
                }
                .padding(.bottom, 8)
            }

            Spacer(minLength: 0)

            BottomTabBar(selectedTab: $selectedTab, onSelect: onSelectTab)
        }
        .padding(.horizontal, AppTheme.screenPadding)
        .padding(.bottom, 14)
    }
}

private struct ToolIntroGrid: View {
    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
            ForEach(AppMockData.toolItems) { item in
                SoftCard(radius: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Image(systemName: item.icon)
                            .foregroundStyle(item.level.color)
                        Text(item.title)
                            .font(.appSubheadline)
                            .foregroundStyle(AppTheme.primaryText)
                        Text(item.subtitle)
                            .font(.appCaption)
                            .foregroundStyle(AppTheme.secondaryText)
                            .lineLimit(2)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, minHeight: 105, alignment: .topLeading)
                }
            }
        }
    }
}

private struct EmptyDetectionView: View {
    var body: some View {
        SoftCard(radius: 18) {
            VStack(alignment: .leading, spacing: 8) {
                Text("还没有检测结果")
                    .font(.appHeadline)
                    .foregroundStyle(AppTheme.primaryText)
                Text("输入配置后，系统会检查显卡太弱、CPU 过剩、主板过度消费、电源虚标、价格偏高等问题。")
                    .font(.appBody)
                    .foregroundStyle(AppTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(18)
        }
    }
}

private struct LoadingDetectionView: View {
    var body: some View {
        SoftCard(radius: 18) {
            HStack(spacing: 12) {
                ProgressView()
                    .tint(AppTheme.primaryText)
                VStack(alignment: .leading, spacing: 4) {
                    Text("正在检测配置")
                        .font(.appHeadline)
                        .foregroundStyle(AppTheme.primaryText)
                    Text("正在核对 CPU、主板、显卡、电源和价格风险。")
                        .font(.appCaption)
                        .foregroundStyle(AppTheme.secondaryText)
                }
                Spacer()
            }
            .padding(18)
        }
    }
}

private struct DetectionResultView: View {
    private let risks = [
        BuildRisk(level: .error, title: "显卡偏弱", detail: "i7 搭配 RTX4060 对游戏预算不均衡，建议降低 CPU 或提升显卡。"),
        BuildRisk(level: .warning, title: "主板过低", detail: "H610 搭配高功耗 CPU 不利于长期稳定。"),
        BuildRisk(level: .warning, title: "报价偏高", detail: "同类配置公开参考价约低 800-1200 元。"),
        BuildRisk(level: .pass, title: "电源功率", detail: "500W 勉强可用，但建议选择一线 650W 金牌。")
    ]

    var body: some View {
        SoftCard(radius: 18) {
            VStack(alignment: .leading, spacing: 14) {
                Text("检测结果")
                    .font(.appHeadline)
                    .foregroundStyle(AppTheme.primaryText)

                ForEach(risks) { risk in
                    HStack(alignment: .top, spacing: 10) {
                        Text(risk.level.title)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(risk.level.color, in: Capsule())

                        VStack(alignment: .leading, spacing: 4) {
                            Text(risk.title)
                                .font(.appSubheadline)
                                .foregroundStyle(AppTheme.primaryText)
                            Text(risk.detail)
                                .font(.appCaption)
                                .foregroundStyle(AppTheme.secondaryText)
                        }
                    }
                }
            }
            .padding(18)
        }
    }
}

#Preview {
    ToolsView(selectedTab: .constant(.tools), onSelectTab: { _ in })
}
