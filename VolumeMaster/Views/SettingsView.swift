import SwiftUI

struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()

    var body: some View {
        TabView {
            MergeSettingsView(viewModel: viewModel)
                .tabItem {
                    Label("Merge", systemImage: "link")
                }

            ProfileSettingsView(viewModel: viewModel)
                .tabItem {
                    Label("Profiles", systemImage: "arrow.triangle.swap")
                }
        }
        .frame(width: 480, height: 360)
        .onAppear {
            viewModel.refresh()
        }
    }
}
