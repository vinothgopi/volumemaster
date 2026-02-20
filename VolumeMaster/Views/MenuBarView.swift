import SwiftUI

struct MenuBarView: View {
    @ObservedObject var viewModel: MenuBarViewModel
    @ObservedObject var settings = AppSettings.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            Text("VolumeMaster")
                .font(.system(size: 13, weight: .semibold))
                .padding(.horizontal, 14)
                .padding(.top, 12)
                .padding(.bottom, 8)

            // Merge status (only shown when active)
            if viewModel.isMergeActive {
                MergeStatusRow(viewModel: viewModel)
                    .padding(.horizontal, 10)
                    .padding(.bottom, 6)
            }

            // Active profile (only shown when a profile has been applied)
            if let profileName = viewModel.activeProfileName {
                ActiveProfileRow(name: profileName)
                    .padding(.horizontal, 10)
                    .padding(.bottom, 6)
            }

            // Output Devices
            SectionHeader(title: "Output")

            ForEach(viewModel.outputDevices) { device in
                DeviceRow(
                    device: device,
                    isSelected: device.uid == viewModel.defaultOutputUID,
                    icon: "speaker.wave.2.fill"
                ) {
                    viewModel.selectOutputDevice(device)
                }
            }
            .padding(.horizontal, 10)

            Spacer()
                .frame(height: 10)

            // Input Devices
            SectionHeader(title: "Input")

            ForEach(viewModel.inputDevices) { device in
                DeviceRow(
                    device: device,
                    isSelected: device.uid == viewModel.defaultInputUID,
                    icon: "mic.fill"
                ) {
                    viewModel.selectInputDevice(device)
                }
            }
            .padding(.horizontal, 10)

            Spacer()
                .frame(height: 6)

            Divider()
                .padding(.horizontal, 14)
                .padding(.vertical, 4)

            // Footer
            if #available(macOS 14.0, *) {
                SettingsLink {
                    FooterLabel(title: "Settings...")
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 10)
            } else {
                FooterButton(title: "Settings...") {
                    NSApp.sendAction(
                        Selector(("showPreferencesWindow:")),
                        to: nil,
                        from: nil
                    )
                }
                .padding(.horizontal, 10)
            }

            FooterButton(title: "Quit VolumeMaster") {
                NSApplication.shared.terminate(nil)
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 8)
        }
        .frame(width: 290)
        .onAppear {
            viewModel.refresh()
            viewModel.setupDeviceMonitor()
        }
    }
}

// MARK: - Section Header

private struct SectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(.secondary)
            .padding(.horizontal, 14)
            .padding(.bottom, 4)
    }
}

// MARK: - Merge Status Row

private struct MergeStatusRow: View {
    @ObservedObject var viewModel: MenuBarViewModel

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "link")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.green)
            Text("Merged Output")
                .font(.system(size: 13, weight: .medium))
            Spacer()
            Button {
                viewModel.unmerge()
            } label: {
                Text("Unmerge")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.quaternary, in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(Color.green.opacity(0.1), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

// MARK: - Active Profile Row

private struct ActiveProfileRow: View {
    let name: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.triangle.swap")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.blue)
            Text(name)
                .font(.system(size: 13, weight: .medium))
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(Color.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

// MARK: - Device Row

private struct DeviceRow: View {
    let device: AudioDevice
    let isSelected: Bool
    let icon: String
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(isSelected ? .white : .secondary)
                    .frame(width: 28, height: 28)
                    .background(
                        Circle()
                            .fill(isSelected ? Color.accentColor : Color.clear)
                    )
                Text(device.name)
                    .font(.system(size: 13))
                    .lineLimit(1)
                Spacer()
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isHovered ? Color.primary.opacity(0.08) : Color.clear)
            )
            .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Footer

private struct FooterLabel: View {
    let title: String

    @State private var isHovered = false

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 13))
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(isHovered ? Color.primary.opacity(0.08) : Color.clear)
        )
        .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

private struct FooterButton: View {
    let title: String
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.system(size: 13))
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isHovered ? Color.primary.opacity(0.08) : Color.clear)
            )
            .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
