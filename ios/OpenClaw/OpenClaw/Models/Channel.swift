import Foundation

struct Channel: Codable, Identifiable {
    let name: String
    let accountId: String
    let botName: String
    let enabled: Bool
    let running: Bool
    let lastIn: String?
    let lastOut: String?
    let details: String?

    var id: String { name }
}
