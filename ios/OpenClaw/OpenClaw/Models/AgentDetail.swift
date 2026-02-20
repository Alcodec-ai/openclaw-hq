import Foundation

struct AgentDetail: Codable, Identifiable {
    let id: String
    let name: String
    let model: String
    let platform: String
    let sessionCount: Int
    let messages: [AgentMessage]
    let tokens: TokenUsage
}

struct AgentMessage: Codable, Identifiable {
    let id: String
    let role: String
    let text: String
    let timestamp: String?

    enum CodingKeys: String, CodingKey {
        case role, text, timestamp
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.role = try container.decode(String.self, forKey: .role)
        self.text = try container.decode(String.self, forKey: .text)
        self.timestamp = try container.decodeIfPresent(String.self, forKey: .timestamp)
        self.id = "\(role)-\(timestamp ?? "none")-\(text.prefix(20))"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(role, forKey: .role)
        try container.encode(text, forKey: .text)
        try container.encode(timestamp, forKey: .timestamp)
    }
}

struct TokenUsage: Codable {
    let input: Int
    let output: Int
    let total: Int
    let context: Int

    var usageRatio: Double {
        guard context > 0 else { return 0 }
        return Double(total) / Double(context)
    }
}
