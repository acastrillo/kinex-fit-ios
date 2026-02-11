import Foundation
import GRDB
import OSLog

private let logger = Logger(subsystem: "com.kinex.fit", category: "UserRepository")

/// Repository for user data operations
/// Handles local caching of user profile data
final class UserRepository {
    private let database: AppDatabase

    init(database: AppDatabase) {
        self.database = database
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
