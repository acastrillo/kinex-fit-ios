import Foundation
import GRDB
import OSLog

private let logger = Logger(subsystem: "com.kinex.fit", category: "UserRepository")

/// Repository for user data operations
/// Handles local caching of user profile data
final class UserRepository {
    private let database: AppDatabase
    private let apiClient: APIClient
    private let tokenStore: TokenStore

    init(database: AppDatabase, apiClient: APIClient, tokenStore: TokenStore) {
        self.database = database
        self.apiClient = apiClient
        self.tokenStore = tokenStore
    }

    // MARK: - Read Operations

    /// Get the current user from local storage
    func getCurrentUser() async throws -> User? {
        try await database.dbQueue.read { db in
            try User.fetchOne(db)
        }
    }

    // MARK: - Write Operations

    /// Save or update user in local storage
    func save(_ user: User) async throws {
        try await database.dbQueue.write { db in
            try user.save(db)
        }
        logger.debug("User saved: \(user.id)")
    }

    /// Update user quotas after an operation
    func incrementScanQuota() async throws {
        try await database.dbQueue.write { db in
            try db.execute(
                sql: "UPDATE users SET scanQuotaUsed = scanQuotaUsed + 1, updatedAt = ?",
                arguments: [Date()]
            )
        }
        logger.debug("Scan quota incremented")
    }

    /// Update user subscription information
    func updateSubscription(
        tier: SubscriptionTier,
        status: SubscriptionStatus,
        expiresAt: Date?
    ) async throws {
        try await database.dbQueue.write { db in
            try db.execute(
                sql: """
                UPDATE users
                SET subscriptionTier = ?,
                    subscriptionStatus = ?,
                    subscriptionExpiresAt = ?,
                    updatedAt = ?
                """,
                arguments: [tier.rawValue, status.rawValue, expiresAt, Date()]
            )
        }
        logger.info("Subscription updated: tier=\(tier.rawValue), status=\(status.rawValue)")
    }

    /// Clear all user data (for sign out)
    func clear() async throws {
        try await database.dbQueue.write { db in
            try User.deleteAll(db)
        }
        logger.debug("User data cleared")
    }

    /// Delete user account permanently
    /// This will:
    /// 1. Call backend API to delete user data from DynamoDB
    /// 2. Clear all local data (workouts, metrics, user info)
    /// 3. Clear authentication tokens (signs user out)
    func deleteAccount() async throws {
        logger.warning("Initiating account deletion")

        // Call backend to delete user data
        let request = APIRequest(path: "/api/mobile/user/delete", method: .delete)

        struct EmptyResponse: Decodable {}
        let _: EmptyResponse = try await apiClient.send(request)

        logger.info("Backend account deletion successful")

        // Clear all local data
        try await database.dbQueue.write { db in
            // Delete all workouts
            try db.execute(sql: "DELETE FROM workouts")

            // Delete all body metrics
            try db.execute(sql: "DELETE FROM body_metrics")

            // Delete all sync queue items
            try db.execute(sql: "DELETE FROM sync_queue")

            // Delete user data
            try db.execute(sql: "DELETE FROM users")

            // Delete settings
            try db.execute(sql: "DELETE FROM settings")

            logger.info("Local database cleared")
        }

        // Clear authentication tokens (signs user out)
        try tokenStore.clearAll()

        logger.warning("Account deletion complete")
    }

    // MARK: - Observation

    /// Observe user changes
    func observeCurrentUser() -> AsyncThrowingStream<User?, Error> {
        AsyncThrowingStream { continuation in
            let observation = ValueObservation.tracking { db in
                try User.fetchOne(db)
            }

            let cancellable = observation.start(
                in: database.dbQueue,
                scheduling: .immediate,
                onError: { error in
                    continuation.finish(throwing: error)
                },
                onChange: { user in
                    continuation.yield(user)
                }
            )

            continuation.onTermination = { _ in
                cancellable.cancel()
            }
        }
    }
}
