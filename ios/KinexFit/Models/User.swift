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
    var scanQuotaUsed: Int
    var aiQuotaUsed: Int
    var onboardingCompleted: Bool
    var updatedAt: Date

    /// Scan quota limit derived from subscription tier
    var scanQuotaLimit: Int {
        subscriptionTier.scanLimit
    }

    /// AI quota limit derived from subscription tier
    var aiQuotaLimit: Int {
        switch subscriptionTier {
        case .free: return 5
        case .core: return 20
        case .pro: return 100
        case .elite: return .max
        }
    }

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

    var scanLimit: Int {
        switch self {
        case .free: return 8
        case .core: return 12
        case .pro: return 60
        case .elite: return .max
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
        case scanQuotaUsed, aiQuotaUsed
        case onboardingCompleted
        case updatedAt
    }

    init(row: Row) {
        id = row[Columns.id]
        email = row[Columns.email]
        firstName = row[Columns.firstName]
        lastName = row[Columns.lastName]
        subscriptionTier = SubscriptionTier(rawValue: row[Columns.subscriptionTier] ?? "free") ?? .free
        subscriptionStatus = (row[Columns.subscriptionStatus] as String?).flatMap { SubscriptionStatus(rawValue: $0) }
        scanQuotaUsed = row[Columns.scanQuotaUsed]
        aiQuotaUsed = row[Columns.aiQuotaUsed]
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
        container[Columns.scanQuotaUsed] = scanQuotaUsed
        container[Columns.aiQuotaUsed] = aiQuotaUsed
        container[Columns.onboardingCompleted] = onboardingCompleted
        container[Columns.updatedAt] = updatedAt
    }
}
