import Foundation

@main
struct ProfileInteractionRulesTests {
    static func main() {
        let profileSource = try! String(
            contentsOfFile: "May/May/Screens/ProfileView.swift",
            encoding: .utf8
        )
        assertContains(
            profileSource,
            ".contentShape(Rectangle())",
            "Profile settings rows should make the entire row tappable, not just the text."
        )
        assertContains(
            profileSource,
            "onOpenContactComplaint()",
            "Contact and complaint row should open the in-app feedback screen."
        )

        let contentSource = try! String(
            contentsOfFile: "May/May/ContentView.swift",
            encoding: .utf8
        )
        assertContains(
            contentSource,
            "case contactComplaint",
            "Main navigation should include a route for the contact and complaint screen."
        )
        assertContains(
            contentSource,
            "ContactComplaintView(",
            "Contact and complaint route should render the feedback screen."
        )
        print("ProfileInteractionRulesTests passed")
    }

    private static func assertContains(_ text: String, _ expectedFragment: String, _ message: String) {
        guard text.contains(expectedFragment) else {
            fatalError("\(message)\nMissing: \(expectedFragment)")
        }
    }
}
