import Foundation

@main
struct CommunityContentRulesTests {
    static func main() {
        assertEqual(
            AppTab.allCases.map(\.rawValue),
            ["首页", "社区", "配置", "我的"],
            "Bottom navigation should remove Tools and keep Community as a primary tab."
        )

        assertEqual(
            AppTab.community.icon,
            "bubble.left.and.bubble.right.fill",
            "Community tab should use the chat icon from the design."
        )

        assertEqual(
            CommunityPost.featuredFeed.count,
            3,
            "Community feed should start with three curated hardware discussion posts."
        )

        assertEqual(
            CommunityPost.featuredFeed.first?.isPinned,
            true,
            "The first community post should be pinned on the home community preview."
        )

        assertEqual(
            CommunityPost.featuredFeed.first?.image?.displayHeight(forWidth: 328),
            180,
            "Community images should cap display height even when the original aspect ratio is tall."
        )

        let tallUpload = CommunityPostImage(assetName: "TallUpload", aspectRatio: 0.25, accessibilityLabel: "竖图")
        assertEqual(
            tallUpload.displayHeight(forWidth: 328),
            180,
            "Very tall uploaded images should use the maximum placeholder height."
        )

        let wideUpload = CommunityPostImage(assetName: "WideUpload", aspectRatio: 2, accessibilityLabel: "横图")
        assertEqual(
            wideUpload.displayHeight(forWidth: 328),
            164,
            "Wide uploaded images should derive placeholder height from their image ratio."
        )

        assertEqual(
            CommunityComposerDraft.characterLimit,
            1000,
            "Composer should keep the 1000 character limit shown in the design."
        )

        var draft = CommunityComposerDraft()
        assertEqual(
            draft.selectedTopicTitles,
            ["装机配置"],
            "Composer should start with 装机配置 selected."
        )

        draft.toggleTopic("求助问答")
        assertEqual(
            draft.selectedTopicTitles,
            ["装机配置", "求助问答"],
            "Composer should allow adding another selected topic."
        )

        draft.toggleTopic("装机配置")
        assertEqual(
            draft.selectedTopicTitles,
            ["求助问答"],
            "Composer should allow removing an already selected topic."
        )

        print("CommunityContentRulesTests passed")
    }

    private static func assertEqual<T: Equatable>(_ actual: T, _ expected: T, _ message: String) {
        guard actual == expected else {
            fatalError("\(message)\nExpected: \(expected)\nActual: \(actual)")
        }
    }
}
