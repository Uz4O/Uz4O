import Foundation

enum LegalDocument: String, CaseIterable, Hashable, Identifiable {
    case userAgreement = "UserAgreement"
    case privacyPolicy = "PrivacyPolicy"
    case thirdPartySharing = "ThirdPartySharingList"
    case communityGuidelines = "CommunityGuidelines"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .userAgreement:
            "用户协议"
        case .privacyPolicy:
            "隐私政策"
        case .thirdPartySharing:
            "第三方信息共享清单"
        case .communityGuidelines:
            "社区规范"
        }
    }

    func load(bundle: Bundle = .main) throws -> String {
        let bundledURL = bundle.url(
            forResource: rawValue,
            withExtension: "md",
            subdirectory: "Legal"
        ) ?? bundle.url(forResource: rawValue, withExtension: "md")

        guard let bundledURL else {
            throw CocoaError(.fileNoSuchFile)
        }

        return try String(contentsOf: bundledURL, encoding: .utf8)
    }
}

struct LoginConsentState: Equatable {
    var hasAcceptedTerms = false

    var canAuthenticate: Bool { hasAcceptedTerms }
}

enum AIContentDisclosure {
    static let text = "内容由 AI 辅助生成，仅供装机参考，请在购买前核对价格、规格与兼容性。"
}

enum LegalContact {
    static let operatorName = "孙裕凤"
    static let email = "youz66811@gmail.com"
}

enum DevelopmentLoginMode {
    static let testVerificationCode = "123456"
    static let restoresBackendSession = false

    static func canRequestCode(phone: String, consent: LoginConsentState) -> Bool {
        consent.canAuthenticate && isValidPhone(phone)
    }

    static func canCompleteLogin(phone: String, code: String, consent: LoginConsentState) -> Bool {
        canRequestCode(phone: phone, consent: consent) && code == testVerificationCode
    }

    static func isValidPhone(_ phone: String) -> Bool {
        phone.range(of: #"^\+?[0-9]{5,32}$"#, options: .regularExpression) != nil
    }
}
