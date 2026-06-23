import SwiftUI

struct ContactComplaintView: View {
    @Environment(\.openURL) private var openURL

    let onBack: () -> Void

    @State private var selectedType = ContactComplaintType.feature
    @State private var description = ""
    @State private var contact = ""
    @State private var showsEmptyDescriptionAlert = false

    var body: some View {
        GeometryReader { proxy in
            let contentWidth = AppTheme.responsiveContentWidth(
                for: proxy.size.width,
                compactWidth: 328,
                expandedWidth: 380,
                sideMargin: 48
            )

            VStack(spacing: 0) {
                header

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 26) {
                        intro
                        typePicker
                        descriptionField
                        contactField
                    }
                    .frame(width: contentWidth)
                    .padding(.top, 26)
                    .padding(.bottom, 126)
                    .frame(maxWidth: .infinity)
                }
            }
            .safeAreaInset(edge: .bottom) {
                submitButton
                    .frame(width: contentWidth)
                    .padding(.top, 10)
                    .padding(.bottom, 18)
                    .frame(maxWidth: .infinity)
                    .background(AppTheme.background.opacity(0.96))
            }
            .background(AppTheme.background.ignoresSafeArea())
        }
        .alert("请先填写问题描述", isPresented: $showsEmptyDescriptionAlert) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text("描述越具体，我们越容易定位问题。")
        }
    }

    private var header: some View {
        HStack {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 25, weight: .semibold))
                    .foregroundStyle(AppTheme.primaryText)
                    .frame(width: 42, height: 42, alignment: .leading)
            }
            .buttonStyle(.plain)

            Spacer()

            Text("联系与投诉")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(AppTheme.primaryText)

            Spacer()

            Color.clear.frame(width: 42, height: 42)
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .frame(height: 62)
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("提交反馈")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(AppTheme.primaryText)

            Text("如果你在使用 AI 装机助手时遇到问题，或想反馈功能建议、内容投诉、账号问题，可以在这里提交。")
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(AppTheme.secondaryText)
                .lineSpacing(8)

            HStack(spacing: 8) {
                Image(systemName: "clock")
                    .font(.system(size: 14, weight: .regular))
                Text("一般会在 1-3 个工作日内处理")
                    .font(.system(size: 14, weight: .regular))
            }
            .foregroundStyle(AppTheme.mutedText)
        }
    }

    private var typePicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("问题类型")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppTheme.secondaryText)

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12)
                ],
                alignment: .leading,
                spacing: 12
            ) {
                ForEach(ContactComplaintType.allCases) { type in
                    Button {
                        selectedType = type
                    } label: {
                        Text(type.title)
                            .font(.system(size: 14, weight: selectedType == type ? .bold : .regular))
                            .foregroundStyle(selectedType == type ? AppTheme.primaryText : AppTheme.secondaryText)
                            .frame(maxWidth: .infinity)
                            .frame(height: 42)
                            .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 16))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(selectedType == type ? AppTheme.primaryText : AppTheme.border, lineWidth: selectedType == type ? 1.4 : 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var descriptionField: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("问题描述")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppTheme.secondaryText)

            VStack(spacing: 0) {
                ZStack(alignment: .topLeading) {
                    TextEditor(text: $description)
                        .font(.system(size: 14))
                        .foregroundStyle(AppTheme.primaryText)
                        .frame(minHeight: 148)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .scrollContentBackground(.hidden)
                        .background(Color.clear)

                    if description.isEmpty {
                        Text("请尽量描述你遇到的问题，例如发生在哪个页面、具体表现是什么")
                            .font(.system(size: 14))
                            .foregroundStyle(AppTheme.mutedText)
                            .lineSpacing(6)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 20)
                            .allowsHitTesting(false)
                    }
                }

                Divider()
                    .padding(.horizontal, 16)

                Button(action: {}) {
                    HStack(spacing: 10) {
                        Image(systemName: "plus.circle")
                            .font(.system(size: 19, weight: .regular))
                        Text("添加截图")
                            .font(.system(size: 14, weight: .regular))
                        Spacer()
                    }
                    .foregroundStyle(AppTheme.secondaryText)
                    .padding(.horizontal, 18)
                    .frame(height: 52)
                }
                .buttonStyle(.plain)
                .disabled(true)
                .opacity(0.86)
            }
            .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 18))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(AppTheme.border, lineWidth: 1)
            )
        }
    }

    private var contactField: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("联系方式（选填）")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppTheme.secondaryText)

            TextField("邮箱 / 微信 / 手机号，方便我回复你", text: $contact)
                .font(.system(size: 14))
                .foregroundStyle(AppTheme.primaryText)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .padding(.horizontal, 16)
                .frame(height: 54)
                .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 18))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(AppTheme.border, lineWidth: 1)
                )
        }
    }

    private var submitButton: some View {
        Button(action: submit) {
            Text("提交反馈")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(AppTheme.primaryButton, in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }

    private func submit() {
        let trimmedDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedDescription.isEmpty else {
            showsEmptyDescriptionAlert = true
            return
        }

        let body = """
        问题类型：\(selectedType.title)

        问题描述：
        \(trimmedDescription)

        联系方式：
        \(contact.trimmingCharacters(in: .whitespacesAndNewlines))
        """

        var components = URLComponents()
        components.scheme = "mailto"
        components.path = LegalContact.email
        components.queryItems = [
            URLQueryItem(name: "subject", value: "AI 装机助手反馈：\(selectedType.title)"),
            URLQueryItem(name: "body", value: body)
        ]

        if let url = components.url {
            openURL(url)
        }
    }
}

private enum ContactComplaintType: String, CaseIterable, Identifiable {
    case feature
    case bug
    case content
    case account
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .feature:
            "功能建议"
        case .bug:
            "Bug 反馈"
        case .content:
            "内容投诉"
        case .account:
            "账号问题"
        case .other:
            "其他问题"
        }
    }
}

#Preview {
    ContactComplaintView(onBack: {})
}
