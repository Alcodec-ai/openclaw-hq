import Foundation

@MainActor
final class LogsViewModel: ObservableObject {
    @Published var logs: [LogEntry] = []
    @Published var isLive = false
    @Published var selectedLevel: String = "ALL"
    @Published var isLoading = false
    @Published var errorMessage: String?

    private var sseClient: SSEClient?
    private var streamTask: Task<Void, Never>?
    private let maxEntries = 500

    static let levels = ["ALL", "DEBUG", "INFO", "WARNING", "ERROR"]

    var filteredLogs: [LogEntry] {
        if selectedLevel == "ALL" { return logs }
        return logs.filter { $0.level.uppercased() == selectedLevel }
    }

    func loadRecent(client: APIClient) async {
        isLoading = true
        errorMessage = nil
        do {
            logs = try await client.fetchLogsRecent()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func startLive(baseURL: URL) {
        guard !isLive else { return }
        isLive = true
        sseClient = SSEClient(baseURL: baseURL)
        streamTask = Task {
            guard let client = sseClient else { return }
            for await entry in client.stream() {
                if Task.isCancelled { break }
                logs.append(entry)
                if logs.count > maxEntries {
                    logs.removeFirst(logs.count - maxEntries)
                }
            }
        }
    }

    func stopLive() {
        isLive = false
        sseClient?.stop()
        sseClient = nil
        streamTask?.cancel()
        streamTask = nil
    }

    func clearLogs() {
        logs.removeAll()
    }
}
