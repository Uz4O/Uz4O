import Foundation

struct PerformanceHardwareDTO: Encodable {
    let cpu: String
    let gpu: String
}

struct PerformanceEstimateRequestDTO: Encodable {
    let hardware: PerformanceHardwareDTO
    let resolution: String
    let games: [String]
}

struct GamePerformanceResultDTO: Decodable {
    let game: String
    let averageFps: Int

    var model: GamePerformanceResult {
        GamePerformanceResult(
            gameID: game,
            averageFPS: averageFps
        )
    }
}

struct PerformanceEstimateResponseDTO: Decodable {
    let status: String
    let averageFps: Int?
    let missingGames: [String]?
    let gameResults: [GamePerformanceResultDTO]

    var model: PerformanceEstimatePayload {
        PerformanceEstimatePayload(
            status: PerformanceEstimateStatus(rawValue: status) ?? .needsMoreData,
            averageFPS: averageFps,
            missingGames: missingGames ?? [],
            gameResults: gameResults.map(\.model)
        )
    }
}
