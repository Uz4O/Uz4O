import Foundation

@main
struct AestheticBuildFlowRulesTests {
    static func main() {
        assertEqual(AestheticBuildStyle.all.count, 42, "All verified aesthetic styles should be available.")
        assertEqual(AestheticBuildStyle.featured.map(\.title), ["联立 VISION COMPACT", "ROG 创世神 701", "未知玩家 幻翼"], "Home should feature the first three catalog styles.")
        assertEqual(AestheticBuildStyle.featured, Array(AestheticBuildStyle.all.prefix(3)), "Home should preview only the first three catalog styles.")

        verifyAllStyleSelections()

        let panorama = AestheticBuildStyle.featured[1]
        assertEqual(panorama.options.map(\.tier), [.core, .high, .complete], "Restoration choices should be ordered.")

        var flow = AestheticBuildFlow(styleID: panorama.id)
        assertEqual(flow.step, .performanceBudget, "Performance budget should be the first aesthetic build step.")
        assertEqual(AestheticBuildStep.allCases.count, 3, "The aesthetic build flow should have three steps.")
        assertEqual(AestheticBuildStep.allCases.last, .hardware, "Hardware preferences should generate the build without a quote step.")
        flow.setPerformanceBudget(3500)
        assertEqual(flow.performanceBudget, 4000, "Performance budget should not go below ¥4,000.")
        flow.selectUseCase("办公")
        assertEqual(flow.selectedUseCase, "办公", "The selected use case should be retained.")
        flow.setHasOwnedGPU(true)
        flow.setOwnedGPUModel("RTX 5070")
        flow.needsWirelessNetwork = true
        flow.selectedMemorySize = "32GB"
        flow.selectedStorageSize = "2TB"
        assertTrue(flow.hasOwnedGPU, "An owned GPU should be retained in the flow.")
        assertEqual(flow.ownedGPUModel, "RTX 5070", "The owned GPU model should be retained.")
        assertTrue(flow.needsWirelessNetwork, "The wireless network preference should be retained.")
        assertEqual(flow.selectedMemorySize, "32GB", "The selected memory size should be retained.")
        assertEqual(flow.selectedStorageSize, "2TB", "The selected storage size should be retained.")
        assertEqual(flow.resolvedResolution, .twoK, "Unknown display should use 2K for the demo quote.")
        assertEqual(flow.quote.total, flow.quote.performanceCore + flow.quote.styleModule, "Total should not double-count style parts.")

        let coreQuote = flow.quote
        flow.selectTier(.complete)
        assertTrue(flow.quote.styleModule.low > coreQuote.styleModule.low, "Complete restoration should cost more than core restoration.")
        assertTrue(flow.quote.aestheticPremium.high <= flow.quote.styleModule.high, "Premium cannot exceed style module cost.")

        flow.setGames([.valorant])
        let lightGameQuote = flow.quote
        assertEqual(flow.buildDirection, .fps, "Competitive games should select the FPS direction.")
        flow.setGames([.cyberpunk])
        assertEqual(flow.buildDirection, .aaa, "Demanding games should select the AAA direction.")
        assertTrue(flow.quote.performanceCore.low > lightGameQuote.performanceCore.low, "Demanding games should raise the estimate.")
        flow.setGames([.valorant, .cyberpunk])
        assertEqual(flow.buildDirection, .balanced, "Mixed games should select the balanced direction.")
        flow.selectResolution(.fourK)
        assertEqual(flow.buildDirection, .aaa, "4K should select the AAA direction.")
        flow.selectExperience(.competitive)
        assertEqual(flow.buildDirection, .fps, "Competitive experience should select the FPS direction.")

        let selectedStyle = AestheticBuildStyle.all[0]
        let selectedCase = selectedStyle.overviewParts[0]
        let appearanceSelection = selectedStyle.buildSelection(
            color: .white,
            selectedAlternativeIDs: [selectedCase.id: selectedCase.alternatives[0].id]
        )
        let selectedFlow = AestheticBuildFlow(
            styleID: selectedStyle.id,
            appearanceSelection: appearanceSelection
        )
        assertEqual(selectedFlow.appearanceSelection, appearanceSelection, "The complete appearance selection should be retained.")
        assertEqual(selectedFlow.appearanceCost, appearanceSelection.totalPrice, "The selected parts should determine appearance cost.")

        print("AestheticBuildFlowRulesTests passed")
    }

    private static func verifyAllStyleSelections() {
        var selectionsByID: [String: AestheticBuildPartSelection] = [:]

        for style in AestheticBuildStyle.all {
            assertEqual(
                style.overviewParts.filter { part in
                    style.buildSelection(color: .black, selectedAlternativeIDs: [:])
                        .parts.first { $0.category == part.name }?.role == .case
                }.count,
                1,
                "Each style should contain exactly one case: \(style.title)"
            )

            for color in AestheticStyleColor.allCases {
                let original = style.buildSelection(color: color, selectedAlternativeIDs: [:])
                let lockedParts = style.overviewParts.filter { !$0.usesAICooler }
                assertEqual(original.parts.count, lockedParts.count, "Only locked appearance parts should be retained: \(style.title)")
                assertEqual(original.parts.filter { $0.role == .case }.count, 1, "Each selection should lock one case: \(style.title)")
                assertEqual(original.totalPrice, style.overviewTotal(for: color), "Selection and overview totals should match: \(style.title) \(color.title)")
                assertEqual(Set(original.parts.map(\.componentID)).count, original.parts.count, "A selection cannot contain duplicate SKUs: \(style.title)")
                recordConsistentParts(original.parts, in: &selectionsByID)

                for part in lockedParts {
                    guard let selectedPart = original.parts.first(where: { $0.name == part.detail }) else {
                        fatalError("Locked part should be included: \(style.title) / \(part.detail)")
                    }
                    if part.name.contains("一体式水冷") {
                        assertTrue(selectedPart.supportsHotCPU, "Named all-in-one liquid coolers should support hot CPUs: \(style.title)")
                    }
                }
                for part in style.overviewParts where part.usesAICooler {
                    assertTrue(!original.parts.contains { $0.name == part.detail }, "AI-matched coolers must stay in the base build: \(style.title)")
                }

                for part in style.overviewParts {
                    for alternative in part.alternatives {
                        let selection = style.buildSelection(
                            color: color,
                            selectedAlternativeIDs: [part.id: alternative.id]
                        )
                        guard let selectedPart = selection.parts.first(where: {
                            $0.role == part.buildRole && $0.name == alternative.name
                        }) else {
                            fatalError("Alternative should be included: \(style.title) / \(alternative.name)")
                        }
                        assertEqual(selectedPart.referencePrice, alternative.price(for: color), "The color-specific alternative price should be retained.")
                        recordConsistentParts([selectedPart], in: &selectionsByID)
                    }
                }
            }
        }

        let challenger = selectionsByID.values.filter { $0.name == "酷冷至尊挑战者 V4" }
        assertEqual(challenger.count, 2, "Cooler Master Challenger V4 should have black and white catalog entries.")
        assertTrue(challenger.allSatisfy { !$0.supportsHotCPU }, "Cooler Master Challenger V4 must not be used for hot CPUs.")

        let data = try! JSONEncoder().encode(
            AestheticBuildStyle.all[0].buildSelection(color: .black, selectedAlternativeIDs: [:])
        )
        let json = String(decoding: data, as: UTF8.self)
        for key in ["style_id", "style_name", "price_date", "component_id", "reference_price", "supports_hot_cpu"] {
            assertTrue(json.contains("\"\(key)\""), "Encoded appearance selection should include \(key).")
        }
    }

    private static func recordConsistentParts(
        _ parts: [AestheticBuildPartSelection],
        in recordedParts: inout [String: AestheticBuildPartSelection]
    ) {
        for part in parts {
            assertTrue(part.componentID.hasPrefix("aesthetic-"), "Every style SKU should use a formal aesthetic ID: \(part.componentID)")
            if let existing = recordedParts[part.componentID] {
                assertEqual(existing.role, part.role, "A shared SKU must keep the same role.")
                assertEqual(existing.name, part.name, "A shared SKU must keep the same name.")
                assertEqual(existing.condition, part.condition, "A shared SKU must keep the same condition.")
                assertEqual(existing.referencePrice, part.referencePrice, "A shared SKU must keep the same price.")
                assertEqual(existing.supportsHotCPU, part.supportsHotCPU, "A shared SKU must keep the same cooling capability.")
            } else {
                recordedParts[part.componentID] = part
            }
        }
    }

    private static func assertEqual<T: Equatable>(_ actual: T, _ expected: T, _ message: String) {
        guard actual == expected else { fatalError("\(message)\nExpected: \(expected)\nActual: \(actual)") }
    }

    private static func assertTrue(_ value: Bool, _ message: String) {
        guard value else { fatalError(message) }
    }
}
