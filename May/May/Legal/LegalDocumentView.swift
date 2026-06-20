import SwiftUI

struct LegalDocumentView: View {
    let document: LegalDocument

    @State private var content = ""
    @State private var loadError: String?

    var body: some View {
        ScrollView(showsIndicators: true) {
            Group {
                if let loadError {
                    ContentUnavailableView(
                        "无法载入文档",
                        systemImage: "doc.text.magnifyingglass",
                        description: Text(loadError)
                    )
                    .padding(.top, 80)
                } else {
                    Text(renderedContent)
                        .font(.system(size: 15))
                        .foregroundStyle(AppTheme.primaryText)
                        .lineSpacing(6)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(AppTheme.screenPadding)
        }
        .background(AppTheme.background.ignoresSafeArea())
        .navigationTitle(document.title)
        .navigationBarTitleDisplayMode(.inline)
        .task { load() }
    }

    private var renderedContent: AttributedString {
        (try? AttributedString(
            markdown: content,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        )) ?? AttributedString(content)
    }

    private func load() {
        do {
            content = try document.load()
            loadError = nil
        } catch {
            loadError = "请稍后重试或联系 \(LegalContact.email)"
        }
    }
}

#Preview {
    NavigationStack {
        LegalDocumentView(document: .privacyPolicy)
    }
}
