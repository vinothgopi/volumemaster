import Cocoa
import CoreAudio
import CoreGraphics

private func mediaKeyCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    // Re-enable tap if it was disabled by timeout
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        if let userInfo {
            let interceptor = Unmanaged<MediaKeyInterceptor>.fromOpaque(userInfo).takeUnretainedValue()
            if let tap = interceptor.eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
        }
        return Unmanaged.passUnretained(event)
    }

    // NX_SYSDEFINED = 14
    guard type.rawValue == 14 else {
        return Unmanaged.passUnretained(event)
    }

    guard let nsEvent = NSEvent(cgEvent: event),
          nsEvent.subtype.rawValue == 8 else { // 8 = media key events
        return Unmanaged.passUnretained(event)
    }

    let data1 = nsEvent.data1
    let keyCode = (data1 & 0xFFFF0000) >> 16
    let keyState = (data1 & 0xFF00) >> 8
    let isKeyDown = keyState == 0x0A

    guard isKeyDown else {
        // Pass through key-up events
        return Unmanaged.passUnretained(event)
    }

    guard let userInfo else {
        return Unmanaged.passUnretained(event)
    }

    let interceptor = Unmanaged<MediaKeyInterceptor>.fromOpaque(userInfo).takeUnretainedValue()

    // NX_KEYTYPE_SOUND_UP = 0, NX_KEYTYPE_SOUND_DOWN = 1, NX_KEYTYPE_MUTE = 7
    switch keyCode {
    case 0:
        interceptor.adjustVolume(delta: interceptor.volumeStep)
        return nil
    case 1:
        interceptor.adjustVolume(delta: -interceptor.volumeStep)
        return nil
    case 7:
        interceptor.toggleMute()
        return nil
    default:
        return Unmanaged.passUnretained(event)
    }
}

final class MediaKeyInterceptor {
    static let shared = MediaKeyInterceptor()

    fileprivate var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    let volumeStep: Float = 0.0625 // 1/16, matches macOS

    private var primaryDeviceID: AudioDeviceID?
    private var secondaryDeviceID: AudioDeviceID?
    private var permissionPollTimer: Timer?
    private var hasPromptedForPermission = false

    private init() {}

    func start(primaryID: AudioDeviceID, secondaryID: AudioDeviceID) {
        stop()

        self.primaryDeviceID = primaryID
        self.secondaryDeviceID = secondaryID

        if !AXIsProcessTrusted() && !hasPromptedForPermission {
            hasPromptedForPermission = true
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
            _ = AXIsProcessTrustedWithOptions(options)
        }

        if !tryInstallEventTap() {
            startRetryPolling()
        }
    }

    /// Returns true if the event tap was successfully created.
    @discardableResult
    private func tryInstallEventTap() -> Bool {
        guard eventTap == nil else { return true } // already installed

        // NX_SYSDEFINED = 14
        let mask = CGEventMask(1 << 14)

        guard let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: mediaKeyCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            return false
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(nil, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    private func startRetryPolling() {
        permissionPollTimer?.invalidate()
        permissionPollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            if self.tryInstallEventTap() {
                self.permissionPollTimer?.invalidate()
                self.permissionPollTimer = nil
            }
        }
    }

    func stop() {
        permissionPollTimer?.invalidate()
        permissionPollTimer = nil
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            if let source = runLoopSource {
                CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            }
            CFMachPortInvalidate(tap)
        }
        eventTap = nil
        runLoopSource = nil
        primaryDeviceID = nil
        secondaryDeviceID = nil
    }

    func adjustVolume(delta: Float) {
        if SpatialAudioController.shared.isActive {
            SpatialAudioController.shared.adjustVolume(delta: delta)
            VolumeHUD.shared.show(volume: SpatialAudioController.shared.baseVolume)
            return
        }

        guard let primaryID = primaryDeviceID, let secondaryID = secondaryDeviceID else { return }

        // Adjust on both sub-devices across all channels
        for channel: UInt32 in 0...2 {
            if let current = CoreAudioHelpers.getVolume(deviceID: primaryID, channel: channel) {
                let newVolume = max(0, min(1, current + delta))
                CoreAudioHelpers.setVolume(deviceID: primaryID, volume: newVolume, channel: channel)
                CoreAudioHelpers.setVolume(deviceID: secondaryID, volume: newVolume, channel: channel)
            }
        }

        if let vol = CoreAudioHelpers.getVolume(deviceID: primaryID, channel: 0) {
            VolumeHUD.shared.show(volume: vol)
        }
    }

    func toggleMute() {
        if SpatialAudioController.shared.isActive {
            SpatialAudioController.shared.toggleMute()
            if let pID = primaryDeviceID, let muted = CoreAudioHelpers.getMute(deviceID: pID) {
                VolumeHUD.shared.show(volume: SpatialAudioController.shared.baseVolume, muted: muted)
            }
            return
        }

        guard let primaryID = primaryDeviceID, let secondaryID = secondaryDeviceID else { return }

        if let muted = CoreAudioHelpers.getMute(deviceID: primaryID) {
            let newMute = !muted
            CoreAudioHelpers.setMute(deviceID: primaryID, muted: newMute)
            CoreAudioHelpers.setMute(deviceID: secondaryID, muted: newMute)
            if let vol = CoreAudioHelpers.getVolume(deviceID: primaryID, channel: 0) {
                VolumeHUD.shared.show(volume: vol, muted: newMute)
            }
        }
    }
}
