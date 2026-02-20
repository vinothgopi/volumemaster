import SwiftUI

struct ProfileSettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        VStack(spacing: 0) {
            // Top bar
            HStack {
                Toggle("Enable Auto-Switch Profiles", isOn: $settings.profilesEnabled)
                    .toggleStyle(.switch)
                    .controlSize(.small)
                Spacer()
                Button {
                    viewModel.addProfile()
                } label: {
                    Image(systemName: "plus")
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider()

            if settings.profiles.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "arrow.triangle.swap")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("No profiles configured")
                        .foregroundColor(.secondary)
                    Text("Add a profile to auto-switch audio devices when a USB device connects or disconnects.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 300)
                    Spacer()
                }
            } else {
                List {
                    ForEach($settings.profiles) { $profile in
                        ProfileRow(
                            profile: $profile,
                            allDevices: viewModel.allDevices,
                            outputDevices: viewModel.outputDevices,
                            inputDevices: viewModel.inputDevices,
                            videoDevices: viewModel.videoDevices,
                            onDelete: {
                                viewModel.deleteProfile(id: profile.id)
                            }
                        )
                    }
                    .onDelete { offsets in
                        viewModel.deleteProfile(at: offsets)
                    }
                }
            }
        }
    }
}

private struct ProfileRow: View {
    @Binding var profile: DeviceProfile
    let allDevices: [AudioDevice]
    let outputDevices: [AudioDevice]
    let inputDevices: [AudioDevice]
    let videoDevices: [VideoDevice]
    var onDelete: () -> Void

    @State private var isExpanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 8) {
                TextField("Profile Name", text: $profile.name)
                    .textFieldStyle(.roundedBorder)

                Picker("Trigger Device", selection: $profile.triggerDeviceUID) {
                    Text("Select...").tag("")
                    if !profile.triggerDeviceUID.isEmpty,
                       !allDevices.contains(where: { $0.uid == profile.triggerDeviceUID }) {
                        Text("Disconnected device").tag(profile.triggerDeviceUID)
                    }
                    ForEach(allDevices) { device in
                        Text(device.name).tag(device.uid)
                    }
                }

                Picker("Trigger On", selection: $profile.triggerOnConnect) {
                    Text("Connect").tag(true)
                    Text("Disconnect").tag(false)
                }

                Picker("Set Output To", selection: Binding(
                    get: { profile.outputDeviceUID ?? "" },
                    set: { profile.outputDeviceUID = $0.isEmpty ? nil : $0 }
                )) {
                    Text("No change").tag("")
                    if let uid = profile.outputDeviceUID,
                       !outputDevices.contains(where: { $0.uid == uid }) {
                        Text("Disconnected device").tag(uid)
                    }
                    ForEach(outputDevices) { device in
                        Text(device.name).tag(device.uid)
                    }
                }

                Picker("Set Input To", selection: Binding(
                    get: { profile.inputDeviceUID ?? "" },
                    set: { profile.inputDeviceUID = $0.isEmpty ? nil : $0 }
                )) {
                    Text("No change").tag("")
                    if let uid = profile.inputDeviceUID,
                       !inputDevices.contains(where: { $0.uid == uid }) {
                        Text("Disconnected device").tag(uid)
                    }
                    ForEach(inputDevices) { device in
                        Text(device.name).tag(device.uid)
                    }
                }

                Picker("Set Camera To", selection: Binding(
                    get: { profile.videoDeviceUID ?? "" },
                    set: { profile.videoDeviceUID = $0.isEmpty ? nil : $0 }
                )) {
                    Text("No change").tag("")
                    if let uid = profile.videoDeviceUID,
                       !videoDevices.contains(where: { $0.id == uid }) {
                        Text("Disconnected device").tag(uid)
                    }
                    ForEach(videoDevices) { device in
                        Text(device.name).tag(device.id)
                    }
                }

                Picker("Merge Outputs", selection: Binding(
                    get: {
                        if let val = profile.enableMerge { return val ? 1 : 0 }
                        return -1
                    },
                    set: {
                        if $0 == -1 { profile.enableMerge = nil }
                        else { profile.enableMerge = $0 == 1 }
                    }
                )) {
                    Text("No change").tag(-1)
                    Text("Enable").tag(1)
                    Text("Disable").tag(0)
                }

                Divider()

                Button(role: .destructive, action: onDelete) {
                    Label("Delete Profile", systemImage: "trash")
                }
            }
            .padding(.vertical, 4)
        } label: {
            HStack {
                Image(systemName: profile.triggerOnConnect ? "cable.connector" : "cable.connector.slash")
                    .foregroundColor(.secondary)
                Text(profile.name)
                Spacer()
                if let triggerName = allDevices.first(where: { $0.uid == profile.triggerDeviceUID })?.name {
                    Text(triggerName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}
