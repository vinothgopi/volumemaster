import SwiftUI

@main
struct VolumeMasterApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var viewModel = MenuBarViewModel()

    var body: some Scene {
        MenuBarExtra("VolumeMaster", systemImage: "speaker.wave.2.fill") {
            MenuBarView(viewModel: viewModel)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
        }
    }

    init() {
        // Device monitoring is set up after viewModel initializes (in onAppear)
    }
}
