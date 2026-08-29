import Foundation
import Security
import Combine
import AuthenticationServices

protocol TokenStore {
    func save(_ token: String) throws
    func load() throws -> String?
    func delete() throws
}

struct KeychainTokenStore: TokenStore {
    private let service = "AI-PC-Builder"
    private let account: String

    init(account: String = "access-token") {
        self.account = account
    }

    func save(_ token: String) throws {
        try delete()
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            kSecValueData as String: Data(token.utf8)
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError(status: status)
        }
    }

    func load() throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess,
              let data = item as? Data,
              let token = String(data: data, encoding: .utf8) else {
            throw KeychainError(status: status)
        }
        return token
    }

    func delete() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError(status: status)
        }
    }
}

private struct KeychainError: LocalizedError {
    let status: OSStatus

    var errorDescription: String? { "无法安全保存登录状态（\(status)）" }
}

@MainActor
final class AppSession: ObservableObject {
    @Published private(set) var accessToken: String?
    @Published private(set) var accountID: String?
    @Published private(set) var isRestoringSession = false

    let api: AppAPIClient
    private let tokenStore: TokenStore
    private let appleUserStore: TokenStore
    private var unauthorizedObserver: NSObjectProtocol?

    var isAuthenticated: Bool { accessToken != nil }

    convenience init() {
        self.init(
            api: AppAPIClient(),
            tokenStore: KeychainTokenStore(),
            appleUserStore: KeychainTokenStore(account: "apple-user-id")
        )
    }

    init(
        api: AppAPIClient,
        tokenStore: TokenStore,
        appleUserStore: TokenStore? = nil
    ) {
        self.api = api
        self.tokenStore = tokenStore
        self.appleUserStore = appleUserStore ?? KeychainTokenStore(account: "apple-user-id")
        accessToken = try? tokenStore.load()
        isRestoringSession = accessToken != nil
        unauthorizedObserver = NotificationCenter.default.addObserver(
            forName: .appSessionUnauthorized,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.handleUnauthorized()
            }
        }
    }

    deinit {
        if let unauthorizedObserver {
            NotificationCenter.default.removeObserver(unauthorizedObserver)
        }
    }

    func sendSMS(phone: String) async throws -> String? {
        let response = try await api.sendSMS(phone: phone)
        return response.debugCode
    }

    func login(phone: String, code: String) async throws {
        let response = try await api.login(phone: phone, code: code)
        try persistLogin(response, appleUserID: nil)
    }

    func loginWithApple(
        identityToken: String,
        authorizationCode: String?,
        nonce: String,
        appleUserID: String
    ) async throws {
        let response = try await api.loginWithApple(
            identityToken: identityToken,
            authorizationCode: authorizationCode,
            nonce: nonce
        )
        try persistLogin(response, appleUserID: appleUserID)
    }

    private func persistLogin(_ response: LoginResponse, appleUserID: String?) throws {
        try tokenStore.save(response.accessToken)
        if let appleUserID {
            try appleUserStore.save(appleUserID)
        } else {
            try? appleUserStore.delete()
        }
        accessToken = response.accessToken
        accountID = response.account.id
        isRestoringSession = false
    }

    func restoreStoredSession() async {
        guard let accessToken else {
            isRestoringSession = false
            return
        }

        let appleUserID = (try? appleUserStore.load()) ?? nil
        if let appleUserID {
            if let state = await appleCredentialState(for: appleUserID),
               state == .revoked || state == .notFound {
                handleUnauthorized()
                isRestoringSession = false
                return
            }
        }

        do {
            let account = try await api.currentAccount(token: accessToken)
            accountID = account.id
        } catch APIError.http(let status, _) where status == 401 {
            handleUnauthorized()
        } catch {
            // 网络暂时不可用时保留 token，避免把用户强制登出。
        }
        isRestoringSession = false
    }

    func logout() throws {
        try tokenStore.delete()
        try? appleUserStore.delete()
        accessToken = nil
        accountID = nil
        isRestoringSession = false
    }

    func deleteAccount() async throws {
        guard let accessToken else {
            throw APIError.http(status: 401, message: "登录状态已失效，请重新登录")
        }
        try await api.deleteAccount(confirmation: "DELETE", token: accessToken)
        try? tokenStore.delete()
        try? appleUserStore.delete()
        self.accessToken = nil
        accountID = nil
        isRestoringSession = false
    }

    private func handleUnauthorized() {
        guard accessToken != nil else { return }
        try? tokenStore.delete()
        try? appleUserStore.delete()
        accessToken = nil
        accountID = nil
        isRestoringSession = false
    }

    private func appleCredentialState(
        for userID: String
    ) async -> ASAuthorizationAppleIDProvider.CredentialState? {
        await withCheckedContinuation { continuation in
            ASAuthorizationAppleIDProvider().getCredentialState(forUserID: userID) { state, error in
                continuation.resume(returning: error == nil ? state : nil)
            }
        }
    }
}
