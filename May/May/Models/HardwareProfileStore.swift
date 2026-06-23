import Foundation

struct HardwareProfileStore {
    private let defaults: UserDefaults
    private let key = "savedHardwareProfile"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> HardwareProfile {
        guard
            let data = defaults.data(forKey: key),
            let profile = try? JSONDecoder().decode(HardwareProfile.self, from: data)
        else {
            return .skipped
        }

        return profile
    }

    func save(_ profile: HardwareProfile) {
        guard let data = try? JSONEncoder().encode(profile) else { return }
        defaults.set(data, forKey: key)
    }

    func clear() {
        defaults.removeObject(forKey: key)
    }
}
