import SwiftUI

struct AgentListView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = AgentListViewModel()

    var body: some View {
        NavigationStack {
            List {
                if let status = viewModel.gatewayStatus {
                    Section {
                        HStack {
                            Circle()
                                .fill(status.active ? .green : .red)
                                .frame(width: 10, height: 10)
                            Text("Gateway")
                                .font(.headline)
                            Spacer()
                            Text(status.active ? "Online" : "Offline")
                                .foregroundStyle(status.active ? .green : .red)
                                .font(.subheadline)
                        }
                        if status.active {
                            if let uptime = status.uptime {
                                LabeledContent("Uptime", value: uptime)
                            }
                            if let memory = status.memory {
                                LabeledContent("Memory", value: memory)
                            }
                            if let version = status.version {
                                LabeledContent("Version", value: version)
                            }
                        }
                    }
                }

                Section("Agents") {
                    if viewModel.isLoading && viewModel.agents.isEmpty {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else if viewModel.agents.isEmpty {
                        Text("No agents found")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(viewModel.agents) { agent in
                            NavigationLink(value: agent.id) {
                                AgentRowView(agent: agent)
                            }
                        }
                    }
                }
            }
            .navigationTitle("OpenClaw")
            .navigationDestination(for: String.self) { agentId in
                AgentDetailView(agentId: agentId)
            }
            .refreshable {
                await viewModel.refresh(client: appState.apiClient)
            }
            .overlay {
                if let error = viewModel.errorMessage, viewModel.agents.isEmpty {
                    ContentUnavailableView {
                        Label("Connection Error", systemImage: "wifi.slash")
                    } description: {
                        Text(error)
                    } actions: {
                        Button("Retry") {
                            Task { await viewModel.refresh(client: appState.apiClient) }
                        }
                    }
                }
            }
            .onAppear {
                viewModel.startPolling(client: appState.apiClient)
            }
            .onDisappear {
                viewModel.stopPolling()
            }
        }
    }
}
