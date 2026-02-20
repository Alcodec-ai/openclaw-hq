import SwiftUI

struct TokenUsageView: View {
    let tokens: TokenUsage

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Context Usage")
                    .font(.subheadline)
                Spacer()
                Text("\(Int(tokens.usageRatio * 100))%")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(ratioColor)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.quaternary)
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(ratioColor)
                        .frame(width: geo.size.width * min(tokens.usageRatio, 1.0), height: 8)
                }
            }
            .frame(height: 8)
        }
        .padding(.vertical, 4)
    }

    private var ratioColor: Color {
        let r = tokens.usageRatio
        if r < 0.5 { return .green }
        if r < 0.75 { return .yellow }
        if r < 0.9 { return .orange }
        return .red
    }
}
