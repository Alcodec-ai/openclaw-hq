import Foundation

actor APIClient {
    let baseURL: URL
    private let session: URLSession
    private let decoder: JSONDecoder

    init(baseURL: URL) {
        self.baseURL = baseURL
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        self.session = URLSession(configuration: config)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let str = try container.decode(String.self)

            let iso = ISO8601DateFormatter()
            iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = iso.date(from: str) { return date }

            iso.formatOptions = [.withInternetDateTime]
            if let date = iso.date(from: str) { return date }

            let fallback = DateFormatter()
            fallback.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS"
            fallback.locale = Locale(identifier: "en_US_POSIX")
            if let date = fallback.date(from: str) { return date }

            fallback.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
            if let date = fallback.date(from: str) { return date }

            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date: \(str)")
        }
        self.decoder = decoder
    }

    // MARK: - Helpers

    private func get<T: Decodable>(_ path: String) async throws -> T {
        let url = baseURL.appendingPathComponent(path)
        let (data, response) = try await session.data(from: url)
        try validateResponse(response)
        return try decoder.decode(T.self, from: data)
    }

    private func post<T: Decodable>(_ path: String, body: [String: Any]? = nil) async throws -> T {
        let url = baseURL.appendingPathComponent(path)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        let (data, response) = try await session.data(for: request)
        try validateResponse(response)
        return try decoder.decode(T.self, from: data)
    }

    private func postRaw(_ path: String, body: [String: Any]? = nil) async throws -> [String: Any] {
        let url = baseURL.appendingPathComponent(path)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        let (data, response) = try await session.data(for: request)
        try validateResponse(response)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw APIError.invalidResponse
        }
        return json
    }

    private func validateResponse(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        guard (200...299).contains(http.statusCode) else {
            throw APIError.httpError(http.statusCode)
        }
    }

    // MARK: - Status

    func fetchStatus() async throws -> GatewayStatus {
        try await get("api/status")
    }

    // MARK: - Agents

    func fetchAgents() async throws -> [Agent] {
        try await get("api/agents")
    }

    func fetchAgentDetail(id: String) async throws -> AgentDetail {
        try await get("api/agent/\(id)")
    }

    func setAgentModel(id: String, model: String) async throws {
        let _: [String: Any] = try await postRaw("api/agent/\(id)/model", body: ["model": model])
    }

    func setAgentPlatform(id: String, platform: String) async throws {
        let _: [String: Any] = try await postRaw("api/agent/\(id)/platform", body: ["platform": platform])
    }

    // MARK: - Tasks

    func sendTask(agentId: String, message: String) async throws -> String {
        let result: [String: Any] = try await postRaw("api/task", body: [
            "agent_id": agentId,
            "message": message
        ])
        return result["output"] as? String ?? ""
    }

    // MARK: - Settings

    func fetchSettings() async throws -> AppSettings {
        try await get("api/settings")
    }

    func fetchModelsInfo() async throws -> ModelsInfo {
        try await get("api/models")
    }

    func fetchModelsAvailable() async throws -> [String] {
        try await get("api/models/available")
    }

    func fetchPlatforms() async throws -> [String] {
        try await get("api/platforms")
    }

    func setDefaultModel(primary: String, fallbacks: [String]) async throws {
        let _: [String: Any] = try await postRaw("api/defaults/model", body: [
            "primary": primary,
            "fallbacks": fallbacks
        ])
    }

    func setCompaction(_ mode: String) async throws {
        let _: [String: Any] = try await postRaw("api/defaults/compaction", body: ["mode": mode])
    }

    // MARK: - Gateway Control

    func gatewayControl(_ action: String) async throws -> String {
        let result: [String: Any] = try await postRaw("api/gateway/\(action)")
        return result["output"] as? String ?? (result["ok"] as? Bool == true ? "OK" : "Failed")
    }

    // MARK: - Providers

    func fetchProviders() async throws -> [Provider] {
        let url = baseURL.appendingPathComponent("api/providers")
        let (data, response) = try await session.data(from: url)
        try validateResponse(response)
        guard let dict = try JSONSerialization.jsonObject(with: data) as? [String: [String: Any]] else {
            throw APIError.invalidResponse
        }
        return dict.map { name, info in
            Provider(
                id: name,
                apiKey: info["apiKey"] as? String ?? "",
                hasKey: info["hasKey"] as? Bool ?? false,
                baseUrl: info["baseUrl"] as? String ?? "",
                models: info["models"] as? [String] ?? []
            )
        }.sorted { $0.id < $1.id }
    }

    func addProvider(name: String, apiKey: String, baseUrl: String, models: [String]) async throws {
        let _: [String: Any] = try await postRaw("api/providers", body: [
            "name": name,
            "apiKey": apiKey,
            "baseUrl": baseUrl,
            "models": models
        ])
    }

    func updateProvider(name: String, apiKey: String, baseUrl: String, models: [String]) async throws {
        let _: [String: Any] = try await postRaw("api/providers/\(name)/update", body: [
            "apiKey": apiKey,
            "baseUrl": baseUrl,
            "models": models
        ])
    }

    func deleteProvider(name: String) async throws {
        let _: [String: Any] = try await postRaw("api/providers/\(name)/delete")
    }

    // MARK: - Channels

    func fetchChannels() async throws -> [Channel] {
        try await get("api/channels")
    }

    func toggleChannel(name: String) async throws -> Bool {
        let result: [String: Any] = try await postRaw("api/channel/\(name)/toggle")
        return result["enabled"] as? Bool ?? false
    }

    func setChannelSettings(name: String, dmPolicy: String, groupPolicy: String, streamMode: String) async throws {
        let _: [String: Any] = try await postRaw("api/channel/\(name)/settings", body: [
            "dmPolicy": dmPolicy,
            "groupPolicy": groupPolicy,
            "streamMode": streamMode
        ])
    }

    // MARK: - Logs

    func fetchLogsRecent() async throws -> [LogEntry] {
        try await get("api/logs/recent")
    }

    // MARK: - Backup

    func fetchBackupStatus() async throws -> BackupStatus {
        try await get("api/md-backup/status")
    }

    func setBackupSettings(path: String, enabled: Bool, intervalMinutes: Int) async throws {
        let _: [String: Any] = try await postRaw("api/md-backup/settings", body: [
            "path": path,
            "enabled": enabled,
            "interval_minutes": intervalMinutes
        ])
    }

    func exportBackup() async throws -> BackupExportResponse {
        try await post("api/md-backup/export")
    }

    // MARK: - Sessions

    func fetchSessions() async throws -> [Session] {
        try await get("api/sessions")
    }

    // MARK: - Test Connection

    func testConnection() async throws -> Bool {
        let _: GatewayStatus = try await get("api/status")
        return true
    }
}

enum APIError: LocalizedError {
    case invalidResponse
    case httpError(Int)

    var errorDescription: String? {
        switch self {
        case .invalidResponse: return "Invalid server response"
        case .httpError(let code): return "HTTP error \(code)"
        }
    }
}
