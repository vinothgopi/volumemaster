import CoreAudio
import Foundation

// C-function callback for device list changes (avoids Swift block API removal bug)
private func deviceListChanged(
    objectID: AudioObjectID,
    numberAddresses: UInt32,
    addresses: UnsafePointer<AudioObjectPropertyAddress>,
    clientData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let clientData = clientData else { return noErr }
    let monitor = Unmanaged<DeviceMonitor>.fromOpaque(clientData).takeUnretainedValue()
    monitor.handleDeviceListChange()
    return noErr
}

final class DeviceMonitor {
    static let shared = DeviceMonitor()

    var onDevicesChanged: ((_ connected: Set<String>, _ disconnected: Set<String>) -> Void)?

    private var knownDeviceUIDs: Set<String> = []
    private var isListening = false

    private init() {}

    func startMonitoring() {
        guard !isListening else { return }

        // Snapshot current devices
        knownDeviceUIDs = Set(AudioDeviceManager.shared.allDevices().map(\.uid))

        var address = CoreAudioHelpers.propertyAddress(
            selector: kAudioHardwarePropertyDevices
        )

        let selfPointer = Unmanaged.passUnretained(self).toOpaque()
        let status = AudioObjectAddPropertyListener(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            deviceListChanged,
            selfPointer
        )

        if status == noErr {
            isListening = true
        }
    }

    func stopMonitoring() {
        guard isListening else { return }

        var address = CoreAudioHelpers.propertyAddress(
            selector: kAudioHardwarePropertyDevices
        )

        let selfPointer = Unmanaged.passUnretained(self).toOpaque()
        AudioObjectRemovePropertyListener(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            deviceListChanged,
            selfPointer
        )

        isListening = false
    }

    func handleDeviceListChange() {
        // CoreAudio callback runs on its own thread — dispatch to main
        DispatchQueue.main.async { [weak self] in
            self?.diffDevices()
        }
    }

    private func diffDevices() {
        let currentUIDs = Set(AudioDeviceManager.shared.allDevices().map(\.uid))
        let connected = currentUIDs.subtracting(knownDeviceUIDs)
        let disconnected = knownDeviceUIDs.subtracting(currentUIDs)
        knownDeviceUIDs = currentUIDs

        if !connected.isEmpty || !disconnected.isEmpty {
            onDevicesChanged?(connected, disconnected)
        }
    }
}
