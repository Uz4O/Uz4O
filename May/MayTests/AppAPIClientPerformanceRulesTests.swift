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

        let platformData = Data(
            #"{"target_budget":7500,"direction":"fps","purchase_mode":"new","parts":[],"cpu_platform_alternative":{"replacement_parts":[{"role":"cpu","component_id":"i5-14600kf","name":"i5-14600KF","condition":"new","reference_price":1499,"price_source":"user","price_date":"2026-08-26"},{"role":"motherboard","component_id":"msi-b760m-a","name":"微星 B760M-A","condition":"new","reference_price":850,"price_source":"catalog","price_date":"2026-08-26"},{"role":"ram","component_id":"base-ddr4-16gb-3200","name":"DDR4 8GB×2 3200","condition":"new","reference_price":500,"price_source":"catalog","price_date":"2026-08-26"},{"role":"cooler","component_id":"base-cooler-dual-tower-6-heatpipe","name":"双塔6热管风冷","condition":"new","reference_price":150,"price_source":"catalog","price_date":"2026-08-26"}],"price_difference":100,"performance_gain_percent":40},"suitable_user":"FPS 玩家","price_date":"2026-08-26"}"#.utf8
        )
        let platformDetails = try decoder.decode(BuildOptionDetailsDTO.self, from: platformData)
        guard let platform = platformDetails.cpuPlatformAlternative,
              platform.replacementParts.first?.componentId == "i5-14600kf",
              platform.replacementParts.first(where: { $0.role == .ram })?.name.contains("DDR4") == true,
              platform.performanceGainPercent == 40 else {
            fatalError("7500F results should decode the complete DDR4 14600KF platform alternative.")
        }

        print("AppAPIClientPerformanceRulesTests passed")
    }
}
