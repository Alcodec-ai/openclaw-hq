import Foundation

@MainActor
final class AgentListViewModel: ObservableObject {
    @Published var agents: [Agent] = []
    @Published var gatewayStatus: GatewayStatus?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private var pollingTask: Task<Void, Never>?

    func startPolling(client: APIClient) {
        pollingTask?.cancel()
        pollingTask = Task {
            while !Task.isCancelled {
                await refresh(client: client)
                try? await Task.sleep(nanoseconds: 10_000_000_000)
            }
        }
    }

    func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    func refresh(client: APIClient) async {
        if agents.isEmpty { isLoading = true }
        errorMessage = nil
        do {
            async let agentsResult = client.fetchAgents()
            async let statusResult = client.fetchStatus()
            let (a, s) = try await (agentsResult, statusResult)
            agents = a
            gatewayStatus = s
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
