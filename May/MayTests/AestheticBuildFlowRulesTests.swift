import Foundation

@main
struct AestheticBuildFlowRulesTests {
    static func main() {
        assertEqual(AestheticBuildStyle.featured.map(\.title), ["黑武士", "海景房", "白色极简"], "Only unique styles should ship in the prototype.")
        assertEqual(AestheticBuildStyle.featured, Array(AestheticBuildStyle.all.prefix(3)), "Home should preview only the first three catalog styles.")

        let panorama = AestheticBuildStyle.featured[1]
        assertEqual(panorama.options.map(\.tier), [.core, .high, .complete], "Restoration choices should be ordered.")

        var flow = AestheticBuildFlow(styleID: panorama.id)
        assertEqual(flow.resolvedResolution, .twoK, "Unknown display should use 2K for the demo quote.")
        assertEqual(flow.quote.total, flow.quote.performanceCore + flow.quote.styleModule, "Total should not double-count style parts.")

        let coreQuote = flow.quote
        flow.selectTier(.complete)
        assertTrue(flow.quote.styleModule.low > coreQuote.styleModule.low, "Complete restoration should cost more than core restoration.")
        assertTrue(flow.quote.aestheticPremium.high <= flow.quote.styleModule.high, "Premium cannot exceed style module cost.")

        flow.setGames([.valorant])
        let lightGameQuote = flow.quote
        flow.setGames([.cyberpunk])
        assertTrue(flow.quote.performanceCore.low > lightGameQuote.performanceCore.low, "Demanding games should raise the estimate.")

        flow.confirmQuote()
        assertTrue(flow.isQuoteConfirmed, "Quote confirmation should be recorded.")
        flow.selectExperience(.highRefresh)
        assertTrue(!flow.isQuoteConfirmed, "Changing requirements should invalidate confirmation.")

        print("AestheticBuildFlowRulesTests passed")
    }

    private static func assertEqual<T: Equatable>(_ actual: T, _ expected: T, _ message: String) {
        guard actual == expected else { fatalError("\(message)\nExpected: \(expected)\nActual: \(actual)") }
    }

    private static func assertTrue(_ value: Bool, _ message: String) {
        guard value else { fatalError(message) }
    }
}
