import Foundation
import StoreKit
import OSLog

private let logger = Logger(subsystem: "com.kinex.fit", category: "StoreManager")

enum StoreError: Error, LocalizedError {
    case failedVerification
    case productNotFound
    case purchaseFailed
    case purchaseCancelled
    case unknownError

    var errorDescription: String? {
        switch self {
        case .failedVerification: return "Transaction verification failed"
        case .productNotFound: return "Product not found"
        case .purchaseFailed: return "Purchase failed"
        case .purchaseCancelled: return "Purchase was cancelled"
        case .unknownError: return "An unknown error occurred"
        }
    }
}

@MainActor
final class StoreManager: ObservableObject {
    @Published private(set) var products: [Product] = []
    @Published private(set) var purchasedProductIDs: Set<String> = []
    @Published private(set) var isLoading = false

    private let purchaseValidator: PurchaseValidator
    private var updateListenerTask: Task<Void, Never>?

    init(purchaseValidator: PurchaseValidator) {
        self.purchaseValidator = purchaseValidator
        updateListenerTask = listenForTransactions()
    }

    deinit {
        updateListenerTask?.cancel()
    }

    // MARK: - Load Products

    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let productIDs = ProductID.allCases.map(\.rawValue)
            products = try await Product.products(for: productIDs)
            logger.info("Loaded \\(self.products.count) products from App Store")

            // Load current subscriptions
            await updatePurchasedProducts()
        } catch {
            logger.error("Failed to load products: \\(error.localizedDescription)")
        }
    }

    // MARK: - Purchase

    func purchase(_ product: Product) async throws -> Transaction? {
        logger.info("Initiating purchase for product: \\(product.id)")

        let result = try await product.purchase()

        switch result {
        case .success(let verification):
            // Verify the transaction
            let transaction = try checkVerified(verification)

            // Validate with backend
            try await purchaseValidator.validate(transaction)

            // Update purchased products
            await updatePurchasedProducts()

            // Finish the transaction
            await transaction.finish()

            logger.info("Purchase successful for product: \\(product.id)")
            return transaction

        case .userCancelled:
            logger.info("Purchase cancelled by user")
            throw StoreError.purchaseCancelled

        case .pending:
            logger.info("Purchase pending approval")
            return nil

        @unknown default:
            logger.error("Unknown purchase result")
            throw StoreError.unknownError
        }
    }

    // MARK: - Restore Purchases

    func restorePurchases() async {
        logger.info("Restoring purchases")

        // Sync with App Store
        try? await AppStore.sync()

        // Update purchased products
        await updatePurchasedProducts()
    }

    // MARK: - Transaction Listener

    private func listenForTransactions() -> Task<Void, Never> {
        Task.detached { [weak self] in
            // Listen for transaction updates
            for await result in Transaction.updates {
                guard let self else { return }

                do {
                    let transaction = try await MainActor.run {
                        try self.checkVerified(result)
                    }

                    // Validate with backend
                    try await self.purchaseValidator.validate(transaction)

                    // Update purchased products
                    await self.updatePurchasedProducts()

                    // Finish the transaction
                    await transaction.finish()

                    logger.info("Transaction update processed: \\(transaction.id)")
                } catch {
                    logger.error("Failed to process transaction update: \\(error.localizedDescription)")
                }
            }
        }
    }

    // MARK: - Update Purchased Products

    private func updatePurchasedProducts() async {
        var purchasedIDs: Set<String> = []

        // Check all subscription groups
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)

                // Only include active subscriptions
                if transaction.revocationDate == nil {
                    purchasedIDs.insert(transaction.productID)
                }
            } catch {
                logger.error("Failed to verify entitlement: \\(error.localizedDescription)")
            }
        }

        purchasedProductIDs = purchasedIDs
        logger.info("Updated purchased products: \\(purchasedIDs)")
    }

    // MARK: - Verification

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            logger.error("Transaction verification failed")
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }

    // MARK: - Current Subscription

    /// Get the current active subscription tier
    var currentSubscription: ProductID? {
        // Check for highest tier first (Elite > Pro > Core)
        if purchasedProductIDs.contains(ProductID.eliteMonthly.rawValue) {
            return .eliteMonthly
        } else if purchasedProductIDs.contains(ProductID.proMonthly.rawValue) {
            return .proMonthly
        } else if purchasedProductIDs.contains(ProductID.coreMonthly.rawValue) {
            return .coreMonthly
        }
        return nil
    }

    /// Check if user has an active subscription
    var hasActiveSubscription: Bool {
        currentSubscription != nil
    }

    /// Get the subscription tier
    var subscriptionTier: SubscriptionTier {
        currentSubscription?.tier ?? .free
    }
}

// MARK: - Preview

extension StoreManager {
    static var preview: StoreManager {
        StoreManager(purchaseValidator: PurchaseValidator.preview)
    }
}
