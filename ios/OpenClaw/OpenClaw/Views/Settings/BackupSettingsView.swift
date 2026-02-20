import SwiftUI

struct BackupSettingsView: View {
    @EnvironmentObject private var appState: AppState
    @ObservedObject var viewModel: SettingsViewModel
    @State private var path = ""
    @State private var enabled = false
    @State private var intervalMinutes = 60
    @State private var exportResult: String?

    private let intervals = [15, 30, 60, 120, 360, 720, 1440]

    var body: some View {
        Form {
            Section("Configuration") {
                TextField("Backup Path", text: $path)
                    .textInputAutocapitalization(.never)

                Toggle("Enabled", isOn: $enabled)

                Picker("Interval", selection: $intervalMinutes) {
                    ForEach(intervals, id: \.self) { mins in
                        Text(intervalLabel(mins)).tag(mins)
                    }
                }
            }

            Section {
                Button("Save Settings") {
                    Task {
                        await viewModel.setBackupSettings(
                            path: path,
                            enabled: enabled,
                            intervalMinutes: intervalMinutes,
                            client: appState.apiClient
                        )
                    }
                }
            }

            if let backup = viewModel.backupStatus {
                Section("Last Backup") {
                    if let lastBackup = backup.lastBackup {
                        LabeledContent("Time", value: lastBackup)
                    }
                    if let result = backup.lastResult {
                        LabeledContent("Files Copied", value: "\(result.filesCopied)")
                        LabeledContent("Agents", value: result.agents.joined(separator: ", "))
                    }
                }
            }

            Section("Export") {
                Button {
                    Task {
                        if let result = await viewModel.exportBackup(client: appState.apiClient) {
                            exportResult = "Exported \(result.filesCopied) files from \(result.agents.count) agents"
                        }
                    }
                } label: {
                    Label("Export Now", systemImage: "square.and.arrow.up")
                }

                if let result = exportResult {
                    Text(result)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("MD Backup")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if let backup = viewModel.backupStatus {
                path = backup.path
                enabled = backup.enabled
                intervalMinutes = backup.intervalMinutes
            }
        }
    }

    private func intervalLabel(_ mins: Int) -> String {
        if mins < 60 { return "\(mins) min" }
        let hours = mins / 60
        return hours == 1 ? "1 hour" : "\(hours) hours"
    }
}
