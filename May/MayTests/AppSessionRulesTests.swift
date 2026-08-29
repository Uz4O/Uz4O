import Foundation

@main
struct AppSessionRulesTests {
    static func main() {
        let sessionSource = try! String(
            contentsOfFile: "May/May/Models/AppSession.swift",
            encoding: .utf8
        )
        assertContains(
            sessionSource,
            "restoreStoredSession()",
            "Stored tokens must be validated during app launch."
        )
        assertContains(
            sessionSource,
            "ASAuthorizationAppleIDProvider",
            "Apple sessions must check credential state after relaunch."
        )
        assertContains(
            sessionSource,
            "apple-user-id",
            "Apple user identifiers must be stored separately from access tokens."
        )

        let apiSource = try! String(
            contentsOfFile: "May/May/Networking/AppAPIClient.swift",
            encoding: .utf8
        )
        assertContains(
            apiSource,
            "currentAccount(token:",
            "Launch session validation must use the current-account endpoint."
        )
        assertContains(
            apiSource,
            "appSessionUnauthorized",
            "Authorized 401 responses must notify the session layer."
        )

        let contentSource = try! String(
            contentsOfFile: "May/May/ContentView.swift",
            encoding: .utf8
        )
        assertContains(
            contentSource,
            "session.restoreStoredSession()",
            "ContentView must wait for stored-session validation."
        )

        let profileSource = try! String(
            contentsOfFile: "May/May/Screens/ProfileView.swift",
            encoding: .utf8
        )
        assertContains(
            profileSource,
            "退出登录",
            "Users need a non-destructive sign-out entry separate from account deletion."
        )

        print("AppSessionRulesTests passed")
    }

    private static func assertContains(_ text: String, _ expectedFragment: String, _ message: String) {
        guard text.contains(expectedFragment) else {
            fatalError("\(message)\nMissing: \(expectedFragment)")
        }
    }
}
