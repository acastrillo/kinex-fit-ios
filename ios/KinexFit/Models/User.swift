import Foundation
import GRDB

/// User model representing the authenticated user
/// Maps to the `users` table in local database and matches backend API responses
struct User: Codable, Equatable, Identifiable {
    let id: String
    let email: String
    var firstName: String?
    var lastName: String?
    var subscriptionTier: SubscriptionTier
    var subscriptionStatus: SubscriptionStatus?
    var subscriptionExpiresAt: Date?
    var scanQuotaUsed: Int
    var scanQuotaLimit: Int
    var aiQuotaUsed: Int
    var aiQuotaLimit: Int
    var onboardingCompleted: Bool
    var updatedAt: Date

    var displayName: String {
        if let firstName, !firstName.isEmpty {
            if let lastName, !lastName.isEmpty {
                return "\(firstName) \(lastName)"
            }
            return firstName
        }
        return email
    }
}

// MARK: - Subscription Types

enum SubscriptionTier: String, Codable, CaseIterable {
    case free
    case core
    case pro
    case elite

    var displayName: String {
        switch self {
        case .free: return "Free"
        case .core: return "Core"
        case .pro: return "Pro"
        case .elite: return "Elite"
        }
    }

    /// Default scan quota limit per tier (fallback when server hasn't provided limits yet)
    var defaultScanLimit: Int {
        switch self {
        case .free: return 2
        case .core: return 5
        case .pro: return 20
        case .elite: return .max
        }
    }

    /// Default AI quota limit per tier (fallback when server hasn't provided limits yet)
    var defaultAILimit: Int {
        switch self {
        case .free: return 0
        case .core: return 10
        case .pro: return 30
        case .elite: return 100
        }
    }
}

enum SubscriptionStatus: String, Codable {
    case active
    case canceled
    case pastDue = "past_due"
    case trialing
}

// MARK: - GRDB Conformance

extension User: FetchableRecord, PersistableRecord {
    static let databaseTableName = "users"

    enum Columns: String, ColumnExpression {
        case id, email, firstName, lastName
        case subscriptionTier = "tier"
        case subscriptionStatus
        case subscriptionExpiresAt
        case scanQuotaUsed, scanQuotaLimit
        case aiQuotaUsed, aiQuotaLimit
        case onboardingCompleted
        case updatedAt
    }

    init(row: Row) {
        id = row[Columns.id]
        email = row[Columns.email]
        firstName = row[Columns.firstName]
        lastName = row[Columns.lastName]
        let tier = SubscriptionTier(rawValue: row[Columns.subscriptionTier] ?? "free") ?? .free
        subscriptionTier = tier
        subscriptionStatus = (row[Columns.subscriptionStatus] as String?).flatMap { SubscriptionStatus(rawValue: $0) }
        subscriptionExpiresAt = row[Columns.subscriptionExpiresAt]
        scanQuotaUsed = row[Columns.scanQuotaUsed]
        scanQuotaLimit = row[Columns.scanQuotaLimit] ?? tier.defaultScanLimit
        aiQuotaUsed = row[Columns.aiQuotaUsed]
        aiQuotaLimit = row[Columns.aiQuotaLimit] ?? tier.defaultAILimit
        onboardingCompleted = row[Columns.onboardingCompleted] ?? false
        updatedAt = row[Columns.updatedAt]
    }

    func encode(to container: inout PersistenceContainer) {
        container[Columns.id] = id
        container[Columns.email] = email
        container[Columns.firstName] = firstName
        container[Columns.lastName] = lastName
        container[Columns.subscriptionTier] = subscriptionTier.rawValue
        container[Columns.subscriptionStatus] = subscriptionStatus?.rawValue
        container[Columns.subscriptionExpiresAt] = subscriptionExpiresAt
        container[Columns.scanQuotaUsed] = scanQuotaUsed
        container[Columns.scanQuotaLimit] = scanQuotaLimit
        container[Columns.aiQuotaUsed] = aiQuotaUsed
        container[Columns.aiQuotaLimit] = aiQuotaLimit
        container[Columns.onboardingCompleted] = onboardingCompleted
        container[Columns.updatedAt] = updatedAt
    }
}
