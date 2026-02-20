import SwiftUI

struct ChannelDetailView: View {
    @EnvironmentObject private var appState: AppState
    let channel: Channel
    @ObservedObject var viewModel: SettingsViewModel
    @State private var dmPolicy = ""
    @State private var groupPolicy = ""
    @State private var streamMode = ""

    private let policies = ["allow", "deny", "ignore"]
    private let streamModes = ["full", "partial", "off"]

    var body: some View {
        Form {
            Section("Info") {
                LabeledContent("Name", value: channel.name)
                LabeledContent("Account ID", value: channel.accountId)
                LabeledContent("Bot", value: channel.botName)
                LabeledContent("Running", value: channel.running ? "Yes" : "No")
                if let lastIn = channel.lastIn {
                    LabeledContent("Last In", value: lastIn)
                }
                if let lastOut = channel.lastOut {
                    LabeledContent("Last Out", value: lastOut)
                }
            }

            Section("Policies") {
                Picker("DM Policy", selection: $dmPolicy) {
                    ForEach(policies, id: \.self) { Text($0).tag($0) }
                }

                Picker("Group Policy", selection: $groupPolicy) {
                    ForEach(policies, id: \.self) { Text($0).tag($0) }
                }

                Picker("Stream Mode", selection: $streamMode) {
                    ForEach(streamModes, id: \.self) { Text($0).tag($0) }
                }
            }

            Section {
                Button("Save") {
                    Task {
                        await viewModel.setChannelSettings(
                            name: channel.name,
                            dmPolicy: dmPolicy,
                            groupPolicy: groupPolicy,
                            streamMode: streamMode,
                            client: appState.apiClient
                        )
                    }
                }
            }
        }
        .navigationTitle(channel.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if let settings = viewModel.settings?.channels[channel.name] {
                dmPolicy = settings.dmPolicy
                groupPolicy = settings.groupPolicy
                streamMode = settings.streamMode
            }
        }
    }
}
