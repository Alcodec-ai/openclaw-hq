import Foundation

struct LogEntry: Codable, Identifiable {
    let id: UUID
    let time: String
    let level: String
    let subsystem: String
    let message: String

    init(time: String, level: String, subsystem: String, message: String) {
        self.id = UUID()
        self.time = time
        self.level = level
        self.subsystem = subsystem
        self.message = message
    }

    enum CodingKeys: String, CodingKey {
        case time, level, subsystem, message
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = UUID()
        self.time = try container.decode(String.self, forKey: .time)
        self.level = try container.decode(String.self, forKey: .level)
        self.subsystem = try container.decodeIfPresent(String.self, forKey: .subsystem) ?? ""
        self.message = try container.decode(String.self, forKey: .message)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(time, forKey: .time)
        try container.encode(level, forKey: .level)
        try container.encode(subsystem, forKey: .subsystem)
        try container.encode(message, forKey: .message)
    }

    var levelColor: String {
        switch level.uppercased() {
        case "ERROR", "CRITICAL": return "red"
        case "WARNING", "WARN": return "orange"
        case "INFO": return "blue"
        case "DEBUG": return "gray"
        default: return "primary"
        }
    }
}
