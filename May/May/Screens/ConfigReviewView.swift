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

    @State private var inputText = ""
    @State private var selectedImageItem: PhotosPickerItem?
    @State private var state: ConfigReviewState = .landing

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppTheme.primaryText)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("返回")
            .padding(.top, 4)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    ConfigReviewHeroView()

                    switch state {
                    case .landing:
                        ConfigReviewActionCard(
                            icon: "doc",
                            title: "上传配置单",
                            subtitle: "支持截图、照片、聊天记录"
                        ) {
                            PhotosPicker(selection: $selectedImageItem, matching: .images) {
                                Text("选择图片")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(.white)
                                    .frame(width: 100, height: 38)
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
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Color.black)
                            .frame(width: 100, height: 38)
                            .background(Color.white, in: Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(Color.black, lineWidth: 2)
                            )
                            .buttonStyle(.plain)
                        }

                        ConfigReviewExampleLink()
                        ConfigReviewChecksView()
                    case .input:
                        ConfigReviewInputPanel(
                            inputText: $inputText,
                            onCancel: { state = .landing },
                            onSubmit: startTextReview
                        )
                        ConfigReviewChecksView()
                    case .loading:
                        ConfigReviewLoadingView()
                    case .result(let result):
                        ConfigReviewResultView(result: result)
                    case .error(let message):
                        ConfigReviewErrorView(message: message)
                    }
                }
                .padding(.bottom, 24)
            }
        }
        .padding(.horizontal, 30)
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
        VStack(alignment: .leading, spacing: 15) {
            VStack(alignment: .leading, spacing: 10) {
                Text("当前功能")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppTheme.secondaryText)

                Text("配置排雷")
                    .font(.system(size: 36, weight: .black))
                    .foregroundStyle(Color.black)

                Text("上传或粘贴配置，检查整机电源、主板供电和性能瓶颈")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.black.opacity(0.74))
            }

            HStack(spacing: 10) {
                ConfigReviewHeroPoint(title: "检查电源余量")
                ConfigReviewHeroPoint(title: "检查主板供电")
                ConfigReviewHeroPoint(title: "检查性能瓶颈")
            }
            .padding(.top, 6)
        }
    }
}

private struct ConfigReviewHeroPoint: View {
    let title: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 13, weight: .semibold))
            Text(title)
                .font(.system(size: 12, weight: .medium))
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
        HStack(spacing: 22) {
            ConfigReviewCardIcon(name: icon)
                .frame(width: 76)

            VStack(alignment: .leading, spacing: 9) {
                Text(title)
                    .font(.system(size: 23, weight: .black))
                    .foregroundStyle(Color.black)

                Text(subtitle)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppTheme.secondaryText)

                control()
                    .padding(.top, 2)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 28)
        .frame(maxWidth: .infinity, minHeight: 146)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 24))
        .shadow(color: Color.black.opacity(0.055), radius: 22, x: 0, y: 13)
        .accessibilityElement(children: .combine)
    }
}

private struct ConfigReviewCardIcon: View {
    let name: String

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Image(systemName: name)
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(Color.black)

            if name == "doc" {
                Image(systemName: "arrow.up")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(Color.black, in: Circle())
                    .offset(x: 9, y: 8)
            }
        }
    }
}

private struct ConfigReviewExampleLink: View {
    var body: some View {
        HStack(spacing: 10) {
            Spacer()
            Image(systemName: "doc.text")
                .font(.system(size: 14, weight: .semibold))
            Text("查看示例")
                .font(.system(size: 14, weight: .medium))
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .bold))
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
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 14)
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .foregroundStyle(Color.black)
        .padding(.horizontal, 7)
        .frame(maxWidth: .infinity, minHeight: 36)
        .background(AppTheme.softSurface, in: Capsule())
    }
}

private struct ConfigReviewChecksView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("将为你检查")
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(AppTheme.secondaryText)

            HStack(spacing: 8) {
                ConfigReviewCheckPill(icon: "bolt", title: "电源余量")
                ConfigReviewCheckPill(icon: "memorychip", title: "主板供电")
                ConfigReviewCheckPill(icon: "speedometer", title: "性能瓶颈")
            }
        }
        .padding(.top, 4)
    }
}

private struct ConfigReviewInputPanel: View {
    @Binding var inputText: String
    let onCancel: () -> Void
    let onSubmit: () -> Void

    private var isEmpty: Bool {
        inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: onCancel) {
                Label("重新选择输入方式", systemImage: "chevron.left")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.secondaryText)
            }
            .buttonStyle(.plain)

            SoftCard(radius: 22) {
                VStack(alignment: .leading, spacing: 14) {
                    Text("粘贴配置单")
                        .font(.appHeadline)
                        .foregroundStyle(AppTheme.primaryText)

                    Text("把 CPU、显卡、主板和电源的具体型号粘贴进来。")
                        .font(.appCaption)
                        .foregroundStyle(AppTheme.secondaryText)

                    ZStack(alignment: .topLeading) {
                        TextEditor(text: $inputText)
                            .font(.appBody)
                            .padding(10)
                            .scrollContentBackground(.hidden)

                        if isEmpty {
                            Text("例如：i5-14600K、RTX 4070、B760M 主板、650W 电源……")
                                .font(.appBody)
                                .foregroundStyle(AppTheme.secondaryText.opacity(0.72))
                                .padding(.horizontal, 15)
                                .padding(.vertical, 18)
                                .allowsHitTesting(false)
                        }
                    }
                    .frame(minHeight: 190)
                    .background(AppTheme.softSurface, in: RoundedRectangle(cornerRadius: 12))

                    ConfigReviewExampleLink()

                    PrimaryButton(title: "开始诊断", icon: "magnifyingglass", action: onSubmit)
                        .disabled(isEmpty)
                        .opacity(isEmpty ? 0.42 : 1)
                }
                .padding(18)
            }
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
                    Text("正在计算整机功耗、主板供电和 CPU、显卡瓶颈。")
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
                    Text("检测结果")
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
