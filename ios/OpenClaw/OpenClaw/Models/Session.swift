import Foundation

struct Session: Codable, Identifiable {
    let agent: String
    let key: String
    let age: String
    let chatType: String
    let lastChannel: String

    var id: String { key }
}
