import Foundation

struct DIYStoredPart: Codable {
    let category: String
    let name: String
    let brand: String
    let price: Int?
}

enum DIYBuildStore {
    private static let key = "savedDIYBuilds"

    static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}
