import CoreAudio
import Foundation

final class AudioDeviceManager {
    static let shared = AudioDeviceManager()

    private init() {}

    // MARK: - Device Enumeration

    func allDevices() -> [AudioDevice] {
        let address = CoreAudioHelpers.propertyAddress(
            selector: kAudioHardwarePropertyDevices
        )
        guard let deviceIDs = try? CoreAudioHelpers.getPropertyDataArray(
            objectID: AudioObjectID(kAudioObjectSystemObject),
            address: address,
            type: AudioDeviceID.self
        ) else { return [] }

        return deviceIDs.compactMap { AudioDevice.from(deviceID: $0) }
    }

    func outputDevices() -> [AudioDevice] {
        allDevices().filter { $0.hasOutput && !$0.isOurAggregate }
    }

    func inputDevices() -> [AudioDevice] {
        allDevices().filter { $0.hasInput && !$0.isOurAggregate }
    }

    // MARK: - Default Device Getters

    func defaultOutputDevice() -> AudioDevice? {
        guard let deviceID = try? CoreAudioHelpers.getPropertyData(
            objectID: AudioObjectID(kAudioObjectSystemObject),
            address: CoreAudioHelpers.propertyAddress(selector: kAudioHardwarePropertyDefaultOutputDevice),
            type: AudioDeviceID.self
        ) else { return nil }
        return AudioDevice.from(deviceID: deviceID)
    }

    func defaultInputDevice() -> AudioDevice? {
        guard let deviceID = try? CoreAudioHelpers.getPropertyData(
            objectID: AudioObjectID(kAudioObjectSystemObject),
            address: CoreAudioHelpers.propertyAddress(selector: kAudioHardwarePropertyDefaultInputDevice),
            type: AudioDeviceID.self
        ) else { return nil }
        return AudioDevice.from(deviceID: deviceID)
    }

    func defaultSystemOutputDevice() -> AudioDevice? {
        guard let deviceID = try? CoreAudioHelpers.getPropertyData(
            objectID: AudioObjectID(kAudioObjectSystemObject),
            address: CoreAudioHelpers.propertyAddress(selector: kAudioHardwarePropertyDefaultSystemOutputDevice),
            type: AudioDeviceID.self
        ) else { return nil }
        return AudioDevice.from(deviceID: deviceID)
    }

    // MARK: - Default Device Setters

    func setDefaultOutputDevice(_ device: AudioDevice) throws {
        try CoreAudioHelpers.setPropertyData(
            objectID: AudioObjectID(kAudioObjectSystemObject),
            address: CoreAudioHelpers.propertyAddress(selector: kAudioHardwarePropertyDefaultOutputDevice),
            value: device.id
        )
        setSystemOutputDeviceIfSettable(device.id)
    }

    func setDefaultOutputDeviceByID(_ deviceID: AudioDeviceID) throws {
        try CoreAudioHelpers.setPropertyData(
            objectID: AudioObjectID(kAudioObjectSystemObject),
            address: CoreAudioHelpers.propertyAddress(selector: kAudioHardwarePropertyDefaultOutputDevice),
            value: deviceID
        )
        setSystemOutputDeviceIfSettable(deviceID)
    }

    private func setSystemOutputDeviceIfSettable(_ deviceID: AudioDeviceID) {
        let address = CoreAudioHelpers.propertyAddress(
            selector: kAudioHardwarePropertyDefaultSystemOutputDevice
        )
        guard CoreAudioHelpers.isPropertySettable(
            objectID: AudioObjectID(kAudioObjectSystemObject),
            address: address
        ) else { return }
        try? CoreAudioHelpers.setPropertyData(
            objectID: AudioObjectID(kAudioObjectSystemObject),
            address: address,
            value: deviceID
        )
    }

    func setDefaultInputDevice(_ device: AudioDevice) throws {
        try CoreAudioHelpers.setPropertyData(
            objectID: AudioObjectID(kAudioObjectSystemObject),
            address: CoreAudioHelpers.propertyAddress(selector: kAudioHardwarePropertyDefaultInputDevice),
            value: device.id
        )
    }

    func setDefaultInputDeviceByID(_ deviceID: AudioDeviceID) throws {
        try CoreAudioHelpers.setPropertyData(
            objectID: AudioObjectID(kAudioObjectSystemObject),
            address: CoreAudioHelpers.propertyAddress(selector: kAudioHardwarePropertyDefaultInputDevice),
            value: deviceID
        )
    }

    // MARK: - Lookup by UID

    func device(forUID uid: String) -> AudioDevice? {
        allDevices().first { $0.uid == uid }
    }

    func deviceID(forUID uid: String) -> AudioDeviceID? {
        device(forUID: uid)?.id
    }
}
