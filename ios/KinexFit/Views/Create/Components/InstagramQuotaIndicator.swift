import SwiftUI

/// Displays Instagram scan quota usage with visual indicators
struct InstagramQuotaIndicator: View {
    let used: Int
    let limit: Int
    let onUpgrade: (() -> Void)?

    init(used: Int, limit: Int, onUpgrade: (() -> Void)? = nil) {
        self.used = used
        self.limit = limit
        self.onUpgrade = onUpgrade
    }

    private var quotaColor: Color {
        let percentage = Double(used) / Double(limit)
        if percentage >= 1.0 {
            return .red
        } else if percentage >= 0.8 {
            return .orange
        } else {
            return .green
        }
    }

    private var quotaIcon: String {
        let percentage = Double(used) / Double(limit)
        if percentage >= 1.0 {
            return "exclamationmark.triangle.fill"
        } else if percentage >= 0.8 {
            return "exclamationmark.circle.fill"
        } else {
            return "checkmark.circle.fill"
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: quotaIcon)
                .foregroundStyle(quotaColor)
                .font(.caption)

            Text("\(used)/\(limit) scans used this month")
                .font(.caption)
                .foregroundStyle(.secondary)

            if used >= limit, let onUpgrade = onUpgrade {
                Button("Upgrade") {
                    onUpgrade()
                }
                .font(.caption)
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(quotaColor.opacity(0.1))
        .cornerRadius(8)
    }
}

#Preview("Low Usage") {
    InstagramQuotaIndicator(used: 2, limit: 10)
        .padding()
        .preferredColorScheme(.dark)
}

#Preview("High Usage") {
    InstagramQuotaIndicator(used: 9, limit: 10)
        .padding()
        .preferredColorScheme(.dark)
}

#Preview("Quota Exceeded") {
    InstagramQuotaIndicator(used: 10, limit: 10) {
        print("Upgrade tapped")
    }
    .padding()
    .preferredColorScheme(.dark)
}
