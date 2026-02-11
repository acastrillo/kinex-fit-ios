import SwiftUI

struct SubscriptionStatusView: View {
    @EnvironmentObject private var storeManager: StoreManager
    @State private var user: User?
    @State private var showPaywall = false

    var body: some View {
        VStack(spacing: 16) {
            // Tier Badge
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Current Plan")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 8) {
                        tierIcon
                        Text(tierDisplayName)
                            .font(.title2)
                            .fontWeight(.bold)
                    }
                }

                Spacer()

                if storeManager.subscriptionTier != .free {
                    tierBadge
                }
            }

            Divider()

            // Usage Quotas
            if let user = user {
                VStack(spacing: 12) {
                    QuotaRow(
                        title: "Scans Used",
                        used: user.scanQuotaUsed,
                        limit: user.scanQuotaLimit,
                        icon: "camera.fill",
                        color: .blue
                    )

                    QuotaRow(
                        title: "AI Requests Used",
                        used: user.aiQuotaUsed,
                        limit: user.aiQuotaLimit,
                        icon: "sparkles",
                        color: .purple
                    )
                }

                Divider()
            }

            // Renewal Info
            if let expiresAt = user?.subscriptionExpiresAt,
               storeManager.subscriptionTier != .free {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Renewal Date")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Text(expiresAt, style: .date)
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }

                    Spacer()

                    Button {
                        openAppStoreSubscriptions()
                    } label: {
                        Text("Manage")
                            .font(.subheadline)
                            .foregroundStyle(.blue)
                    }
                }
            }

            // Upgrade Button
            if storeManager.subscriptionTier == .free {
                Button {
                    showPaywall = true
                } label: {
                    HStack {
                        Image(systemName: "star.fill")
                        Text("Upgrade to Premium")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .foregroundStyle(.white)
                    .fontWeight(.semibold)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            } else {
                Button {
                    showPaywall = true
                } label: {
                    Text("Change Plan")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .foregroundStyle(.blue)
                        .fontWeight(.medium)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
        )
        .padding()
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
        .task {
            // Load user data
            if let environment = AppState.shared?.environment {
                user = try? await environment.userRepository.getCurrentUser()
            }
        }
    }

    // MARK: - Tier Info

    private var tierIcon: some View {
        Group {
            switch storeManager.subscriptionTier {
            case .free:
                Image(systemName: "person.circle")
                    .foregroundStyle(.gray)
            case .core:
                Image(systemName: "star.circle.fill")
                    .foregroundStyle(.blue)
            case .pro:
                Image(systemName: "star.circle.fill")
                    .foregroundStyle(.purple)
            case .elite:
                Image(systemName: "crown.fill")
                    .foregroundStyle(.yellow)
            }
        }
        .font(.title)
    }

    private var tierDisplayName: String {
        switch storeManager.subscriptionTier {
        case .free: return "Free"
        case .core: return "Core"
        case .pro: return "Pro"
        case .elite: return "Elite"
        }
    }

    private var tierBadge: some View {
        Text(tierDisplayName.uppercased())
            .font(.caption)
            .fontWeight(.bold)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(tierBadgeColor)
            .foregroundStyle(.white)
            .clipShape(Capsule())
    }

    private var tierBadgeColor: Color {
        switch storeManager.subscriptionTier {
        case .free: return .gray
        case .core: return .blue
        case .pro: return .purple
        case .elite: return .yellow
        }
    }

    // MARK: - Actions

    private func openAppStoreSubscriptions() {
        if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Quota Row

struct QuotaRow: View {
    let title: String
    let used: Int
    let limit: Int
    let icon: String
    let color: Color

    private var percentage: Double {
        guard limit > 0 else { return 0 }
        return Double(used) / Double(limit)
    }

    private var isNearLimit: Bool {
        percentage >= 0.8
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)

                Text(title)
                    .font(.subheadline)

                Spacer()

                Text("\(used) / \(limit)")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(isNearLimit ? .orange : .primary)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemGray5))

                    // Progress
                    RoundedRectangle(cornerRadius: 4)
                        .fill(isNearLimit ? Color.orange : color)
                        .frame(width: geometry.size.width * percentage)
                }
            }
            .frame(height: 8)
        }
    }
}

// MARK: - Preview

#Preview {
    SubscriptionStatusView()
        .environmentObject(StoreManager.preview)
}
