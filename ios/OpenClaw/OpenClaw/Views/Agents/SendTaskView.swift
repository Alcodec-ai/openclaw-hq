import SwiftUI

struct SendTaskView: View {
    @EnvironmentObject private var appState: AppState
    @ObservedObject var viewModel: AgentDetailViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var message = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Message") {
                    TextEditor(text: $message)
                        .frame(minHeight: 100)
                }

                Section {
                    Button {
                        Task {
                            await viewModel.sendTask(message: message, client: appState.apiClient)
                        }
                    } label: {
                        if viewModel.isSending {
                            HStack {
                                ProgressView()
                                    .controlSize(.small)
                                Text("Sending...")
                            }
                        } else {
                            Label("Send Task", systemImage: "paperplane.fill")
                        }
                    }
                    .disabled(message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isSending)
                }

                if let output = viewModel.taskOutput {
                    Section("Output") {
                        Text(output)
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                    }
                }
            }
            .navigationTitle("Send Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}
