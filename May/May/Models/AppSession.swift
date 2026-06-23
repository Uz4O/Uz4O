import Foundation
import Security
import Combine

protocol TokenStore {
    func save(_ token: String) throws
    func load() throws -> String?
    func delete() throws
}

struct KeychainTokenStore: TokenStore {
    private let service = "AI-PC-Builder"
    private let account = "access-token"

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

    let api: AppAPIClient
    private let tokenStore: TokenStore

    var isAuthenticated: Bool { accessToken != nil }

    convenience init() {
        self.init(api: AppAPIClient(), tokenStore: KeychainTokenStore())
    }

    init(api: AppAPIClient, tokenStore: TokenStore) {
        self.api = api
        self.tokenStore = tokenStore
        accessToken = try? tokenStore.load()
    }

    func sendSMS(phone: String) async throws -> String? {
        let response = try await api.sendSMS(phone: phone)
        return response.debugCode
    }

    func login(phone: String, code: String) async throws {
        let response = try await api.login(phone: phone, code: code)
        try tokenStore.save(response.accessToken)
        accessToken = response.accessToken
        accountID = response.account.id
    }

    func logout() throws {
        try tokenStore.delete()
        accessToken = nil
        accountID = nil
    }

    func deleteAccount() async throws {
        guard let accessToken else {
            throw APIError.http(status: 401, message: "登录状态已失效，请重新登录")
        }
        try await api.deleteAccount(confirmation: "DELETE", token: accessToken)
        try? tokenStore.delete()
        self.accessToken = nil
        accountID = nil
    }
}
