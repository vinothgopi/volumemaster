import Foundation

struct DeviceProfile: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var triggerDeviceUID: String
    var triggerOnConnect: Bool
    var outputDeviceUID: String?
    var inputDeviceUID: String?
    var videoDeviceUID: String?
    var enableMerge: Bool?

    init(
        id: UUID = UUID(),
        name: String = "New Profile",
        triggerDeviceUID: String = "",
        triggerOnConnect: Bool = true,
        outputDeviceUID: String? = nil,
        inputDeviceUID: String? = nil,
        videoDeviceUID: String? = nil,
        enableMerge: Bool? = nil
    ) {
        self.id = id
        self.name = name
        self.triggerDeviceUID = triggerDeviceUID
        self.triggerOnConnect = triggerOnConnect
        self.outputDeviceUID = outputDeviceUID
        self.inputDeviceUID = inputDeviceUID
        self.videoDeviceUID = videoDeviceUID
        self.enableMerge = enableMerge
    }
}
