import SwiftUI
import OSLog
import StoreKit

private let logger = Logger(subsystem: "com.kinex.fit", category: "SubscriptionStatusView")

struct SubscriptionStatusView: View {
    @State private var user: User?
    @State private var showPaywall = false
    @State private var isManagingSubscriptions = false
    @State private var errorMessage: String?
    @State private var showError = false

    private var currentTier: SubscriptionTier {
        user?.subscriptionTier ?? .free
    }

    var body: some View {
        VStack(spacing: 16) {
            // Tier Badge
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Current Plan")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.secondaryText)

                    HStack(spacing: 8) {
                        tierIcon
                        Text(currentTier.displayName)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(AppTheme.primaryText)
                    }
                }

                Spacer()

                if currentTier != .free {
                    tierBadge
                }
            }

            Rectangle()
                .fill(AppTheme.separator)
                .frame(height: 1)

            // Usage Quotas
            if let user {
                VStack(spacing: 12) {
                    QuotaRow(
                        title: "Scans Used",
                        used: user.scanQuotaUsed,
                        limit: user.scanQuotaLimit,
                        icon: "camera.fill",
                        color: AppTheme.statClock
                    )

                    QuotaRow(
                        title: "AI Requests Used",
                        used: user.aiQuotaUsed,
                        limit: user.aiQuotaLimit,
                        icon: "sparkles",
                        color: .purple
                    )
                }

                Rectangle()
                    .fill(AppTheme.separator)
                    .frame(height: 1)
            }

            // Renewal Info
            if let expiresAt = user?.subscriptionExpiresAt, currentTier != .free {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Renewal Date")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.secondaryText)

                        Text(expiresAt, style: .date)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(AppTheme.primaryText)
                    }

                    Spacer()

                    Button {
                        Task { await openManageSubscriptions() }
                    } label: {
                        HStack(spacing: 4) {
                            if isManagingSubscriptions {
                                ProgressView()
                                    .controlSize(.small)
                                    .tint(AppTheme.accent)
                            } else {
                                Text("Manage")
                                    .font(.subheadline)
                                    .foregroundStyle(AppTheme.accent)
                            }
                        }
                    }
                    .disabled(isManagingSubscriptions)
                }
            }

            // Upgrade / Change Plan Button
            if currentTier == .free {
                Button {
                    showPaywall = true
                } label: {
                    HStack {
                        Image(systemName: "star.fill")
                        Text("Upgrade to Premium")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(AppTheme.accent)
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
                        .background(AppTheme.accent.opacity(0.12))
                        .foregroundStyle(AppTheme.accent)
                        .fontWeight(.medium)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .padding()
        .kinexCard(cornerRadius: 16)
        .padding()
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "Something went wrong. Please try again.")
        }
        .task {
            if let environment = AppState.shared?.environment {
                user = try? await environment.userRepository.getCurrentUser()
            }
        }
    }

    // MARK: - Tier Info

    private var tierIcon: some View {
        Group {
            switch currentTier {
            case .free:
                Image(systemName: "person.circle")
                    .foregroundStyle(AppTheme.tertiaryText)
            case .core:
                Image(systemName: "star.circle.fill")
                    .foregroundStyle(AppTheme.statClock)
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

    private var tierBadge: some View {
        Text(currentTier.displayName.uppercased())
            .font(.caption)
            .fontWeight(.bold)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(tierBadgeColor.opacity(0.2))
            .foregroundStyle(tierBadgeColor)
            .clipShape(Capsule())
    }

    private var tierBadgeColor: Color {
        switch currentTier {
        case .free: return AppTheme.tertiaryText
        case .core: return AppTheme.statClock
        case .pro: return .purple
        case .elite: return .yellow
        }
    }

    // MARK: - Subscription Management

    private func openManageSubscriptions() async {
        isManagingSubscriptions = true
        defer { isManagingSubscriptions = false }

        do {
            guard let scene = activeWindowScene() else {
                errorMessage = "Could not open subscription management right now."
                showError = true
                return
            }
            try await AppStore.showManageSubscriptions(in: scene)
        } catch {
            logger.error("Manage subscriptions failed: \(error.localizedDescription, privacy: .public)")
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func activeWindowScene() -> UIWindowScene? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        ?? UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first
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
        guard limit > 0, limit != .max else { return 0 }
        return min(Double(used) / Double(limit), 1.0)
    }

    private var isNearLimit: Bool {
        guard limit != .max else { return false }
        return percentage >= 0.8
    }

    private var limitDisplay: String {
        limit == .max ? "Unlimited" : "\(limit)"
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)

                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.primaryText)

                Spacer()

                Text("\(used) / \(limitDisplay)")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(isNearLimit ? AppTheme.warning : AppTheme.primaryText)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(AppTheme.cardBackgroundElevated)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(isNearLimit ? AppTheme.warning : color)
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
}
