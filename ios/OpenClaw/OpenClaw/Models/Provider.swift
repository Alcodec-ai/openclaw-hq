import Foundation

struct Provider: Codable, Identifiable {
    let id: String
    let apiKey: String
    let hasKey: Bool
    let baseUrl: String
    let models: [String]

    init(id: String, apiKey: String, hasKey: Bool, baseUrl: String, models: [String]) {
        self.id = id
        self.apiKey = apiKey
        self.hasKey = hasKey
        self.baseUrl = baseUrl
        self.models = models
    }
}
