import Foundation

@main
struct AppAPIClientPerformanceRulesTests {
    static func main() throws {
        let data = Data(
            #"{"status":"ready","average_fps":84,"gpu_time_spy_score":33018,"missing_games":[],"game_results":[{"game":"cyberpunk-2077","average_fps":84}]}"#.utf8
        )
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        let response = try decoder.decode(PerformanceEstimateResponseDTO.self, from: data)

        guard response.model.averageFPS == 84,
              response.model.gpuTimeSpyScore == 33018,
              response.model.gameResults.first?.averageFPS == 84 else {
            fatalError("Performance response should decode backend average_fps fields.")
        }

        let powerData = Data(#"{"recommended_psu_watt":750}"#.utf8)
        let powerResponse = try decoder.decode(
            DIYPowerRecommendationResponseDTO.self,
            from: powerData
        )
        guard powerResponse.recommendedPsuWatt == 750 else {
            fatalError("DIY should decode the backend-recommended PSU wattage.")
        }

        print("AppAPIClientPerformanceRulesTests passed")
    }
}
