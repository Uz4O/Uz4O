import SwiftUI

struct LoginView: View {
    let onLogin: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer(minLength: 96)

            Text("欢迎使用\nAI 装机助手")
                .font(.appLargeTitle)
                .foregroundStyle(AppTheme.primaryText)
                .lineSpacing(8)

            Spacer(minLength: 68)

            Text("手机号登录")
                .font(.appCaption)
                .foregroundStyle(AppTheme.secondaryText)

            TextField("请输入手机号", text: .constant(""))
                .keyboardType(.phonePad)
                .font(.appBody)
                .padding(.horizontal, 18)
                .frame(height: 58)
                .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(AppTheme.border, lineWidth: 1)
                )
                .padding(.top, 10)

            PrimaryButton(title: "获取验证码", icon: nil, action: onLogin)
                .padding(.top, 22)

            Spacer()

            HStack(spacing: 12) {
                Rectangle().fill(AppTheme.border).frame(height: 1)
                Text("其他登录方式")
                    .font(.appCaption)
                    .foregroundStyle(AppTheme.secondaryText)
                Rectangle().fill(AppTheme.border).frame(height: 1)
            }

            Button(action: {}) {
                Image(systemName: "message.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(AppTheme.success)
                    .frame(width: 38, height: 38)
                    .background(AppTheme.surface, in: Circle())
                    .overlay(Circle().stroke(AppTheme.success.opacity(0.55), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity)
            .padding(.top, 18)

            HStack(spacing: 7) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 9))
                Text("我已阅读并同意《用户协议》和《隐私政策》")
                    .font(.system(size: 8))
            }
            .foregroundStyle(AppTheme.primaryText)
            .frame(maxWidth: .infinity)
            .padding(.top, 24)
        }
        .padding(.horizontal, AppTheme.screenPadding)
        .padding(.bottom, 22)
    }
}

#Preview {
    LoginView(onLogin: {})
}
