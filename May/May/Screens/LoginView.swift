import SwiftUI

struct LoginView: View {
    let onLogin: () -> Void
    @State private var phoneNumber = ""
    @State private var verificationCode = ""
    @State private var consent = LoginConsentState(hasAcceptedTerms: true)
    @State private var presentedLegalDocument: LegalDocument?
    @State private var showsConsentReminder = false
    @State private var hasSentCode = false
    @State private var requestError: String?

    var body: some View {
        GeometryReader { proxy in
            let horizontalPadding = min(max(proxy.size.width * 0.066, 24), 30)
            let heroHeight = min(max(proxy.size.height * 0.29, 242), 258)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    LoginHero()
                        .frame(width: proxy.size.width - horizontalPadding * 2, height: heroHeight)
                        .padding(.top, max(18, proxy.safeAreaInsets.top + 4))

                    LoginForm(
                        phoneNumber: $phoneNumber,
                        verificationCode: $verificationCode,
                        hasSentCode: hasSentCode,
                        isSubmitting: false,
                        onRequestCode: requestVerificationCode,
                        onSubmit: authenticate
                    )
                    .padding(.top, 18)

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
                .frame(width: proxy.size.width - horizontalPadding * 2)
                .padding(.horizontal, horizontalPadding)
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
        .alert("登录失败", isPresented: errorIsPresented) {
            Button("知道了", role: .cancel) { requestError = nil }
        } message: {
            Text(requestError ?? "请稍后重试")
        }
    }

    private func authenticate() {
        guard consent.canAuthenticate else {
            showsConsentReminder = true
            return
        }
        guard hasSentCode else {
            requestError = "请先获取验证码"
            return
        }
        guard DevelopmentLoginMode.canCompleteLogin(phone: phoneNumber, code: verificationCode, consent: consent) else {
            if !DevelopmentLoginMode.isValidPhone(phoneNumber) {
                requestError = "请输入有效手机号"
            } else {
                requestError = "开发测试阶段请使用验证码 \(DevelopmentLoginMode.testVerificationCode)"
            }
            return
        }

        onLogin()
    }

    private func requestVerificationCode() {
        guard consent.canAuthenticate else {
            showsConsentReminder = true
            return
        }
        guard DevelopmentLoginMode.canRequestCode(phone: phoneNumber, consent: consent) else {
            requestError = "请输入有效手机号"
            return
        }

        verificationCode = DevelopmentLoginMode.testVerificationCode
        hasSentCode = true
    }

    private var errorIsPresented: Binding<Bool> {
        Binding(
            get: { requestError != nil },
            set: { if !$0 { requestError = nil } }
        )
    }
}

private struct LoginHero: View {
    var body: some View {
        GeometryReader { proxy in
            let pcWidth = min(max(proxy.size.width * 0.43, 146), 165)

            ZStack(alignment: .topLeading) {
                LoginHeroLight()

                Image("LoginPCTowerHero")
                    .resizable()
                    .scaledToFit()
                    .frame(width: pcWidth)
                    .position(
                        x: proxy.size.width - pcWidth * 0.34,
                        y: proxy.size.height * 0.55
                    )

                VStack(alignment: .leading, spacing: 0) {
                    Text("UzBox")
                        .font(.system(size: 18, weight: .heavy))
                        .foregroundStyle(.black)
                        .padding(.bottom, 28)

                    Text("欢迎使用\nAI 装机助手")
                        .font(.system(size: 28, weight: .heavy))
                        .foregroundStyle(.black)
                        .lineSpacing(8)
                        .fixedSize(horizontal: false, vertical: true)

                    Rectangle()
                        .fill(Color.black.opacity(0.9))
                        .frame(width: 22, height: 1.5)
                        .padding(.top, 24)

                    Text("智能推荐最佳配置方案\n装机更简单，选择更放心")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color(red: 0.43, green: 0.46, blue: 0.50))
                        .lineSpacing(7)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 16)
                }
                .padding(.top, 8)
            }
        }
    }
}

private struct LoginHeroLight: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.white.opacity(0),
                    Color.white.opacity(0.78),
                    Color.white.opacity(0)
                ],
                startPoint: .topTrailing,
                endPoint: .bottomLeading
            )
            .rotationEffect(.degrees(6))
            .offset(x: 54, y: 8)

            Path { path in
                path.move(to: CGPoint(x: 330, y: 10))
                path.addLine(to: CGPoint(x: 210, y: 246))
            }
            .stroke(Color.white.opacity(0.9), lineWidth: 1)
            .shadow(color: Color.white.opacity(0.7), radius: 7)
        }
        .allowsHitTesting(false)
    }
}

private struct LoginForm: View {
    @Binding var phoneNumber: String
    @Binding var verificationCode: String
    let hasSentCode: Bool
    let isSubmitting: Bool
    let onRequestCode: () -> Void
    let onSubmit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("手机号登录")
                .font(.system(size: 15, weight: .heavy))
                .foregroundStyle(.black)
                .padding(.bottom, 4)

            HStack(spacing: 12) {
                Image(systemName: "iphone")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(Color(red: 0.45, green: 0.48, blue: 0.52))
                    .frame(width: 20)

                TextField(
                    "",
                    text: $phoneNumber,
                    prompt: Text("请输入手机号")
                        .foregroundColor(Color(red: 0.72, green: 0.74, blue: 0.77))
                )
                    .keyboardType(.phonePad)
                    .textContentType(.telephoneNumber)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.black)
            }
            .modifier(LoginInputShell())

            HStack(spacing: 12) {
                Image(systemName: "number")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(Color(red: 0.45, green: 0.48, blue: 0.52))
                    .frame(width: 20)

                TextField(
                    "",
                    text: $verificationCode,
                    prompt: Text("请输入验证码")
                        .foregroundColor(Color(red: 0.72, green: 0.74, blue: 0.77))
                )
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.black)

                Button(action: onRequestCode) {
                    Text(hasSentCode ? "重新获取" : "获取验证码")
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundStyle(.black)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                }
                .buttonStyle(.plain)
            }
            .modifier(LoginInputShell())
            .padding(.top, 4)

            Button(action: onSubmit) {
                Text(isSubmitting ? "请稍候..." : "登录")
                    .font(.system(size: 15, weight: .heavy))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 47)
                    .background(Color.black, in: RoundedRectangle(cornerRadius: 16))
                    .shadow(color: Color.black.opacity(0.14), radius: 14, x: 0, y: 8)
            }
            .buttonStyle(.plain)
            .disabled(isSubmitting)
            .opacity(isSubmitting ? 0.65 : 1)
            .padding(.top, 12)
        }
    }
}

private struct LoginInputShell: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 20)
            .frame(height: 56)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 18))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(Color(red: 0.88, green: 0.89, blue: 0.91), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.018), radius: 10, x: 0, y: 6)
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
                Color(red: 0.992, green: 0.994, blue: 0.996),
                Color(red: 0.978, green: 0.984, blue: 0.988)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

#Preview {
    LoginView(onLogin: {})
}
