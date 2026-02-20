import SwiftUI

struct AgentRowView: View {
    let agent: Agent

    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            ZStack {
                Circle()
                    .fill(avatarColor)
                    .frame(width: 40, height: 40)
                Text(initials)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
            }

            // Info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(agent.name)
                        .font(.headline)
                    Circle()
                        .fill(statusColor)
                        .frame(width: 8, height: 8)
                }

                HStack(spacing: 8) {
                    Label(agent.platform, systemImage: platformIcon)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())

                    Text(agent.model)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Session count
            if agent.activeSessions > 0 {
                Text("\(agent.activeSessions)")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.blue.opacity(0.15))
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, 4)
    }

    private var initials: String {
        let parts = agent.name.split(separator: " ")
        if parts.count >= 2 {
            return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
        }
        return String(agent.name.prefix(2)).uppercased()
    }

    private var avatarColor: Color {
        let colors: [Color] = [.blue, .purple, .orange, .teal, .pink, .indigo]
        let hash = abs(agent.name.hashValue)
        return colors[hash % colors.count]
    }

    private var statusColor: Color {
        switch agent.status {
        case .busy: return .green
        case .idle: return .yellow
        case .inactive: return .gray
        case .offline: return .red
        }
    }

    private var platformIcon: String {
        switch agent.platform.lowercased() {
        case "telegram": return "paperplane"
        case "discord": return "gamecontroller"
        case "whatsapp": return "phone"
        default: return "globe"
        }
    }
}
