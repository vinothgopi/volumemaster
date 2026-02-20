import AVFoundation

struct VideoDevice: Identifiable, Hashable {
    let id: String
    let name: String
}

enum VideoDeviceManager {

    static func allCameras() -> [VideoDevice] {
        let session = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .externalUnknown],
            mediaType: .video,
            position: .unspecified
        )
        return session.devices.map { VideoDevice(id: $0.uniqueID, name: $0.localizedName) }
    }

    static func setPreferredCamera(uniqueID: String) {
        let session = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .externalUnknown],
            mediaType: .video,
            position: .unspecified
        )
        guard let device = session.devices.first(where: { $0.uniqueID == uniqueID }) else { return }
        AVCaptureDevice.userPreferredCamera = device
    }

    static func preferredCameraUID() -> String? {
        AVCaptureDevice.userPreferredCamera?.uniqueID
    }
}
