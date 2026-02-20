import Foundation

enum AgentStatus: String, CaseIterable {
    case busy
    case idle
    case inactive
    case offline

    var color: String {
        switch self {
        case .busy: return "green"
        case .idle: return "yellow"
        case .inactive: return "gray"
        case .offline: return "red"
        }
    }

    var label: String { rawValue.capitalized }
}

struct Agent: Codable, Identifiable {
    let id: String
    let name: String
    let model: String
    let platform: String
    let lastActivity: Date?
    let activeSessions: Int
    let currentTask: String?

    var status: AgentStatus {
        AgentStatusCalculator.calculate(lastActivity: lastActivity)
    }
}
