import Foundation
import StoreKit
import OSLog

private let logger = Logger(subsystem: "com.kinex.fit", category: "PurchaseValidator")

/// Validates App Store purchases with backend
final class PurchaseValidator {
    private let apiClient: APIClient
    private let userRepository: UserRepository

    init(apiClient: APIClient, userRepository: UserRepository) {
        self.apiClient = apiClient
        self.userRepository = userRepository
    }

    /// Validate a transaction with the backend
    func validate(_ transaction: Transaction) async throws {
        logger.info("Validating transaction: \\(transaction.id)")

        // Get the receipt data
        guard let receiptData = try? await getReceiptData(for: transaction) else {
            logger.error("Failed to get receipt data for transaction: \\(transaction.id)")
            throw StoreError.failedVerification
        }

        // Create validation request
        let request = try APIRequest.json(
            path: "/api/mobile/subscriptions/validate",
            method: .post,
            body: ValidateReceiptRequest(
                transactionId: String(transaction.id),
                productId: transaction.productID,
                receiptData: receiptData
            )
        )

        // Send to backend
        let response: ValidateReceiptResponse = try await apiClient.send(request)

        logger.info("Receipt validated successfully. New tier: \\(response.subscriptionTier)")

        // Update local user with new subscription info
        try await userRepository.updateSubscription(
            tier: response.subscriptionTier,
            status: response.subscriptionStatus,
            expiresAt: response.subscriptionExpiresAt
        )
    }

    // MARK: - Receipt Data

    private func getReceiptData(for transaction: Transaction) async throws -> String {
        // For StoreKit 2, we use the transaction's JWS representation
        // This is a cryptographically signed receipt that the backend can verify with Apple
        guard let appStoreReceiptURL = Bundle.main.appStoreReceiptURL,
              FileManager.default.fileExists(atPath: appStoreReceiptURL.path) else {
            logger.error("App Store receipt not found")
            throw StoreError.failedVerification
        }

        let receiptData = try Data(contentsOf: appStoreReceiptURL)
        return receiptData.base64EncodedString()
    }
}

// MARK: - Request/Response Models

struct ValidateReceiptRequest: Codable {
    let transactionId: String
    let productId: String
    let receiptData: String
}

struct ValidateReceiptResponse: Codable {
    let subscriptionTier: SubscriptionTier
    let subscriptionStatus: SubscriptionStatus
    let subscriptionExpiresAt: Date?
}

// MARK: - Preview

extension PurchaseValidator {
    static var preview: PurchaseValidator {
        let tokenStore = InMemoryTokenStore()
        let apiClient = APIClient(
            baseURL: URL(string: "https://kinexfit.com")!,
            tokenStore: tokenStore
        )
        return PurchaseValidator(
            apiClient: apiClient,
            userRepository: UserRepository(
                database: try! AppDatabase.inMemory(),
                apiClient: apiClient,
                tokenStore: tokenStore
            )
        )
    }
}
