import Foundation

struct DIYStoredPart: Codable {
    let category: String
    let name: String
    let brand: String
    let price: Int?
}

struct DIYStoredBuild: Codable, Identifiable {
    let id: UUID
    let createdAt: Date
    let totalPrice: Int
    let recommendedPsuWatt: Int?
    let parts: [DIYStoredPart]

    private enum CodingKeys: String, CodingKey {
        case id
        case createdAt
        case totalPrice
        case recommendedPsuWatt
        case parts
    }

    init(
        id: UUID,
        createdAt: Date,
        totalPrice: Int,
        recommendedPsuWatt: Int?,
        parts: [DIYStoredPart]
    ) {
        self.id = id
        self.createdAt = createdAt
        self.totalPrice = totalPrice
        self.recommendedPsuWatt = recommendedPsuWatt
        self.parts = parts
    }
}

enum DIYBuildStore {
    private static let key = "savedDIYBuilds"

    static func load() -> [DIYStoredBuild] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let builds = try? JSONDecoder().decode([DIYStoredBuild].self, from: data) else {
            return []
        }
        return builds
    }

    static func save(_ build: DIYStoredBuild) {
        var builds = load()
        builds.removeAll { $0.id == build.id }
        builds.insert(build, at: 0)
        guard let data = try? JSONEncoder().encode(builds) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}
