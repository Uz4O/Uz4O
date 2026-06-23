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

        let communityGuidelines = try! String(
            contentsOfFile: "May/May/Legal/CommunityGuidelines.md",
            encoding: .utf8
        )
        assertContains(communityGuidelines, "未满14周岁", "Community rules must repeat the child age boundary.")
        assertContains(communityGuidelines, "网络暴力", "Community rules must cover online violence and harassment.")
        assertContains(communityGuidelines, "价格、性能、兼容性", "Community rules must cover hardware advice risk.")
        assertContains(communityGuidelines, "优先处理涉未成年人", "Community rules must prioritize minor-related reports.")
        assertContains(communityGuidelines, "15个工作日", "Community appeal response timing should stay visible.")
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
}
