import SwiftUI

/// Shows AI quota usage with progress bar
struct AIQuotaIndicator: View {
    let quota: AIQuota

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundStyle(.purple)

                Text("AI Requests")
                    .font(.subheadline)
                    .fontWeight(.medium)

                Spacer()

                Text(quota.displayText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if quota.limit > 0 {
                ProgressView(value: quota.usagePercentage)
                    .tint(progressColor)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    private var progressColor: Color {
        if quota.usagePercentage >= 0.9 {
            return .red
        } else if quota.usagePercentage >= 0.7 {
            return .orange
        }
        return .purple
    }
}

/// Compact inline version
struct AIQuotaBadge: View {
    let quota: AIQuota

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "sparkles")
                .font(.caption2)

            if quota.limit == 0 {
                Text("—")
            } else {
                Text("\(quota.remaining)")
            }
        }
        .font(.caption)
        .fontWeight(.medium)
        .foregroundStyle(quota.isExhausted ? .red : .purple)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(quota.isExhausted ? Color.red.opacity(0.1) : Color.purple.opacity(0.1))
        .cornerRadius(8)
    }
}

/// Upgrade prompt shown when quota is exhausted
struct AIUpgradePrompt: View {
    let currentTier: String
    var onUpgrade: (() -> Void)?

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.largeTitle)
                .foregroundStyle(.purple.opacity(0.5))

            Text("AI Quota Exhausted")
                .font(.headline)

            Text("Upgrade your plan for more AI-powered enhancements")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if let onUpgrade = onUpgrade {
                Button("Upgrade Plan") {
                    onUpgrade()
                }
                .buttonStyle(.borderedProminent)
                .tint(.purple)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
    }
}

// MARK: - Preview

#Preview("Quota Indicator") {
    VStack(spacing: 20) {
        AIQuotaIndicator(quota: AIQuota(
            used: 3,
            limit: 10,
            remaining: 7,
            isExhausted: false,
            tier: "core",
            resetsAt: nil
        ))

        AIQuotaIndicator(quota: AIQuota(
            used: 28,
            limit: 30,
            remaining: 2,
            isExhausted: false,
            tier: "pro",
            resetsAt: nil
        ))

        AIQuotaIndicator(quota: AIQuota(
            used: 50,
            limit: 100,
            remaining: 50,
            isExhausted: false,
            tier: "elite",
            resetsAt: nil
        ))
    }
    .padding()
}

#Preview("Badges") {
    HStack(spacing: 12) {
        AIQuotaBadge(quota: AIQuota(
            used: 3,
            limit: 10,
            remaining: 7,
            isExhausted: false,
            tier: "core",
            resetsAt: nil
        ))

        AIQuotaBadge(quota: AIQuota(
            used: 10,
            limit: 10,
            remaining: 0,
            isExhausted: true,
            tier: "core",
            resetsAt: nil
        ))
    }
}

#Preview("Upgrade Prompt") {
    AIUpgradePrompt(currentTier: "free") {
        print("Upgrade tapped")
    }
    .padding()
}
