import CoreAudio
import Foundation

// C-function callback for volume changes on the primary device.
// Fires on CoreAudio's internal thread — collect changes and dispatch to main.
private func volumeChanged(
    objectID: AudioObjectID,
    numberAddresses: UInt32,
    addresses: UnsafePointer<AudioObjectPropertyAddress>,
    clientData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let clientData = clientData else { return noErr }
    let manager = Unmanaged<AggregateDeviceManager>.fromOpaque(clientData).takeUnretainedValue()

    var volumeChannels: [UInt32] = []
    var hasMuteChange = false

    for i in 0..<Int(numberAddresses) {
        let selector = addresses[i].mSelector
        if selector == kAudioDevicePropertyVolumeScalar {
            volumeChannels.append(addresses[i].mElement)
        } else if selector == kAudioDevicePropertyMute {
            hasMuteChange = true
        }
    }

    DispatchQueue.main.async {
        for channel in volumeChannels {
            manager.mirrorVolume(channel: channel)
        }
        if hasMuteChange {
            manager.mirrorMute()
        }
    }

    return noErr
}

final class AggregateDeviceManager {
    static let shared = AggregateDeviceManager()

    private(set) var activeAggregateDeviceID: AudioDeviceID?
    private(set) var previousDefaultOutputUID: String?

    private var primaryDeviceID: AudioDeviceID?
    private var secondaryDeviceID: AudioDeviceID?
    private var isListeningForVolume = false
    private var registeredVolumeChannels: Set<UInt32> = []
    private var isListeningForMute = false
    private var isTransitioningSpatial = false

    private let uidPrefix = "com.volumemaster.multioutput."

    private init() {}

    // MARK: - Create Aggregate Device

    func createMultiOutputDevice(
        primaryUID: String,
        secondaryUID: String,
        stereoSplit: Bool = false
    ) throws -> AudioDeviceID {
        // Save current default output UID for revert
        if let current = AudioDeviceManager.shared.defaultOutputDevice() {
            previousDefaultOutputUID = current.uid
        }

        // Tear down any existing aggregate
        destroyActiveAggregate()

        let uid = uidPrefix + UUID().uuidString
        let name = "VolumeMaster Multi-Output"

        let subDevices: [[String: Any]] = [
            [
                kAudioSubDeviceUIDKey as String: primaryUID,
                kAudioSubDeviceDriftCompensationKey as String: 0
            ],
            [
                kAudioSubDeviceUIDKey as String: secondaryUID,
                kAudioSubDeviceDriftCompensationKey as String: 1
            ]
        ]

        // Stacked mode concatenates channels (4ch for two stereo devices),
        // non-stacked mirrors audio to both devices.
        let description: [String: Any] = [
            kAudioAggregateDeviceNameKey as String: name,
            kAudioAggregateDeviceUIDKey as String: uid,
            kAudioAggregateDeviceSubDeviceListKey as String: subDevices,
            kAudioAggregateDeviceMasterSubDeviceKey as String: primaryUID,
            kAudioAggregateDeviceIsPrivateKey as String: 0,
            kAudioAggregateDeviceIsStackedKey as String: stereoSplit ? 1 : 0
        ]

        var aggregateDeviceID: AudioDeviceID = kAudioObjectUnknown
        let status = AudioHardwareCreateAggregateDevice(description as CFDictionary, &aggregateDeviceID)
        guard status == noErr else {
            throw CoreAudioError.osStatus(status)
        }

        // CoreAudio needs a brief moment to initialize the aggregate device
        CFRunLoopRunInMode(.defaultMode, 0.1, false)

        activeAggregateDeviceID = aggregateDeviceID

        // Resolve sub-device IDs for volume mirroring
        primaryDeviceID = AudioDeviceManager.shared.deviceID(forUID: primaryUID)
        secondaryDeviceID = AudioDeviceManager.shared.deviceID(forUID: secondaryUID)

        // For stereo split: route L to device 1 (ch 1), R to device 2 (ch 3)
        if stereoSplit {
            setPreferredStereoChannels(deviceID: aggregateDeviceID, left: 1, right: 3)
        }

        // Set the aggregate device as default output
        try AudioDeviceManager.shared.setDefaultOutputDeviceByID(aggregateDeviceID)

        // Intercept media keys so volume buttons control both sub-devices
        if let pID = primaryDeviceID, let sID = secondaryDeviceID {
            MediaKeyInterceptor.shared.start(primaryID: pID, secondaryID: sID)

            // Start spatial audio or volume mirroring
            if stereoSplit && AppSettings.shared.mergeSpatialAudio {
                SpatialAudioController.shared.start(primaryID: pID, secondaryID: sID)
            } else {
                startVolumeMirroring()
                syncVolumeNow()
            }
        }

        return aggregateDeviceID
    }

    private func setPreferredStereoChannels(deviceID: AudioDeviceID, left: UInt32, right: UInt32) {
        var channels: [UInt32] = [left, right]
        var address = CoreAudioHelpers.propertyAddress(
            selector: kAudioDevicePropertyPreferredChannelsForStereo,
            scope: kAudioDevicePropertyScopeOutput
        )
        let size = UInt32(MemoryLayout<UInt32>.size * 2)
        AudioObjectSetPropertyData(deviceID, &address, 0, nil, size, &channels)
    }

    // MARK: - Destroy Aggregate Device

    @discardableResult
    func destroyActiveAggregate() -> Bool {
        SpatialAudioController.shared.stop()
        MediaKeyInterceptor.shared.stop()
        stopVolumeMirroring()
        guard let deviceID = activeAggregateDeviceID else { return false }
        return destroyAggregate(deviceID: deviceID)
    }

    @discardableResult
    func destroyAggregate(deviceID: AudioDeviceID) -> Bool {
        let status = AudioHardwareDestroyAggregateDevice(deviceID)
        if status == noErr {
            if deviceID == activeAggregateDeviceID {
                activeAggregateDeviceID = nil
                primaryDeviceID = nil
                secondaryDeviceID = nil
            }
            return true
        }
        return false
    }

    // MARK: - Revert to Previous Default

    func revertDefaultOutput() {
        guard let uid = previousDefaultOutputUID,
              let device = AudioDeviceManager.shared.device(forUID: uid) else { return }
        try? AudioDeviceManager.shared.setDefaultOutputDevice(device)
        previousDefaultOutputUID = nil
    }

    // MARK: - Cleanup Orphaned Aggregates

    func cleanupOrphanedAggregates() {
        let devices = AudioDeviceManager.shared.allDevices()
        for device in devices where device.uid.hasPrefix(uidPrefix) {
            if device.id != activeAggregateDeviceID {
                destroyAggregate(deviceID: device.id)
            }
        }
    }

    // MARK: - Volume Mirroring

    private func startVolumeMirroring() {
        guard let primaryID = primaryDeviceID, !isListeningForVolume else { return }

        let selfPointer = Unmanaged.passUnretained(self).toOpaque()

        // Listen for volume changes on primary device (channels 0, 1, 2 cover master + stereo)
        for channel: UInt32 in 0...2 {
            var volumeAddr = CoreAudioHelpers.propertyAddress(
                selector: kAudioDevicePropertyVolumeScalar,
                scope: kAudioDevicePropertyScopeOutput,
                element: channel
            )
            if CoreAudioHelpers.hasProperty(objectID: primaryID, address: volumeAddr) {
                let status = AudioObjectAddPropertyListener(primaryID, &volumeAddr, volumeChanged, selfPointer)
                if status == noErr {
                    registeredVolumeChannels.insert(channel)
                }
            }
        }

        // Listen for mute changes
        var muteAddr = CoreAudioHelpers.propertyAddress(
            selector: kAudioDevicePropertyMute,
            scope: kAudioDevicePropertyScopeOutput,
            element: kAudioObjectPropertyElementMain
        )
        if CoreAudioHelpers.hasProperty(objectID: primaryID, address: muteAddr) {
            let status = AudioObjectAddPropertyListener(primaryID, &muteAddr, volumeChanged, selfPointer)
            if status == noErr {
                isListeningForMute = true
            }
        }

        isListeningForVolume = !registeredVolumeChannels.isEmpty || isListeningForMute
    }

    private func stopVolumeMirroring() {
        guard let primaryID = primaryDeviceID, isListeningForVolume else { return }

        // Only remove listeners if the device still exists — it may have been
        // physically disconnected, which invalidates the AudioObjectID.
        let deviceStillExists = CoreAudioHelpers.hasProperty(
            objectID: primaryID,
            address: CoreAudioHelpers.propertyAddress(
                selector: kAudioDevicePropertyDeviceUID,
                scope: kAudioObjectPropertyScopeGlobal
            )
        )

        if deviceStillExists {
            let selfPointer = Unmanaged.passUnretained(self).toOpaque()

            for channel in registeredVolumeChannels {
                var volumeAddr = CoreAudioHelpers.propertyAddress(
                    selector: kAudioDevicePropertyVolumeScalar,
                    scope: kAudioDevicePropertyScopeOutput,
                    element: channel
                )
                AudioObjectRemovePropertyListener(primaryID, &volumeAddr, volumeChanged, selfPointer)
            }

            if isListeningForMute {
                var muteAddr = CoreAudioHelpers.propertyAddress(
                    selector: kAudioDevicePropertyMute,
                    scope: kAudioDevicePropertyScopeOutput,
                    element: kAudioObjectPropertyElementMain
                )
                AudioObjectRemovePropertyListener(primaryID, &muteAddr, volumeChanged, selfPointer)
            }
        }

        registeredVolumeChannels.removeAll()
        isListeningForMute = false
        isListeningForVolume = false
    }

    func mirrorVolume(channel: UInt32) {
        guard !SpatialAudioController.shared.isActive else { return }
        guard let primaryID = primaryDeviceID, let secondaryID = secondaryDeviceID else { return }
        if let volume = CoreAudioHelpers.getVolume(deviceID: primaryID, channel: channel) {
            CoreAudioHelpers.setVolume(deviceID: secondaryID, volume: volume, channel: channel)
        }
    }

    func mirrorMute() {
        guard !SpatialAudioController.shared.isActive else { return }
        guard let primaryID = primaryDeviceID, let secondaryID = secondaryDeviceID else { return }
        if let muted = CoreAudioHelpers.getMute(deviceID: primaryID) {
            CoreAudioHelpers.setMute(deviceID: secondaryID, muted: muted)
        }
    }

    private func syncVolumeNow() {
        for channel: UInt32 in 0...2 {
            mirrorVolume(channel: channel)
        }
        mirrorMute()
    }

    // MARK: - State

    var isMergeActive: Bool {
        activeAggregateDeviceID != nil
    }

    // MARK: - Spatial Audio Toggle

    func updateSpatialAudio(enabled: Bool) {
        guard !isTransitioningSpatial,
              isMergeActive,
              let pID = primaryDeviceID,
              let sID = secondaryDeviceID else { return }

        isTransitioningSpatial = true
        defer { isTransitioningSpatial = false }

        if enabled {
            stopVolumeMirroring()
            SpatialAudioController.shared.start(primaryID: pID, secondaryID: sID)
        } else {
            SpatialAudioController.shared.stop()
            startVolumeMirroring()
            syncVolumeNow()
        }
    }
}
