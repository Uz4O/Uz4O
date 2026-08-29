import AuthenticationServices
import CryptoKit
import Security
import SwiftUI

struct LoginView: View {
    @ObservedObject var session: AppSession
    let onLogin: () -> Void

    @State private var consent = LoginConsentState()
    @State private var presentedLegalDocument: LegalDocument?
    @State private var showsConsentReminder = false
    @State private var requestError: String?
    @State private var currentNonce: String?
    @State private var isAuthenticating = false

    var body: some View {
        AppleLoginView(
            consent: $consent,
            isAuthenticating: isAuthenticating,
            onRequest: prepareAppleAuthorization,
            onCompletion: completeAppleAuthorization,
            onMissingConsent: { showsConsentReminder = true },
            onOpenDocument: { presentedLegalDocument = $0 }
        )
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
            Button("知道了", role: .cancel) { requestError = nil }
        } message: {
            Text(requestError ?? "请稍后重试")
        }
    }

    private func prepareAppleAuthorization(_ request: ASAuthorizationAppleIDRequest) {
        do {
            let nonce = try AppleLoginNonce.make()
            currentNonce = nonce
            request.requestedScopes = [.fullName, .email]
            request.nonce = AppleLoginNonce.sha256(nonce)
        } catch {
            currentNonce = nil
            requestError = error.localizedDescription
        }
    }

    private func completeAppleAuthorization(
        _ result: Result<ASAuthorization, Error>
    ) {
        switch result {
        case .success(let authorization):
            guard consent.canAuthenticate else {
                currentNonce = nil
                showsConsentReminder = true
                return
            }
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let nonce = currentNonce,
                  let identityTokenData = credential.identityToken,
                  let identityToken = String(data: identityTokenData, encoding: .utf8),
                  !credential.user.isEmpty else {
                currentNonce = nil
                requestError = "无法读取 Apple 身份凭证，请重试"
                return
            }

            let authorizationCode = credential.authorizationCode.flatMap {
                String(data: $0, encoding: .utf8)
            }
            currentNonce = nil
            isAuthenticating = true

            Task {
                defer { isAuthenticating = false }
                do {
                    try await session.loginWithApple(
                        identityToken: identityToken,
                        authorizationCode: authorizationCode,
                        nonce: nonce,
                        appleUserID: credential.user
                    )
                    onLogin()
                } catch {
                    requestError = error.localizedDescription
                }
            }
        case .failure(let error):
            currentNonce = nil
            if let authorizationError = error as? ASAuthorizationError,
               authorizationError.code == .canceled {
                return
            }
            requestError = appleAuthorizationErrorMessage(error)
        }
    }

    private var errorIsPresented: Binding<Bool> {
        Binding(
            get: { requestError != nil },
            set: { if !$0 { requestError = nil } }
        )
    }
}

private func appleAuthorizationErrorMessage(_ error: Error) -> String {
    guard let authorizationError = error as? ASAuthorizationError else {
        return error.localizedDescription
    }

    switch authorizationError.code {
    case .unknown:
        #if targetEnvironment(simulator)
        return "当前运行在 iOS 模拟器，Apple 账户授权可能不可用。请先在模拟器“设置”完成 Apple 账户验证；更稳妥的是使用已登录 Apple ID 的真实 iPhone 或 TestFlight 测试。"
        #else
        return "Apple 登录暂时不可用，请确认设备已登录 Apple ID、网络正常后重试。"
        #endif
    case .invalidResponse, .notHandled, .failed:
        return "Apple 登录暂时不可用，请确认设备已登录 Apple ID、网络正常后重试。"
    default:
        return "Apple 登录暂时不可用，请稍后重试。"
    }
}

private struct AppleLoginView: View {
    @Binding var consent: LoginConsentState
    let isAuthenticating: Bool
    let onRequest: (ASAuthorizationAppleIDRequest) -> Void
    let onCompletion: (Result<ASAuthorization, Error>) -> Void
    let onMissingConsent: () -> Void
    let onOpenDocument: (LegalDocument) -> Void

    var body: some View {
        GeometryReader { proxy in
            let compact = proxy.size.height < 730
            let horizontalPadding = min(max(proxy.size.width * 0.075, 24), 34)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("UzBox")
                        .font(.system(size: compact ? 23 : 26, weight: .black))
                        .tracking(-1)
                        .accessibilityLabel("UzBox")
                        .padding(.top, compact ? 10 : 18)

                    Image("LoginHardwareHero")
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .accessibilityHidden(true)
                        .padding(.top, compact ? 4 : 10)

                    Text("更聪明地\n装好一台电脑")
                        .font(.system(size: compact ? 33 : 36, weight: .black))
                        .tracking(-1.2)
                        .lineSpacing(compact ? 2 : 5)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, compact ? 4 : 8)

                    Text("从需求到配置，UzBox 帮你做出更稳妥的选择")
                        .font(.system(size: compact ? 13 : 14, weight: .regular))
                        .foregroundStyle(Color(white: 0.52))
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                        .padding(.top, compact ? 10 : 14)

                    ZStack {
                        SignInWithAppleButton(
                            .signIn,
                            onRequest: onRequest,
                            onCompletion: onCompletion
                        )
                        .signInWithAppleButtonStyle(.black)
                        .frame(height: compact ? 54 : 58)
                        .clipShape(RoundedRectangle(cornerRadius: 17))
                        .allowsHitTesting(consent.canAuthenticate && !isAuthenticating)

                        if !consent.canAuthenticate {
                            Color.clear
                                .contentShape(Rectangle())
                                .onTapGesture(perform: onMissingConsent)
                                .accessibilityLabel("请先同意用户协议和隐私政策")
                        }

                        if isAuthenticating {
                            RoundedRectangle(cornerRadius: 17)
                                .fill(Color.black.opacity(0.82))
                            ProgressView()
                                .tint(.white)
                                .accessibilityLabel("正在登录")
                        }
                    }
                    .frame(maxWidth: 320)
                    .frame(maxWidth: .infinity)
                    .padding(.top, compact ? 42 : 58)

                    AgreementRow(
                        isOn: $consent.hasAcceptedTerms,
                        onOpenDocument: onOpenDocument
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.top, compact ? 14 : 18)
                    .padding(.bottom, max(14, proxy.safeAreaInsets.bottom + 8))
                }
                .frame(width: proxy.size.width - horizontalPadding * 2)
                .padding(.horizontal, horizontalPadding)
            }
        }
    }
}

private enum AppleLoginNonce {
    private static let characters = Array(
        "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._"
    )

    static func make(length: Int = 32) throws -> String {
        precondition(length > 0)
        var result = ""
        var remaining = length

        while remaining > 0 {
            var randomBytes = [UInt8](repeating: 0, count: 16)
            let status = randomBytes.withUnsafeMutableBytes { buffer in
                SecRandomCopyBytes(
                    kSecRandomDefault,
                    buffer.count,
                    buffer.baseAddress!
                )
            }
            guard status == errSecSuccess else {
                throw AppleLoginNonceError(status: status)
            }

            for byte in randomBytes where byte < characters.count {
                result.append(characters[Int(byte)])
                remaining -= 1
                if remaining == 0 { break }
            }
        }

        return result
    }

    static func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }
}

private struct AppleLoginNonceError: LocalizedError {
    let status: OSStatus

    var errorDescription: String? {
        "无法创建安全登录请求（\(status)）"
    }
}

private struct AgreementRow: View {
    @Binding var isOn: Bool
    let onOpenDocument: (LegalDocument) -> Void

    var body: some View {
        HStack(spacing: 4) {
            Button {
                isOn.toggle()
            } label: {
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 21, weight: .medium))
                    .foregroundStyle(isOn ? Color.black : Color(white: 0.56))
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
                    .accessibilityLabel(isOn ? "取消同意" : "同意协议")
            }

            Text("我已阅读并同意")
                .foregroundStyle(Color(white: 0.48))

            Button("《用户协议》") {
                onOpenDocument(.userAgreement)
            }

            Text("和")
                .foregroundStyle(Color(white: 0.48))

            Button("《隐私政策》") {
                onOpenDocument(.privacyPolicy)
            }
        }
        .font(.system(size: 11.5, weight: .medium))
        .foregroundStyle(.black)
        .buttonStyle(.plain)
        .lineLimit(1)
        .minimumScaleFactor(0.72)
    }
}

#Preview {
    LoginView(session: AppSession(), onLogin: {})
}
