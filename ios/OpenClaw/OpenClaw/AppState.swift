import Foundation
import SwiftUI

final class AppState: ObservableObject {
    @Published var serverURL: URL {
        didSet {
            UserDefaults.standard.set(serverURL.absoluteString, forKey: UserDefaultsKeys.serverURL)
            apiClient = APIClient(baseURL: serverURL)
        }
    }

    private(set) var apiClient: APIClient

    init() {
        let saved = UserDefaults.standard.string(forKey: UserDefaultsKeys.serverURL)
        let url = URL(string: saved ?? "") ?? URL(string: "http://localhost:7842")!
        self.serverURL = url
        self.apiClient = APIClient(baseURL: url)
    }
}
