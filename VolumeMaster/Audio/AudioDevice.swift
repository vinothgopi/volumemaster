import CoreAudio
import Foundation

struct AudioDevice: Identifiable, Hashable {
    let id: AudioDeviceID
    let uid: String
    let name: String
    let manufacturer: String
    let hasInput: Bool
    let hasOutput: Bool
    let transportType: UInt32

    var isAggregate: Bool {
        transportType == kAudioDeviceTransportTypeAggregate
    }

    var isOurAggregate: Bool {
        uid.hasPrefix("com.volumemaster.multioutput.")
    }

    static func from(deviceID: AudioDeviceID) -> AudioDevice? {
        guard let uid = try? CoreAudioHelpers.getStringProperty(
            objectID: deviceID,
            address: CoreAudioHelpers.propertyAddress(selector: kAudioDevicePropertyDeviceUID)
        ) else { return nil }

        guard let name = try? CoreAudioHelpers.getStringProperty(
            objectID: deviceID,
            address: CoreAudioHelpers.propertyAddress(selector: kAudioObjectPropertyName)
        ) else { return nil }

        let manufacturer = (try? CoreAudioHelpers.getStringProperty(
            objectID: deviceID,
            address: CoreAudioHelpers.propertyAddress(selector: kAudioObjectPropertyManufacturer)
        )) ?? ""

        let transportType = (try? CoreAudioHelpers.getPropertyData(
            objectID: deviceID,
            address: CoreAudioHelpers.propertyAddress(selector: kAudioDevicePropertyTransportType),
            type: UInt32.self
        )) ?? 0

        let hasOutput = CoreAudioHelpers.channelCount(deviceID: deviceID, scope: kAudioDevicePropertyScopeOutput) > 0
        let hasInput = CoreAudioHelpers.channelCount(deviceID: deviceID, scope: kAudioDevicePropertyScopeInput) > 0

        return AudioDevice(
            id: deviceID,
            uid: uid,
            name: name,
            manufacturer: manufacturer,
            hasInput: hasInput,
            hasOutput: hasOutput,
            transportType: transportType
        )
    }
}
