import CoreAudio
import Foundation

enum CoreAudioError: Error, LocalizedError {
    case osStatus(OSStatus)
    case deviceNotFound
    case invalidProperty

    var errorDescription: String? {
        switch self {
        case .osStatus(let status):
            return "CoreAudio error: \(status)"
        case .deviceNotFound:
            return "Audio device not found"
        case .invalidProperty:
            return "Invalid audio property"
        }
    }
}

enum CoreAudioHelpers {
    // MARK: - Property Address Builders

    static func propertyAddress(
        selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal,
        element: AudioObjectPropertyElement = kAudioObjectPropertyElementMain
    ) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: scope,
            mElement: element
        )
    }

    static func outputAddress(_ selector: AudioObjectPropertySelector) -> AudioObjectPropertyAddress {
        propertyAddress(selector: selector, scope: kAudioDevicePropertyScopeOutput)
    }

    static func inputAddress(_ selector: AudioObjectPropertySelector) -> AudioObjectPropertyAddress {
        propertyAddress(selector: selector, scope: kAudioDevicePropertyScopeInput)
    }

    // MARK: - Property Getters

    static func getPropertyData<T>(
        objectID: AudioObjectID,
        address: AudioObjectPropertyAddress,
        type: T.Type
    ) throws -> T {
        var addr = address
        var size = UInt32(MemoryLayout<T>.size)
        let value = UnsafeMutableRawPointer.allocate(byteCount: Int(size), alignment: MemoryLayout<T>.alignment)
        defer { value.deallocate() }

        let status = AudioObjectGetPropertyData(objectID, &addr, 0, nil, &size, value)
        guard status == noErr else { throw CoreAudioError.osStatus(status) }
        return value.load(as: T.self)
    }

    static func getPropertyDataArray<T>(
        objectID: AudioObjectID,
        address: AudioObjectPropertyAddress,
        type: T.Type
    ) throws -> [T] {
        var addr = address
        var size: UInt32 = 0

        var status = AudioObjectGetPropertyDataSize(objectID, &addr, 0, nil, &size)
        guard status == noErr else { throw CoreAudioError.osStatus(status) }

        let count = Int(size) / MemoryLayout<T>.size
        guard count > 0 else { return [] }

        let byteCount = Int(size)
        let pointer = UnsafeMutableRawPointer.allocate(byteCount: byteCount, alignment: MemoryLayout<T>.alignment)
        defer { pointer.deallocate() }

        status = AudioObjectGetPropertyData(objectID, &addr, 0, nil, &size, pointer)
        guard status == noErr else { throw CoreAudioError.osStatus(status) }

        let typedPointer = pointer.bindMemory(to: T.self, capacity: count)
        return Array(UnsafeBufferPointer(start: typedPointer, count: count))
    }

    static func getStringProperty(
        objectID: AudioObjectID,
        address: AudioObjectPropertyAddress
    ) throws -> String {
        var addr = address
        var size = UInt32(MemoryLayout<Unmanaged<CFString>>.size)
        var unmanagedValue: Unmanaged<CFString>?

        let status = AudioObjectGetPropertyData(objectID, &addr, 0, nil, &size, &unmanagedValue)
        guard status == noErr else { throw CoreAudioError.osStatus(status) }
        guard let cfString = unmanagedValue?.takeUnretainedValue() else {
            throw CoreAudioError.invalidProperty
        }
        return cfString as String
    }

    // MARK: - Property Setters

    static func setPropertyData<T>(
        objectID: AudioObjectID,
        address: AudioObjectPropertyAddress,
        value: T
    ) throws {
        var addr = address
        let size = UInt32(MemoryLayout<T>.size)

        let status = withUnsafeBytes(of: value) { bufferPointer in
            let pointer = UnsafeMutableRawPointer(mutating: bufferPointer.baseAddress!)
            return AudioObjectSetPropertyData(objectID, &addr, 0, nil, size, pointer)
        }
        guard status == noErr else { throw CoreAudioError.osStatus(status) }
    }

    // MARK: - Property Data Size

    static func getPropertyDataSize(
        objectID: AudioObjectID,
        address: AudioObjectPropertyAddress
    ) throws -> UInt32 {
        var addr = address
        var size: UInt32 = 0
        let status = AudioObjectGetPropertyDataSize(objectID, &addr, 0, nil, &size)
        guard status == noErr else { throw CoreAudioError.osStatus(status) }
        return size
    }

    // MARK: - Has Property

    static func hasProperty(
        objectID: AudioObjectID,
        address: AudioObjectPropertyAddress
    ) -> Bool {
        var addr = address
        return AudioObjectHasProperty(objectID, &addr)
    }

    // MARK: - Property Settable Check

    static func isPropertySettable(
        objectID: AudioObjectID,
        address: AudioObjectPropertyAddress
    ) -> Bool {
        var addr = address
        var isSettable: DarwinBoolean = false
        let status = AudioObjectIsPropertySettable(objectID, &addr, &isSettable)
        return status == noErr && isSettable.boolValue
    }

    // MARK: - Volume Helpers

    static func getVolume(deviceID: AudioDeviceID, channel: UInt32 = 0) -> Float32? {
        let address = propertyAddress(
            selector: kAudioDevicePropertyVolumeScalar,
            scope: kAudioDevicePropertyScopeOutput,
            element: channel
        )
        guard hasProperty(objectID: deviceID, address: address) else { return nil }
        return try? getPropertyData(objectID: deviceID, address: address, type: Float32.self)
    }

    static func setVolume(deviceID: AudioDeviceID, volume: Float32, channel: UInt32 = 0) {
        let address = propertyAddress(
            selector: kAudioDevicePropertyVolumeScalar,
            scope: kAudioDevicePropertyScopeOutput,
            element: channel
        )
        guard isPropertySettable(objectID: deviceID, address: address) else { return }
        try? setPropertyData(objectID: deviceID, address: address, value: volume)
    }

    static func getMute(deviceID: AudioDeviceID) -> Bool? {
        let address = propertyAddress(
            selector: kAudioDevicePropertyMute,
            scope: kAudioDevicePropertyScopeOutput,
            element: kAudioObjectPropertyElementMain
        )
        guard hasProperty(objectID: deviceID, address: address) else { return nil }
        guard let value = try? getPropertyData(objectID: deviceID, address: address, type: UInt32.self) else { return nil }
        return value != 0
    }

    static func setMute(deviceID: AudioDeviceID, muted: Bool) {
        let address = propertyAddress(
            selector: kAudioDevicePropertyMute,
            scope: kAudioDevicePropertyScopeOutput,
            element: kAudioObjectPropertyElementMain
        )
        guard isPropertySettable(objectID: deviceID, address: address) else { return }
        let value: UInt32 = muted ? 1 : 0
        try? setPropertyData(objectID: deviceID, address: address, value: value)
    }

    // MARK: - Stream Configuration (channel count check)

    static func channelCount(
        deviceID: AudioDeviceID,
        scope: AudioObjectPropertyScope
    ) -> Int {
        let address = propertyAddress(
            selector: kAudioDevicePropertyStreamConfiguration,
            scope: scope
        )
        guard let size = try? getPropertyDataSize(objectID: deviceID, address: address) else {
            return 0
        }
        let bufferListPointer = UnsafeMutablePointer<AudioBufferList>.allocate(capacity: Int(size))
        defer { bufferListPointer.deallocate() }

        var addr = address
        var dataSize = size
        let status = AudioObjectGetPropertyData(deviceID, &addr, 0, nil, &dataSize, bufferListPointer)
        guard status == noErr else { return 0 }

        let bufferList = UnsafeMutableAudioBufferListPointer(bufferListPointer)
        return bufferList.reduce(0) { $0 + Int($1.mNumberChannels) }
    }
}
