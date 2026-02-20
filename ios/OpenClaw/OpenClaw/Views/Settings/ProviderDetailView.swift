import SwiftUI

struct ProviderDetailView: View {
    @EnvironmentObject private var appState: AppState
    let provider: Provider
    @ObservedObject var viewModel: SettingsViewModel
    @State private var apiKey = ""
    @State private var baseUrl = ""
    @State private var modelsText = ""

    var body: some View {
        Form {
            Section("API Key") {
                SecureField("API Key", text: $apiKey)
                if provider.hasKey {
                    Text("Current: \(provider.apiKey)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Base URL") {
                TextField("Base URL", text: $baseUrl)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
            }

            Section("Models") {
                TextField("Models (comma separated)", text: $modelsText)
                    .textInputAutocapitalization(.never)

                ForEach(provider.models, id: \.self) { model in
                    Text(model)
                        .font(.system(.body, design: .monospaced))
                }
            }

            Section {
                Button("Save Changes") {
                    let models = modelsText.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                    Task {
                        await viewModel.updateProvider(
                            name: provider.id,
                            apiKey: apiKey.isEmpty ? provider.apiKey : apiKey,
                            baseUrl: baseUrl,
                            models: models.isEmpty ? provider.models : models,
                            client: appState.apiClient
                        )
                    }
                }
            }
        }
        .navigationTitle(provider.id)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            baseUrl = provider.baseUrl
            modelsText = provider.models.joined(separator: ", ")
        }
    }
}
