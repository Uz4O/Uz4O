import Foundation

@main
struct ConfigReviewFlowRulesTests {
    static func main() {
        let viewSource = try! String(
            contentsOfFile: "May/May/Screens/ConfigReviewView.swift",
            encoding: .utf8
        )
        let apiSource = try! String(
            contentsOfFile: "May/May/Networking/AppAPIClient.swift",
            encoding: .utf8
        )

        assertContains(viewSource, "case manualEntry", "The landing page should open a dedicated manual-entry flow.")
        assertContains(viewSource, "Text(\"填写配置\")", "Manual entry should use the approved title.")
        assertContains(viewSource, "HardwareCatalog.filters(for: title)", "Part choices should reuse the maintained hardware catalog.")
        assertNotContains(viewSource, "ConfigReviewContextSelector", "Review context selectors should be removed.")
        assertNotContains(viewSource, "主要用途", "Use-case selection should be removed from review.")
        assertNotContains(viewSource, "目标分辨率", "Resolution selection should be removed from review.")
        assertContains(viewSource, "completedPartCount >= 2", "Submission should require multiple selected parts.")
        assertContains(viewSource, "pairingRating.displayValue", "The report should display the public pairing grade or status.")
        assertContains(viewSource, "result.performanceRating", "The report should display performance rating.")
        assertContains(viewSource, "result.recommendations", "The report should use the structured recommendation checklist.")
        assertContains(viewSource, "recommendation.action", "Each recommendation should explain how to modify the build.")
        assertContains(viewSource, "result.detectedComponents", "The report should expose detected components.")
        assertContains(viewSource, "draft.prefill(with: result.detectedComponents)", "Detected components should be editable and resubmittable.")
        assertContains(viewSource, "normalizedReviewJPEGData", "Image uploads should be normalized before submission.")
        assertContains(viewSource, "format.scale = 1", "Image normalization should cap real pixel dimensions.")
        assertContains(viewSource, "filters: category.filters()", "Review entry should allow selecting incompatible parts for diagnosis.")
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
        assertNotContains(viewSource, "motherboardFilters(compatibleWithCPU:", "Review input must not hide incompatible motherboards.")
        assertNotContains(viewSource, "rating.score.map", "Public ratings should display C-S grades instead of numeric scores.")
        assertContains(apiSource, "case \"failed\": \"不通过\"", "Hard compatibility failures should display as failed.")
        assertContains(apiSource, "case \"incomplete\": \"待补全\"", "Incomplete reviews should display as pending.")
        assertContains(apiSource, "let recommendations: [ConfigReviewRecommendationDTO]", "The client contract should decode structured recommendations.")
        assertContains(apiSource, "let detectedComponents: [String: ConfigReviewDetectedComponentDTO]", "The client contract should decode recognized components.")
        assertContains(apiSource, "body: ConfigReviewRequestDTO(text: text)", "Text review requests should send only the configuration text.")
        assertNotContains(apiSource, "name=\"direction\"", "Image review requests should not send use case.")
        assertNotContains(apiSource, "name=\"resolution\"", "Image review requests should not send resolution.")
        assertContains(apiSource, "!$0.code.localizedCaseInsensitiveContains(\"price\")", "Legacy price findings must not leak into the new report.")
        assertContains(apiSource, "URL(string: \"http://127.0.0.1:8790\")", "Debug builds should use the documented local backend.")

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
