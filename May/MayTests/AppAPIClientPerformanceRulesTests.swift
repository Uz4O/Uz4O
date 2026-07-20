import Foundation

@main
struct AppAPIClientPerformanceRulesTests {
    static func main() throws {
        let data = Data(
            #"{"status":"ready","average_fps":84,"missing_games":[],"game_results":[{"game":"cyberpunk-2077","average_fps":84}]}"#.utf8
        )
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        let response = try decoder.decode(PerformanceEstimateResponseDTO.self, from: data)

        guard response.model.averageFPS == 84, response.model.gameResults.first?.averageFPS == 84 else {
            fatalError("Performance response should decode backend average_fps fields.")
        }

        print("AppAPIClientPerformanceRulesTests passed")
    }
}
