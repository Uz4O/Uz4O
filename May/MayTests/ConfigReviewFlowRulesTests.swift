import Foundation

@main
struct ConfigReviewFlowRulesTests {
    static func main() {
        let viewSource = try! String(
            contentsOfFile: "May/May/Screens/ConfigReviewView.swift",
            encoding: .utf8
        )

        assertContains(viewSource, "case manualEntry", "The landing page should open a dedicated manual-entry flow.")
        assertContains(viewSource, "Text(\"填写配置\")", "Manual entry should use the approved title.")
        assertContains(viewSource, "HardwareCatalog.filters(for: title)", "Part choices should reuse the maintained hardware catalog.")
        assertContains(viewSource, "ConfigReviewContextSelector", "The review must capture use case and resolution.")
        assertContains(viewSource, "completedPartCount >= 2", "Submission should require multiple selected parts.")
        assertContains(viewSource, "result.pairingRating", "The report should display pairing score.")
        assertContains(viewSource, "result.performanceRating", "The report should display performance rating.")
        assertContains(viewSource, "result.findings.filter { $0.level != \"pass\" }", "Pass findings should not be counted as risks.")
        assertContains(viewSource, "result.webSources", "The report should disclose web research sources.")
        assertContains(viewSource, "UIPasteboard.general.string = result.replyText", "The seller reply action should copy real result text.")
        assertContains(viewSource, ".saturation(0)", "Review imagery should remain monochrome.")
        assertNotContains(viewSource, "粘贴配置单", "The removed paste-config mode should not return.")
        assertNotContains(viewSource, "ConfigReviewChecksView", "The removed four-icon checks strip should not return.")
        assertNotContains(viewSource, "查看示例", "The removed top example action should not return.")
        assertNotContains(viewSource, "第一次排雷？", "The removed bottom helper row should not return.")
        assertNotContains(viewSource, "TextField(\"价格\"", "Merchant price input should be removed.")
        assertNotContains(viewSource, "商家报价：", "Manual reviews should not send prices.")
        assertNotContains(viewSource, "priceDifference", "The report should not calculate price differences.")
        assertNotContains(viewSource, "budgetTitle", "The report should not show a budget metric.")

        print("ConfigReviewFlowRulesTests passed")
    }

    private static func assertContains(_ text: String, _ fragment: String, _ message: String) {
        guard text.contains(fragment) else {
            fatalError("\(message)\nMissing: \(fragment)")
        }
    }

    private static func assertNotContains(_ text: String, _ fragment: String, _ message: String) {
        guard !text.contains(fragment) else {
            fatalError("\(message)\nUnexpected: \(fragment)")
        }
    }
}
