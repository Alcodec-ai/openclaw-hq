import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = SettingsViewModel()

    var body: some View {
        NavigationStack {
            List {
                if viewModel.isLoading && viewModel.settings == nil {
                    Section {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    }
                }

                Section("Gateway") {
                    NavigationLink("Gateway Control") {
                        GatewayControlView(viewModel: viewModel)
                    }
                }

                Section("Model Defaults") {
                    NavigationLink("Default Model") {
                        DefaultModelView(viewModel: viewModel)
                    }

                    if let settings = viewModel.settings {
                        Picker("Compaction", selection: Binding(
                            get: { settings.defaults.compaction },
                            set: { newValue in
                                Task {
                                    await viewModel.setCompaction(newValue, client: appState.apiClient)
                                }
                            }
                        )) {
                            Text("Safeguard").tag("safeguard")
                            Text("Full").tag("full")
                            Text("Off").tag("off")
                        }
                    }
                }

                Section("Providers") {
                    NavigationLink {
                        ProvidersView(viewModel: viewModel)
                    } label: {
                        LabeledContent("Providers", value: "\(viewModel.providers.count)")
                    }
                }

                Section("Channels") {
                    NavigationLink {
                        ChannelsView(viewModel: viewModel)
                    } label: {
                        LabeledContent("Channels", value: "\(viewModel.channels.count)")
                    }
                }

                Section("Backup") {
                    NavigationLink("MD Backup") {
                        BackupSettingsView(viewModel: viewModel)
                    }
                }

                Section("Connection") {
                    NavigationLink("Server URL") {
                        ServerURLView()
                    }
                }
            }
            .navigationTitle("Settings")
            .refreshable {
                await viewModel.loadAll(client: appState.apiClient)
            }
            .task {
                await viewModel.loadAll(client: appState.apiClient)
            }
        }
    }
}
