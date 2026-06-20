import SwiftUI

struct LoginView: View {
    let onLogin: () -> Void
    @State private var phoneNumber = ""
    @State private var verificationCode = ""
    @State private var consent = LoginConsentState()
    @State private var presentedLegalDocument: LegalDocument?
    @State private var showsConsentReminder = false

    var body: some View {
        GeometryReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    LoginHero()
                        .frame(width: proxy.size.width - (AppTheme.screenPadding + 10) * 2, height: 250)
                        .padding(.top, 8)

                    LoginForm(
                        phoneNumber: $phoneNumber,
                        verificationCode: $verificationCode,
                        onLogin: authenticate
                    )
                    .padding(.top, 30)

                    OtherLoginDivider()
                        .padding(.top, 34)

                    Spacer(minLength: 20)

                    SecurityAssurance()
                        .frame(maxWidth: .infinity)
                        .offset(x: -22)

                    AgreementRow(
                        isOn: $consent.hasAcceptedTerms,
                        onOpenDocument: { presentedLegalDocument = $0 }
                    )
                        .frame(maxWidth: .infinity)
                        .padding(.top, 20)
                        .padding(.bottom, max(18, proxy.safeAreaInsets.bottom + 6))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(minHeight: proxy.size.height)
                .frame(width: proxy.size.width - (AppTheme.screenPadding + 10) * 2)
                .padding(.horizontal, AppTheme.screenPadding + 10)
            }
        }
        .background(LoginBackground().ignoresSafeArea())
        .sheet(item: $presentedLegalDocument) { document in
            NavigationStack {
                LegalDocumentView(document: document)
            }
        }
        .alert("请先阅读并同意", isPresented: $showsConsentReminder) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text("请先阅读并同意用户协议和隐私政策。")
        }
    }

    private func authenticate() {
        guard consent.canAuthenticate else {
            showsConsentReminder = true
            return
        }
        onLogin()
    }
}

private struct LoginHero: View {
    var body: some View {
        ZStack(alignment: .leading) {
            Image("LoginCardBackground")
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: 250)

            VStack(alignment: .leading, spacing: 13) {
                Text("欢迎使用\nAI 装机助手")
                    .font(.system(size: 29, weight: .heavy))
                    .foregroundStyle(AppTheme.primaryText)
                    .lineSpacing(7)
                    .fixedSize(horizontal: false, vertical: true)

                Rectangle()
                    .fill(AppTheme.secondaryText.opacity(0.65))
                    .frame(width: 24, height: 1)
                    .padding(.top, 3)
                    .padding(.bottom, 2)

                Text("智能推荐最佳配置方案\n装机更简单，选择更放心")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppTheme.secondaryText)
                    .lineSpacing(6)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.leading, 28)
            .padding(.top, 20)
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: Color.black.opacity(0.025), radius: 18, x: 0, y: 10)
        .clipped()
    }
}

private struct LoginForm: View {
    @Binding var phoneNumber: String
    @Binding var verificationCode: String
    let onLogin: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("手机号登录")
                .font(.system(size: 16, weight: .bold))
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
            .frame(height: 56)
            .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(AppTheme.border, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.022), radius: 10, x: 0, y: 7)

            HStack(spacing: 12) {
                Image(systemName: "number")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(AppTheme.mutedText)
                    .frame(width: 18)

                TextField("请输入验证码", text: $verificationCode)
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppTheme.primaryText)
            }
            .padding(.horizontal, 20)
            .frame(height: 56)
            .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(AppTheme.border, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.022), radius: 10, x: 0, y: 7)

            Button(action: onLogin) {
                Text("获取验证码")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.black, in: RoundedRectangle(cornerRadius: 16))
                    .shadow(color: Color.black.opacity(0.14), radius: 14, x: 0, y: 8)
            }
            .buttonStyle(.plain)
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
    let onOpenDocument: (LegalDocument) -> Void

    var body: some View {
        HStack(spacing: 7) {
            Button {
                isOn.toggle()
            } label: {
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(AppTheme.primaryButton)
                    .accessibilityLabel(isOn ? "取消同意" : "同意协议")
            }
            .buttonStyle(.plain)

            Text("我已阅读并同意")
                .foregroundStyle(AppTheme.primaryText)

            Button("《用户协议》") {
                onOpenDocument(.userAgreement)
            }
            .foregroundStyle(AppTheme.primaryButton)

            Text("和")
                .foregroundStyle(AppTheme.primaryText)

            Button("《隐私政策》") {
                onOpenDocument(.privacyPolicy)
            }
            .foregroundStyle(AppTheme.primaryButton)
        }
        .font(.system(size: 11, weight: .medium))
        .buttonStyle(.plain)
        .lineLimit(1)
        .minimumScaleFactor(0.78)
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
