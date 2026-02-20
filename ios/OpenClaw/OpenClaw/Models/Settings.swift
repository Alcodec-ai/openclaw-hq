import Foundation

struct AppSettings: Codable {
    let defaults: DefaultSettings
    let channels: [String: ChannelSettings]
    let gateway: GatewayConfig
}

struct DefaultSettings: Codable {
    let primary: String
    let fallbacks: [String]
    let compaction: String
    let workspace: String?
}

struct GatewayConfig: Codable {
    let port: Int?
    let mode: String
    let bind: String
}

struct ChannelSettings: Codable {
    let enabled: Bool
    let dmPolicy: String
    let groupPolicy: String
    let streamMode: String
    let botName: String
}

struct ModelsInfo: Codable {
    let primary: String
    let fallbacks: [String]
    let providers: [String]
}
