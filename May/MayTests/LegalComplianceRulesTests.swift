import Foundation

@main
struct LegalComplianceRulesTests {
    static func main() {
        assertEqual(
            LegalDocument.allCases.map(\.title),
            ["用户协议", "隐私政策", "第三方信息共享清单"],
            "Launch legal documents should match the no-community build."
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

        let userAgreement = try! String(contentsOfFile: "May/May/Legal/UserAgreement.md", encoding: .utf8)
        let privacyPolicy = try! String(contentsOfFile: "May/May/Legal/PrivacyPolicy.md", encoding: .utf8)
        let thirdPartyList = try! String(contentsOfFile: "May/May/Legal/ThirdPartySharingList.md", encoding: .utf8)
        for legalText in [userAgreement, privacyPolicy, thirdPartyList] {
            assertNotContains(legalText, "社区", "Launch legal text must not describe removed community features.")
            assertNotContains(legalText, "帖子", "Launch legal text must not describe removed community posts.")
            assertNotContains(legalText, "评论", "Launch legal text must not describe removed community comments.")
            assertNotContains(legalText, "屏蔽", "Launch legal text must not describe removed community blocks.")
        }
        print("LegalComplianceRulesTests passed")
    }

    private static func assertEqual<T: Equatable>(_ actual: T, _ expected: T, _ message: String) {
        guard actual == expected else {
            fatalError("\(message)\nExpected: \(expected)\nActual: \(actual)")
        }
    }

    private static func assertContains(_ text: String, _ expectedFragment: String, _ message: String) {
        guard text.contains(expectedFragment) else {
            fatalError("\(message)\nMissing: \(expectedFragment)")
        }
    }

    private static func assertNotContains(_ text: String, _ unexpectedFragment: String, _ message: String) {
        guard !text.contains(unexpectedFragment) else {
            fatalError("\(message)\nUnexpected: \(unexpectedFragment)")
        }
    }
}
