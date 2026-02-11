import Foundation

/// Product identifiers for Kinex Fit subscriptions
/// These must match the product IDs configured in App Store Connect
enum ProductID: String, CaseIterable {
    case coreMonthly = "com.kinex.fit.core.monthly"
    case proMonthly = "com.kinex.fit.pro.monthly"
    case eliteMonthly = "com.kinex.fit.elite.monthly"

    /// Display name for the subscription tier
    var displayName: String {
        switch self {
        case .coreMonthly: return "Core"
        case .proMonthly: return "Pro"
        case .eliteMonthly: return "Elite"
        }
    }

    /// Monthly price (will be replaced by actual App Store pricing)
    var price: String {
        switch self {
        case .coreMonthly: return "$8.99"
        case .proMonthly: return "$13.99"
        case .eliteMonthly: return "$19.99"
        }
    }

    /// Subscription tier mapping
    var tier: SubscriptionTier {
        switch self {
        case .coreMonthly: return .core
        case .proMonthly: return .pro
        case .eliteMonthly: return .elite
        }
    }
}
