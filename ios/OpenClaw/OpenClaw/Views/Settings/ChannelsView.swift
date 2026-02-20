import SwiftUI

struct ChannelsView: View {
    @EnvironmentObject private var appState: AppState
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        List {
            ForEach(viewModel.channels) { channel in
                NavigationLink {
                    ChannelDetailView(channel: channel, viewModel: viewModel)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(channel.name)
                                .font(.headline)
                            Text(channel.botName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        HStack(spacing: 8) {
                            if channel.running {
                                Text("Running")
                                    .font(.caption)
                                    .foregroundStyle(.green)
                            }

                            Toggle("", isOn: Binding(
                                get: { channel.enabled },
                                set: { _ in
                                    Task {
                                        await viewModel.toggleChannel(name: channel.name, client: appState.apiClient)
                                    }
                                }
                            ))
                            .labelsHidden()
                        }
                    }
                }
            }
        }
        .navigationTitle("Channels")
        .navigationBarTitleDisplayMode(.inline)
    }
}
