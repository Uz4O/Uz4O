import SwiftUI

private enum ConfigReviewState {
    case empty
    case loading
    case result
}

struct ConfigReviewView: View {
    let onBack: () -> Void

    @State private var inputText = "i7-14700F + RTX4060 + H610 主板 + 500W 电源，商家报价 6999"
    @State private var state: ConfigReviewState = .empty

    var body: some View {
        VStack(spacing: 14) {
            ScreenHeader(title: "配置单诊断", trailingIcon: nil, onBack: onBack)
                .padding(.top, 8)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    SoftCard(radius: 22) {
                        VStack(alignment: .leading, spacing: 14) {
                            VStack(alignment: .leading, spacing: 5) {
                                Text("粘贴配置单或报价")
                                    .font(.appHeadline)
                                    .foregroundStyle(AppTheme.primaryText)
                                Text("适合把商家整机、朋友推荐配置发来，让系统用小白能看懂的话判断能不能买。")
                                    .font(.appCaption)
                                    .foregroundStyle(AppTheme.secondaryText)
                                    .fixedSize(horizontal: false, vertical: true)
                            }

                            TextEditor(text: $inputText)
                                .font(.appBody)
                                .frame(minHeight: 116)
                                .padding(10)
                                .scrollContentBackground(.hidden)
                                .background(AppTheme.softSurface, in: RoundedRectangle(cornerRadius: 12))

                            PrimaryButton(title: "开始诊断", icon: "magnifyingglass") {
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
                        ConfigReviewEmptyView()
                    case .loading:
                        ConfigReviewLoadingView()
                    case .result:
                        ConfigReviewResultView()
                    }
                }
                .padding(.bottom, 22)
            }
        }
        .padding(.horizontal, AppTheme.screenPadding)
    }
}

private struct ConfigReviewEmptyView: View {
    var body: some View {
        SoftCard(radius: 18) {
            VStack(alignment: .leading, spacing: 8) {
                Text("会输出三样东西")
                    .font(.appHeadline)
                    .foregroundStyle(AppTheme.primaryText)
                Text("小白结论、主要问题、以及一段可以直接复制给商家的回复。")
                    .font(.appBody)
                    .foregroundStyle(AppTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(18)
        }
    }
}

private struct ConfigReviewLoadingView: View {
    var body: some View {
        SoftCard(radius: 18) {
            HStack(spacing: 12) {
                ProgressView()
                    .tint(AppTheme.primaryText)
                VStack(alignment: .leading, spacing: 4) {
                    Text("正在诊断配置单")
                        .font(.appHeadline)
                        .foregroundStyle(AppTheme.primaryText)
                    Text("正在核对配置搭配、报价和适合直接回复的话术。")
                        .font(.appCaption)
                        .foregroundStyle(AppTheme.secondaryText)
                }
                Spacer()
            }
            .padding(18)
        }
    }
}

private struct ConfigReviewResultView: View {
    private let sourceText = "i7-14700F + RTX4060 + H610 + 500W，报价 6999"
    private let conclusion = "不建议直接买。主要问题是 CPU 太高、显卡偏弱，主板和电源也偏保守，6999 这个报价不太划算。"
    private let replyText = "这套配置有高 U 低显问题，预算更适合降低 CPU、提高显卡，电源建议换一线 650W，主板也建议至少换到供电更稳的 B760。"
    private let risks = [
        BuildRisk(level: .error, title: "高 U 低显", detail: "i7-14700F 搭配 RTX4060，对游戏用户来说预算分配不均衡。"),
        BuildRisk(level: .warning, title: "主板偏保守", detail: "H610 搭配 i7 级 CPU 不利于长期满载稳定。"),
        BuildRisk(level: .warning, title: "电源余量一般", detail: "500W 可以点亮，但更建议换一线 650W。")
    ]

    var body: some View {
        VStack(spacing: 14) {
            SoftCard(radius: 18) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("小白结论")
                            .font(.appHeadline)
                            .foregroundStyle(AppTheme.primaryText)

                        Spacer()

                        Text("不建议直接买")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 6)
                            .background(AppTheme.error, in: Capsule())
                    }

                    Text(sourceText)
                        .font(.appCaption)
                        .foregroundStyle(AppTheme.secondaryText)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AppTheme.softSurface, in: RoundedRectangle(cornerRadius: 12))

                    Text(conclusion)
                        .font(.appBody)
                        .foregroundStyle(AppTheme.primaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(18)
            }

            SoftCard(radius: 18) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("主要问题")
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
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
                .padding(18)
            }

            SoftCard(radius: 18) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("可复制回复")
                            .font(.appHeadline)
                            .foregroundStyle(AppTheme.primaryText)

                        Spacer()

                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(AppTheme.primaryText)
                    }

                    Text(replyText)
                        .font(.appBody)
                        .foregroundStyle(AppTheme.primaryText)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AppTheme.softSurface, in: RoundedRectangle(cornerRadius: 12))

                    Button("复制这段回复") {}
                        .font(.appSubheadline)
                        .foregroundStyle(AppTheme.primaryText)
                        .frame(maxWidth: .infinity)
                        .frame(height: 42)
                        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(AppTheme.border, lineWidth: 1)
                        )
                        .buttonStyle(.plain)
                }
                .padding(18)
            }
        }
    }
}

#Preview {
    ConfigReviewView(onBack: {})
}
