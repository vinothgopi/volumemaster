import Foundation
import ServiceManagement

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var outputDevices: [AudioDevice] = []
    @Published var inputDevices: [AudioDevice] = []
    @Published var allDevices: [AudioDevice] = []
    @Published var videoDevices: [VideoDevice] = []
    @Published var isMergeActive: Bool = false
    @Published var mergeError: String?

    let settings = AppSettings.shared
    private let deviceManager = AudioDeviceManager.shared
    private let aggregateManager = AggregateDeviceManager.shared

    func refresh() {
        allDevices = deviceManager.allDevices().filter { !$0.isOurAggregate }
        outputDevices = allDevices.filter(\.hasOutput)
        inputDevices = allDevices.filter(\.hasInput)
        videoDevices = VideoDeviceManager.allCameras()
        isMergeActive = aggregateManager.isMergeActive
    }

    // MARK: - Merge Control

    func toggleMerge(enabled: Bool) {
        if enabled {
            guard settings.hasMergeDevicesConfigured else { return }
            do {
                _ = try aggregateManager.createMultiOutputDevice(
                    primaryUID: settings.mergePrimaryUID,
                    secondaryUID: settings.mergeSecondaryUID,
                    stereoSplit: settings.mergeStereoSplit
                )
                settings.mergeEnabled = true
                mergeError = nil
            } catch {
                mergeError = "Failed to create aggregate device: \(error.localizedDescription)"
            }
        } else {
            aggregateManager.revertDefaultOutput()
            aggregateManager.destroyActiveAggregate()
            settings.mergeEnabled = false
        }
        isMergeActive = aggregateManager.isMergeActive
    }

    // MARK: - Launch at Login

    func setLaunchAtLogin(_ enabled: Bool) {
        settings.launchAtLogin = enabled
        if enabled {
            try? SMAppService.mainApp.register()
        } else {
            try? SMAppService.mainApp.unregister()
        }
    }

    // MARK: - Profile Management

    func addProfile() {
        var profile = DeviceProfile()
        profile.name = "Profile \(settings.profiles.count + 1)"
        settings.profiles.append(profile)
    }

    func deleteProfile(at offsets: IndexSet) {
        settings.profiles.remove(atOffsets: offsets)
    }

    func deleteProfile(id: UUID) {
        settings.profiles.removeAll { $0.id == id }
    }

    func updateProfile(_ profile: DeviceProfile) {
        if let index = settings.profiles.firstIndex(where: { $0.id == profile.id }) {
            settings.profiles[index] = profile
        }
    }
}
