import Foundation

struct BackupStatus: Codable {
    let path: String
    let enabled: Bool
    let intervalMinutes: Int
    let lastBackup: String?
    let lastResult: BackupResult?

    enum CodingKeys: String, CodingKey {
        case path, enabled
        case intervalMinutes = "interval_minutes"
        case lastBackup = "last_backup"
        case lastResult = "last_result"
    }
}

struct BackupResult: Codable {
    let filesCopied: Int
    let agents: [String]
    let ok: Bool

    enum CodingKeys: String, CodingKey {
        case filesCopied = "files_copied"
        case agents, ok
    }
}

struct BackupExportResponse: Codable {
    let ok: Bool
    let filesCopied: Int
    let agents: [String]
    let errors: [String]
    let timestamp: String

    enum CodingKeys: String, CodingKey {
        case ok
        case filesCopied = "files_copied"
        case agents, errors, timestamp
    }
}
