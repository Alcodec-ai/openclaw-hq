import SwiftUI

struct DefaultModelView: View {
    @EnvironmentObject private var appState: AppState
    @ObservedObject var viewModel: SettingsViewModel
    @State private var primary: String = ""
    @State private var fallbacks: [String] = []
    @State private var showAddFallback = false

    var body: some View {
        Form {
            Section("Primary Model") {
                if viewModel.availableModels.isEmpty {
                    Text("Loading models...")
                        .foregroundStyle(.secondary)
                } else {
                    Picker("Primary", selection: $primary) {
                        ForEach(viewModel.availableModels, id: \.self) { model in
                            Text(model).tag(model)
                        }
                    }
                    .onChange(of: primary) { _, newValue in
                        guard let info = viewModel.modelsInfo, newValue != info.primary else { return }
                        Task {
                            await viewModel.setDefaultModel(
                                primary: newValue,
                                fallbacks: fallbacks,
                                client: appState.apiClient
                            )
                        }
                    }
                }
            }

            Section("Fallback Models") {
                ForEach(fallbacks, id: \.self) { model in
                    Text(model)
                }
                .onDelete { indices in
                    fallbacks.remove(atOffsets: indices)
                    Task {
                        await viewModel.setDefaultModel(
                            primary: primary,
                            fallbacks: fallbacks,
                            client: appState.apiClient
                        )
                    }
                }

                Button {
                    showAddFallback = true
                } label: {
                    Label("Add Fallback", systemImage: "plus")
                }
            }
        }
        .navigationTitle("Default Model")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if let info = viewModel.modelsInfo {
                primary = info.primary
                fallbacks = info.fallbacks
            }
        }
        .sheet(isPresented: $showAddFallback) {
            NavigationStack {
                List {
                    ForEach(viewModel.availableModels.filter { !fallbacks.contains($0) && $0 != primary }, id: \.self) { model in
                        Button(model) {
                            fallbacks.append(model)
                            showAddFallback = false
                            Task {
                                await viewModel.setDefaultModel(
                                    primary: primary,
                                    fallbacks: fallbacks,
                                    client: appState.apiClient
                                )
                            }
                        }
                    }
                }
                .navigationTitle("Select Model")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { showAddFallback = false }
                    }
                }
            }
        }
    }
}
