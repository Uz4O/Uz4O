import Foundation

@main
struct LoginDevelopmentModeTests {
    static func main() {
        assertEqual(
            DevelopmentLoginMode.testVerificationCode,
            "123456",
            "Development login should use a predictable local verification code."
        )
        assertEqual(
            DevelopmentLoginMode.restoresBackendSession,
            false,
            "Development login should not restore a persisted backend session."
        )
        assertEqual(
            DevelopmentLoginMode.canRequestCode(phone: "13800138000", consent: LoginConsentState(hasAcceptedTerms: true)),
            true,
            "A valid phone and active consent should allow requesting the local code."
        )
        assertEqual(
            DevelopmentLoginMode.canRequestCode(phone: "13800138000", consent: LoginConsentState()),
            false,
            "The local login shortcut must still require legal consent."
        )
        assertEqual(
            DevelopmentLoginMode.canCompleteLogin(phone: "13800138000", code: "123456", consent: LoginConsentState(hasAcceptedTerms: true)),
            true,
            "The local login shortcut should accept the development code."
        )
        assertEqual(
            DevelopmentLoginMode.canCompleteLogin(phone: "13800138000", code: "000000", consent: LoginConsentState(hasAcceptedTerms: true)),
            false,
            "The local login shortcut should reject any non-development code."
        )
        print("LoginDevelopmentModeTests passed")
    }

    private static func assertEqual<T: Equatable>(_ actual: T, _ expected: T, _ message: String) {
        guard actual == expected else {
            fatalError("\(message)\nExpected: \(expected)\nActual: \(actual)")
        }
    }
}
