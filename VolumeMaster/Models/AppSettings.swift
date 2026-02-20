import Foundation

final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let mergeEnabled = "mergeEnabled"
        static let mergePrimaryUID = "mergePrimaryUID"
        static let mergeSecondaryUID = "mergeSecondaryUID"
        static let mergeStereoSplit = "mergeStereoSplit"
        static let mergeSpatialAudio = "mergeSpatialAudio"
        static let profiles = "profiles"
        static let profilesEnabled = "profilesEnabled"
        static let launchAtLogin = "launchAtLogin"
    }

    @Published var mergeEnabled: Bool {
        didSet { defaults.set(mergeEnabled, forKey: Keys.mergeEnabled) }
    }

    @Published var mergePrimaryUID: String {
        didSet { defaults.set(mergePrimaryUID, forKey: Keys.mergePrimaryUID) }
    }

    @Published var mergeSecondaryUID: String {
        didSet { defaults.set(mergeSecondaryUID, forKey: Keys.mergeSecondaryUID) }
    }

    @Published var mergeStereoSplit: Bool {
        didSet { defaults.set(mergeStereoSplit, forKey: Keys.mergeStereoSplit) }
    }

    @Published var mergeSpatialAudio: Bool {
        didSet { defaults.set(mergeSpatialAudio, forKey: Keys.mergeSpatialAudio) }
    }

    @Published var profiles: [DeviceProfile] {
        didSet { saveProfiles() }
    }

    @Published var profilesEnabled: Bool {
        didSet { defaults.set(profilesEnabled, forKey: Keys.profilesEnabled) }
    }

    @Published var launchAtLogin: Bool {
        didSet { defaults.set(launchAtLogin, forKey: Keys.launchAtLogin) }
    }

    private init() {
        self.mergeEnabled = defaults.bool(forKey: Keys.mergeEnabled)
        self.mergePrimaryUID = defaults.string(forKey: Keys.mergePrimaryUID) ?? ""
        self.mergeSecondaryUID = defaults.string(forKey: Keys.mergeSecondaryUID) ?? ""
        self.mergeStereoSplit = defaults.bool(forKey: Keys.mergeStereoSplit)
        self.mergeSpatialAudio = defaults.bool(forKey: Keys.mergeSpatialAudio)
        self.profilesEnabled = defaults.bool(forKey: Keys.profilesEnabled)
        self.launchAtLogin = defaults.bool(forKey: Keys.launchAtLogin)

        if let data = defaults.data(forKey: Keys.profiles),
           let decoded = try? JSONDecoder().decode([DeviceProfile].self, from: data) {
            self.profiles = decoded
        } else {
            self.profiles = []
        }
    }

    private func saveProfiles() {
        if let data = try? JSONEncoder().encode(profiles) {
            defaults.set(data, forKey: Keys.profiles)
        }
    }

    var hasMergeDevicesConfigured: Bool {
        !mergePrimaryUID.isEmpty && !mergeSecondaryUID.isEmpty
    }
}
