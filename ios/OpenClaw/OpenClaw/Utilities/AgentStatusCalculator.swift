import Foundation

enum AgentStatusCalculator {
    static func calculate(lastActivity: Date?) -> AgentStatus {
        guard let lastActivity else { return .offline }
        let elapsed = Date().timeIntervalSince(lastActivity)
        if elapsed < 120 { return .busy }        // < 2 min
        if elapsed < 1800 { return .idle }        // < 30 min
        if elapsed < 86400 { return .inactive }   // < 24 hours
        return .offline
    }
}
