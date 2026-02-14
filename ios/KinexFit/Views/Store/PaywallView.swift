import SwiftUI
import StoreKit

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var storeManager: StoreManager

    @State private var selectedProduct: Product?
    @State private var isPurchasing = false
    @State private var errorMessage: String?
    @State private var showError = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: "star.circle.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(.yellow)

                        Text("Upgrade to Premium")
                            .font(.largeTitle)
                            .fontWeight(.bold)

                        Text("Unlock advanced features and boost your fitness journey")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top)

                    // Feature Comparison
                    VStack(spacing: 16) {
                        Text("Choose Your Plan")
                            .font(.headline)

                        // Tier Cards
                        ForEach(storeManager.products, id: \.id) { product in
                            TierCard(
                                product: product,
                                isSelected: selectedProduct?.id == product.id,
                                onSelect: {
                                    selectedProduct = product
                                }
                            )
                        }

                        if storeManager.products.isEmpty {
                            ProgressView("Loading subscriptions...")
                                .padding()
                        }
                    }

                    // Feature Matrix
                    FeatureMatrix()

                    // Purchase Button
                    if let selectedProduct {
                        Button {
                            Task {
                                await purchase(selectedProduct)
                            }
                        } label: {
                            HStack {
                                if isPurchasing {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Text("Subscribe for \(selectedProduct.displayPrice)")
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundStyle(.white)
                            .fontWeight(.semibold)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .disabled(isPurchasing)
                        .padding(.horizontal)
                    }

                    // Restore Purchases
                    Button {
                        Task {
                            await restorePurchases()
                        }
                    } label: {
                        Text("Restore Purchases")
                            .font(.subheadline)
                            .foregroundStyle(.blue)
                    }
                    .disabled(isPurchasing)

                    // Legal Links
                    HStack(spacing: 16) {
                        Link("Terms of Service", destination: URL(string: "https://kinexfit.com/terms")!)
                        Text("•")
                            .foregroundStyle(.secondary)
                        Link("Privacy Policy", destination: URL(string: "https://kinexfit.com/privacy")!)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.bottom)
                }
                .padding()
            }
            .navigationTitle("Premium")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "An error occurred")
            }
        }
        .task {
            await storeManager.loadProducts()
            // Pre-select Pro tier as recommended
            if let proProduct = storeManager.products.first(where: { $0.id == ProductID.proMonthly.rawValue }) {
                selectedProduct = proProduct
            }
        }
    }

    // MARK: - Purchase

    private func purchase(_ product: Product) async {
        isPurchasing = true
        defer { isPurchasing = false }

        do {
            let transaction = try await storeManager.purchase(product)
            if transaction != nil {
                // Purchase successful
                dismiss()
            }
        } catch StoreError.purchaseCancelled {
            // User cancelled, no error message needed
            return
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func restorePurchases() async {
        isPurchasing = true
        defer { isPurchasing = false }

        await storeManager.restorePurchases()

        if storeManager.hasActiveSubscription {
            dismiss()
        } else {
            errorMessage = "No previous purchases found"
            showError = true
        }
    }
}

// MARK: - Tier Card

struct TierCard: View {
    let product: Product
    let isSelected: Bool
    let onSelect: () -> Void

    private var productID: ProductID? {
        ProductID(rawValue: product.id)
    }

    private var isRecommended: Bool {
        product.id == ProductID.proMonthly.rawValue
    }

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(productID?.displayName ?? "Unknown")
                            .font(.title2)
                            .fontWeight(.bold)

                        Text(product.displayPrice + "/month")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if isRecommended {
                        Text("Recommended")
                            .font(.caption)
                            .fontWeight(.medium)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.yellow)
                            .foregroundStyle(.black)
                            .clipShape(Capsule())
                    }
                }

                // Features
                VStack(alignment: .leading, spacing: 8) {
                    if let features = featuresForProduct(productID) {
                        ForEach(features, id: \.self) { feature in
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                    .font(.caption)
                                Text(feature)
                                    .font(.subheadline)
                            }
                        }
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.blue.opacity(0.1) : Color(.systemGray6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }

    private func featuresForProduct(_ productID: ProductID?) -> [String]? {
        switch productID {
        case .coreMonthly:
            return [
                "12 scans per month",
                "10 AI requests per month",
                "Unlimited workout history",
                "Basic analytics"
            ]
        case .proMonthly:
            return [
                "60 scans per month",
                "30 AI requests per month",
                "Advanced analytics",
                "Progress tracking",
                "Export workouts"
            ]
        case .eliteMonthly:
            return [
                "120 scans per month",
                "100 AI requests per month",
                "Priority support",
                "All Pro features",
                "Custom workout programs"
            ]
        default:
            return nil
        }
    }
}

// MARK: - Feature Matrix

private struct FeatureMatrix: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("All Plans Include")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                FeatureRow(text: "Offline-first workout tracking")
                FeatureRow(text: "OCR workout scanning")
                FeatureRow(text: "Instagram import")
                FeatureRow(text: "Body metrics tracking")
                FeatureRow(text: "Cloud sync across devices")
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
}

private struct FeatureRow: View {
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark")
                .foregroundStyle(.green)
                .font(.caption)
            Text(text)
                .font(.subheadline)
        }
    }
}

// MARK: - Preview

#Preview {
    PaywallView()
        .environmentObject(StoreManager.preview)
}
