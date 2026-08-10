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
        assertContains(viewSource, "TextField(\"价格\"", "Every selected part should accept a merchant price.")
        assertContains(viewSource, "completedPartCount >= 2", "Submission should require multiple complete part rows.")
        assertContains(viewSource, "商家报价：", "Manual entries should include the calculated merchant total sent for review.")
        assertContains(viewSource, "UIPasteboard.general.string = result.replyText", "The seller reply action should copy real result text.")
        assertContains(viewSource, ".saturation(0)", "Review imagery should remain monochrome.")
        assertNotContains(viewSource, "粘贴配置单", "The removed paste-config mode should not return.")
        assertNotContains(viewSource, "ConfigReviewChecksView", "The removed four-icon checks strip should not return.")
        assertNotContains(viewSource, "查看示例", "The removed top example action should not return.")
        assertNotContains(viewSource, "第一次排雷？", "The removed bottom helper row should not return.")

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
