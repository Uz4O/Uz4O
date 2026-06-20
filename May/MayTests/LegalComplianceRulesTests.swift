import Foundation

@main
struct LegalComplianceRulesTests {
    static func main() {
        assertEqual(
            LegalDocument.allCases.map(\.title),
            ["用户协议", "隐私政策", "第三方信息共享清单", "社区规范"],
            "Every effective legal document should have an in-app destination."
        )
        assertEqual(
            LoginConsentState().canAuthenticate,
            false,
            "Consent must be off by default."
        )
        assertEqual(
            LoginConsentState(hasAcceptedTerms: true).canAuthenticate,
            true,
            "Authentication is available only after active consent."
        )
        precondition(AIContentDisclosure.text.contains("AI 辅助生成"))
        assertEqual(LegalContact.operatorName, "孙裕凤", "Operator metadata must stay consistent.")
        assertEqual(LegalContact.email, "youz66811@gmail.com", "Contact metadata must stay consistent.")
        print("LegalComplianceRulesTests passed")
    }

    private static func assertEqual<T: Equatable>(_ actual: T, _ expected: T, _ message: String) {
        guard actual == expected else {
            fatalError("\(message)\nExpected: \(expected)\nActual: \(actual)")
        }
    }
}
