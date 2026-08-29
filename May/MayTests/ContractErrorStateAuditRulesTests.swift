import Foundation

@main
struct ContractErrorStateAuditRulesTests {
    static func main() throws {
        let buildsSource = try source("May/May/Screens/MyBuildsView.swift")
        let upgradeSource = try source("May/May/Screens/UpgradePlanView.swift")
        let apiSource = try source("May/May/Networking/AppAPIClient.swift")
        let reviewBackendSource = try source("backend/app/review/service.py")

        assertNotContains(
            buildsSource,
            "(try? await AppAPIClient().savedUpgradePlans(token: accessToken)) ?? []",
            "Upgrade-plan service failures must not appear as an empty list."
        )
        assertNotContains(
            buildsSource,
            "(try? await AppAPIClient().savedConfigurations(token: accessToken)) ?? []",
            "Saved-configuration service failures must not appear as an empty list."
        )
        assertContains(
            buildsSource,
            "loadError = \"配置加载失败：\\(error.localizedDescription)\"",
            "The configuration list must expose load failures."
        )
        assertContains(
            upgradeSource,
            "planLoadState = .failed(error.localizedDescription)",
            "Upgrade-plan generation must expose service failures."
        )

        for field in [
            "let pairingRating: ConfigReviewRatingDTO",
            "let performanceRating: ConfigReviewRatingDTO",
            "let recommendations: [ConfigReviewRecommendationDTO]",
            "let questionsForSeller: [String]",
            "let replyText: String",
            "let webSearchStatus: String",
            "let webSources: [ConfigReviewSourceDTO]",
        ] {
            assertContains(apiSource, field, "The Swift review DTO is missing a modern response field.")
        }

        for field in [
            "pairing_rating: ReviewRating",
            "performance_rating: ReviewRating",
            "recommendations: List[ReviewRecommendation]",
            "questions_for_seller: List[str]",
            "reply_text: str",
            "web_search_status: WebSearchStatus",
            "web_sources: List[ReviewEvidenceSource]",
        ] {
            assertContains(reviewBackendSource, field, "The backend review schema is missing a modern response field.")
        }

        print("ContractErrorStateAuditRulesTests passed")
    }

    private static func source(_ path: String) throws -> String {
        try String(contentsOfFile: path, encoding: .utf8)
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
