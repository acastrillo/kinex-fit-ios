import Foundation
import StoreKit
import OSLog

private let logger = Logger(subsystem: "com.kinex.fit", category: "StoreKit")

/// Manages in-app purchases using StoreKit 2
@MainActor
final class StoreKitManager: NSObject, ObservableObject {
    @Published var products: [Product] = []
    @Published var purchasedProductIds: Set<String> = []
    @Published var isLoading: Bool = false
    @Published var error: Error?

    static let shared = StoreKitManager()

    // MARK: - Product IDs

    static let productIds = [
        "com.kinex.fit.core",      // Core tier subscription
        "com.kinex.fit.pro",       // Pro tier subscription
        "com.kinex.fit.elite",     // Elite tier subscription
        "com.kinex.fit.ai_boost",  // AI generation boost
    ]

    // MARK: - Initialization

    override init() {
        super.init()
        Task {
            await fetchProducts()
            await checkPurchases()
            await listenForTransactions()
        }
    }

    // MARK: - Product Fetching

    /// Fetch products from App Store
    func fetchProducts() async {
        isLoading = true
        error = nil

        do {
            let products = try await Product.products(for: Self.productIds)
            self.products = products.sorted { $0.displayPrice < $1.displayPrice }
            logger.info("Fetched \(products.count) products from App Store")
        } catch {
            self.error = error
            logger.error("Failed to fetch products: \(error.localizedDescription)")
        }

        isLoading = false
    }

    // MARK: - Purchases

    /// Purchase a product
    func purchase(_ product: Product) async -> Bool {
        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                purchasedProductIds.insert(product.id)
                logger.info("Purchase successful: \(product.id)")
                return true

            case .userCancelled:
                logger.info("User cancelled purchase")
                return false

            case .pending:
                logger.info("Purchase pending")
                return false

            @unknown default:
                logger.warning("Unknown purchase result")
                return false
            }
        } catch {
            self.error = error
            logger.error("Purchase failed: \(error.localizedDescription)")
            return false
        }
    }

    /// Check if a product is purchased
    func isPurchased(_ productId: String) -> Bool {
        purchasedProductIds.contains(productId)
    }

    // MARK: - Transaction Handling

    /// Listen for transaction updates
    private func listenForTransactions() async {
        for await result in Transaction.updates {
            do {
                let transaction = try checkVerified(result)

                switch transaction.productType {
                case .autoRenewable:
                    await handleAutoRenewableSubscription(transaction)
                case .nonConsumable, .nonRenewable, .consumable:
                    purchasedProductIds.insert(transaction.productID)
                }

                await transaction.finish()
            } catch {
                logger.error("Transaction verification failed: \(error.localizedDescription)")
            }
        }
    }

    /// Handle auto-renewable subscription transactions
    private func handleAutoRenewableSubscription(_ transaction: Transaction) async {
        if transaction.revocationDate == nil {
            purchasedProductIds.insert(transaction.productID)
            logger.info("Subscription active: \(transaction.productID)")
        } else {
            purchasedProductIds.remove(transaction.productID)
            logger.info("Subscription revoked: \(transaction.productID)")
        }
    }

    /// Restore purchases
    func restorePurchases() async {
        isLoading = true
        error = nil

        do {
            try await AppStore.sync()
            await checkPurchases()
            logger.info("Purchases restored")
        } catch {
            self.error = error
            logger.error("Failed to restore purchases: \(error.localizedDescription)")
        }

        isLoading = false
    }

    // MARK: - Purchase Checking

    /// Check current purchases
    private func checkPurchases() async {
        var purchased = Set<String>()

        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                purchased.insert(transaction.productID)
            } catch {
                logger.error("Failed to verify transaction: \(error.localizedDescription)")
            }
        }

        purchasedProductIds = purchased
        logger.info("Checked purchases: \(purchased.count) active entitlements")
    }

    // MARK: - Verification

    /// Verify transaction signature
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreKitError.unverifiedTransaction
        case .verified(let safe):
            return safe
        }
    }
}

// MARK: - StoreKit Errors

enum StoreKitError: LocalizedError {
    case unverifiedTransaction

    var errorDescription: String? {
        switch self {
        case .unverifiedTransaction:
            return "Transaction could not be verified"
        }
    }
}

// MARK: - Product Extensions

extension Product {
    var displayPrice: String {
        "\(displayName) - \(price)"
    }

    var isTrial: Bool {
        trialPeriod != nil
    }

    var trialDuration: String? {
        guard let period = trialPeriod else { return nil }
        return "\(period.value) \(period.unit.displayName)"
    }
}

extension Product.SubscriptionPeriod.Unit {
    var displayName: String {
        switch self {
        case .day: return "days"
        case .week: return "weeks"
        case .month: return "months"
        case .year: return "years"
        @unknown default: return "period"
        }
    }
}
