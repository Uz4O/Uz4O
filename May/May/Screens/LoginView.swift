import SwiftUI

struct LoginView: View {
    let onLogin: () -> Void
    @State private var phoneNumber = ""
    @State private var hasAgreed = true

    var body: some View {
        GeometryReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    LoginHero()
                        .padding(.top, max(38, proxy.safeAreaInsets.top + 30))

                    LoginForm(
                        phoneNumber: $phoneNumber,
                        onLogin: onLogin
                    )
                    .padding(.top, 58)

                    OtherLoginDivider()
                        .padding(.top, 38)

                    Spacer(minLength: 70)

                    SecurityAssurance()
                        .frame(maxWidth: .infinity)
                        .offset(x: -22)

                    AgreementRow(isOn: $hasAgreed)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 20)
                        .padding(.bottom, max(18, proxy.safeAreaInsets.bottom + 6))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(minHeight: proxy.size.height)
                .padding(.horizontal, AppTheme.screenPadding + 10)
            }
        }
        .background(LoginBackground().ignoresSafeArea())
    }
}

private struct LoginHero: View {
    var body: some View {
        HStack(alignment: .center, spacing: 4) {
            VStack(alignment: .leading, spacing: 20) {
                Text("欢迎使用\nAI 装机助手")
                    .font(.system(size: 27, weight: .bold))
                    .foregroundStyle(AppTheme.primaryText)
                    .lineSpacing(6)
                    .fixedSize(horizontal: false, vertical: true)

                Text("智能推荐最佳配置方案\n装机更简单，选择更放心")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppTheme.secondaryText)
                    .lineSpacing(7)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            ZStack {
                Circle()
                    .fill(Color(red: 0.92, green: 0.96, blue: 1.0).opacity(0.72))
                    .frame(width: 116, height: 116)
                    .blur(radius: 2)
                    .offset(y: 10)

                Image("RobotMascot")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 138, height: 138)
                    .shadow(color: Color(red: 0.45, green: 0.53, blue: 0.66).opacity(0.18), radius: 16, x: 0, y: 14)
            }
            .frame(width: 136, height: 144)
            .offset(x: 12, y: 8)
        }
    }
}

private struct LoginForm: View {
    @Binding var phoneNumber: String
    let onLogin: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("手机号登录")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(AppTheme.primaryText)

            HStack(spacing: 12) {
                Image(systemName: "iphone")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(AppTheme.mutedText)
                    .frame(width: 18)

                TextField("请输入手机号", text: $phoneNumber)
                    .keyboardType(.phonePad)
                    .textContentType(.telephoneNumber)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppTheme.primaryText)
            }
            .padding(.horizontal, 20)
            .frame(height: 58)
            .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(AppTheme.border, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.022), radius: 10, x: 0, y: 7)

            Button(action: onLogin) {
                Text("获取验证码")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(
                        LinearGradient(
                            colors: [
                                Color(red: 0.018, green: 0.055, blue: 0.135),
                                Color(red: 0.028, green: 0.145, blue: 0.310)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        in: RoundedRectangle(cornerRadius: 14)
                    )
                    .shadow(color: AppTheme.primaryButton.opacity(0.16), radius: 14, x: 0, y: 8)
            }
            .buttonStyle(.plain)
            .padding(.top, 10)
        }
    }
}

private struct OtherLoginDivider: View {
    var body: some View {
        HStack(spacing: 15) {
            Rectangle()
                .fill(AppTheme.border)
                .frame(height: 1)

            Text("其他登录方式")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AppTheme.secondaryText)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)

            Rectangle()
                .fill(AppTheme.border)
                .frame(height: 1)
        }
        .padding(.horizontal, 64)
    }
}

private struct SecurityAssurance: View {
    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            ZStack {
                Image(systemName: "shield.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(AppTheme.primaryButton)

                Image(systemName: "checkmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white)
                    .offset(y: -1)
            }
            .frame(width: 28, height: 32)

            Text("数据安全保障")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(AppTheme.primaryText)
        }
    }
}

private struct AgreementRow: View {
    @Binding var isOn: Bool

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(AppTheme.primaryButton)

                Text("我已阅读并同意《用户协议》和《隐私政策》")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppTheme.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct LoginBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color.white,
                Color(red: 0.985, green: 0.990, blue: 0.992),
                Color(red: 0.952, green: 0.970, blue: 0.976)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

#Preview {
    LoginView(onLogin: {})
}
