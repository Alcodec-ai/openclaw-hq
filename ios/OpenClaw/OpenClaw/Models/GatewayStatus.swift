import Foundation

struct GatewayStatus: Codable {
    let active: Bool
    let pid: String?
    let memory: String?
    let uptime: String?
    let version: String?
}
