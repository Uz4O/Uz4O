import Foundation

@main
struct AppConfigurationRulesTests {
    static func main() {
        let expectedURL = URL(string: "https://api.uzbox.top")!

        guard AppConfiguration.apiBaseURL == expectedURL else {
            fatalError(
                "App builds should use the deployed API by default.\n" +
                "Expected: \(expectedURL)\n" +
                "Actual: \(AppConfiguration.apiBaseURL)"
            )
        }

        print("AppConfigurationRulesTests passed")
    }
}
