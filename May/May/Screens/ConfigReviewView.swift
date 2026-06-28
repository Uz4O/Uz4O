import SwiftUI
import PhotosUI

private enum ConfigReviewState {
    case landing
    case input
    case loading
    case result(ConfigReviewResponseDTO)
    case error(String)
}

struct ConfigReviewView: View {
    let onBack: () -> Void

    @State private var inputText = "i7-14700F + RTX4060 + H610 主板 + 500W 电源，商家报价 6999"
    @State private var selectedImageItem: PhotosPickerItem?
    @State private var state: ConfigReviewState = .landing

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AppTheme.primaryText)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("返回")
            .padding(.top, 8)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    ConfigReviewHeroView()

                    ConfigReviewActionCard(
                        icon: "doc",
                        title: "上传配置单",
                        subtitle: "支持截图、照片、聊天记录"
                    ) {
                        PhotosPicker(selection: $selectedImageItem, matching: .images) {
                            Text("选择图片")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 112, height: 44)
                                .background(Color.black, in: Capsule())
                        }
                    }

                    ConfigReviewActionCard(
                        icon: "list.clipboard",
                        title: "粘贴配置单",
                        subtitle: "直接粘贴整段配置文本"
                    ) {
                        Button("去粘贴") {
                            state = .input
                        }
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Color.black)
                        .frame(width: 112, height: 44)
                        .background(Color.white, in: Capsule())
                        .overlay(
                            Capsule()
                                .stroke(Color.black, lineWidth: 2)
                        )
                        .buttonStyle(.plain)
                    }

                    ConfigReviewExampleLink()

                    VStack(alignment: .leading, spacing: 14) {
                        Text("AI 将为你检查")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundStyle(AppTheme.secondaryText)

                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 132), spacing: 12)], alignment: .leading, spacing: 12) {
                            ConfigReviewCheckPill(icon: "puzzlepiece", title: "兼容性")
                            ConfigReviewCheckPill(icon: "yensign", title: "预算")
                            ConfigReviewCheckPill(icon: "speedometer", title: "性能瓶颈")
                            ConfigReviewCheckPill(icon: "tag", title: "是否买贵")
                        }
                    }
                    .padding(.top, 4)

                    switch state {
                    case .landing:
                        EmptyView()
                    case .input:
                        ConfigReviewInputPanel(inputText: $inputText, onSubmit: startTextReview)
                    case .loading:
                        ConfigReviewLoadingView()
                    case .result(let result):
                        ConfigReviewResultView(result: result)
                    case .error(let message):
                        ConfigReviewErrorView(message: message)
                    }
                }
                .padding(.bottom, 28)
            }
        }
        .padding(.horizontal, AppTheme.screenPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.white)
        .onChange(of: selectedImageItem) { _, item in
            guard let item else { return }
            startImageReview(item)
        }
    }

    private func startTextReview() {
        state = .loading
        Task {
            do {
                let result = try await AppAPIClient().analyzeConfigReviewText(inputText)
                state = .result(result)
            } catch {
                state = .error(error.localizedDescription)
            }
        }
    }

    private func startImageReview(_ item: PhotosPickerItem) {
        state = .loading
        Task {
            do {
                guard let data = try await item.loadTransferable(type: Data.self) else {
                    state = .error("没有读取到图片内容")
                    return
                }
                let result = try await AppAPIClient().analyzeConfigReviewImage(imageData: data)
                state = .result(result)
            } catch {
                state = .error(error.localizedDescription)
            }
        }
    }
}

private struct ConfigReviewHeroView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 12) {
                Text("当前功能")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.secondaryText)

                Text("配置排雷")
                    .font(.system(size: 42, weight: .black))
                    .foregroundStyle(Color.black)

                Text("上传配置单或粘贴配置，AI 帮你找出哪里有坑")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(Color.black.opacity(0.74))
            }

            HStack(spacing: 12) {
                ConfigReviewHeroPoint(title: "识别搭配风险")
                ConfigReviewHeroPoint(title: "检查兼容问题")
                ConfigReviewHeroPoint(title: "给出修改建议")
            }
            .padding(.top, 10)
        }
    }
}

private struct ConfigReviewHeroPoint: View {
    let title: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 15, weight: .semibold))
            Text(title)
                .font(.system(size: 13, weight: .semibold))
        }
        .foregroundStyle(AppTheme.secondaryText)
    }
}

private struct ConfigReviewActionCard<Control: View>: View {
    let icon: String
    let title: String
    let subtitle: String
    @ViewBuilder let control: () -> Control

    var body: some View {
        HStack(spacing: 30) {
            ConfigReviewCardIcon(name: icon)
                .frame(width: 96)

            VStack(alignment: .leading, spacing: 12) {
                Text(title)
                    .font(.system(size: 26, weight: .black))
                    .foregroundStyle(Color.black)

                Text(subtitle)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppTheme.secondaryText)

                control()
                    .padding(.top, 2)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 36)
        .frame(maxWidth: .infinity, minHeight: 172)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 28))
        .shadow(color: Color.black.opacity(0.06), radius: 26, x: 0, y: 16)
        .accessibilityElement(children: .combine)
    }
}

private struct ConfigReviewCardIcon: View {
    let name: String

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Image(systemName: name)
                .font(.system(size: 58, weight: .light))
                .foregroundStyle(Color.black)

            if name == "doc" {
                Image(systemName: "arrow.up")
                    .font(.system(size: 23, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.black, in: Circle())
                    .offset(x: 12, y: 10)
            }
        }
    }
}

private struct ConfigReviewExampleLink: View {
    var body: some View {
        HStack(spacing: 10) {
            Spacer()
            Image(systemName: "doc.text")
                .font(.system(size: 16, weight: .semibold))
            Text("查看示例")
                .font(.system(size: 16, weight: .semibold))
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .bold))
            Spacer()
        }
        .foregroundStyle(AppTheme.secondaryText)
        .padding(.vertical, 4)
    }
}

private struct ConfigReviewCheckPill: View {
    let icon: String
    let title: String

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
            Text(title)
                .font(.system(size: 14, weight: .bold))
        }
        .foregroundStyle(Color.black)
        .padding(.horizontal, 14)
        .frame(height: 42)
        .background(AppTheme.softSurface, in: Capsule())
    }
}

private struct ConfigReviewInputPanel: View {
    @Binding var inputText: String
    let onSubmit: () -> Void

    var body: some View {
        SoftCard(radius: 22) {
            VStack(alignment: .leading, spacing: 14) {
                Text("粘贴配置单或报价")
                    .font(.appHeadline)
                    .foregroundStyle(AppTheme.primaryText)

                TextEditor(text: $inputText)
                    .font(.appBody)
                    .frame(minHeight: 116)
                    .padding(10)
                    .scrollContentBackground(.hidden)
                    .background(AppTheme.softSurface, in: RoundedRectangle(cornerRadius: 12))

                PrimaryButton(title: "开始诊断", icon: "magnifyingglass", action: onSubmit)
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

private struct ConfigReviewErrorView: View {
    let message: String

    var body: some View {
        SoftCard(radius: 18) {
            VStack(alignment: .leading, spacing: 8) {
                Text("识别失败")
                    .font(.appHeadline)
                    .foregroundStyle(AppTheme.primaryText)
                Text(message)
                    .font(.appBody)
                    .foregroundStyle(AppTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(18)
        }
    }
}

private struct ConfigReviewResultView: View {
    let result: ConfigReviewResponseDTO

    private var riskLevel: RiskLevel {
        RiskLevel(reviewLevel: result.riskLevel)
    }

    var body: some View {
        VStack(spacing: 14) {
            SoftCard(radius: 18) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("小白结论")
                            .font(.appHeadline)
                            .foregroundStyle(AppTheme.primaryText)

                        Spacer()

                        Text(riskLevel.title)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 6)
                            .background(riskLevel.color, in: Capsule())
                    }

                    Text(result.sourceText)
                        .font(.appCaption)
                        .foregroundStyle(AppTheme.secondaryText)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AppTheme.softSurface, in: RoundedRectangle(cornerRadius: 12))

                    Text(result.summary)
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

                    ForEach(result.findings) { finding in
                        let level = RiskLevel(reviewLevel: finding.level)
                        HStack(alignment: .top, spacing: 10) {
                            Text(level.title)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .background(level.color, in: Capsule())

                            VStack(alignment: .leading, spacing: 4) {
                                Text(finding.title)
                                    .font(.appSubheadline)
                                    .foregroundStyle(AppTheme.primaryText)
                                Text(finding.detail)
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

                    Text(result.replyText)
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

private extension RiskLevel {
    init(reviewLevel: String) {
        switch reviewLevel {
        case "pass":
            self = .pass
        case "error":
            self = .error
        default:
            self = .warning
        }
    }
}

#Preview {
    ConfigReviewView(onBack: {})
}
