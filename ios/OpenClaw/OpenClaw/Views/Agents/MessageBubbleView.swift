import SwiftUI

struct MessageBubbleView: View {
    let message: AgentMessage

    private var isUser: Bool { message.role == "user" }

    var body: some View {
        HStack {
            if isUser { Spacer(minLength: 40) }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                Text(message.role.capitalized)
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Text(message.text)
                    .font(.body)
                    .padding(10)
                    .background(isUser ? Color.blue.opacity(0.15) : Color.green.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                if let ts = message.timestamp {
                    Text(ts)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            if !isUser { Spacer(minLength: 40) }
        }
        .listRowSeparator(.hidden)
    }
}
