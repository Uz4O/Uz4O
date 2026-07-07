import SwiftUI

struct AccountDeletionView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var session: AppSession
    let onDeleted: () -> Void

    @State private var confirmation = ""
    @State private var isDeleting = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("注销后将删除或匿名化账号资料、硬件档案和保存方案。相关记录将按隐私政策和法律要求处理。")
                        .font(.appBody)
                        .foregroundStyle(AppTheme.primaryText)
                        .lineSpacing(5)

                    Text("此操作不可撤销。请输入 DELETE 确认。")
                        .font(.appSubheadline)
                        .foregroundStyle(.red)

                    TextField("DELETE", text: $confirmation)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .padding(.horizontal, 16)
                        .frame(height: 50)
                        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(AppTheme.border, lineWidth: 1)
                        )

                    Button {
                        deleteAccount()
                    } label: {
                        Text(isDeleting ? "正在注销..." : "永久注销账号")
                            .font(.appSubheadline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(.red, in: RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                    .disabled(confirmation != "DELETE" || isDeleting)
                    .opacity(confirmation == "DELETE" && !isDeleting ? 1 : 0.45)
                }
                .padding(AppTheme.screenPadding)
            }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("注销账号")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
            .alert("注销失败", isPresented: errorIsPresented) {
                Button("知道了", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "请稍后重试")
            }
        }
    }

    private func deleteAccount() {
        Task {
            isDeleting = true
            defer { isDeleting = false }
            do {
                try await session.deleteAccount()
                dismiss()
                onDeleted()
            } catch {
                errorMessage = (error as? LocalizedError)?.errorDescription ?? "网络请求失败，请稍后重试"
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
