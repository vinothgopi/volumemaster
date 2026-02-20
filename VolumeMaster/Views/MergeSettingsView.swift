import SwiftUI

struct MergeSettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        Form {
            Section {
                Text("Merge two audio outputs into a single multi-output device. Keyboard volume keys will control both.")
                    .font(.callout)
                    .foregroundColor(.secondary)
            }

            Section {
                Toggle("Enable Merge", isOn: Binding(
                    get: { viewModel.isMergeActive },
                    set: { viewModel.toggleMerge(enabled: $0) }
                ))
                .disabled(!settings.hasMergeDevicesConfigured)

                Toggle("Stereo Split (L/R)", isOn: $settings.mergeStereoSplit)
                    .disabled(viewModel.isMergeActive)
            }

            if settings.mergeStereoSplit {
                Section {
                    Text("Left channel routes to the primary output, right channel to the secondary. Works like studio monitors — one speaker per side.")
                        .font(.callout)
                        .foregroundColor(.secondary)

                    Toggle("Spatial Audio", isOn: Binding(
                        get: { settings.mergeSpatialAudio },
                        set: { newValue in
                            settings.mergeSpatialAudio = newValue
                            if viewModel.isMergeActive {
                                AggregateDeviceManager.shared.updateSpatialAudio(enabled: newValue)
                            }
                        }
                    ))

                    if settings.mergeSpatialAudio {
                        Text("Balance follows the focused window. Window on left monitor plays louder from the left output, and vice versa.")
                            .font(.callout)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Section("Primary Output") {
                Picker("Device", selection: Binding(
                    get: {
                        viewModel.outputDevices.contains(where: { $0.uid == settings.mergePrimaryUID })
                            ? settings.mergePrimaryUID : ""
                    },
                    set: { settings.mergePrimaryUID = $0 }
                )) {
                    Text("Select...").tag("")
                    ForEach(viewModel.outputDevices) { device in
                        Text(device.name).tag(device.uid)
                    }
                }
            }

            Section("Secondary Output") {
                Picker("Device", selection: Binding(
                    get: {
                        viewModel.outputDevices.contains(where: { $0.uid == settings.mergeSecondaryUID })
                            ? settings.mergeSecondaryUID : ""
                    },
                    set: { settings.mergeSecondaryUID = $0 }
                )) {
                    Text("Select...").tag("")
                    ForEach(viewModel.outputDevices.filter { $0.uid != settings.mergePrimaryUID }) { device in
                        Text(device.name).tag(device.uid)
                    }
                }
            }

            Section {
                if viewModel.isMergeActive {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Merge is active. Audio plays on both outputs.")
                            .font(.callout)
                    }
                } else if settings.hasMergeDevicesConfigured {
                    HStack {
                        Image(systemName: "circle")
                            .foregroundColor(.secondary)
                        Text("Ready to merge. Toggle above to activate.")
                            .font(.callout)
                    }
                } else {
                    HStack {
                        Image(systemName: "exclamationmark.circle")
                            .foregroundColor(.orange)
                        Text("Select both a primary and secondary output above.")
                            .font(.callout)
                    }
                }

                if let error = viewModel.mergeError {
                    HStack {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                        Text(error)
                            .font(.callout)
                            .foregroundColor(.red)
                    }
                }
            }

            Section {
                Toggle("Launch at Login", isOn: Binding(
                    get: { settings.launchAtLogin },
                    set: { viewModel.setLaunchAtLogin($0) }
                ))
                LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
            }
        }
        .formStyle(.grouped)
        .onAppear {
            viewModel.refresh()
        }
    }
}
