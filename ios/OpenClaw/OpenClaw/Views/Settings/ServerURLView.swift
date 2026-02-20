import SwiftUI

struct ServerURLView: View {
    @EnvironmentObject private var appState: AppState
    @State private var urlString = ""
    @State private var testResult: TestResult?
    @State private var isTesting = false

    enum TestResult {
        case success
        case failure(String)
    }

    var body: some View {
        Form {
            Section("Server URL") {
                TextField("http://192.168.1.x:7842", text: $urlString)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                Button("Save") {
                    if let url = URL(string: urlString) {
                        appState.serverURL = url
                    }
                }
                .disabled(URL(string: urlString) == nil)
            }

            Section("Test Connection") {
                Button {
                    testConnection()
                } label: {
                    if isTesting {
                        HStack {
                            ProgressView()
                                .controlSize(.small)
                            Text("Testing...")
                        }
                    } else {
                        Label("Test Connection", systemImage: "antenna.radiowaves.left.and.right")
                    }
                }
                .disabled(isTesting)

                if let result = testResult {
                    switch result {
                    case .success:
                        Label("Online", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    case .failure(let msg):
                        Label(msg, systemImage: "xmark.circle.fill")
                            .foregroundStyle(.red)
                    }
                }
            }

            Section("Current") {
                Text(appState.serverURL.absoluteString)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Server URL")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            urlString = appState.serverURL.absoluteString
        }
    }

    private func testConnection() {
        isTesting = true
        testResult = nil
        Task {
            do {
                let testURL = URL(string: urlString) ?? appState.serverURL
                let client = APIClient(baseURL: testURL)
                _ = try await client.testConnection()
                testResult = .success
            } catch {
                testResult = .failure(error.localizedDescription)
            }
            isTesting = false
        }
    }
}
