import CoreAudio
import Foundation
import SwiftUI

@MainActor
final class MenuBarViewModel: ObservableObject {
    @Published var outputDevices: [AudioDevice] = []
    @Published var inputDevices: [AudioDevice] = []
    @Published var defaultOutputUID: String = ""
    @Published var defaultInputUID: String = ""
    @Published var isMergeActive: Bool = false
    @Published var activeProfileName: String?

    private let deviceManager = AudioDeviceManager.shared
    private let aggregateManager = AggregateDeviceManager.shared
    private let settings = AppSettings.shared
    private var monitorSetUp = false

    func refresh() {
        outputDevices = deviceManager.outputDevices()
        inputDevices = deviceManager.inputDevices()
        defaultOutputUID = deviceManager.defaultOutputDevice()?.uid ?? ""
        defaultInputUID = deviceManager.defaultInputDevice()?.uid ?? ""
        isMergeActive = aggregateManager.isMergeActive
    }

    func selectOutputDevice(_ device: AudioDevice) {
        // If merge is active, tear it down first
        if aggregateManager.isMergeActive {
            unmerge()
        }
        try? deviceManager.setDefaultOutputDevice(device)
        refresh()
    }

    func selectInputDevice(_ device: AudioDevice) {
        try? deviceManager.setDefaultInputDevice(device)
        refresh()
    }

    func unmerge() {
        aggregateManager.revertDefaultOutput()
        aggregateManager.destroyActiveAggregate()
        settings.mergeEnabled = false
        refresh()
    }

    func setupDeviceMonitor() {
        guard !monitorSetUp else { return }
        monitorSetUp = true
        let monitor = DeviceMonitor.shared
        monitor.onDevicesChanged = { [weak self] connected, disconnected in
            guard let self else { return }

            self.refresh()

            // Handle active aggregate disruption
            if self.aggregateManager.isMergeActive {
                let mergedUIDs = [self.settings.mergePrimaryUID, self.settings.mergeSecondaryUID]
                if !disconnected.isDisjoint(with: mergedUIDs) {
                    self.unmerge()
                }
            }

            // Apply profiles
            guard self.settings.profilesEnabled else { return }
            for profile in self.settings.profiles {
                let triggerUID = profile.triggerDeviceUID
                let shouldApply: Bool
                if profile.triggerOnConnect {
                    shouldApply = connected.contains(triggerUID)
                } else {
                    shouldApply = disconnected.contains(triggerUID)
                }

                if shouldApply {
                    self.applyProfile(profile)
                }
            }
        }
        monitor.startMonitoring()
        applyStartupProfiles()
    }

    private func applyStartupProfiles() {
        guard settings.profilesEnabled else { return }
        let connectedUIDs = Set(deviceManager.allDevices().map(\.uid))
        for profile in settings.profiles where profile.triggerOnConnect {
            if connectedUIDs.contains(profile.triggerDeviceUID) {
                applyProfile(profile)
            }
        }
    }

    private func applyProfile(_ profile: DeviceProfile) {
        activeProfileName = profile.name

        // Handle merge before output device changes
        if let enableMerge = profile.enableMerge {
            if enableMerge {
                if settings.hasMergeDevicesConfigured && !aggregateManager.isMergeActive {
                    do {
                        _ = try aggregateManager.createMultiOutputDevice(
                            primaryUID: settings.mergePrimaryUID,
                            secondaryUID: settings.mergeSecondaryUID,
                            stereoSplit: settings.mergeStereoSplit
                        )
                        settings.mergeEnabled = true
                    } catch {
                        print("Profile merge failed: \(error)")
                    }
                }
            } else if aggregateManager.isMergeActive {
                unmerge()
            }
        }

        if let outputUID = profile.outputDeviceUID,
           let device = deviceManager.device(forUID: outputUID) {
            try? deviceManager.setDefaultOutputDevice(device)
        }
        if let inputUID = profile.inputDeviceUID,
           let device = deviceManager.device(forUID: inputUID) {
            try? deviceManager.setDefaultInputDevice(device)
        }
        if let videoUID = profile.videoDeviceUID {
            VideoDeviceManager.setPreferredCamera(uniqueID: videoUID)
        }
        refresh()
    }
}
