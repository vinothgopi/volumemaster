import CoreAudio
import Foundation

final class SpatialAudioController {
    static let shared = SpatialAudioController()

    struct Balance {
        var leftGain: Float
        var rightGain: Float
    }

    private(set) var isActive = false
    private(set) var baseVolume: Float = 0.5
    private(set) var currentBalance = Balance(leftGain: 1.0, rightGain: 1.0)

    private var primaryDeviceID: AudioDeviceID?
    private var secondaryDeviceID: AudioDeviceID?
    private let windowTracker = WindowTracker()
    private let gainFloor: Float = 0.15

    private init() {}

    func start(primaryID: AudioDeviceID, secondaryID: AudioDeviceID) {
        stop()

        primaryDeviceID = primaryID
        secondaryDeviceID = secondaryID

        // Seed base volume from current primary device volume
        if let vol = CoreAudioHelpers.getVolume(deviceID: primaryID, channel: 0) {
            baseVolume = vol
        }

        isActive = true

        windowTracker.onPositionChanged = { [weak self] normalizedX in
            self?.updateBalance(normalizedX: Float(normalizedX))
        }
        windowTracker.start()
    }

    func stop() {
        guard isActive else { return }

        // Clear flag first so volume mirroring guards see the correct state
        isActive = false

        windowTracker.stop()
        windowTracker.onPositionChanged = nil

        // Restore equal volumes before cleanup (only if devices still exist)
        if let pID = primaryDeviceID, let sID = secondaryDeviceID {
            let uidAddress = CoreAudioHelpers.propertyAddress(
                selector: kAudioDevicePropertyDeviceUID,
                scope: kAudioObjectPropertyScopeGlobal
            )
            let primaryExists = CoreAudioHelpers.hasProperty(objectID: pID, address: uidAddress)
            let secondaryExists = CoreAudioHelpers.hasProperty(objectID: sID, address: uidAddress)
            for channel: UInt32 in 0...2 {
                if primaryExists {
                    CoreAudioHelpers.setVolume(deviceID: pID, volume: baseVolume, channel: channel)
                }
                if secondaryExists {
                    CoreAudioHelpers.setVolume(deviceID: sID, volume: baseVolume, channel: channel)
                }
            }
        }

        primaryDeviceID = nil
        secondaryDeviceID = nil
        currentBalance = Balance(leftGain: 1.0, rightGain: 1.0)
    }

    func adjustVolume(delta: Float) {
        baseVolume = max(0, min(1, baseVolume + delta))
        applyVolumes()
    }

    func toggleMute() {
        guard let pID = primaryDeviceID, let sID = secondaryDeviceID else { return }

        if let muted = CoreAudioHelpers.getMute(deviceID: pID) {
            let newMute = !muted
            CoreAudioHelpers.setMute(deviceID: pID, muted: newMute)
            CoreAudioHelpers.setMute(deviceID: sID, muted: newMute)
        }
    }

    private func updateBalance(normalizedX: Float) {
        let pos = max(0, min(1, normalizedX))

        if pos <= 0.5 {
            currentBalance.leftGain = 1.0
            currentBalance.rightGain = gainFloor + (1 - gainFloor) * (pos / 0.5)
        } else {
            currentBalance.rightGain = 1.0
            currentBalance.leftGain = gainFloor + (1 - gainFloor) * ((1 - pos) / 0.5)
        }

        applyVolumes()
    }

    private func applyVolumes() {
        guard let pID = primaryDeviceID, let sID = secondaryDeviceID else { return }

        let leftVolume = baseVolume * currentBalance.leftGain
        let rightVolume = baseVolume * currentBalance.rightGain

        for channel: UInt32 in 0...2 {
            CoreAudioHelpers.setVolume(deviceID: pID, volume: leftVolume, channel: channel)
            CoreAudioHelpers.setVolume(deviceID: sID, volume: rightVolume, channel: channel)
        }
    }
}
