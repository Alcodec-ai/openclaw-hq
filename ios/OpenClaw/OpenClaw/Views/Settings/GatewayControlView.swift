import SwiftUI

struct GatewayControlView: View {
    @EnvironmentObject private var appState: AppState
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        Form {
            Section("Status") {
                if let gw = viewModel.settings?.gateway {
                    LabeledContent("Mode", value: gw.mode)
                    LabeledContent("Bind", value: gw.bind)
                    if let port = gw.port {
                        LabeledContent("Port", value: "\(port)")
                    }
                }
            }

            Section("Actions") {
                Button {
                    Task { await viewModel.gatewayAction("start", client: appState.apiClient) }
                } label: {
                    Label("Start", systemImage: "play.fill")
                }
                .tint(.green)

                Button {
                    Task { await viewModel.gatewayAction("stop", client: appState.apiClient) }
                } label: {
                    Label("Stop", systemImage: "stop.fill")
                }
                .tint(.red)

                Button {
                    Task { await viewModel.gatewayAction("restart", client: appState.apiClient) }
                } label: {
                    Label("Restart", systemImage: "arrow.clockwise")
                }
                .tint(.orange)
            }

            if let output = viewModel.gatewayOutput {
                Section("Output") {
                    Text(output)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                }
            }
        }
        .navigationTitle("Gateway Control")
        .navigationBarTitleDisplayMode(.inline)
    }
}
