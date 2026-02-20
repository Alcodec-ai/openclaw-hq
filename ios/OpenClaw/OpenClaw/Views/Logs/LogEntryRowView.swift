import SwiftUI

struct LogEntryRowView: View {
    let entry: LogEntry

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // Time
            Text(timeOnly)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 65, alignment: .leading)

            // Level badge
            Text(entry.level.uppercased())
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(levelColor.opacity(0.2))
                .foregroundStyle(levelColor)
                .clipShape(RoundedRectangle(cornerRadius: 3))
                .frame(width: 55)

            // Message
            VStack(alignment: .leading, spacing: 2) {
                if !entry.subsystem.isEmpty {
                    Text(entry.subsystem)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                Text(entry.message)
                    .font(.system(.caption, design: .monospaced))
                    .lineLimit(4)
            }
        }
        .padding(.vertical, 2)
    }

    private var timeOnly: String {
        // Extract time portion from timestamp
        if let range = entry.time.range(of: #"\d{2}:\d{2}:\d{2}"#, options: .regularExpression) {
            return String(entry.time[range])
        }
        return entry.time.suffix(8).description
    }

    private var levelColor: Color {
        switch entry.level.uppercased() {
        case "ERROR", "CRITICAL": return .red
        case "WARNING", "WARN": return .orange
        case "INFO": return .blue
        case "DEBUG": return .gray
        default: return .primary
        }
    }
}
