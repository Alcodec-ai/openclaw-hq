import SwiftUI

struct LogsView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = LogsViewModel()
    @State private var autoScroll = true

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Filter bar
                HStack {
                    Picker("Level", selection: $viewModel.selectedLevel) {
                        ForEach(LogsViewModel.levels, id: \.self) { level in
                            Text(level).tag(level)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)

                // Log list
                ScrollViewReader { proxy in
                    List {
                        ForEach(viewModel.filteredLogs) { entry in
                            LogEntryRowView(entry: entry)
                                .id(entry.id)
                        }
                    }
                    .listStyle(.plain)
                    .onChange(of: viewModel.filteredLogs.count) { _, _ in
                        if autoScroll, let last = viewModel.filteredLogs.last {
                            withAnimation {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Logs")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    HStack(spacing: 12) {
                        Button {
                            autoScroll.toggle()
                        } label: {
                            Image(systemName: autoScroll ? "arrow.down.to.line.compact" : "arrow.down.to.line")
                                .foregroundStyle(autoScroll ? .blue : .secondary)
                        }

                        Button {
                            if viewModel.isLive {
                                viewModel.stopLive()
                            } else {
                                viewModel.startLive(baseURL: appState.serverURL)
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(viewModel.isLive ? .red : .secondary)
                                    .frame(width: 8, height: 8)
                                Text(viewModel.isLive ? "Live" : "Paused")
                                    .font(.caption)
                            }
                        }

                        Button {
                            viewModel.clearLogs()
                        } label: {
                            Image(systemName: "trash")
                        }
                    }
                }
            }
            .task {
                await viewModel.loadRecent(client: appState.apiClient)
            }
            .onDisappear {
                viewModel.stopLive()
            }
        }
    }
}
