import Foundation

enum SavedConfigurationKind: String, CaseIterable, Codable, Hashable {
    case ai
    case diy

    var useCase: String {
        switch self {
        case .ai: "AI装机"
        case .diy: "DIY装机"
        }
    }
}

struct SavedConfigurationPartDTO: Codable, Hashable {
    let category: String
    let model: String
    let price: String
    let condition: String
}

struct SavedConfigurationGPUAlternativeDTO: Codable, Hashable {
    let componentID: String
    let model: String
    let referencePrice: Int
    let priceDifference: Int
    let performanceComparison: String
    let gamingPerformanceGainPercent: Int?
}

struct SavedConfigurationCPUPlatformReplacementDTO: Codable, Hashable {
    let componentID: String
    let category: String
    let model: String
    let referencePrice: Int
    let condition: String
}

struct SavedConfigurationCPUPlatformAlternativeDTO: Codable, Hashable {
    let replacementParts: [SavedConfigurationCPUPlatformReplacementDTO]
    let priceDifference: Int
    let performanceGainPercent: Int
}

struct SavedConfigurationPerformanceContextDTO: Codable, Hashable {
    let cpuID: String
    let gpuID: String
    let gameIDs: [String]
    let unavailableGameNames: [String]
}

struct SavedConfigurationPlanDTO: Codable, Hashable {
    let version: Int
    let kind: SavedConfigurationKind
    let name: String
    let budget: String
    let totalPrice: String
    let useCase: String
    let createdAt: String
    let parts: [SavedConfigurationPartDTO]
    let usedGPUAlternative: SavedConfigurationGPUAlternativeDTO?
    let cpuPlatformAlternative: SavedConfigurationCPUPlatformAlternativeDTO?
    let performanceContext: SavedConfigurationPerformanceContextDTO?

    var numericBudget: Int? { Int(budget.filter(\.isNumber)) }
    var numericTotalPrice: Int? { Int(totalPrice.filter(\.isNumber)) }
}

struct SaveConfigurationRequestDTO: Encodable {
    let title: String
    let plan: SavedConfigurationPlanDTO
    let budget: Int?
    let totalPrice: Int?
    let useCase: String

    enum CodingKeys: String, CodingKey {
        case title, plan, budget
        case totalPrice = "total_price"
        case useCase = "use_case"
    }
}

struct SavedConfigurationDTO: Decodable, Hashable, Identifiable {
    let id: String
    let title: String
    let plan: SavedConfigurationPlanDTO
    let budget: Int?
    let totalPrice: Int?
    let useCase: String?
    let createdAt: String
    let updatedAt: String
}
