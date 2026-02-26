import SwiftUI
import OSLog

private let logger = Logger(subsystem: "com.kinex.fit", category: "PaywallView")

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var user: User?
    @State private var loadingTier: SubscriptionTier?
    @State private var isLoadingPortal = false
    @State private var errorMessage: String?
    @State private var showError = false

    private var currentTier: SubscriptionTier {
        user?.subscriptionTier ?? .free
    }

    private var hasPaidPlan: Bool {
        currentTier != .free
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    if hasPaidPlan {
                        currentSubscriptionBanner
                    }

                    headerSection

                    ForEach(TierDefinition.all) { tier in
                        tierCard(tier)
                    }

                    restoreAndLegalFooter
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 24)
            }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("Subscription")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppTheme.background, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(AppTheme.accent)
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "Something went wrong. Please try again.")
            }
        }
        .preferredColorScheme(.dark)
        .task {
            await loadUser()
        }
    }

    // MARK: - Current Subscription Banner

    private var currentSubscriptionBanner: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Current Plan")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppTheme.secondaryText)

                HStack(spacing: 8) {
                    Text(currentTier.displayName)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(AppTheme.primaryText)

                    if let status = user?.subscriptionStatus {
                        Text(status.displayLabel.uppercased())
                            .font(.system(size: 11, weight: .bold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(status.badgeColor.opacity(0.2))
                            .foregroundStyle(status.badgeColor)
                            .clipShape(Capsule())
                    }
                }
            }

            Spacer()

            Button {
                Task { await openStripePortal() }
            } label: {
                HStack(spacing: 4) {
                    if isLoadingPortal {
                        ProgressView()
                            .controlSize(.small)
                            .tint(AppTheme.accent)
                    } else {
                        Text("Manage")
                            .font(.system(size: 15, weight: .semibold))
                    }
                }
                .foregroundStyle(AppTheme.accent)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(AppTheme.accent.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .disabled(isLoadingPortal)
        }
        .padding(16)
        .kinexCard(cornerRadius: 16)
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 8) {
            Text("Choose Your Plan")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(AppTheme.primaryText)

            Text("Unlock advanced features and accelerate your fitness journey")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(AppTheme.secondaryText)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 4)
    }

    // MARK: - Tier Card

    private func tierCard(_ tier: TierDefinition) -> some View {
        let isCurrent = tier.tier == currentTier
        let isUpgrade = tier.tier.sortOrder > currentTier.sortOrder
        let isLoading = loadingTier == tier.tier

        return VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(tier.name)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(AppTheme.primaryText)

                        if isCurrent {
                            Text("CURRENT")
                                .font(.system(size: 11, weight: .bold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(AppTheme.statStreak.opacity(0.2))
                                .foregroundStyle(AppTheme.statStreak)
                                .clipShape(Capsule())
                        }
                    }

                    if let price = tier.monthlyPrice {
                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            Text(price)
                                .font(.system(size: 26, weight: .bold))
                                .foregroundStyle(AppTheme.primaryText)
                            Text("/mo")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(AppTheme.secondaryText)
                        }
                    } else {
                        Text("Free")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundStyle(AppTheme.primaryText)
                    }
                }

                Spacer()

                if tier.isPopular {
                    Text("Most Popular")
                        .font(.system(size: 12, weight: .bold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(AppTheme.accent)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                }
            }

            Rectangle()
                .fill(AppTheme.separator)
                .frame(height: 1)

            VStack(alignment: .leading, spacing: 10) {
                if let inherits = tier.inheritsFrom {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(AppTheme.accent)
                        Text("Everything in \(inherits)")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(AppTheme.accent)
                    }
                    .padding(.bottom, 2)
                }

                ForEach(tier.features, id: \.self) { feature in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(AppTheme.statStreak)
                            .frame(width: 18)
                            .padding(.top, 2)

                        Text(feature)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(AppTheme.secondaryText)
                    }
                }
            }

            if tier.tier != .free {
                if isCurrent {
                    Button {
                        Task { await openStripePortal() }
                    } label: {
                        HStack(spacing: 6) {
                            if isLoadingPortal {
                                ProgressView()
                                    .controlSize(.small)
                                    .tint(AppTheme.primaryText)
                            }
                            Text("Manage Subscription")
                        }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(AppTheme.primaryText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(AppTheme.cardBackgroundElevated)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(AppTheme.cardBorder, lineWidth: 1)
                        }
                    }
                    .disabled(isLoadingPortal)
                } else if isUpgrade {
                    Button {
                        Task { await startCheckout(tier: tier.tier) }
                    } label: {
                        HStack(spacing: 6) {
                            if isLoading {
                                ProgressView()
                                    .controlSize(.small)
                                    .tint(.white)
                            }
                            Text("Upgrade to \(tier.name)")
                        }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(tier.isPopular ? AppTheme.accent : AppTheme.accent.opacity(0.85))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .shadow(color: tier.isPopular ? AppTheme.accent.opacity(0.3) : .clear,
                                radius: tier.isPopular ? 12 : 0, y: 4)
                    }
                    .disabled(isLoading)
                } else {
                    Button {
                        Task { await openStripePortal() }
                    } label: {
                        Text("Change Plan")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(AppTheme.secondaryText)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(AppTheme.cardBackgroundElevated)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(AppTheme.cardBorder, lineWidth: 1)
                            }
                    }
                    .disabled(isLoadingPortal)
                }
            }
        }
        .padding(20)
        .kinexCard(cornerRadius: 18, fill: tier.isPopular
                   ? AppTheme.cardBackgroundElevated
                   : AppTheme.cardBackground)
        .overlay {
            if tier.isPopular {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(AppTheme.accent.opacity(0.4), lineWidth: 1.5)
            }
        }
    }

    // MARK: - Footer

    private var restoreAndLegalFooter: some View {
        VStack(spacing: 14) {
            Button {
                if let url = URL(string: "https://kinexfit.com/subscription") {
                    UIApplication.shared.open(url)
                }
            } label: {
                Text("Manage on Web")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(AppTheme.accent)
            }

            HStack(spacing: 16) {
                Link("Terms of Service", destination: AppLinks.termsOfService)
                Text("|")
                    .foregroundStyle(AppTheme.tertiaryText)
                Link("Privacy Policy", destination: AppLinks.privacyPolicy)
            }
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(AppTheme.secondaryText)
        }
        .padding(.top, 8)
        .padding(.bottom, 16)
    }

    // MARK: - Data Loading

    private func loadUser() async {
        guard let environment = AppState.shared?.environment else { return }
        user = try? await environment.userRepository.getCurrentUser()
    }

    // MARK: - Stripe Actions

    private func startCheckout(tier: SubscriptionTier) async {
        guard let apiClient = AppState.shared?.environment.apiClient else { return }
        loadingTier = tier
        defer { loadingTier = nil }

        do {
            let request = try APIRequest.stripeCheckout(tier: tier.rawValue)
            let response: StripeSessionResponse = try await apiClient.send(request)

            if let error = response.error {
                logger.error("Stripe checkout error: \(error, privacy: .public)")
                errorMessage = error
                showError = true
                return
            }

            guard let urlString = response.url, let url = URL(string: urlString) else {
                errorMessage = "Could not create checkout session. Please try again."
                showError = true
                return
            }

            await MainActor.run {
                UIApplication.shared.open(url)
            }
        } catch {
            logger.error("Stripe checkout failed: \(error.localizedDescription, privacy: .public)")
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func openStripePortal() async {
        guard let apiClient = AppState.shared?.environment.apiClient else { return }
        isLoadingPortal = true
        defer { isLoadingPortal = false }

        do {
            let request = APIRequest.stripePortal()
            let response: StripeSessionResponse = try await apiClient.send(request)

            if let error = response.error {
                logger.error("Stripe portal error: \(error, privacy: .public)")
                errorMessage = error
                showError = true
                return
            }

            guard let urlString = response.url, let url = URL(string: urlString) else {
                errorMessage = "Could not open subscription management. Please try again."
                showError = true
                return
            }

            await MainActor.run {
                UIApplication.shared.open(url)
            }
        } catch {
            logger.error("Stripe portal failed: \(error.localizedDescription, privacy: .public)")
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

// MARK: - Tier Definitions

private struct TierDefinition: Identifiable {
    let tier: SubscriptionTier
    let name: String
    let monthlyPrice: String?
    let isPopular: Bool
    let inheritsFrom: String?
    let features: [String]

    var id: String { tier.rawValue }

    static let all: [TierDefinition] = [
        TierDefinition(
            tier: .free,
            name: "Free",
            monthlyPrice: nil,
            isPopular: false,
            inheritsFrom: nil,
            features: [
                "Unlimited workouts",
                "8 scans per month",
                "1 AI request per month",
                "90-day history",
                "Basic workout tracking",
                "Calendar view",
                "Basic timers"
            ]
        ),
        TierDefinition(
            tier: .core,
            name: "Core",
            monthlyPrice: "$8.99",
            isPopular: false,
            inheritsFrom: "Free",
            features: [
                "12 scans per month",
                "10 AI requests per month",
                "Unlimited history",
                "PR tracking",
                "Body metrics",
                "Basic analytics",
                "Calendar scheduling"
            ]
        ),
        TierDefinition(
            tier: .pro,
            name: "Pro",
            monthlyPrice: "$13.99",
            isPopular: true,
            inheritsFrom: "Core",
            features: [
                "60 scans per month",
                "30 AI requests per month",
                "Advanced analytics",
                "Volume trends & PR progression",
                "1RM calculations",
                "Workout templates",
                "Export data"
            ]
        ),
        TierDefinition(
            tier: .elite,
            name: "Elite",
            monthlyPrice: "$24.99",
            isPopular: false,
            inheritsFrom: "Pro",
            features: [
                "100 AI requests per month",
                "Priority support (24-hour response)",
                "Early access to new features",
                "Custom workout templates",
                "API access (coming soon)",
                "Workout sharing"
            ]
        )
    ]
}

// MARK: - SubscriptionTier Sort Order

private extension SubscriptionTier {
    var sortOrder: Int {
        switch self {
        case .free: return 0
        case .core: return 1
        case .pro: return 2
        case .elite: return 3
        }
    }
}

// MARK: - SubscriptionStatus Display Helpers

private extension SubscriptionStatus {
    var displayLabel: String {
        switch self {
        case .active: return "Active"
        case .canceled: return "Canceled"
        case .pastDue: return "Past Due"
        case .trialing: return "Trial"
        }
    }

    var badgeColor: Color {
        switch self {
        case .active, .trialing: return AppTheme.statStreak
        case .canceled: return AppTheme.warning
        case .pastDue: return AppTheme.error
        }
    }
}

// MARK: - Preview

#Preview {
    PaywallView()
}
