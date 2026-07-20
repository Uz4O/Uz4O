import SwiftUI

struct LoginView: View {
    let onLogin: () -> Void
    @State private var showsPhoneLogin = false
    @State private var phoneNumber = ""
    @State private var verificationCode = ""
    @State private var consent = LoginConsentState(hasAcceptedTerms: true)
    @State private var presentedLegalDocument: LegalDocument?
    @State private var showsConsentReminder = false
    @State private var hasSentCode = false
    @State private var requestError: String?

    var body: some View {
        Group {
            if showsPhoneLogin {
                PhoneCodeLoginView(
                    phoneNumber: $phoneNumber,
                    verificationCode: $verificationCode,
                    consent: $consent,
                    hasSentCode: hasSentCode,
                    onBack: { showsPhoneLogin = false },
                    onRequestCode: requestVerificationCode,
                    onSubmit: authenticateWithCode,
                    onOpenDocument: { presentedLegalDocument = $0 }
                )
            } else {
                OneTapLoginView(
                    consent: $consent,
                    onLogin: authenticateWithOneTap,
                    onMoreLoginMethods: { showsPhoneLogin = true },
                    onOpenDocument: { presentedLegalDocument = $0 }
                )
            }
        }
        .background(Color.white.ignoresSafeArea())
        .preferredColorScheme(.light)
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
            Button("使用验证码登录") { showsPhoneLogin = true }
            Button("知道了", role: .cancel) { requestError = nil }
        } message: {
            Text(requestError ?? "请稍后重试")
        }
    }

    private func authenticateWithOneTap() {
        guard consent.canAuthenticate else {
            showsConsentReminder = true
            return
        }

#if DEBUG
        onLogin()
#else
        requestError = "一键登录服务暂不可用，请使用验证码登录"
#endif
    }

    private func authenticateWithCode() {
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

private struct OneTapLoginView: View {
    @Binding var consent: LoginConsentState
    let onLogin: () -> Void
    let onMoreLoginMethods: () -> Void
    let onOpenDocument: (LegalDocument) -> Void

    var body: some View {
        GeometryReader { proxy in
            let compact = proxy.size.height < 730
            let horizontalPadding = min(max(proxy.size.width * 0.09, 28), 44)
            let logoSize: CGFloat = compact ? 112 : 154

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    Text("UzBox")
                        .font(.system(size: compact ? 20 : 22, weight: .heavy))
                        .padding(.top, compact ? 10 : 22)

                    Text("Uz")
                        .font(.system(size: logoSize, weight: .black, design: .rounded))
                        .tracking(-logoSize * 0.1)
                        .accessibilityLabel("UzBox")
                        .padding(.top, compact ? 8 : 30)

                    Text("欢迎使用\nAI 装机助手")
                        .font(.system(size: compact ? 31 : 36, weight: .heavy))
                        .multilineTextAlignment(.center)
                        .lineSpacing(compact ? 5 : 8)
                        .padding(.top, compact ? -2 : 4)

                    Text("智能推荐最佳配置方案，让装机更简单")
                        .font(.system(size: compact ? 14 : 15, weight: .regular))
                        .foregroundStyle(Color.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, compact ? 12 : 18)

                    VStack(spacing: compact ? 5 : 7) {
                        Text("本机号码")
                            .font(.system(size: 13, weight: .regular))
                            .foregroundStyle(Color.secondary)

                        Text(maskedPhoneNumber)
                            .font(.system(size: compact ? 24 : 27, weight: .medium))

                        Text(carrierStatusText)
                            .font(.system(size: 12, weight: .regular))
                            .foregroundStyle(Color.secondary)
                    }
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.top, compact ? 24 : 54)

                    Button(action: onLogin) {
                        Text("本机号码一键登录")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: compact ? 50 : 52)
                            .background(Color.black, in: RoundedRectangle(cornerRadius: 16))
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: 288)
                    .padding(.top, compact ? 22 : 32)

                    Button(action: onMoreLoginMethods) {
                        HStack(spacing: 8) {
                            Text("更多登录方式")
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.secondary)
                        .frame(minHeight: 44)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, compact ? 10 : 18)

                    Spacer(minLength: compact ? 18 : 34)

                    AgreementRow(
                        isOn: $consent.hasAcceptedTerms,
                        onOpenDocument: onOpenDocument
                    )
                    .padding(.bottom, max(12, proxy.safeAreaInsets.bottom + 6))
                }
                .frame(width: proxy.size.width - horizontalPadding * 2)
                .frame(minHeight: proxy.size.height)
                .padding(.horizontal, horizontalPadding)
            }
        }
    }

    private var maskedPhoneNumber: String {
#if DEBUG
        "138****5621"
#else
        "本机号码"
#endif
    }

    private var carrierStatusText: String {
#if DEBUG
        "运营商认证预览，可一键登录"
#else
        "接入运营商认证后可一键登录"
#endif
    }
}

private struct PhoneCodeLoginView: View {
    @Binding var phoneNumber: String
    @Binding var verificationCode: String
    @Binding var consent: LoginConsentState
    let hasSentCode: Bool
    let onBack: () -> Void
    let onRequestCode: () -> Void
    let onSubmit: () -> Void
    let onOpenDocument: (LegalDocument) -> Void

    var body: some View {
        GeometryReader { proxy in
            let compact = proxy.size.height < 730

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    Button(action: onBack) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.black)
                            .frame(width: 44, height: 44)
                            .background(Color.black.opacity(0.05), in: Circle())
                    }
                    .buttonStyle(.plain)

                    Text("手机号登录")
                        .font(.system(size: compact ? 30 : 34, weight: .heavy))
                        .padding(.top, compact ? 28 : 48)

                    Text("输入手机号和验证码完成登录")
                        .font(.system(size: 15))
                        .foregroundStyle(Color.secondary)
                        .padding(.top, 10)

                    LoginForm(
                        phoneNumber: $phoneNumber,
                        verificationCode: $verificationCode,
                        hasSentCode: hasSentCode,
                        onRequestCode: onRequestCode,
                        onSubmit: onSubmit
                    )
                    .padding(.top, compact ? 34 : 50)

                    Spacer(minLength: 32)

                    AgreementRow(
                        isOn: $consent.hasAcceptedTerms,
                        onOpenDocument: onOpenDocument
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, max(12, proxy.safeAreaInsets.bottom + 6))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(minHeight: proxy.size.height)
                .padding(.horizontal, min(max(proxy.size.width * 0.075, 24), 34))
                .padding(.top, max(12, proxy.safeAreaInsets.top + 4))
            }
        }
    }
}

private struct LoginForm: View {
    @Binding var phoneNumber: String
    @Binding var verificationCode: String
    let hasSentCode: Bool
    let onRequestCode: () -> Void
    let onSubmit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "iphone")
                    .foregroundStyle(Color.secondary)
                    .frame(width: 20)

                TextField("", text: $phoneNumber, prompt: Text("请输入手机号"))
                    .keyboardType(.phonePad)
                    .textContentType(.telephoneNumber)
            }
            .modifier(LoginInputShell())

            HStack(spacing: 12) {
                Image(systemName: "number")
                    .foregroundStyle(Color.secondary)
                    .frame(width: 20)

                TextField("", text: $verificationCode, prompt: Text("请输入验证码"))
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)

                Button(hasSentCode ? "重新获取" : "获取验证码", action: onRequestCode)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.black)
            }
            .modifier(LoginInputShell())

            Button(action: onSubmit) {
                Text("登录")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.black, in: RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
        }
    }
}

private struct LoginInputShell: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 15, weight: .medium))
            .padding(.horizontal, 18)
            .frame(height: 56)
            .background(Color.black.opacity(0.035), in: RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.black.opacity(0.1), lineWidth: 1)
            )
    }
}

private struct AgreementRow: View {
    @Binding var isOn: Bool
    let onOpenDocument: (LegalDocument) -> Void

    var body: some View {
        HStack(spacing: 5) {
            Button {
                isOn.toggle()
            } label: {
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.black)
                    .frame(width: 30, height: 30)
                    .contentShape(Rectangle())
                    .accessibilityLabel(isOn ? "取消同意" : "同意协议")
            }

            Text("我已阅读并同意")
                .foregroundStyle(Color.secondary)

            Button("《用户协议》") {
                onOpenDocument(.userAgreement)
            }

            Text("和")
                .foregroundStyle(Color.secondary)

            Button("《隐私政策》") {
                onOpenDocument(.privacyPolicy)
            }
        }
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(.black)
        .buttonStyle(.plain)
        .lineLimit(1)
        .minimumScaleFactor(0.72)
    }
}

#Preview {
    LoginView(onLogin: {})
}
