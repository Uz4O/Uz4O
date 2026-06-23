import SwiftUI

struct CommunityComposerView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var session: AppSession
    let onPublished: () -> Void

    @State private var draft = CommunityComposerDraft()
    @State private var content = ""
    @State private var isPublishing = false
    @State private var errorMessage: String?
    @State private var presentedLegalDocument: LegalDocument?

    private let selectableTopics = ["装机配置", "硬件评测", "求助问答", "交流分享", "其他"]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack {
                    Button("取消") {
                        dismiss()
                    }
                    .font(.appBody)
                    .foregroundStyle(AppTheme.primaryText)

                    Spacer()

                    Text("发布帖子")
                        .font(.appSubheadline)
                        .foregroundStyle(AppTheme.primaryText)

                    Spacer()

                    Button(isPublishing ? "发布中..." : "发布") { publish() }
                    .font(.appSubheadline)
                    .foregroundStyle(canPublish ? AppTheme.primaryText : AppTheme.mutedText)
                    .disabled(!canPublish || isPublishing)
                }
                .padding(.horizontal, AppTheme.screenPadding)
                .frame(height: 54)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        ZStack(alignment: .bottomTrailing) {
                            TextEditor(text: $content)
                                .font(.appBody)
                                .frame(minHeight: 178)
                                .padding(12)
                                .scrollContentBackground(.hidden)
                                .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 18))
                                .modifier(AppTheme.cardShadow)
                                .onChange(of: content) { _, newValue in
                                    if newValue.count > CommunityComposerDraft.characterLimit {
                                        content = String(newValue.prefix(CommunityComposerDraft.characterLimit))
                                    }
                                }

                            if content.isEmpty {
                                Text("分享你的装机心得、配置方案或遇到的问题...")
                                    .font(.appBody)
                                    .foregroundStyle(AppTheme.mutedText)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                                    .padding(.top, 22)
                                    .padding(.leading, 18)
                                    .allowsHitTesting(false)
                            }

                            Text("\(content.count)/\(CommunityComposerDraft.characterLimit)")
                                .font(.appCaption)
                                .foregroundStyle(AppTheme.secondaryText)
                                .padding(14)
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            Text("选择话题")
                                .font(.appSubheadline)
                                .foregroundStyle(AppTheme.primaryText)

                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 76), spacing: 10)], alignment: .leading, spacing: 10) {
                                ForEach(selectableTopics, id: \.self) { topic in
                                    Button {
                                        draft.toggleTopic(topic)
                                    } label: {
                                        Text(topic)
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundStyle(draft.selectedTopicTitles.contains(topic) ? AppTheme.primaryText : AppTheme.secondaryText)
                                            .frame(height: 32)
                                            .padding(.horizontal, 12)
                                            .background(
                                                draft.selectedTopicTitles.contains(topic) ? AppTheme.surface : AppTheme.softSurface,
                                                in: RoundedRectangle(cornerRadius: 9)
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            Text("添加图片")
                                .font(.appSubheadline)
                                .foregroundStyle(AppTheme.primaryText)

                            Button(action: {}) {
                                Image(systemName: "plus")
                                    .font(.system(size: 22, weight: .regular))
                                    .foregroundStyle(AppTheme.primaryText)
                                    .frame(width: 62, height: 62)
                                    .background(AppTheme.softSurface, in: RoundedRectangle(cornerRadius: 12))
                            }
                            .buttonStyle(.plain)
                            .disabled(true)
                            .opacity(0.45)

                            Text("图片上传将在对象存储服务完成配置和隐私披露后开放。")
                                .font(.appCaption)
                                .foregroundStyle(AppTheme.secondaryText)
                        }

                        HStack(alignment: .top, spacing: 9) {
                            Button {
                                draft.hasAcceptedGuidelines.toggle()
                            } label: {
                                Image(systemName: draft.hasAcceptedGuidelines ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(AppTheme.primaryButton)
                            }
                            .buttonStyle(.plain)

                            Text("我已阅读并遵守")
                                .font(.appCaption)
                                .foregroundStyle(AppTheme.primaryText)

                            Button("《社区规范》") {
                                presentedLegalDocument = .communityGuidelines
                            }
                            .font(.appCaption.weight(.semibold))
                            .foregroundStyle(AppTheme.primaryButton)
                            .buttonStyle(.plain)
                        }

                        Spacer(minLength: 20)
                    }
                    .padding(.horizontal, AppTheme.screenPadding)
                    .padding(.bottom, 28)
                }
            }
            .background(AppTheme.background.ignoresSafeArea())
        }
        .sheet(item: $presentedLegalDocument) { document in
            NavigationStack { LegalDocumentView(document: document) }
        }
        .alert("发布失败", isPresented: errorIsPresented) {
            Button("知道了", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "请稍后重试")
        }
    }

    private var canPublish: Bool {
        draft.canPublish(content: content)
    }

    private func publish() {
        guard let token = session.accessToken else {
            errorMessage = "登录状态已失效，请重新登录"
            return
        }
        let body = content.trimmingCharacters(in: .whitespacesAndNewlines)
        Task {
            isPublishing = true
            defer { isPublishing = false }
            do {
                _ = try await session.api.createCommunityPost(
                    summary: String(body.prefix(160)),
                    body: body,
                    tags: draft.selectedTopicTitles,
                    token: token
                )
                onPublished()
                dismiss()
            } catch {
                errorMessage = (error as? LocalizedError)?.errorDescription ?? "网络请求失败"
            }
        }
    }

    private var errorIsPresented: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }
}

#Preview {
    CommunityComposerView(session: AppSession(), onPublished: {})
}
