import SwiftUI

struct AgentDetailView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel: AgentDetailViewModel
    @State private var showSendTask = false
    @State private var selectedModel: String = ""
    @State private var selectedPlatform: String = ""

    init(agentId: String) {
        _viewModel = StateObject(wrappedValue: AgentDetailViewModel(agentId: agentId))
    }

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.detail == nil {
                ProgressView("Loading...")
            } else if let detail = viewModel.detail {
                Form {
                    // Stats Section
                    Section("Token Usage") {
                        TokenUsageView(tokens: detail.tokens)
                        LabeledContent("Input", value: "\(detail.tokens.input)")
                        LabeledContent("Output", value: "\(detail.tokens.output)")
                        LabeledContent("Total", value: "\(detail.tokens.total)")
                        LabeledContent("Context", value: "\(detail.tokens.context)")
                    }

                    // Config Section
                    Section("Configuration") {
                        LabeledContent("Sessions", value: "\(detail.sessionCount)")

                        if !viewModel.availableModels.isEmpty {
                            Picker("Model", selection: $selectedModel) {
                                ForEach(viewModel.availableModels, id: \.self) { model in
                                    Text(model).tag(model)
                                }
                            }
                            .onChange(of: selectedModel) { _, newValue in
                                guard newValue != detail.model else { return }
                                Task {
                                    await viewModel.changeModel(newValue, client: appState.apiClient)
                                }
                            }
                        }

                        if !viewModel.availablePlatforms.isEmpty {
                            Picker("Platform", selection: $selectedPlatform) {
                                ForEach(viewModel.availablePlatforms, id: \.self) { platform in
                                    Text(platform).tag(platform)
                                }
                            }
                            .onChange(of: selectedPlatform) { _, newValue in
                                guard newValue != detail.platform else { return }
                                Task {
                                    await viewModel.changePlatform(newValue, client: appState.apiClient)
                                }
                            }
                        }
                    }

                    // Messages Section
                    Section("Recent Messages") {
                        if detail.messages.isEmpty {
                            Text("No messages")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(detail.messages) { msg in
                                MessageBubbleView(message: msg)
                            }
                        }
                    }
                }
                .onAppear {
                    selectedModel = detail.model
                    selectedPlatform = detail.platform
                }
                .onChange(of: viewModel.detail?.model) { _, newModel in
                    if let m = newModel { selectedModel = m }
                }
                .onChange(of: viewModel.detail?.platform) { _, newPlatform in
                    if let p = newPlatform { selectedPlatform = p }
                }
            } else if let error = viewModel.errorMessage {
                ContentUnavailableView {
                    Label("Error", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(error)
                }
            }
        }
        .navigationTitle(viewModel.detail?.name ?? "Agent")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showSendTask = true
                } label: {
                    Image(systemName: "paperplane")
                }
            }
        }
        .sheet(isPresented: $showSendTask) {
            SendTaskView(viewModel: viewModel)
        }
        .task {
            await viewModel.load(client: appState.apiClient)
        }
    }
}
