import Foundation

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var settings: AppSettings?
    @Published var modelsInfo: ModelsInfo?
    @Published var availableModels: [String] = []
    @Published var providers: [Provider] = []
    @Published var channels: [Channel] = []
    @Published var backupStatus: BackupStatus?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var gatewayOutput: String?

    func loadAll(client: APIClient) async {
        isLoading = true
        errorMessage = nil
        do {
            async let s = client.fetchSettings()
            async let m = client.fetchModelsInfo()
            async let am = client.fetchModelsAvailable()
            async let p = client.fetchProviders()
            async let c = client.fetchChannels()
            async let b = client.fetchBackupStatus()

            let (settings, models, available, providers, channels, backup) = try await (s, m, am, p, c, b)
            self.settings = settings
            self.modelsInfo = models
            self.availableModels = available
            self.providers = providers
            self.channels = channels
            self.backupStatus = backup
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    // MARK: - Gateway

    func gatewayAction(_ action: String, client: APIClient) async {
        gatewayOutput = nil
        do {
            let output = try await client.gatewayControl(action)
            gatewayOutput = output
            self.settings = try await client.fetchSettings()
        } catch {
            gatewayOutput = "Error: \(error.localizedDescription)"
        }
    }

    // MARK: - Default Model

    func setDefaultModel(primary: String, fallbacks: [String], client: APIClient) async {
        do {
            try await client.setDefaultModel(primary: primary, fallbacks: fallbacks)
            modelsInfo = try await client.fetchModelsInfo()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func setCompaction(_ mode: String, client: APIClient) async {
        do {
            try await client.setCompaction(mode)
            settings = try await client.fetchSettings()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Providers

    func addProvider(name: String, apiKey: String, baseUrl: String, models: [String], client: APIClient) async {
        do {
            try await client.addProvider(name: name, apiKey: apiKey, baseUrl: baseUrl, models: models)
            providers = try await client.fetchProviders()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updateProvider(name: String, apiKey: String, baseUrl: String, models: [String], client: APIClient) async {
        do {
            try await client.updateProvider(name: name, apiKey: apiKey, baseUrl: baseUrl, models: models)
            providers = try await client.fetchProviders()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteProvider(name: String, client: APIClient) async {
        do {
            try await client.deleteProvider(name: name)
            providers = try await client.fetchProviders()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Channels

    func toggleChannel(name: String, client: APIClient) async {
        do {
            _ = try await client.toggleChannel(name: name)
            channels = try await client.fetchChannels()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func setChannelSettings(name: String, dmPolicy: String, groupPolicy: String, streamMode: String, client: APIClient) async {
        do {
            try await client.setChannelSettings(name: name, dmPolicy: dmPolicy, groupPolicy: groupPolicy, streamMode: streamMode)
            channels = try await client.fetchChannels()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Backup

    func setBackupSettings(path: String, enabled: Bool, intervalMinutes: Int, client: APIClient) async {
        do {
            try await client.setBackupSettings(path: path, enabled: enabled, intervalMinutes: intervalMinutes)
            backupStatus = try await client.fetchBackupStatus()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func exportBackup(client: APIClient) async -> BackupExportResponse? {
        do {
            let result = try await client.exportBackup()
            backupStatus = try await client.fetchBackupStatus()
            return result
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }
}
