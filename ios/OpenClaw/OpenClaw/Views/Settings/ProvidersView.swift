import SwiftUI

struct ProvidersView: View {
    @EnvironmentObject private var appState: AppState
    @ObservedObject var viewModel: SettingsViewModel
    @State private var showAddProvider = false
    @State private var newName = ""
    @State private var newApiKey = ""
    @State private var newBaseUrl = ""
    @State private var newModels = ""

    var body: some View {
        List {
            ForEach(viewModel.providers) { provider in
                NavigationLink {
                    ProviderDetailView(provider: provider, viewModel: viewModel)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(provider.id)
                            .font(.headline)
                        HStack {
                            Image(systemName: provider.hasKey ? "key.fill" : "key")
                                .foregroundStyle(provider.hasKey ? .green : .red)
                                .font(.caption)
                            Text("\(provider.models.count) models")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .onDelete { indices in
                for index in indices {
                    let provider = viewModel.providers[index]
                    Task {
                        await viewModel.deleteProvider(name: provider.id, client: appState.apiClient)
                    }
                }
            }
        }
        .navigationTitle("Providers")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showAddProvider = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showAddProvider) {
            NavigationStack {
                Form {
                    TextField("Name", text: $newName)
                    SecureField("API Key", text: $newApiKey)
                    TextField("Base URL", text: $newBaseUrl)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                    TextField("Models (comma separated)", text: $newModels)
                        .textInputAutocapitalization(.never)

                    Button("Add Provider") {
                        let models = newModels.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                        Task {
                            await viewModel.addProvider(
                                name: newName,
                                apiKey: newApiKey,
                                baseUrl: newBaseUrl,
                                models: models,
                                client: appState.apiClient
                            )
                            showAddProvider = false
                            newName = ""
                            newApiKey = ""
                            newBaseUrl = ""
                            newModels = ""
                        }
                    }
                    .disabled(newName.isEmpty)
                }
                .navigationTitle("Add Provider")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { showAddProvider = false }
                    }
                }
            }
        }
    }
}
