import Foundation

@MainActor
final class AgentDetailViewModel: ObservableObject {
    @Published var detail: AgentDetail?
    @Published var availableModels: [String] = []
    @Published var availablePlatforms: [String] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var taskOutput: String?
    @Published var isSending = false

    let agentId: String

    init(agentId: String) {
        self.agentId = agentId
    }

    func load(client: APIClient) async {
        isLoading = true
        errorMessage = nil
        do {
            async let detailResult = client.fetchAgentDetail(id: agentId)
            async let modelsResult = client.fetchModelsAvailable()
            async let platformsResult = client.fetchPlatforms()
            let (d, m, p) = try await (detailResult, modelsResult, platformsResult)
            detail = d
            availableModels = m
            availablePlatforms = p
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func changeModel(_ model: String, client: APIClient) async {
        do {
            try await client.setAgentModel(id: agentId, model: model)
            detail = try await client.fetchAgentDetail(id: agentId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func changePlatform(_ platform: String, client: APIClient) async {
        do {
            try await client.setAgentPlatform(id: agentId, platform: platform)
            detail = try await client.fetchAgentDetail(id: agentId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func sendTask(message: String, client: APIClient) async {
        isSending = true
        taskOutput = nil
        do {
            let output = try await client.sendTask(agentId: agentId, message: message)
            taskOutput = output
        } catch {
            taskOutput = "Error: \(error.localizedDescription)"
        }
        isSending = false
    }
}
