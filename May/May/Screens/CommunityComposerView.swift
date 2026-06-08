import SwiftUI

struct CommunityComposerView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var draft = CommunityComposerDraft()
    @State private var content = ""

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

                    Button("发布") {
                        dismiss()
                    }
                    .font(.appSubheadline)
                    .foregroundStyle(AppTheme.primaryText)
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
                            Text("添加图片/视频 (0/9)")
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
                        }

                        Spacer(minLength: 20)
                    }
                    .padding(.horizontal, AppTheme.screenPadding)
                    .padding(.bottom, 28)
                }
            }
            .background(AppTheme.background.ignoresSafeArea())
        }
    }
}

#Preview {
    CommunityComposerView()
}
